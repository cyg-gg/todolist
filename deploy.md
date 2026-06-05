# TodoList 项目 Docker + GitHub Actions 全自动部署指南（零外部镜像仓库方案）

> 技术栈：Vue3 前端 + Express 后端 + MySQL 数据库  
> 部署方式：GitHub Actions → SCP 传输源码 → SSH 远程 → ECS 本地 docker build + docker compose up  
> 服务器：阿里云 ECS Ubuntu，公网 IP `39.97.238.25`，端口 80（前端）/ 3000（后端）
>
> **核心特点：不依赖 Docker Hub / ACR 等任何外部镜像仓库，镜像在 ECS 上本地构建**

---

## 一、整体流程图

```
本地 git push main
        │
        ▼
GitHub Actions 触发
        │
        ▼
  ┌──────────────────────────────────────────┐
  │  Job: Deploy to ECS                      │
  │                                          │
  │  Step 1: Checkout 拉取仓库代码            │
  │           ↓                              │
  │  Step 2: SCP 传输源码到 ECS /root/todolist│
  │           ↓                              │
  │  Step 3: SSH 远程执行部署：               │
  │    ① 写入 .env 环境变量                   │
  │    ② docker compose build（本地构建镜像）  │
  │    ③ docker compose down（停止旧容器）     │
  │    ④ docker compose up -d（启动新容器）    │
  │    ⑤ 健康检查                             │
  │    ⑥ 清理旧镜像                           │
  └──────────────────────────────────────────┘
        │
        ▼
   ✅ 部署完成
```

---

## 二、GitHub Secrets 配置

进入：GitHub 仓库 → Settings → Secrets and variables → Actions → New repository secret

| Secret 名称 | 值 | 说明 |
|---|---|---|
| `ALIYUN_ECS_IP` | `39.97.238.25` | 阿里云 ECS 公网 IP |
| `ALIYUN_ECS_USERNAME` | `root` | SSH 登录用户名 |
| `ALIYUN_ECS_SSH_KEY` | （SSH 私钥完整内容） | 见下方生成步骤 |
| `MYSQL_ROOT_PASSWORD` | 自定义强密码 | 例：`Todolist@2024!` |
| `JWT_SECRET` | 随机字符串 | 例：`aB3xK9mP2qR7vW5yZ1` |

**与旧方案的区别：不再需要 `DOCKER_HUB_USERNAME` 和 `DOCKER_HUB_TOKEN` 两个 Secret！**

---

## 三、ALIYUN_ECS_SSH_KEY 获取方式

在服务器上执行 `scripts/server-init.sh` 会自动生成并打印私钥，或手动执行：

```bash
# SSH 登录服务器
ssh root@39.97.238.25

# 生成专用密钥对
ssh-keygen -t ed25519 -C "github-actions-deploy" \
  -f /root/.ssh/github_actions_deploy -N ""

# 将公钥加入信任列表
cat /root/.ssh/github_actions_deploy.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 查看私钥内容（复制全部粘贴到 GitHub Secret）
cat /root/.ssh/github_actions_deploy
```

> ⚠️ 复制私钥时，必须包含 `-----BEGIN OPENSSH PRIVATE KEY-----` 和 `-----END OPENSSH PRIVATE KEY-----` 这两行！

---

## 四、首次服务器环境准备

**登录服务器后，一次性执行：**

```bash
ssh root@39.97.238.25

# 复制以下全部命令粘贴执行：
apt-get update -y && apt-get upgrade -y

# 安装 Docker（官方源）
apt-get install -y ca-certificates curl gnupg lsb-release
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动 Docker 并设置开机自启
systemctl enable docker && systemctl start docker

# 验证安装
docker --version
docker compose version

# 创建部署目录
mkdir -p /root/todolist

# 开放防火墙端口
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 3000/tcp
ufw --force enable

# 生成 SSH 密钥（供 GitHub Actions 使用）
ssh-keygen -t ed25519 -C "github-actions-deploy" -f /root/.ssh/github_actions_deploy -N ""
cat /root/.ssh/github_actions_deploy.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 打印私钥（复制到 GitHub Secrets）
echo "=== 私钥内容（复制到 ALIYUN_ECS_SSH_KEY）==="
cat /root/.ssh/github_actions_deploy
echo "=== 私钥内容结束 ==="

# 预拉取 MySQL 镜像（加速首次部署）
docker pull mysql:8.0
```

