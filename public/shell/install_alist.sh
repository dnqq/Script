#!/bin/bash

# ==================================================
# 脚本名称: install_alist.sh
# 脚本作用: 自动安装并启动 Alist 服务
#           - 创建 /opt/alist 目录
#           - 生成 docker-compose.yml 文件
#           - 启动 Alist 服务
# 使用方式:
#   1. 将脚本保存为 install_alist.sh
#   2. 赋予脚本执行权限: chmod +x install_alist.sh
#   3. 运行脚本: sudo ./install_alist.sh
# 访问地址: http://localhost:5244
# 数据存储路径: /opt/alist
# ==================================================

# 定义安装目录
INSTALL_DIR="/opt/alist"

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 创建 docker-compose.yml 文件
cat <<EOF > docker-compose.yml
version: '3.3'
services:
  alist:
    image: 'xhofe/alist:beta'
    container_name: alist
    volumes:
      - '$INSTALL_DIR/data:/opt/alist/data'
    ports:
      - '5244:5244'
    environment:
      - PUID=0
      - PGID=0
      - UMASK=022
    restart: always
EOF

# 启动 Alist 服务
docker compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "Alist 服务已成功启动！"
  echo "访问地址：http://localhost:5244"
  echo "数据存储路径：$INSTALL_DIR/data"
else
  echo "Alist 服务启动失败，请检查 Docker 是否已安装并运行。"
fi
