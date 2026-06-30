# 傲游面板 Docker 镜像（Alpine 精简优化版）
# 多阶段构建：编译依赖与运行时环境分离，最终镜像极致精简
# 体积对比：Debian Slim 版约 300MB+，Alpine 版约 80-100MB

# ========== 阶段 1：依赖构建 ==========
FROM node:22-alpine AS deps

WORKDIR /app

# 先复制 package.json，最大化利用 Docker 层缓存
COPY package.json ./

# 安装编译依赖（仅用于构建阶段，不进入最终运行镜像）
# - build-base: 集成 gcc/g++/make，满足 node-gyp 原生模块编译需求
# - python3: node-gyp 强制依赖
# - ca-certificates / curl: 网络证书与下载支持
RUN apk add --no-cache python3 build-base ca-certificates curl \
    && npm install --omit=dev --no-audit --no-fund

# ========== 阶段 2：运行时镜像 ==========
FROM node:22-alpine AS runtime

WORKDIR /app

# 安装运行时必需系统工具
# --no-cache 模式无本地索引缓存，天然避免冗余体积
RUN apk add --no-cache \
        ca-certificates \
        curl \
        wget \
        procps \
        iproute2 \
        net-tools \
        tzdata \
        fontconfig \
    # 设置时区为 Asia/Shanghai，与原版行为一致
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

# 从构建阶段复制已编译好的 node_modules
COPY --from=deps /app/node_modules ./node_modules

# 复制主程序文件
COPY index.js ./

# 创建数据与缓存目录（兼容原代码目录结构，支持 volume 挂载覆盖）
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

# 环境变量默认配置
ENV SERVER_PORT=4237 \
    NODE_ENV=production \
    TZ=Asia/Shanghai

# 暴露端口
# - 4237: 主面板端口
# - 8080: 代理服务端口（按需启用）
EXPOSE 4237 8080

# 健康检查（适配 SnapDeploy 自动监控与重启规则）
# 若面板提供 /health 专用健康检查端点，建议替换路径为 /health，检测更精准
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:4237/ || exit 1

# 启动命令（内存限制与原版保持一致）
CMD ["node", "--max-old-space-size=512", "index.js"]
