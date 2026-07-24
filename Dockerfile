FROM node:22-slim

# 增加 build-essential 和 python3，防止 koffi 需要本地编译时报错
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl wget unzip zip procps tzdata tini build-essential python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json ./
# 安装依赖，并强制预装 koffi 防止运行时报错
RUN npm install --omit=dev && npm install koffi --no-save && npm cache clean --force

COPY index.js ./
COPY keepalive.js ./

RUN groupadd -r -g 1001 appuser \
    && useradd -r -g appuser -u 1001 -d /app -s /usr/sbin/nologin appuser \
    && chown -R 1001:1001 /app

ENV NODE_ENV=production \
    TZ=Asia/Shanghai \
    HOME=/app

EXPOSE 4237
EXPOSE 8080

VOLUME ["/app/node_modules"]

USER 1001:1001

# 恢复你原始的启动命令，不带进程伪装
ENTRYPOINT ["/usr/bin/tini", "--", "sh", "-c", "export SERVER_PORT=${SERVER_PORT:-${PORT:-4237}}; node keepalive.js & exec node index.js"]
CMD []
