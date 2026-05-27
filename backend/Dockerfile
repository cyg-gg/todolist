FROM node:20-alpine

# 设置时区（可选，适合中文日志）
ENV TZ=Asia/Shanghai

WORKDIR /app

# 先拷贝 package 文件，利用 Docker 层缓存
COPY package*.json ./
RUN npm install --omit=dev --ignore-scripts

# 拷贝源码
COPY src ./src

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
