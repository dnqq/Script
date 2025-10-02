#!/bin/bash

# ==================================================
# 脚本名称: install_openlist.sh
# 脚本作用: 自动安装并启动 OpenList 服务
#           - 创建 /opt/openlist 目录
#           - 生成 docker-compose.yml 文件
#           - 启动 OpenList 服务
# 使用方式:
#   1. 将脚本保存为 install_openlist.sh
#   2. 赋予脚本执行权限: chmod +x install_openlist.sh
#   3. 运行脚本: sudo ./install_openlist.sh
# 访问地址: http://localhost:5244
# 数据存储路径: /opt/openlist
# ==================================================

# 定义安装目录
INSTALL_DIR="/opt/openlist"

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 获取当前用户的 UID 和 GID
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# 创建 docker-compose.yml 文件
cat <<EOF > docker-compose.yml
services:
  openlist:
    image: 'openlistteam/openlist:latest'
    container_name: openlist
    user: '${USER_ID}:${GROUP_ID}'
    volumes:
      - './data:/opt/openlist/data'
    ports:
      - '5244:5244'
    environment:
      - UMASK=022
    restart: unless-stopped
EOF

# 启动 OpenList 服务
docker compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "OpenList 服务已成功启动！"
  echo "访问地址：http://localhost:5244"
  echo "数据存储路径：$INSTALL_DIR/data"
else
  echo "OpenList 服务启动失败，请检查 Docker 是否已安装并运行。"
fi
