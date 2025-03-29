#!/bin/bash

# ================================================================
# new-api 服务安装脚本
# 
# 功能：自动安装和配置 new-api 服务，包括必要的 Redis 和 MySQL 数据库
# 
# 使用方法：
#   1. 确保已安装 Docker 和 Docker Compose
#   2. 给脚本执行权限：chmod +x install_new_api.sh
#   3. 执行脚本：./install_new_api.sh
#
# 安装后：
#   - 服务访问地址：http://localhost:3000
#   - 数据存储位置：/app/new-api/data
#   - 日志存储位置：/app/new-api/logs
# ================================================================

# 定义安装目录
INSTALL_DIR="/root/app/new-api"

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 创建 docker-compose.yml 文件
cat <<'EOF' > docker-compose.yml
version: '3.4'

services:
  new-api:
    image: calciumion/new-api:latest
    container_name: new-api
    restart: always
    command: --log-dir /app/logs
    ports:
      - "3000:3000"
    volumes:
      - $INSTALL_DIR/data:/data
      - $INSTALL_DIR/logs:/app/logs
    environment:
      - SQL_DSN=root:123456@tcp(mysql:3306)/new-api  # Point to the mysql service
      - REDIS_CONN_STRING=redis://redis
      - TZ=Asia/Shanghai
    #      - SESSION_SECRET=random_string  # 多机部署时设置，必须修改这个随机字符串！！！！！！！
    #      - NODE_TYPE=slave  # Uncomment for slave node in multi-node deployment
    #      - SYNC_FREQUENCY=60  # Uncomment if regular database syncing is needed
    #      - FRONTEND_BASE_URL=https://openai.justsong.cn  # Uncomment for multi-node deployment with front-end URL

    depends_on:
      - redis
      - mysql
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O - http://localhost:3000/api/status | grep -o '\"success\":\\s*true' | awk -F: '{print $$2}'"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:latest
    container_name: redis
    restart: always

  mysql:
    image: mysql:8.2
    container_name: mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: 123456  # Ensure this matches the password in SQL_DSN
      MYSQL_DATABASE: new-api
    volumes:
      - mysql_data:/var/lib/mysql
    # ports:
    #   - "3306:3306"  # If you want to access MySQL from outside Docker, uncomment

volumes:
  mysql_data:
EOF

# 替换 docker-compose.yml 中的 INSTALL_DIR 变量
sed -i "s|\$INSTALL_DIR|$INSTALL_DIR|g" docker-compose.yml

# 启动 new-api 服务
docker compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "new-api 服务已成功启动！"
  echo "访问地址：http://localhost:3000"
  echo "数据存储路径：$INSTALL_DIR/data"
else
  echo "new-api 服务启动失败，请检查 Docker 是否已安装并运行。"
fi
