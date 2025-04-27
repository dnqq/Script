#!/bin/bash

# ==================================================
# 脚本名称: install_vaultwarden.sh
# 脚本作用: 自动安装并启动 Vaultwarden 服务
#           - 创建 /opt/vaultwarden 目录
#           - 生成 docker-compose.yml 文件
#           - 启动 Vaultwarden 服务
# 使用方式:
#   1. 将脚本保存为 install_vaultwarden.sh
#   2. 赋予脚本执行权限: chmod +x install_vaultwarden.sh
#   3. 运行脚本: sudo ./install_vaultwarden.sh
# 访问地址: http://localhost:8687
# 数据存储路径: /opt/vaultwarden/vw-data
# ==================================================

# 定义安装目录
INSTALL_DIR="/opt/vaultwarden"

# 生成随机 ADMIN_TOKEN
ADMIN_TOKEN=$(openssl rand -base64 32)

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 创建 docker-compose.yml 文件
cat <<EOF > docker-compose.yml
version: '3'

services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    ports:
      - 8687:80
    environment:
      ADMIN_TOKEN: "$ADMIN_TOKEN"
    volumes:
      - ./vw-data:/data
EOF

# 启动 Vaultwarden 服务
docker compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "Vaultwarden 服务已成功启动！"
  echo "访问地址：http://localhost:8687"
  echo "数据存储路径：$INSTALL_DIR/vw-data"
  echo "管理员 Token：$ADMIN_TOKEN"
  echo "请妥善保管管理员 Token，它用于访问管理界面！"
else
  echo "Vaultwarden 服务启动失败，请检查 Docker 是否已安装并运行。"
fi 