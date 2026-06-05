#!/bin/bash
# =============================================================
# 阿里云 ECS (Ubuntu) 首次部署环境准备脚本
# 使用方式：SSH 登录服务器后执行
#   ssh root@39.97.238.25
#   然后复制以下全部命令粘贴执行
# =============================================================

set -e

echo "══════════════════════════════════════════"
echo "  [1/6] 更新系统包"
echo "══════════════════════════════════════════"
apt-get update -y && apt-get upgrade -y

echo ""
echo "══════════════════════════════════════════"
echo "  [2/6] 安装 Docker CE + Compose Plugin"
echo "══════════════════════════════════════════"

# 卸载旧版本（如有）
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 安装依赖
apt-get install -y ca-certificates curl gnupg lsb-release

# 添加 Docker 官方 GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# 添加 Docker apt 源
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker CE + Compose Plugin + Buildx
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# 启动 Docker 并设置开机自启
systemctl enable docker
systemctl start docker

echo ""
echo "Docker 版本信息："
docker --version
docker compose version

echo ""
echo "══════════════════════════════════════════"
echo "  [3/6] 创建部署目录"
echo "══════════════════════════════════════════"
mkdir -p /root/todolist
echo "部署目录：/root/todolist 已创建"

echo ""
echo "══════════════════════════════════════════"
echo "  [4/6] 配置防火墙（开放必要端口）"
echo "══════════════════════════════════════════"
# Ubuntu ufw 防火墙
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # 前端 HTTP
ufw allow 3000/tcp  # 后端 API
ufw --force enable

echo ""
echo "防火墙状态："
ufw status verbose

echo ""
echo "请同时在「阿里云控制台 -> ECS -> 安全组」中添加入方向规则："
echo "  协议  端口    授权对象      说明"
echo "  TCP   22      0.0.0.0/0     SSH 远程连接"
echo "  TCP   80      0.0.0.0/0     前端 HTTP 访问"
echo "  TCP   3000    0.0.0.0/0     后端 API 访问"

echo ""
echo "══════════════════════════════════════════"
echo "  [5/6] 生成 SSH 密钥对（供 GitHub Actions 免密登录）"
echo "══════════════════════════════════════════"
SSH_KEY_FILE="/root/.ssh/github_actions_deploy"

if [ ! -f "$SSH_KEY_FILE" ]; then
  mkdir -p /root/.ssh
  ssh-keygen -t ed25519 -C "github-actions-deploy" \
    -f "$SSH_KEY_FILE" -N ""
  echo "密钥对已生成"
else
  echo "密钥对已存在，跳过生成"
fi

# 将公钥追加到 authorized_keys
cat "${SSH_KEY_FILE}.pub" >> /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys
echo "公钥已加入 authorized_keys"

echo ""
echo "══════════════════════════════════════════"
echo "  [6/6] 预拉取 MySQL 基础镜像（加速首次部署）"
echo "══════════════════════════════════════════"
docker pull mysql:8.0
echo "MySQL 8.0 镜像已就绪"

echo ""
echo "══════════════════════════════════════════"
echo "  请将以下私钥内容复制到 GitHub Secrets"
echo "══════════════════════════════════════════"
echo ""
echo "  Secret 名称：ALIYUN_ECS_SSH_KEY"
echo ""
echo "  ============ 私钥内容开始 ============"
cat "$SSH_KEY_FILE"
echo "  ============ 私钥内容结束 ============"
echo ""
echo "  复制时必须包含 BEGIN 和 END 两行！"

echo ""
echo "══════════════════════════════════════════"
echo "  服务器环境准备完成！"
echo "══════════════════════════════════════════"
echo ""
echo "  接下来你需要做的："
echo "  1. 将上方私钥内容添加到 GitHub Secrets: ALIYUN_ECS_SSH_KEY"
echo "  2. 在 GitHub 仓库添加以下 Secrets："
echo "     - ALIYUN_ECS_IP          = 39.97.238.25"
echo "     - ALIYUN_ECS_USERNAME    = root"
echo "     - ALIYUN_ECS_SSH_KEY     = （上方的私钥内容）"
echo "     - MYSQL_ROOT_PASSWORD    = （你自定义的 MySQL 密码）"
echo "     - JWT_SECRET             = （你自定义的随机字符串）"
echo "  3. 推送代码到 main 分支，触发自动部署"
echo ""
