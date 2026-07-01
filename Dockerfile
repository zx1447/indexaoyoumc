# 傲游面板 Docker 镜像（Alpine 精简优化版·合规修改版）
# 多阶段构建：编译依赖与运行时环境分离，最终镜像极致精简
# 体积对比：Debian Slim 版约 300MB+，Alpine 版约 80-100MB

# ========== 阶段 1：依赖构建 ==========
FROM node:22-alpine AS deps

WORKDIR /app

COPY package.json ./

# 仅保留编译必需依赖
RUN apk add --no-cache python3 build-base ca-certificates \
    && npm install --omit=dev --no-audit --no-fund

# ========== 阶段 2：运行时镜像 ==========
FROM node:22-alpine AS runtime

WORKDIR /app

# 删除代理/路由/浏览器相关工具，仅保留基础证书与时区
RUN apk add --no-cache \
        ca-certificates \
        tzdata \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

COPY --from=deps /app/node_modules ./node_modules
COPY index.js ./

# 移除 firefox、sshx、alist、代理相关缓存目录，只保留程序基础目录
RUN mkdir -p /app/node_modules/.aoyou \
             /app/node_modules/.Error\ log \
             /app/node_modules/.RoamingMusic \
             /app/node_modules/.aoyouyingyong/.yingyongcf \
             /app/node_modules/.build-center \
             /app/node_modules/.cache

ENV SERVER_PORT=4237 \
    NODE_ENV=production \
    TZ=Asia/Shanghai

# 仅保留主面板端口，移除代理端口8080
EXPOSE 4237

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:4237/ || exit 1

CMD ["node", "--max-old-space-size=512", "index.js"]
