#!/bin/bash

# ==================================================
# 脚本名称: install_rsshub.sh
# 脚本作用: 自动安装并启动 RSSHub 服务
#           - 下载并生成 docker-compose.yml 文件
#           - 启动 RSSHub 服务
# 使用方式:
#   1. 将脚本保存为 install_rsshub.sh
#   2. 赋予脚本执行权限: chmod +x install_rsshub.sh
#   3. 运行脚本: sudo ./install_rsshub.sh
# 访问地址: http://localhost:1200
# ==================================================

# 定义安装目录
INSTALL_DIR="/opt/rsshub"

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 下载 docker-compose.yml 文件
echo "下载 docker-compose.yml 文件..."
wget https://raw.githubusercontent.com/DIYgod/RSSHub/master/docker-compose.yml

# 启动 RSSHub 服务
docker-compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "RSSHub 服务已成功启动！"
  echo "访问地址：http://localhost:1200"
else
  echo "RSSHub 服务启动失败，请检查 Docker 是否已安装并运行。"
fi
