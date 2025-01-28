#!/bin/bash

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
docker-compose up -d

# 输出结果
echo "Nginx Proxy Manager 部署完成！"
echo "访问管理界面：http://<your-server-ip>:34999"
echo "默认登录信息："
echo "用户名：admin@example.com"
echo "密码：changeme"
