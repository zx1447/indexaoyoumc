# 傲游面板 Docker 镜像
# 多阶段构建：先用完整镜像装依赖，再用精简镜像运行

# ========== 阶段 1：安装依赖 ==========
FROM node:22-bookworm-slim AS deps

WORKDIR /app

# 先复制 package.json，利用 Docker 缓存
COPY package.json ./

# 安装依赖（包含 devDependencies，mineflayer 需要 node-gyp）
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    ca-certificates \
    curl \
    && npm install --omit=dev --no-audit --no-fund \
    && apt-get purge -y python3 make g++ && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# ========== 阶段 2：运行时镜像 ==========
FROM node:22-bookworm-slim AS runtime

WORKDIR /app

# 安装运行时需要的系统工具
# - ca-certificates: HTTPS 证书
# - curl: 健康检查 + 下载外部二进制（cloudflared/xray 等）
# - wget: 备用下载工具
# - procps: ps/top 命令（系统状态监控）
# - iproute2: ip 命令（网络配置）
# - net-tools: ifconfig/netstat
# - tzdata: 时区（Asia/Shanghai）
# - fontconfig: 字体配置（哪吒探针用）
RUN apt-get update && apt-get install -y --no-install-recommends \
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
