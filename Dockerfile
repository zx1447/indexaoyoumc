FROM node:22-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates curl wget unzip zip procps tzdata tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

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

ENTRYPOINT ["/usr/bin/tini", "--", "sh", "-c", "export SERVER_PORT=${SERVER_PORT:-${PORT:-4237}}; node keepalive.js & exec node index.js"]
CMD []
