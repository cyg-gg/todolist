# 阿里云服务器 CI/CD 部署方案

## 1. 目标

通过 GitHub Actions 实现代码推送到 main 分支后，自动构建 Docker 镜像、部署到阿里云服务器（182.92.116.65），全过程无需人工干预。

## 2. 技术栈与约束

- **服务器**：阿里云 Ubuntu，IP 182.92.116.65，Docker + Docker Compose 已安装
- **容器**：backend (Node.js/Express)、frontend (nginx)、mysql (MySQL 8.0)
- **部署方式**：GitHub Actions 构建镜像 → 打包上传 → 服务器加载运行
- **无自定义域名**：直接通过服务器 IP 访问（HTTP）
- **数据库**：Docker 容器化，与后端同网络

## 3. 架构

```
GitHub Repo (main branch)
        │
        ▼ push
GitHub Actions Runner (ubuntu-latest)
        │
        ├─1─ 构建 backend 镜像 → backend.tar
        ├─2─ 构建 frontend 镜像 → frontend.tar
        └─3─ scp 上传 backend.tar + frontend.tar + deploy-scripts.tar
                │
                ▼
        阿里云服务器 (182.92.116.65)
                │
                ├─ docker load -i backend.tar
                ├─ docker load -i frontend.tar
                └─ docker-compose up -d --build
                        │
                        ▼
              ┌─────────┴──────────┐
              │  todolist-backend   │
              │  todolist-frontend │
              │  todolist-mysql    │
              └────────────────────┘
```

## 4. 目录结构

服务器上使用 `/root/todolist/` 作为项目根目录。

```
/root/todolist/
├── backend/
│   ├── Dockerfile
│   ├── .env (由 Actions 从 Secrets 生成)
│   └── src/
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── dist/ (构建产物)
│   └── .env
├── docker-compose.yml (根目录的 compose 文件，用于编排 mysql + backend + frontend)
└── .env
```

## 5. Docker Compose 配置

使用根目录的 `docker-compose.yml` 统一编排三个服务，与开发环境保持一致：

```yaml
services:
  mysql:
    image: mysql:8.0
    container_name: todolist-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: todolist
    ports:
      - "3306:3306"
    volumes:
      - todolist-mysql-data:/var/lib/mysql
    networks:
      - todolist-net
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: todolist-backend:latest
    container_name: todolist-backend
    restart: always
    env_file:
      - .env
    ports:
      - "3000:3000"
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - todolist-net

  frontend:
    image: todolist-frontend:latest
    container_name: todolist-frontend
    restart: always
    ports:
      - "80:80"
    depends_on:
      - backend
    networks:
      - todolist-net

volumes:
  todolist-mysql-data:

networks:
  todolist-net:
    driver: bridge
```

## 6. GitHub Actions 工作流

文件路径：`.github/workflows/deploy.yml`

### 6.1 触发条件

```yaml
on:
  push:
    branches: [main]
```

### 6.2 环境变量与 Secrets

Secrets 需要在 GitHub Repo Settings 中配置：

| Secret 名称 | 说明 |
|------------|------|
| `SERVER_IP` | 182.92.116.65 |
| `SERVER_USER` | root |
| `SERVER_SSH_KEY` | 私钥（用于 SSH 登录服务器） |
| `MYSQL_ROOT_PASSWORD` | 数据库 root 密码 |
| `JWT_SECRET` | JWT 签名密钥 |
| `VITE_API_BASE_URL` | 前端访问后端的 URL（生产环境为 http://182.92.116.65:3000/api） |

### 6.3 Jobs

**Job 1: build-and-upload（ Actions Runner）**

1. Checkout 代码
2. 构建 backend 镜像：`docker build -t todolist-backend:latest ./backend`
3. 保存 backend 镜像：`docker save todolist-backend:latest -o backend.tar`
4. 构建 frontend 镜像（复用现有 Dockerfile）
5. 保存 frontend 镜像：`docker save todolist-frontend:latest -o frontend.tar`
6. 创建部署脚本包（包含 docker-compose.yml 和 entrypoint.sh）
7. 通过 scp 上传三个 tar 包到服务器

**Job 2: deploy（通过 SSH 在服务器执行）**

1. SSH 登录服务器
2. 加载 backend 镜像：`docker load -i /root/todolist-deploy/backend.tar`
3. 加载 frontend 镜像：`docker load -i /root/todolist-deploy/frontend.tar`
4. 生成 `/root/todolist/.env` 文件（从 Secrets 注入）
5. 解压部署脚本包到 `/root/todolist/`
6. 执行 `docker-compose up -d --build`（--build 会重新构建容器内的服务，镜像加载后不再需要 build）
7. 健康检查：`curl http://localhost:3000/health`

### 6.4 部署脚本（entrypoint.sh）

```bash
#!/bin/bash
set -e
cd /root/todolist

# 加载镜像
docker load -i backend.tar
docker load -i frontend.tar

# 停止旧容器（如果存在）
docker-compose down 2>/dev/null || true

# 启动新容器
docker-compose up -d

# 健康检查
sleep 10
curl -sf http://localhost:3000/health || { echo "Health check failed"; exit 1; }
```

## 7. 初始化流程

服务器首次部署时，需要手动执行一次 MySQL 初始化：

1. 启动 MySQL 容器后，后端首次启动会自动建表（`initDatabase()` 函数）
2. 默认创建 admin 用户（admin/admin123）和一条欢迎待办
3. 后续 CI/CD 部署时，MySQL 数据通过 volume 持久化，不会丢失

## 8. 部署流程图

```
开发者 push 代码到 main
        │
        ▼
GitHub Actions 自动触发
        │
        ▼
构建 backend.tar + frontend.tar
        │
        ▼
上传到服务器 /root/todolist-deploy/
        │
        ▼
SSH 执行部署脚本
        │
        ├→ 加载 Docker 镜像
        ├→ 更新 .env
        ├→ docker-compose up -d
        └→ 健康检查
        │
        ▼
服务上线
```

## 9. 回滚方案

如需回滚到上一个版本：

1. 在 GitHub Actions 历史中找到上一个成功的 deployment
2. 下载对应的 `backend.tar` 和 `frontend.tar`
3. 通过手动 scp 上传到服务器
4. SSH 执行 `docker load` + `docker-compose up -d`

## 10. 安全考虑

- SSH 私钥仅保存在 GitHub Secrets，不提交到代码仓库
- `.env` 文件由 Actions 在运行时生成，不存储在代码仓库
- 服务器防火墙仅开放必要端口：22（SSH）、80（前端）、3306（MySQL，仅内网）、3000（后端 API，仅内网）
- 不开启 HTTPS（无域名）

## 11. 依赖项

- 服务器已安装 Docker 和 Docker Compose
- 服务器 SSH 服务已启动
- GitHub Repo 中配置了上述 6 个 Secrets
- 根目录 docker-compose.yml 存在且可用