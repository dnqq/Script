#!/bin/bash

# ========================================================
# 该脚本用于一键部署 Syncthing。
# 
# 作用：
# 本脚本通过 Docker Compose 自动创建 Syncthing 容器并启动，
# Syncthing 是一个开源的文件同步工具，支持多设备间的文件同步。
# 
# 用法：
# 1. 将脚本保存为 install_syncthing
# 2. 使用命令 `chmod +x install_syncthing` 赋予脚本执行权限
# 3. 执行脚本：`./install_syncthing`
# 
# 默认配置：
# - Web 管理界面：端口 8384
# - 数据传输端口：22000 (TCP/UDP)
# - 本地发现端口：21027 (UDP)
#
# 注意：
# - 确保系统已安装 Docker 和 Docker Compose
# ========================================================

# 设置项目目录
PROJECT_DIR="/opt/syncthing"

# 创建项目目录
echo "创建目录：$PROJECT_DIR"
mkdir -p $PROJECT_DIR

# 创建 docker-compose.yml 文件
echo "创建 docker-compose.yml 文件..."
cat > $PROJECT_DIR/docker-compose.yml <<EOF
services:
  syncthing:
    image: syncthing/syncthing:latest
    container_name: syncthing
    hostname: 甲骨文_新加坡西_ARM  # 自定义设备名称
    environment:
      - PUID=0  # 宿主用户ID
      - PGID=0  # 宿主组ID
    volumes:
      - ./config:/var/syncthing/config  # 配置目录
      - /data/syncthing:/var/syncthing/data      # 同步数据目录
    ports:
      - 8384:8384       # Web管理界面
      - 22000:22000     # 数据传输端口 (TCP)
      - 22000:22000/udp
      - 21027:21027/udp # 本地发现端口
    restart: always
EOF

# 启动 Syncthing
echo "启动 Syncthing..."
cd $PROJECT_DIR
docker compose up -d

# 输出结果
echo "Syncthing 部署完成！"
echo "访问 Web 管理界面：http://<your-server-ip>:8384"
echo "默认配置目录：$PROJECT_DIR/config"
echo "默认数据目录：/data/syncthing"