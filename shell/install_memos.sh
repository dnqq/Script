#!/bin/bash

# ==================================================
# 脚本名称: install_memos.sh
# 脚本作用: 自动安装并启动 Memos 服务
#           - 创建 /root/app/memos 目录
#           - 生成 docker-compose.yml 文件
#           - 启动 Memos 服务
# 使用方式:
#   1. 将脚本保存为 install_memos.sh
#   2. 赋予脚本执行权限: chmod +x install_memos.sh
#   3. 运行脚本: sudo ./install_memos.sh
# 访问地址: http://localhost:5230
# 数据存储路径: /root/app/memos/data
# ==================================================

# 定义安装目录
INSTALL_DIR="/root/app/memos"

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 创建 docker-compose.yml 文件
cat <<EOF > docker-compose.yml
services:
  memos:
    image: neosmemo/memos:stable
    container_name: memos
    volumes:
      - $INSTALL_DIR/data:/var/opt/memos
    ports:
      - 5230:5230
EOF

# 启动 Memos 服务
docker-compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "Memos 服务已成功启动！"
  echo "访问地址：http://localhost:5230"
  echo "数据存储路径：$INSTALL_DIR/data"
else
  echo "Memos 服务启动失败，请检查 Docker 是否已安装并运行。"
fi