**同时务必在「阿里云控制台 → ECS → 安全组」中开放入方向规则：**

| 协议 | 端口 | 授权对象 | 说明 |
|---|---|---|---|
| TCP | 22 | 0.0.0.0/0 | SSH 远程连接 |
| TCP | 80 | 0.0.0.0/0 | 前端 HTTP 访问 |
| TCP | 3000 | 0.0.0.0/0 | 后端 API 访问 |

---

## 五、项目文件结构说明

```
todolist/
├── .github/
│   └── workflows/
│       └── deploy.yml              ← CI/CD 主配置（无镜像仓库版）
├── backend/
│   ├── Dockerfile                  ← 后端镜像构建文件
│   ├── .dockerignore               ← 后端构建排除
│   ├── src/                        ← Express 后端源码
│   └── package.json
├── frontend/
│   ├── Dockerfile                  ← 前端镜像构建文件（多阶段：build + nginx）
│   ├── .dockerignore               ← 前端构建排除
│   ├── nginx.conf                  ← 前端 Nginx 反向代理配置
│   ├── src/                        ← Vue3 前端源码
│   └── package.json
├── docker-compose.prod.yml         ← 生产部署配置（使用 build 指令本地构建）
├── .dockerignore                   ← 根目录 Docker 构建排除
└── scripts/
    └── server-init.sh              ← 服务器初始化脚本
```

---

## 六、与旧方案的区别

| 项目 | 旧方案（Docker Hub） | 新方案（本地 build） |
|---|---|---|
| 镜像存储 | 推送到 Docker Hub | ECS 本地构建，不推送 |
| 依赖的外部服务 | Docker Hub | 无 |
| GitHub Secrets | 7 个 | 5 个 |
| 部署速度 | 快（拉取已构建的镜像） | 中等（需在 ECS 上编译） |
| 磁盘占用 | 小（只存当前版本镜像） | 稍大（有 node_modules 缓存） |
| 适用场景 | 生产环境高频部署 | 个人项目 / 演示项目 |
| `docker-compose.prod.yml` | `image:` 拉取远程镜像 | `build:` 本地构建 |

---

## 七、推送触发部署

```bash
# 完成代码修改后
git add .
git commit -m "feat: 更新功能"
git push origin main
# ↑ 推送后 GitHub Actions 自动触发，约 3-6 分钟完成部署
```

---

## 八、常用排查命令

```bash
# 查看所有容器状态
docker ps -a

# 查看后端日志（最后100行，持续输出）
docker logs todolist-backend --tail=100 -f

# 查看前端日志
docker logs todolist-frontend --tail=50

# 重启单个容器
docker restart todolist-backend

# 手动重新部署（服务器上执行）
cd /root/todolist
docker compose -f docker-compose.prod.yml build --no-cache backend frontend
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

# 清理无用镜像和构建缓存
docker image prune -af
docker builder prune -f
```

---

## 九、访问地址

| 服务 | 地址 |
|---|---|
| 前端页面 | http://39.97.238.25 |
| 后端 API | http://39.97.238.25:3000 |
| 健康检查 | http://39.97.238.25:3000/health |

---

## 十、容器开机自启说明

所有容器在 `docker-compose.prod.yml` 中均已配置 `restart: always`，意味着：

- ECS 服务器重启后，Docker 会自动启动（`systemctl enable docker` 已配置）
- Docker 启动后，所有配置了 `restart: always` 的容器会自动恢复运行
- 无需任何手动干预
