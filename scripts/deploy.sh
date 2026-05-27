#!/bin/bash
set -e
cd /root/todolist

# 加载镜像
docker load -i backend.tar
docker load -i frontend.tar

# 停止旧容器
docker-compose down 2>/dev/null || true

# 启动新容器
docker-compose up -d

# 健康检查
sleep 15
curl -sf http://localhost:3000/health || { echo "Health check failed"; exit 1; }
echo "Deployment successful"