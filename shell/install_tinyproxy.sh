#!/bin/bash

# ==================================================
# 脚本名称: install_tinyproxy.sh
# 脚本作用: 自动安装并启动 Tinyproxy 服务
#           - 创建安装目录
#           - 生成基础 tinyproxy.conf 配置文件
#           - 生成 docker-compose.yml 文件
#           - 启动 Tinyproxy 服务
# 使用方式:
#   1. 将脚本保存为 install_tinyproxy.sh
#   2. 赋予脚本执行权限: chmod +x install_tinyproxy.sh
#   3. 使用 root 或有 docker 权限的用户运行脚本:
#      - 仅允许本机访问: sudo ./install_tinyproxy.sh
#      - 允许特定 IP (例如 192.168.1.100) 访问: sudo ./install_tinyproxy.sh 192.168.1.100
# 代理地址: <你的服务器IP>:34555
# 配置及数据存储路径: /root/app/tinyproxy (可修改下面的 INSTALL_DIR)
# 重要提示: 传入 IP 后，将允许该 IP 和本机 (127.0.0.1) 访问。
#           如需更复杂的规则，请手动修改 tinyproxy.conf。
# ==================================================

# --- 可配置变量 ---
# 定义安装目录 (请确保运行脚本的用户有权限在此路径下创建目录和文件)
INSTALL_DIR="/root/app/tinyproxy"
# 定义对外暴露的端口
HOST_PORT="34555"
# 定义使用的 Docker 镜像 (可以使用特定版本替换 latest)
DOCKER_IMAGE="dannydirect/tinyproxy:latest"
# --- 配置结束 ---

# 获取传入的 IP 参数
ALLOWED_IP=$1
ALLOW_INFO="默认配置仅允许来自服务器本机 (127.0.0.1) 的连接。" # 默认提示信息

# 检查 docker compose 是否可用
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    echo "错误：找不到 docker 或 docker compose 命令。"
    echo "请确保 Docker 和 Docker Compose v2 已正确安装并运行。"
    exit 1
fi

# 创建安装目录
echo "创建安装目录: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
if [ $? -ne 0 ]; then
    echo "错误：无法创建目录 $INSTALL_DIR。请检查权限或路径。"
    exit 1
fi

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "错误：无法进入目录 $INSTALL_DIR"; exit 1; }
echo "当前工作目录: $(pwd)"

# 创建基础 tinyproxy.conf 文件 - 第一部分
echo "生成基础配置文件: $INSTALL_DIR/tinyproxy.conf"
cat <<EOF > tinyproxy.conf
User nobody
Group nogroup # 使用 nogroup 更通用，某些基础镜像可能没有 nobody 组
Port 8888 # 这是容器内部监听的端口

Timeout 600
DefaultErrorFile "/usr/share/tinyproxy/default.html"
StatFile "/usr/share/tinyproxy/stats.html"
LogLevel Info
PidFile "/var/run/tinyproxy/tinyproxy.pid"
MaxClients 100
MinSpareServers 5
MaxSpareServers 20
StartServers 10
MaxRequestsPerChild 0

# --- 安全性配置 ---
# !!! 重要 !!!
Allow 127.0.0.1       # 始终允许本机访问
EOF

# 创建基础 tinyproxy.conf 文件 - 第二部分 (根据传入 IP 添加 Allow)
if [ -n "$ALLOWED_IP" ]; then
    echo "检测到传入 IP 参数，将添加允许访问的 IP: $ALLOWED_IP"
    # 可以在这里添加 IP 地址格式验证 (可选)
    # if ! [[ "$ALLOWED_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?$ ]]; then
    #     echo "错误：提供的 IP 地址或网段 '$ALLOWED_IP' 格式无效。"
    #     # exit 1 # 如果需要严格验证则退出
    # fi
    echo "Allow $ALLOWED_IP       # 允许通过脚本参数传入的 IP/网段" >> tinyproxy.conf
    ALLOW_INFO="配置已允许来自本机 (127.0.0.1) 和 ${ALLOWED_IP} 的连接。" # 更新提示信息
else
    echo "未指定允许的 IP，将仅允许本机 (127.0.0.1) 访问。"
    # 如果没有传入 IP，添加一些常用的注释掉的 Allow 示例
    cat <<EOF >> tinyproxy.conf
# Allow ::1           # 允许本机 IPv6 访问 (如果需要)
# Allow 172.16.0.0/12 # 允许来自 Docker 默认网络的访问 (根据你的 docker 网络调整)
# Allow 192.168.0.0/16 # 示例：允许常用私有网段
# Allow 10.0.0.0/8     # 示例：允许常用私有网段
EOF
fi

# 创建基础 tinyproxy.conf 文件 - 第三部分 (可选配置)
cat <<EOF >> tinyproxy.conf

# 可选：禁用 Via 请求头，增加一点匿名性
# DisableViaHeader Yes

# 可选：设置上游代理 (如果 Tinyproxy 需要通过另一个代理访问网络)
# upstream http upstream.example.com:8080
# upstream https upstream.example.com:8080
# upstream socks5 upstream.example.com:1080
EOF

# 创建 docker-compose.yml 文件
echo "生成 Docker Compose 文件: $INSTALL_DIR/docker-compose.yml"
cat <<EOF > docker-compose.yml
version: '3.8'

services:
  tinyproxy:
    image: ${DOCKER_IMAGE}
    container_name: tinyproxy_service
    ports:
      # 将主机的 ${HOST_PORT} 端口映射到容器的 8888 端口
      - "${HOST_PORT}:8888"
    volumes:
      # 挂载配置文件 (只读)
      - ./tinyproxy.conf:/etc/tinyproxy/tinyproxy.conf:ro
      # 可选：挂载日志目录 (如果需要持久化日志)
      # - ./logs:/var/log/tinyproxy
    restart: unless-stopped
    # 可选：如果需要加入特定网络
    # networks:
    #  - proxy_network

# 可选：定义网络
# networks:
#   proxy_network:
#     driver: bridge
EOF

# 启动 Tinyproxy 服务
echo "正在使用 Docker Compose 启动 Tinyproxy 服务..."
docker compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo ""
  echo "--------------------------------------------------"
  echo " Tinyproxy 服务已成功启动！"
  echo "--------------------------------------------------"
  echo " 代理服务器地址: <你的服务器IP>:${HOST_PORT}"
  echo " 配置文件路径:   ${INSTALL_DIR}/tinyproxy.conf"
  echo " Compose 文件:   ${INSTALL_DIR}/docker-compose.yml"
  echo ""
  echo " 重要提示:"
  echo "   ${ALLOW_INFO}" # 显示根据参数生成的提示信息
  echo "   如需更改访问权限，请编辑 ${INSTALL_DIR}/tinyproxy.conf 文件，"
  echo "   修改或添加 'Allow' 指令。"
  echo "   修改配置文件后，请在 ${INSTALL_DIR} 目录下运行 'docker compose restart' 使更改生效。"
  echo "--------------------------------------------------"
else
  echo "错误：Tinyproxy 服务启动失败。"
  echo "请检查 Docker 服务是否正在运行，以及端口 ${HOST_PORT} 是否已被占用。"
  echo "查看容器日志：docker compose logs tinyproxy_service"
fi

# 返回原始目录 (可选)
# cd - > /dev/null
