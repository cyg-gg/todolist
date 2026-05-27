#!/bin/bash
set -e

SERVER_IP="182.92.116.65"
SERVER_USER="root"
PROJECT_NAME="todolist"

echo "=== 构建并部署 TodoList 到服务器 $SERVER_IP ==="

# 1. 构建前端
echo "[1/5] 构建前端..."
cd frontend
npm install
npm run build
cd ..

# 2. 打包项目
echo "[2/5] 打包项目..."
tar czf todolist-deploy.tar.gz todolist/

# 3. 上传到服务器
echo "[3/5] 上传到服务器..."
scp todolist-deploy.tar.gz $SERVER_USER@$SERVER_IP:/root/

# 4. 在服务器上部署
echo "[4/5] 在服务器上部署..."
ssh $SERVER_USER@$SERVER_IP << 'REMOTE'
cd /root
rm -rf todolist
tar xzf todolist-deploy.tar.gz
cd todolist

# 安装 Docker（如果未安装）
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
fi

# 安装 Docker Compose（如果未安装）
if ! command -v docker-compose &> /dev/null; then
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# 停止并清理旧容器
docker-compose down 2>/dev/null || true
docker system prune -f

# 构建并启动
docker-compose up -d --build

# 等待 MySQL 启动
sleep 15

# 查看状态
docker-compose ps
REMOTE

# 5. 清理本地临时文件
echo "[5/5] 清理临时文件..."
rm -f todolist-deploy.tar.gz

echo "=== 部署完成！==="
echo "访问地址: http://$SERVER_IP"
