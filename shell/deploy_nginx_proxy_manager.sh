#!/bin/bash

# ========================================================
# 该脚本用于一键部署 Nginx Proxy Manager（NPM）。
# 
# 作用：
# 本脚本通过 Docker Compose 自动创建 Nginx Proxy Manager 容器并启动，
# 其中 Nginx Proxy Manager 会作为反向代理管理工具，提供 HTTP、HTTPS、
# 以及 Web UI 管理界面的访问。容器的端口 81 被映射到主机的 34999 端口。
# 
# 用法：
# 1. 将脚本保存为 deploy_nginx_proxy_manager.sh
# 2. 使用命令 `chmod +x deploy_nginx_proxy_manager.sh` 赋予脚本执行权限
# 3. 执行脚本：`./deploy_nginx_proxy_manager.sh`
# 
# 默认配置：
# - HTTP：端口 80
# - HTTPS：端口 443
# - 管理界面：端口 34999（映射自容器的 81 端口）
#
# 默认登录凭证：
# - 用户名：admin@example.com
# - 密码：changeme
#
# 注意：
# - 确保系统已安装 Docker 和 Docker Compose
# ========================================================

# 设置项目目录
PROJECT_DIR="/root/nginx-proxy-manager"

# 创建项目目录
echo "创建目录：$PROJECT_DIR"
mkdir -p $PROJECT_DIR

# 创建 docker-compose.yml 文件
echo "创建 docker-compose.yml 文件..."
cat > $PROJECT_DIR/docker-compose.yml <<EOF
version: '3'

services:
  app:
    image: 'docker.io/jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - '80:80'         # HTTP
      - '443:443'       # HTTPS
      - '34999:81'      # 将容器的 81 端口映射到主机的 34999 端口
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt  # 用于存储 SSL 证书
    networks:
      - nginx-proxy

networks:
  nginx-proxy:
    driver: bridge
EOF

# 启动 Nginx Proxy Manager
echo "启动 Nginx Proxy Manager..."
cd $PROJECT_DIR
docker compose up -d

# 输出结果
echo "Nginx Proxy Manager 部署完成！"
echo "访问管理界面：http://<your-server-ip>:34999"
echo "默认登录信息："
echo "用户名：admin@example.com"
echo "密码：changeme"
