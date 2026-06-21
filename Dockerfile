FROM node:18-alpine

# 安装系统依赖：curl 和 unzip (代码中通过 execSync 调用了它们)
RUN apk add --no-cache curl unzip bash

# 设置工作目录
WORKDIR /app

# 复制 package.json 并安装依赖
COPY package.json ./
RUN npm install --production

# 复制源代码
COPY index.js ./

# 设置环境变量
# 可选：如果需要修改默认端口，可以设置 SERVER_PORT
# ENV SERVER_PORT=4237

# 暴露端口
# 4237: Web 管理面板
# 8080: 代理服务器 (Cloudflared Tunnel 入口)
EXPOSE 4237 8080

# 启动应用
CMD ["node", "index.js"]
