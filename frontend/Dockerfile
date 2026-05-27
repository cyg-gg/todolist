# ── 阶段1：构建前端静态资源 ──────────────────────────────────
FROM node:20-alpine AS builder

ENV TZ=Asia/Shanghai

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

# 使用 .env.production（VITE_API_BASE_URL=/api）进行生产构建
RUN npm run build

# ── 阶段2：用 Nginx 托管静态资源 ──────────────────────────────
FROM nginx:1.26-alpine

ENV TZ=Asia/Shanghai

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:80 || exit 1

CMD ["nginx", "-g", "daemon off;"]
