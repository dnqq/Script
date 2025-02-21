#!/bin/bash

# ==================================================
# 脚本名称: install_freshrss.sh
# 脚本作用: 自动安装并启动 FreshRSS 服务
#           - 创建 /root/app/freshrss 目录
#           - 生成 docker-compose.yml 文件
#           - 启动 FreshRSS 服务
# 使用方式:
#   1. 将脚本保存为 install_freshrss.sh
#   2. 赋予脚本执行权限: chmod +x install_freshrss.sh
#   3. 运行脚本: sudo ./install_freshrss.sh
# 访问地址: http://localhost:8080
# 数据存储路径: /root/app/freshrss/data
# ==================================================

# 定义安装目录
INSTALL_DIR="/root/app/freshrss"

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 创建 docker-compose.yml 文件
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  freshrss:
    image: freshrss/freshrss
    container_name: freshrss
    restart: unless-stopped
    ports:
      - 8080:80
    environment:
      - TZ=Asia/Shanghai
      - CRON_MIN=1,31
    volumes:
      - $INSTALL_DIR/data:/var/www/FreshRSS/data
      - $INSTALL_DIR/extensions:/var/www/FreshRSS/extensions
    logging:
      options:
        max-size: "10m"
EOF

# 启动 FreshRSS 服务
docker compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "FreshRSS 服务已成功启动！"
  echo "访问地址：http://localhost:8080"
  echo "数据存储路径：$INSTALL_DIR/data"
else
  echo "FreshRSS 服务启动失败，请检查 Docker 是否已安装并运行。"
fi
