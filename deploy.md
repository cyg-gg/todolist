# TodoList 部署手册（Ubuntu + Docker + Vercel）

这个项目分成 3 部分：

- 前端：Vue 3
- 后端：Node.js + Express
- 数据库：MySQL

推荐部署方式：

- 前端部署到 Vercel
- 后端部署到 Ubuntu 服务器上的 Docker
- MySQL 部署到同一台服务器的 Docker 容器，或者云数据库

---

## 一、你要先准备什么

你需要有：

- 一台阿里云 Ubuntu 服务器
- 一个 GitHub 仓库
- 一个域名（可选，但建议有）
- MySQL 数据库账号密码

---

## 二、在服务器上安装 Docker

先 SSH 登录你的 Ubuntu 服务器，然后执行：

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg git
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

执行完以后，退出 SSH 再重新登录一次。

然后检查：

```bash
docker --version
```

如果有版本号，说明成功了。

---

## 三、启动 MySQL

如果你希望数据库也放在这台服务器上，可以直接用 Docker 跑 MySQL。

### 1. 创建数据卷

```bash
docker volume create todolist-mysql-data
```

### 2. 启动 MySQL 容器

把密码改成你自己的：

```bash
docker run -d \
  --name todolist-mysql \
  --restart always \
  -e MYSQL_ROOT_PASSWORD=你的MySQL密码 \
  -e MYSQL_DATABASE=todolist \
  -p 3306:3306 \
  -v todolist-mysql-data:/var/lib/mysql \
  mysql:8.0
```

### 3. 检查容器

```bash
docker ps
```

看到 `todolist-mysql` 就说明运行成功。

---

## 四、导入建表脚本

项目里已经有 `backend/schema.sql`，它会创建：

- `users`
- `todos`

还会插入一条初始化数据。

### 导入方法

如果服务器上有 `mysql` 命令：

```bash
mysql -h 127.0.0.1 -u root -p todolist < backend/schema.sql
```

如果没有这个命令，也可以进入容器执行。

---

## 五、配置后端环境变量

进入后端目录：

```bash
cd backend
```

创建 `.env` 文件：

```bash
nano .env
```

填入：

```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=你的MySQL密码
DB_NAME=todolist
PORT=3000
JWT_SECRET=换成一个足够长的随机字符串
```

---

## 六、启动后端

后端已经准备了 `Dockerfile`，直接构建并运行：

```bash
docker build -t todolist-backend .
docker run -d \
  --name todolist-backend \
  --restart always \
  --env-file .env \
  -p 3000:3000 \
  todolist-backend
```

查看日志：

```bash
docker logs -f todolist-backend
```

健康检查：

```bash
curl http://127.0.0.1:3000/health
```

正常应该返回：

```json
{"message":"ok"}
```

---

## 七、配置前端环境变量

进入前端目录：

```bash
cd frontend
```

创建 `.env`：

```bash
nano .env
```

本地开发时写：

```env
VITE_API_BASE_URL=http://127.0.0.1:3000/api
```

如果上线了，就改成你的线上后端地址：

```env
VITE_API_BASE_URL=https://api.你的域名.com/api
```

---

## 八、前端部署到 Vercel

在 Vercel 中导入前端项目。

### 构建设置

- Framework Preset：Vite
- Build Command：`npm run build`
- Output Directory：`dist`

### 环境变量

添加：

```env
VITE_API_BASE_URL=https://api.你的域名.com/api
```

---

## 九、配置 Nginx 反向代理

如果你没有自己的域名，也可以先直接用服务器公网 IP 访问后端。

### 安装 Nginx

```bash
sudo apt install -y nginx
```

### 使用项目里的 Nginx 配置模板

项目中已经准备了一个 Nginx 模板文件：

```text
backend/nginx.conf
```

把里面的 `server_name _;` 保持不变即可，表示它接收服务器上的默认访问请求。

然后把这个文件复制到 Nginx 配置目录：

```bash
sudo cp backend/nginx.conf /etc/nginx/sites-available/default
sudo nginx -t
sudo systemctl reload nginx
```

---

## 十、开启 HTTPS

安装 certbot：

```bash
sudo apt install -y certbot python3-certbot-nginx
```

申请证书：

```bash
sudo certbot --nginx -d api.xxx.com
```

前端域名也可以用同样方式配置 HTTPS。

---

## 十一、GitHub Actions 自动部署思路

你后面可以把代码推到 GitHub，然后设置自动化流程：

- 前端代码变更后自动构建并部署到 Vercel
- 后端代码变更后自动构建 Docker 镜像
- 服务器拉取最新镜像并重启容器

如果你需要，我下一步可以直接帮你写 `.github/workflows` 文件。

---

## 十二、你现在最简单的执行顺序

你可以按这个顺序来：

1. 在服务器安装 Docker
2. 启动 MySQL 容器
3. 导入 `backend/schema.sql`
4. 创建 `backend/.env`
5. 构建并启动后端容器
6. 给前端配置 `VITE_API_BASE_URL`
7. 把前端部署到 Vercel
8. 用 `backend/nginx.conf` 配置域名反向代理
9. 配置 HTTPS

---

## 十三、你可以直接用的环境变量示例

### 后端 `.env`

```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=你的MySQL密码
DB_NAME=todolist
PORT=3000
JWT_SECRET=replace_with_a_secure_secret
```

### 前端 `.env`

```env
VITE_API_BASE_URL=http://127.0.0.1:3000/api
```

---

## 十四、检查清单

部署完成后，确认下面这些都正常：

- `docker ps` 能看到 MySQL 和后端容器
- `curl http://127.0.0.1:3000/health` 能返回 `ok`
- 前端页面能打开
- 能注册
- 能登录
- 能新增待办
- 能完成/取消完成
- 能删除待办

---

## 十五、如果你看不懂怎么操作

你可以直接把下面信息发给我，我帮你继续往下做：

- 你的阿里云服务器公网 IP
- 你的服务器公网 IP
- 你的 MySQL 密码是否已经设置好

我也可以继续帮你生成：

- GitHub Actions 自动部署文件
- 更完整的 Nginx/HTTPS 配置
- 服务器一键部署脚本
