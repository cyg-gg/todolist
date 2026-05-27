# 阿里云 CI/CD 部署实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 GitHub 代码推送到 main 分支后，自动构建 Docker 镜像并部署到阿里云服务器，全程无需人工干预。

**Architecture:** GitHub Actions 工作流分两个 Job：build-and-upload（在 runner 构建镜像并上传到服务器）和 deploy（通过 SSH 在服务器执行加载镜像和启动容器）。前端代码通过 nginx 容器提供静态服务，后端通过 docker-compose 编排与 MySQL 一起运行。

**Tech Stack:** GitHub Actions, Docker, Docker Compose, SSH/SCP, Node.js, nginx

---

## 文件结构

```
.github/
├── workflows/
│   └── deploy.yml          # GitHub Actions 工作流
scripts/
└── deploy.sh               # 服务器端部署脚本（通过 tar 包分发）
```

**受影响的现有文件：**
- `docker-compose.yml` — 添加 `image:` 字段使 compose 使用预构建镜像
- `deploy.sh` — 替换为自动化版本

---

## Task 1: 创建 GitHub Actions 工作流文件

**Files:**
- Create: `.github/workflows/deploy.yml`

- [ ] **Step 1: 创建工作流文件**

```yaml
name: Deploy to Alibaba Cloud

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build backend image
        run: |
          docker build -t todolist-backend:latest ./backend

      - name: Save backend image
        run: docker save todolist-backend:latest -o backend.tar

      - name: Build frontend image
        run: |
          docker build -t todolist-frontend:latest ./frontend

      - name: Save frontend image
        run: docker save todolist-frontend:latest -o frontend.tar

      - name: Create deploy scripts tar
        run: |
          mkdir -p scripts
          cp docker-compose.yml scripts/
          tar czf deploy-scripts.tar.gz -C scripts docker-compose.yml

      - name: Upload to server
        uses: appleboy/scp-action@v0.1.10
        with:
          host: ${{ secrets.SERVER_IP }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          source: "backend.tar,frontend.tar,deploy-scripts.tar.gz"
          target: "/root/todolist-deploy/"

      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1.0.3
        with:
          host: ${{ secrets.SERVER_IP }}
          username: ${{ secrets.SERVER_USER }}
          key: ${{ secrets.SERVER_SSH_KEY }}
          script: |
            mkdir -p /root/todolist
            cd /root/todolist

            # 加载镜像
            docker load -i /root/todolist-deploy/backend.tar
            docker load -i /root/todolist-deploy/frontend.tar

            # 解压部署脚本
            tar xzf /root/todolist-deploy/deploy-scripts.tar.gz -C /root/todolist/

            # 生成 .env
            cat > /root/todolist/.env << 'ENVEOF'
MYSQL_ROOT_PASSWORD=${{ secrets.MYSQL_ROOT_PASSWORD }}
DB_HOST=mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=${{ secrets.MYSQL_ROOT_PASSWORD }}
DB_NAME=todolist
PORT=3000
JWT_SECRET=${{ secrets.JWT_SECRET }}
VITE_API_BASE_URL=http://${{ secrets.SERVER_IP }}:3000/api
ENVEOF

            # 重启容器
            docker-compose down 2>/dev/null || true
            docker-compose up -d

            # 健康检查
            sleep 15
            curl -sf http://localhost:3000/health || { echo "Health check failed"; exit 1; }
            echo "Deployment successful"
```

- [ ] **Step 2: 提交**

```bash
git add .github/workflows/deploy.yml
git commit -m "feat: add GitHub Actions deploy workflow

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: 更新根目录 docker-compose.yml 添加 image 字段

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: 添加 image 字段到 backend 和 frontend 服务**

查看现有 `docker-compose.yml`，在 `backend` 服务中添加 `image: todolist-backend:latest`，在 `frontend` 服务中添加 `image: todolist-frontend:latest`。这确保 docker-compose up 不尝试 build 而是使用预构建的镜像。

```yaml
  backend:
    image: todolist-backend:latest
    container_name: todolist-backend
    # ... 其余不变

  frontend:
    image: todolist-frontend:latest
    container_name: todolist-frontend
    # ... 其余不变
```

- [ ] **Step 2: 提交**

```bash
git add docker-compose.yml
git commit -m "chore: add image fields for production deployment

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: 创建服务器部署脚本

**Files:**
- Create: `scripts/deploy.sh`

- [ ] **Step 1: 创建部署脚本**

```bash
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
```

- [ ] **Step 2: 设置执行权限并提交**

```bash
chmod +x scripts/deploy.sh
git add scripts/deploy.sh
git commit -m "feat: add server deploy script

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: 创建 GitHub Secrets 配置说明文档

**Files:**
- Create: `docs/superpowers/specs/2026-05-27-alicloud-deploy-secrets.md`

- [ ] **Step 1: 编写 Secrets 配置指南**

```markdown
# GitHub Secrets 配置指南

## 需要在 GitHub Repo Settings 中配置的 Secrets

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `SERVER_IP` | `182.92.116.65` | 阿里云服务器公网 IP |
| `SERVER_USER` | `root` | SSH 用户名 |
| `SERVER_SSH_KEY` | 私钥内容 | 用于 SSH 登录的 RSA 私钥（需包含 `-----BEGIN OPENSSH PRIVATE KEY-----`） |
| `MYSQL_ROOT_PASSWORD` | `YourStrongPassword` | MySQL root 密码 |
| `JWT_SECRET` | `YourJWTSecretAtLeast32Chars` | JWT 签名密钥 |
| `VITE_API_BASE_URL` | `http://182.92.116.65:3000/api` | 前端访问后端的 URL |

## 如何生成 SSH 密钥对

在本地执行：
```bash
ssh-keygen -t rsa -b 4096 -C "github-actions"
```
将公钥添加到服务器的 `~/.ssh/authorized_keys`：
```bash
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
```
将私钥完整内容复制到 `SERVER_SSH_KEY` Secret。

## 配置步骤

1. 打开 GitHub Repo → Settings → Secrets and variables → Actions
2. 点击 "New repository secret" 依次添加上述 6 个 Secret
3. 确保私钥以 `-----BEGIN OPENSSH PRIVATE KEY-----` 开头
```

- [ ] **Step 2: 提交**

```bash
git add docs/superpowers/specs/2026-05-27-alicloud-deploy-secrets.md
git commit -m "docs: add GitHub Secrets configuration guide

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: 最终检查并推送

- [ ] **Step 1: 验证所有文件存在**

```bash
ls -la .github/workflows/deploy.yml
ls -la scripts/deploy.sh
ls -la docker-compose.yml
git log --oneline -3
```

- [ ] **Step 2: 推送到远程**

```bash
git push origin main
```

---

## 实施后检查清单

部署完成后，确认：

- GitHub Actions 页面显示 workflow 成功运行
- `curl http://182.92.116.65:3000/health` 返回 `{"message":"ok"}`
- 前端页面 http://182.92.116.65 可以正常打开
- 注册/登录/增删待办功能正常
- MySQL 数据持久化正常（重启容器后数据不丢失）