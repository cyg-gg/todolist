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