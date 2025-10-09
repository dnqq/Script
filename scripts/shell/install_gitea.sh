#!/bin/bash

# ==================================================
# 脚本名称: install_gitea.sh
# 脚本作用: 自动安装并启动 Gitea 服务
#           - 创建 /opt/gitea 目录
#           - 生成 docker-compose.yml 文件
#           - 启动 Gitea 服务
# 使用方式:
#   1. 赋予脚本执行权限: chmod +x install_gitea.sh
#   2. 运行脚本: sudo ./install_gitea.sh
#
# 首次运行设置:
#   1. 脚本运行成功后，通过浏览器访问 http://<服务器IP>:3000
#   2. 您将被引导至 Gitea 的安装页面。
#   3. 数据库设置已由环境变量配置为 SQLite，无需修改。
#   4. **重要**: 在页面下方找到 "管理员账号设置" 并创建您的管理员账户。
#   5. 完成设置后，即可开始使用 Gitea。
#
# 访问信息:
#   - Web 访问地址: http://localhost:3000
#   - SSH 克隆端口: 222 (例如: git clone ssh://git@localhost:222/user/repo.git)
#   - 数据存储路径: /opt/gitea/data
# ==================================================

# 定义安装目录
INSTALL_DIR="/opt/gitea"

# 创建安装目录
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/data"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 创建 docker-compose.yml 文件
cat <<EOF > docker-compose.yml
version: "3"

services:
  server:
    image: gitea/gitea:latest
    container_name: gitea
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=sqlite3
      - GITEA__database__PATH=/data/gitea/gitea.db
      - TZ=Asia/Shanghai
    volumes:
      - ./data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "222:22"
EOF

# 启动 Gitea 服务
docker compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "Gitea 服务已成功启动！"
  echo "请通过浏览器访问 http://<服务器IP>:3000 完成初始设置。"
  echo "重要：请务必在安装页面创建管理员账号！"
  echo "Web 访问地址：http://localhost:3000"
  echo "SSH 克隆端口：222"
  echo "数据存储路径：$INSTALL_DIR/data"
else
  echo "Gitea 服务启动失败，请检查 Docker 是否已安装并运行。"
fi