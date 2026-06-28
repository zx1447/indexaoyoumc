# 傲游面板 Docker 镜像
# 多阶段构建：先用完整镜像装依赖，再用精简镜像运行
#
# 关键修复：
#   1. 在所有 apt-get 之前显式声明 DEBIAN_FRONTEND=noninteractive，
#      避免 tzdata / ca-certificates / openssl 触发 debconf 交互提示。
#      某些 PaaS 平台（Sealos、Render、Railway 等）会把 stderr 上的
#      debconf 警告当成构建失败，这里一次性消除。
#   2. 对 tzdata 预设时区参数，确保安装过程零交互。
#   3. 合并 apt 层并强制 -y --yes，进一步降低被中断的概率。

# ========== 阶段 1：安装依赖 ==========
FROM node:22-bookworm-slim AS deps

# 非交互模式（必须放在任何 apt-get 之前）
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    TERM=linux

WORKDIR /app

# 先复制 package.json，利用 Docker 缓存
COPY package.json ./

# 安装依赖（包含 devDependencies，mineflayer 需要 node-gyp）
# - 安装前先 dpkg-reconfigure 让 debconf 进入 silent 模式
# - 安装后立刻 purge 编译工具，回收空间
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        make \
        g++ \
        ca-certificates \
        curl \
    && npm install --omit=dev --no-audit --no-fund \
    && apt-get purge -y python3 make g++ \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ========== 阶段 2：运行时镜像 ==========
FROM node:22-bookworm-slim AS runtime

# 非交互模式（运行时也保留，防止后续 exec apt-get 时再次报错）
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    TERM=linux

WORKDIR /app

# 预设 tzdata 时区，避免 tzdata 包安装时触发交互
# 必须在 apt-get install tzdata 之前生效
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && echo "tzdata tzdata/Areas select Asia" | debconf-set-selections \
    && echo "tzdata tzdata/Zones/Asia select Shanghai" | debconf-set-selections

# 安装运行时需要的系统工具
# - ca-certificates: HTTPS 证书
# - curl: 健康检查 + 下载外部二进制（cloudflared/xray 等）
# - wget: 备用下载工具
# - procps: ps/top 命令（系统状态监控）
# - iproute2: ip 命令（网络配置）
# - net-tools: ifconfig/netstat
# - tzdata: 时区（Asia/Shanghai）
# - fontconfig: 字体配置（哪吒探针用）
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        procps \
        iproute2 \
        net-tools \
        tzdata \
        fontconfig \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 从 deps 阶段复制 node_modules
COPY --from=deps /app/node_modules ./node_modules

# 复制主程序
COPY index.js ./

# 创建数据目录（配置文件存放在 node_modules 下，跟原代码逻辑一致）
# 这些目录会被 volume 挂载覆盖，这里只是确保权限
RUN mkdir -p /app/node_modules/.aoyou \
             /app/node_modules/.Error\ log \
             /app/node_modules/.RoamingMusic \
             /app/node_modules/.aoyouyingyong/.yingyongcf \
             /app/node_modules/.build-center \
             /app/node_modules/.firefox \
             /app/node_modules/.alist \
             /app/node_modules/.sshx \
             /app/node_modules/.code-server \
             /app/node_modules/.cache

# 环境变量默认值
# 注意：DEBIAN_FRONTEND 保留为 noninteractive，避免容器内 exec apt-get 时报错
ENV SERVER_PORT=4237 \
    NODE_ENV=production \
    TZ=Asia/Shanghai

# 暴露端口
# - 4237: 主面板
# - 8080: 代理服务器（按需启动）
EXPOSE 4237 8080

# 健康检查（每 30 秒检查一次面板是否响应）
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:4237/ || exit 1

# 启动命令
CMD ["node", "--max-old-space-size=512", "index.js"]
