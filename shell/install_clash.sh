#!/bin/bash

# ==============================================================================
# Clash Docker 一键安装及管理脚本
#
# 功能:
#   - 自动在 Debian/Ubuntu/CentOS 服务器上使用 Docker 或 二进制文件 部署 Clash。
#   - 支持通过参数或交互式输入获取 Clash 订阅链接。
#   - 自动下载并修改配置文件以适应服务器环境。
#   - 将 Clash 设置为开机自启动。
#   - 提供多种安装模式：标准代理、本机透明代理、局域网透明网关。
#   - 自动处理依赖安装、防火墙规则设置与持久化。
#
# 使用方法:
#   1. 赋予脚本执行权限: chmod +x install_clash.sh
#   2. 运行脚本:
#      - 显示菜单: sudo ./install_clash.sh
#      - 一键安装: sudo ./install_clash.sh install <你的订阅链接>
#
# 安装后信息:
#   - 软件目录: /opt/clash
#   - Docker Compose 文件: /opt/clash/docker-compose.yml
#   - Clash 配置文件: /opt/clash/config.yaml
#   - HTTP 代理地址: http://127.0.0.1:7890
#   - SOCKS5 代理地址: socks5://127.0.0.1:7891
# ==============================================================================

# --- 配置变量 ---
# Clash 的安装和配置目录
INSTALL_DIR="/opt/clash"
# Clash 配置文件路径
CONFIG_FILE="$INSTALL_DIR/config.yaml"
# Docker Compose 文件路径
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
# Clash 镜像
CLASH_IMAGE="dreamacro/clash-premium:latest"
# Clash 二进制文件下载链接
CLASH_BINARY_URL="https://alist.739999.xyz/d/%E8%B5%84%E6%BA%90/software/ashin/%E7%BD%91%E7%BB%9C%E5%B7%A5%E5%85%B7/clash-linux-amd64-2023.08.17.gz"
# 代理地址
PROXY_HTTP="http://127.0.0.1:7890"
PROXY_SOCKS5="socks5://127.0.0.1:7891"
IMAGE_PROXY_PREFIX=""

# --- 函数定义 ---

# 打印信息
echo_info() {
  echo -e "\033[32m[信息]\033[0m $1"
}

# 打印错误
echo_error() {
  echo -e "\033[31m[错误]\033[0m $1"
}

# 打印警告
echo_warn() {
  echo -e "\033[33m[警告]\033[0m $1"
}

# 检查 root 权限
check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo_error "此脚本需要以 root 或 sudo 权限运行。"
    exit 1
  fi
}

# 检查 Docker 是否安装
check_docker() {
  if ! command -v docker &> /dev/null; then
    echo_error "Docker 未安装。请先安装 Docker。"
    exit 1
  fi
  if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo_error "Docker Compose 未安装。请先安装。"
    exit 1
  fi
}

# 获取用户输入的订阅链接
get_user_input() {
  if [ -z "$CLASH_SUB_URL" ]; then
    read -p "请输入您的 Clash 订阅链接: " CLASH_SUB_URL
    if [ -z "$CLASH_SUB_URL" ]; then
      echo_error "订阅链接不能为空！"
      exit 1
    fi
  fi
}

# 选择镜像代理
select_image_proxy() {
  echo_info "请选择 Docker 镜像拉取方式:"
  echo " 1. 直接拉取 (默认)"
  echo " 2. 使用 hubproxy.739999.xyz 加速"
  echo " 3. 使用 demo.52013120.xyz 加速"
  read -p "请输入选项 [1-3, 默认 1]: " proxy_choice
  
  case $proxy_choice in
    2)
      IMAGE_PROXY_PREFIX="hubproxy.739999.xyz/"
      echo_info "已选择使用 hubproxy.739999.xyz 加速。"
      ;;
    3)
      IMAGE_PROXY_PREFIX="demo.52013120.xyz/"
      echo_info "已选择使用 demo.52013120.xyz 加速。"
      ;;
    *)
      IMAGE_PROXY_PREFIX=""
      echo_info "已选择直接拉取镜像。"
      ;;
  esac
}

# 创建并准备目录
prepare_directory() {
  echo_info "正在创建配置目录: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  if [ $? -ne 0 ]; then
    echo_error "创建目录 $INSTALL_DIR 失败。"
    exit 1
  fi
}

# 应用服务器特定的配置修改
apply_server_mods_to_config() {
  echo_info "正在为服务器环境优化配置文件..."
  # 使用 sed 删除可能存在的旧配置，避免冲突
  sed -i -e '/^port:/d' \
         -e '/^socks-port:/d' \
         -e '/^allow-lan:/d' \
         -e '/^external-controller:/d' \
         -e '/^log-level:/d' \
         -e '/^tun:/,$d' \
         -e '/^dns:/,$d' "$CONFIG_FILE" # 删除旧的TUN和DNS配置

  # 根据用户选择设置 allow-lan
  local allow_lan_value="false"
  if [[ "$ALLOW_LAN" =~ ^[Yy]$ ]]; then
    allow_lan_value="true"
  fi

  # 追加新的标准配置
  cat <<EOF >> "$CONFIG_FILE"

# --- Appended by install_clash.sh for server environment ---
port: 7890
socks-port: 7891
redir-port: 7892
allow-lan: ${allow_lan_value}
external-controller: '0.0.0.0:9090'
log-level: info

# DNS server settings for gateway mode
dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: redir-host
  nameserver:
    - 114.114.114.114
    - 8.8.8.8
  fallback:
    - https://dns.google/dns-query
    - https://1.1.1.1/dns-query
EOF

  # 如果启用了TUN模式，则追加TUN配置
  if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]]; then
    echo_info "正在为配置文件添加 TUN 模式支持..."
    cat <<EOF >> "$CONFIG_FILE"
tun:
  enable: true
  stack: system
  dns-hijack:
    - any:53
EOF
  fi
  echo_info "配置文件优化完成。"
}

# 下载并修改 Clash 配置
setup_clash_config() {
  local should_download=true
  if [ -f "$CONFIG_FILE" ]; then
    read -p "检测到已存在的配置文件 (config.yaml)，是否要下载并覆盖它？(y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      echo_info "已跳过下载配置文件。"
      should_download=false
    fi
  fi

  if [ "$should_download" = true ]; then
    echo_info "正在从订阅链接下载配置文件..."
    if ! curl -L -A "clash" -o "$CONFIG_FILE" "$CLASH_SUB_URL"; then
      echo_error "下载订阅文件失败！请检查链接是否正确以及网络是否通畅。"
      exit 1
    fi
  fi
  
  apply_server_mods_to_config
}

# 创建 Docker Compose 文件
create_compose_file() {
  echo_info "正在创建 Docker Compose 文件: $COMPOSE_FILE"
  
  local compose_content
  if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]]; then
    echo_info "正在为 Docker Compose 文件添加 TUN 模式支持..."
    compose_content=$(cat <<EOF
services:
  clash:
    image: ${IMAGE_PROXY_PREFIX}${CLASH_IMAGE}
    container_name: clash
    restart: always
    privileged: true
    cap_add:
      - SYS_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    network_mode: "host"
    volumes:
      - ${CONFIG_FILE}:/root/.config/clash/config.yaml
EOF
)
  else
    compose_content=$(cat <<EOF
services:
  clash:
    image: ${IMAGE_PROXY_PREFIX}${CLASH_IMAGE}
    container_name: clash
    restart: always
    network_mode: "host"
    volumes:
      - ${CONFIG_FILE}:/root/.config/clash/config.yaml
EOF
)
  fi
  echo "$compose_content" > "$COMPOSE_FILE"
}

# 检查 Clash 是否正在运行 (Docker 或 systemd)
is_clash_running() {
    # 检查 docker 是否安装，如果安装了再检查容器状态
    if command -v docker &> /dev/null && [ -n "$(docker ps -q -f name=clash)" ]; then
        return 0 # true
    fi
    # 检查 systemd 服务状态
    if systemctl is-active --quiet clash; then
        return 0 # true
    fi
    return 1 # false
}

# 智能重启 Docker 服务
restart_docker_service() {
    if systemctl list-units --type=service --all | grep -q -w 'docker.service'; then
        echo_info "正在重启 docker.service..."
        systemctl restart docker.service
        return $?
    elif systemctl list-units --type=service --all | grep -q -w 'dockerd.service'; then
        echo_info "正在重启 dockerd.service..."
        systemctl restart dockerd.service
        return $?
    else
        echo_error "未找到 docker.service 或 dockerd.service。无法自动重启 Docker。"
        echo_warn "请手动重启 Docker 服务以应用代理设置。"
        return 1
    fi
}

# 打印状态的辅助函数
print_status() {
    local status_text=$1
    local status_color=$2 # 0 for green (enabled), 1 for red (disabled), 2 for yellow (not set)
    
    if [ "$status_color" -eq 0 ]; then
        echo -e "\033[32m${status_text}\033[0m"
    elif [ "$status_color" -eq 1 ]; then
        echo -e "\033[31m${status_text}\033[0m"
    else
        echo -e "\033[33m${status_text}\033[0m"
    fi
}

# 查看 Clash 运行状态
show_clash_status() {
    check_root
    clear
    echo "================================================="
    echo "            Clash 运行状态检查"
    echo "================================================="

    # 1. Clash Core Status
    echo -n "Clash 核心状态: "
    local install_type="未知"
    if command -v docker &> /dev/null && [ -n "$(docker ps -q -f name=clash)" ]; then
        install_type="Docker"
        print_status "运行中" 0
        echo "  - 安装方式: $install_type"
    elif systemctl is-active --quiet clash; then
        install_type="二进制"
        print_status "运行中" 0
        echo "  - 安装方式: $install_type"
    else
        print_status "未运行" 1
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo_warn "未找到 Clash 配置文件，无法获取详细配置信息。"
        echo "================================================="
        return
    fi

    echo "-------------------------------------------------"
    echo "Clash 配置详情:"
    # 2. LAN Connection
    echo -n "  - 局域网连接 (allow-lan): "
    if grep -q "allow-lan: true" "$CONFIG_FILE"; then
        print_status "已开启" 0
    else
        print_status "已关闭" 1
    fi

    # 3. TUN Mode
    echo -n "  - TUN 模式: "
    if is_tun_enabled; then
        print_status "已开启" 0
    else
        print_status "已关闭" 1
    fi
    
    # 4. Gateway Status
    echo -n "  - 透明网关 (iptables): "
    if command -v iptables-save &> /dev/null && iptables-save | grep -q -- '-j CLASH'; then
         print_status "规则已设置" 0
    else
         print_status "规则未设置" 2
    fi


    echo "-------------------------------------------------"
    echo "系统代理状态:"
    # 5. APT Proxy
    echo -n "  - APT 代理: "
    if [ -f "/etc/apt/apt.conf.d/99proxy.conf" ]; then
        print_status "已设置" 0
    else
        print_status "未设置" 2
    fi

    # 6. Docker Proxy
    echo -n "  - Docker 代理: "
    if [ -f "/etc/systemd/system/docker.service.d/http-proxy.conf" ]; then
        print_status "已设置" 0
    else
        print_status "未设置" 2
    fi

    # 7. System Global Proxy
    echo -n "  - 全局环境变量代理: "
    if [ -f "/etc/environment" ] && grep -q -E "http_proxy|https_proxy" "/etc/environment"; then
        print_status "已设置" 0
    else
        print_status "未设置" 2
    fi
    echo "================================================="
}


# 更新订阅
update_subscription() {
    check_root

    local sub_url_file="$INSTALL_DIR/.subscription_url"
    if [ ! -f "$sub_url_file" ]; then
        echo_error "未找到订阅链接文件。请先执行安装过程以保存订阅链接。"
        return 1
    fi

    CLASH_SUB_URL=$(cat "$sub_url_file")
    if [ -z "$CLASH_SUB_URL" ]; then
        echo_error "订阅链接为空。请检查文件: $sub_url_file"
        return 1
    fi
    
    echo_info "正在使用已保存的链接更新订阅: $CLASH_SUB_URL"
    
    # 从现有配置中推断出 TUN 和 allow-lan 的设置
    if is_tun_enabled; then
        ENABLE_TUN='y'
    else
        ENABLE_TUN='n'
    fi

    if [ -f "$CONFIG_FILE" ] && grep -q "allow-lan: true" "$CONFIG_FILE"; then
        ALLOW_LAN='y'
    else
        ALLOW_LAN='n'
    fi

    # 强制覆盖现有配置文件
    echo_info "正在从订阅链接下载新配置文件..."
    if ! curl -L -A "clash" -o "$CONFIG_FILE" "$CLASH_SUB_URL"; then
        echo_error "下载新订阅文件失败！"
        return 1
    fi
    
    # 重新应用服务器配置
    apply_server_mods_to_config
    
    echo_info "订阅已更新。正在尝试应用新配置..."
    if [ -f "$COMPOSE_FILE" ]; then
        echo_info "检测到 Docker 安装。正在启动/重启容器以应用新配置..."
        local compose_cmd="docker compose"
        if command -v docker-compose &> /dev/null; then
            compose_cmd="docker-compose"
        fi
        (cd "$INSTALL_DIR" && $compose_cmd up -d --force-recreate)

        sleep 3
        if [ -n "$(docker ps -q -f name=clash)" ]; then
            echo_info "Clash (Docker) 服务已成功启动/重启。"
        else
            echo_error "Clash (Docker) 服务未能启动。请使用 'cd ${INSTALL_DIR} && $compose_cmd logs' 查看日志。"
        fi
    elif [ -f "/etc/systemd/system/clash.service" ]; then
        echo_info "检测到二进制安装。正在启动/重启服务以应用新配置..."
        systemctl restart clash
        sleep 3
        if systemctl is-active --quiet clash; then
            echo_info "Clash (二进制) 服务已成功启动/重启。"
        else
            echo_error "Clash (二进制) 服务未能启动。请使用 'journalctl -u clash' 查看日志。"
        fi
    else
        echo_warn "未检测到有效的 Clash 安装。配置文件已更新，请手动启动服务。"
    fi
}

# 启动 Clash 服务
start_clash_service() {
  echo_info "正在使用 Docker Compose 启动 Clash 服务..."
  # 优先使用 docker compose (v2)，如果不存在则使用 docker-compose (v1)
  if command -v docker-compose &> /dev/null; then
    (cd "$INSTALL_DIR" && docker-compose up -d)
  else
    (cd "$INSTALL_DIR" && docker compose up -d)
  fi
}

# 停止并移除 Clash 服务
stop_clash_service() {
    echo_info "正在停止并移除旧的 Clash 容器..."
    if ! [ -f "$COMPOSE_FILE" ]; then
        echo_warn "Docker Compose 文件不存在，无法执行停止操作。"
        return
    fi
    if command -v docker-compose &> /dev/null; then
        (cd "$INSTALL_DIR" && docker-compose down)
    else
        (cd "$INSTALL_DIR" && docker compose down)
        fi
    }
    
    # 停止并移除 Clash 二进制服务
    stop_binary_service() {
        echo_info "正在停止并移除 Clash 二进制服务..."
        if systemctl is-active --quiet clash; then
            systemctl stop clash
            systemctl disable clash
            echo_info "Clash 服务已停止并禁用。"
        fi
        if [ -f "/etc/systemd/system/clash.service" ]; then
            rm -f "/etc/systemd/system/clash.service"
            systemctl daemon-reload
            echo_info "Clash systemd 服务文件已移除。"
        fi
        # 不删除二进制文件本身，以便于重新安装
        # rm -f "$INSTALL_DIR/clash"
    }

# 自动安装 - Docker
install_clash_docker() {
  check_root
  check_docker

  # 检查并停止现有服务
  if is_clash_running; then
    read -p "检测到 Clash 已在运行。是否要停止现有服务并使用 Docker 重新安装？(y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      echo_info "操作已取消。"
      return
    fi
    stop_clash_service
    stop_binary_service
  fi

  get_user_input
  select_image_proxy
  
  prepare_directory

  # 保存订阅链接
  echo "$CLASH_SUB_URL" > "$INSTALL_DIR/.subscription_url"
  if [ $? -ne 0 ]; then
    echo_error "保存订阅链接失败。"
    exit 1
  fi
  echo_info "订阅链接已保存，用于后续更新。"

  # Prompts are removed, variables are now set by install_clash()
  ALLOW_LAN=${ALLOW_LAN:-n}
  ENABLE_TUN=${ENABLE_TUN:-n}

  setup_clash_config
  create_compose_file
  start_clash_service

  # 检查启动结果
  sleep 3 # 等待容器启动
  if [ $? -eq 0 ] && [ -n "$(docker ps -q -f name=clash)" ]; then
    echo_info "============================================================"
    echo_info "Clash 服务已成功启动！"
    
    if [[ "$SETUP_GATEWAY" =~ ^[Yy]$ ]]; then
        setup_standard_gateway
    fi

    echo_info ""
    echo_info "代理地址如下:"
    echo_info "  - HTTP 代理: $PROXY_HTTP"
    echo_info "  - SOCKS5 代理: $PROXY_SOCKS5"
    echo_info "============================================================"
    echo_info "正在进行自动代理测试..."
    test_proxy
  else
    echo_error "Clash 服务启动失败。请运行 'cd ${INSTALL_DIR} && docker compose logs' 查看日志。"
  fi
}

# 创建 systemd 服务文件
create_systemd_service() {
    echo_info "正在创建 systemd 服务文件..."
    local service_content
    service_content=$(cat <<EOF
[Unit]
Description=Clash daemon
After=network.target

[Service]
Type=simple
User=root
ExecStart=$INSTALL_DIR/clash -d $INSTALL_DIR
Restart=on-failure
EOF
)
    # 如果启用了TUN模式，为服务添加网络管理权限
    if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]]; then
        service_content+=$(cat <<EOF
AmbientCapabilities=CAP_NET_ADMIN
CapabilityBoundingSet=CAP_NET_ADMIN
EOF
)
    fi

    service_content+=$(cat <<EOF

[Install]
WantedBy=multi-user.target
EOF
)
    echo "$service_content" > /etc/systemd/system/clash.service
    echo_info "正在重新加载 systemd..."
    systemctl daemon-reload
}

# 自动安装 - 二进制
install_clash_binary() {
    check_root

    # 检查并停止现有服务
    if is_clash_running; then
        read -p "检测到 Clash 已在运行。是否要停止现有服务并使用二进制文件重新安装？(y/N): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            echo_info "操作已取消。"
            return
        fi
        stop_clash_service
        stop_binary_service
    fi

    get_user_input
    prepare_directory

    # 保存订阅链接
    echo "$CLASH_SUB_URL" > "$INSTALL_DIR/.subscription_url"
    if [ $? -ne 0 ]; then
        echo_error "保存订阅链接失败。"
        exit 1
    fi
    echo_info "订阅链接已保存，用于后续更新。"

    # Prompts are removed, variables are now set by install_clash()
    ALLOW_LAN=${ALLOW_LAN:-n}
    ENABLE_TUN=${ENABLE_TUN:-n}

    if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]] && ! command -v ip &> /dev/null; then
        echo_error "启用 TUN 模式需要 'ip' 命令 (通常由 'iproute2' 包提供)，但未找到该命令。"
        echo_warn "将禁用 TUN 模式继续安装。"
        ENABLE_TUN='n'
    fi

    setup_clash_config

    local should_download_binary=true
    if [ -f "$INSTALL_DIR/clash" ]; then
        read -p "检测到已存在的 Clash 二进制文件，是否要重新下载并覆盖它？(y/N): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            echo_info "已跳过下载二进制文件。"
            should_download_binary=false
        fi
    fi

    if [ "$should_download_binary" = true ]; then
        echo_info "正在下载 Clash 二进制文件: $CLASH_BINARY_URL"
        if ! curl -L -o "$INSTALL_DIR/clash.gz" "$CLASH_BINARY_URL"; then
            echo_error "下载 Clash 二进制文件失败！"
            exit 1
        fi

        echo_info "正在解压二进制文件..."
        if ! gunzip -c "$INSTALL_DIR/clash.gz" > "$INSTALL_DIR/clash"; then
            echo_error "解压失败！"
            rm -f "$INSTALL_DIR/clash.gz"
            exit 1
        fi
        rm -f "$INSTALL_DIR/clash.gz"
    fi
    
    chmod +x "$INSTALL_DIR/clash"

    create_systemd_service

    echo_info "正在启动 Clash 服务..."
    systemctl start clash
    systemctl enable clash

    sleep 3
    if systemctl is-active --quiet clash; then
        echo_info "============================================================"
        echo_info "Clash 服务已成功启动！"

        if [[ "$SETUP_GATEWAY" =~ ^[Yy]$ ]]; then
            setup_standard_gateway
        fi

        echo_info ""
        echo_info "代理地址如下:"
        echo_info "  - HTTP 代理: $PROXY_HTTP"
        echo_info "  - SOCKS5 代理: $PROXY_SOCKS5"
        echo_info "============================================================"
        echo_info "正在进行自动代理测试..."
        test_proxy
    else
        echo_error "Clash 服务启动失败。请运行 'journalctl -u clash' 查看日志。"
    fi
}

# 安装 Clash (主入口)
install_clash() {
    check_root
    clear
    # 重置网关设置标志
    SETUP_GATEWAY='n'

    echo "================================================="
    echo "                Clash 安装向导"
    echo "================================================="
    echo "--- 场景 1: 标准代理服务器 (客户端手动配置代理) ---"
    echo " 1. Docker 安装:   标准代理 (局域网设备可通过 IP:Port 连接)"
    echo " 2. 二进制 安装:   标准代理 (局域网设备可通过 IP:Port 连接)"
    echo ""
    echo "--- 场景 2: 本机透明代理 (自动接管本机所有流量) ---"
    echo " 3. Docker 安装:   本机 TUN 代理 (局域网设备可通过 IP:Port 连接)"
    echo " 4. 二进制 安装:   本机 TUN 代理 (局域网设备可通过 IP:Port 连接)"
    echo ""
    echo "--- 场景 3: 局域网网关 (客户端自动全局代理) ---"
    echo " 5. Docker 安装:   标准代理服务网关 ( 接管 TCP和DNS)"
    echo " 6. Docker 安装:   TUN 网关 ( 接管 TCP+UDP，容器中安装需要开启 TUN 模块)"
    echo " 7. 二进制 安装:   标准代理服务网关 ( 接管 TCP和DNS)"
    echo " 8. 二进制 安装:   TUN 网关 (接管 TCP+UDP，容器中安装需要开启 TUN 模块)"
    echo "-------------------------------------------------"
    echo " 0. 返回主菜单"
    echo "================================================="
    read -p "请输入选项 [0-8]: " install_choice

    case $install_choice in
        1)
            echo_info "模式: Docker, 标准代理服务器"
            ALLOW_LAN='y'
            ENABLE_TUN='n'
            install_clash_docker
            ;;
        2)
            echo_info "模式: 二进制, 标准代理服务器"
            ALLOW_LAN='y'
            ENABLE_TUN='n'
            install_clash_binary
            ;;
        3)
            echo_info "模式: Docker, 本机透明代理 (TUN)"
            ALLOW_LAN='y' # 本机透明代理也需要允许局域网连接，以便其他设备使用
            ENABLE_TUN='y'
            install_clash_docker
            ;;
        4)
            echo_info "模式: 二进制, 本机透明代理 (TUN)"
            ALLOW_LAN='y' # 本机透明代理也需要允许局域网连接，以便其他设备使用
            ENABLE_TUN='y'
            install_clash_binary
            ;;
        5)
            echo_info "模式: Docker, 标准代理服务网关"
            ALLOW_LAN='y'
            ENABLE_TUN='n'
            SETUP_GATEWAY='y'
            install_clash_docker
            ;;
        6)
            echo_info "模式: Docker, TUN 网关"
            ALLOW_LAN='y'
            ENABLE_TUN='y'
            SETUP_GATEWAY='y'
            install_clash_docker
            ;;
        7)
            echo_info "模式: 二进制, 标准代理服务网关"
            ALLOW_LAN='y'
            ENABLE_TUN='n'
            SETUP_GATEWAY='y'
            install_clash_binary
            ;;
        8)
            echo_info "模式: 二进制, TUN 网关"
            ALLOW_LAN='y'
            ENABLE_TUN='y'
            SETUP_GATEWAY='y'
            install_clash_binary
            ;;
        0)
            return
            ;;
        *)
            echo_error "无效选项。"
            ;;
    esac
}

# 代理测试
test_proxy() {
    echo_info "开始进行代理可用性测试..."
    
    if ! is_clash_running; then
        echo_error "Clash 服务未运行，无法进行测试。"
        return 1
    fi

    echo_info "第一部分: IP 地址变更测试"
    echo -n "正在获取本机公网 IP ... "
    direct_ip=$(curl --silent --max-time 5 ifconfig.me)
    if [ -n "$direct_ip" ]; then
        echo -e "\033[33m${direct_ip}\033[0m"
    else
        echo -e "\033[31m获取失败\033[0m"
    fi

    echo -n "正在通过 HTTP 代理 ($PROXY_HTTP) 获取公网 IP ... "
    proxy_ip_http=$(curl -x "$PROXY_HTTP" --silent --max-time 10 ifconfig.me)
    if [ -n "$proxy_ip_http" ]; then
        echo -e "\033[32m${proxy_ip_http}\033[0m"
    else
        echo -e "\033[31m获取失败\033[0m"
    fi

    echo -n "正在通过 SOCKS5 代理 ($PROXY_SOCKS5) 获取公网 IP ... "
    proxy_ip_socks=$(curl -x "$PROXY_SOCKS5" --silent --max-time 10 ifconfig.me)
    if [ -n "$proxy_ip_socks" ]; then
        echo -e "\033[32m${proxy_ip_socks}\033[0m"
    else
        echo -e "\033[31m获取失败\033[0m"
    fi

    if [ -n "$direct_ip" ] && [ -n "$proxy_ip_http" ] && [ "$direct_ip" != "$proxy_ip_http" ]; then
        echo_info "HTTP 代理工作正常！"
    else
        echo_warn "HTTP 代理可能未生效或网络异常。"
    fi

    if [ -n "$direct_ip" ] && [ -n "$proxy_ip_socks" ] && [ "$direct_ip" != "$proxy_ip_socks" ]; then
        echo_info "SOCKS5 代理工作正常！"
    else
        echo_warn "SOCKS5 代理可能未生效或网络异常。"
    fi
    
    echo ""
    echo_info "第二部分: 关键服务连通性测试"
    local test_sites=(
        "https://www.github.com"
        "https://hub.docker.com"
        "https://www.google.com"
    )

    echo_info "使用 HTTP 代理进行测试..."
    for site in "${test_sites[@]}"; do
        echo -n "  - 正在测试: $site ... "
        if curl -x "$PROXY_HTTP" --head --silent --fail --max-time 5 "$site" > /dev/null; then
            echo -e "\033[32m连接成功\033[0m"
        else
            echo -e "\033[31m连接失败\033[0m"
        fi
    done

    echo_info "使用 SOCKS5 代理进行测试..."
    for site in "${test_sites[@]}"; do
        echo -n "  - 正在测试: $site ... "
        if curl -x "$PROXY_SOCKS5" --head --silent --fail --max-time 5 "$site" > /dev/null; then
            echo -e "\033[32m连接成功\033[0m"
        else
            echo -e "\033[31m连接失败\033[0m"
        fi
    done
}

# 运行所有连接测试
run_all_tests() {
    echo_info "--- 开始综合连接测试 ---"
    test_proxy
    echo ""
    echo_info "--- 开始测试工具代理 ---"
    test_apt_proxy
    test_docker_proxy
    echo_info "--- 所有测试已完成 ---"
}

# 为 APT 设置代理
set_apt_proxy() {
    check_root
    echo_info "正在为 APT 设置 HTTP 代理..."
    cat <<EOF > /etc/apt/apt.conf.d/99proxy.conf
Acquire::http::Proxy "${PROXY_HTTP}";
Acquire::https::Proxy "${PROXY_HTTP}";
EOF
    echo_info "APT 代理设置完成。配置文件: /etc/apt/apt.conf.d/99proxy.conf"
    echo_warn "要移除代理，请删除该文件: sudo rm /etc/apt/apt.conf.d/99proxy.conf"
}

# 为 Docker 设置代理
set_docker_proxy() {
    check_root
    echo_info "正在为 Docker 服务设置 HTTP 代理..."
    
    local docker_service_dir="/etc/systemd/system/docker.service.d"
    mkdir -p "$docker_service_dir"
    
    cat <<EOF > "${docker_service_dir}/http-proxy.conf"
[Service]
Environment="HTTP_PROXY=${PROXY_HTTP}"
Environment="HTTPS_PROXY=${PROXY_HTTP}"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF

    echo_info "正在重新加载 systemd 并重启 Docker 服务..."
    systemctl daemon-reload
    restart_docker_service
    
    if [ $? -eq 0 ]; then
        echo_info "Docker 代理设置完成。"
        echo_warn "要移除代理，请删除文件 ${docker_service_dir}/http-proxy.conf 并重启 Docker。"
    else
        echo_error "Docker 服务重启失败，请手动检查。"
    fi
}

# 为系统设置代理
set_system_proxy() {
    check_root
    echo_info "正在为系统设置全局代理 (写入 /etc/environment)..."
    
    # 移除旧的代理设置
    sed -i -e '/^http_proxy=/d' -e '/^https_proxy=/d' -e '/^no_proxy=/d' /etc/environment
    
    # 添加新的代理设置
    cat <<EOF >> /etc/environment
http_proxy="${PROXY_HTTP}"
https_proxy="${PROXY_HTTP}"
no_proxy="localhost,127.0.0.1"
EOF
    
    echo_info "系统代理设置完成。"
    echo_warn "此设置为全局生效，但需要重新登录或重启系统才能完全应用。"
    echo_warn "要移除代理，请编辑 /etc/environment 文件并删除相关行。"
}

# 为软件/系统设置代理子菜单
set_proxy_menu() {
    while true; do
        clear
        echo "================================================="
        echo "              为软件/系统设置代理"
        echo "================================================="
        echo "此菜单为特定程序设置 HTTP 代理，在 TUN 模式下通常非必需。"
        echo ""
        echo " 1. 为 APT 设置代理"
        echo " 2. 为 Docker 设置代理"
        echo " 3. 为当前系统设置全局代理 (环境变量)"
        echo "-------------------------------------------------"
        echo " 0. 返回主菜单"
        echo "================================================="
        read -p "请输入选项 [0-3]: " choice

        case $choice in
            1)
                if check_unnecessary_action; then
                    set_apt_proxy
                fi
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
            2)
                if check_unnecessary_action; then
                    set_docker_proxy
                fi
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
            3)
                if check_unnecessary_action; then
                    set_system_proxy
                fi
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
            0)
                return
                ;;
            *)
                echo_error "无效选项，请输入 0 到 3 之间的数字。"
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
        esac
    done
}

# 清除 APT 代理
clear_apt_proxy() {
    check_root
    local apt_proxy_file="/etc/apt/apt.conf.d/99proxy.conf"
    if [ -f "$apt_proxy_file" ]; then
        rm -f "$apt_proxy_file"
        echo_info "APT 代理配置已清除。"
    else
        echo_info "未找到 APT 代理配置，无需清除。"
    fi
}

# 清除 Docker 代理
clear_docker_proxy() {
    check_root
    local docker_proxy_file="/etc/systemd/system/docker.service.d/http-proxy.conf"
    if [ -f "$docker_proxy_file" ]; then
        rm -f "$docker_proxy_file"
        echo_info "Docker 代理配置文件已移除。"
        
        # 只有在 Docker 安装的情况下才尝试重启服务
        if command -v docker &> /dev/null; then
            echo_info "正在重新加载 systemd 并重启 Docker 服务..."
            systemctl daemon-reload
            if restart_docker_service; then
                echo_info "Docker 服务已重启。"
            else
                echo_error "Docker 服务重启失败，请手动检查。"
            fi
        else
            echo_info "检测到 Docker 未安装，跳过重启服务。正在重新加载 systemd..."
            systemctl daemon-reload
        fi
    else
        echo_info "未找到 Docker 代理配置，无需清除。"
    fi
}

# 清除系统代理
clear_system_proxy() {
    check_root
    echo_info "正在清除系统全局代理 (从 /etc/environment)..."
    
    # 检查文件是否存在
    if [ -f "/etc/environment" ]; then
        # 移除代理设置
        sed -i -e '/^http_proxy=/d' -e '/^https_proxy=/d' -e '/^no_proxy=/d' /etc/environment
        echo_info "系统代理设置已清除。"
        echo_warn "需要重新登录或重启系统才能使更改完全生效。"
    else
        echo_info "未找到 /etc/environment 文件，无需清除。"
    fi
}

# 清除代理子菜单
clear_proxy_menu() {
    while true; do
        clear
        echo "================================================="
        echo "                清除代理配置"
        echo "================================================="
        echo " 1. 清除 APT 代理"
        echo " 2. 清除 Docker 代理"
        echo " 3. 清除系统全局代理"
        echo " 4. 清除以上所有代理"
        echo "-------------------------------------------------"
        echo " 0. 返回主菜单"
        echo "================================================="
        read -p "请输入选项 [0-4]: " choice

        case $choice in
            1)
                clear_apt_proxy
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
            2)
                clear_docker_proxy
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
            3)
                clear_system_proxy
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
            4)
                echo_info "正在清除所有代理配置..."
                clear_apt_proxy
                clear_docker_proxy
                clear_system_proxy
                echo_info "所有代理配置清除完毕。"
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
            0)
                return
                ;;
            *)
                echo_error "无效选项，请输入 0 到 4 之间的数字。"
                read -p $'\n按任意键返回子菜单...' -n 1 -r -s
                ;;
        esac
    done
}

# 测试 APT 代理是否生效
test_apt_proxy() {
    check_root
    if is_tun_enabled; then
        echo_info "TUN 模式已开启，APT 流量将自动通过代理。跳过配置文件检查。"
        return
    fi
    local apt_proxy_file="/etc/apt/apt.conf.d/99proxy.conf"
    if [ ! -f "$apt_proxy_file" ]; then
        echo_warn "未找到 APT 代理配置文件，跳过测试。"
        return
    fi
    echo_info "正在测试 APT 代理..."
    echo_info "将运行 'apt-get update' 并检查其是否连接到代理。"
    echo_info "请注意：这会刷新您的包列表。"
    # 通过 grep 查找连接到代理的日志，-q 表示静默模式
    if apt-get -o Debug::Acquire::http=true update 2>&1 | grep -q "Connecting to 127.0.0.1"; then
        echo_info "测试成功：APT 正在通过 Clash 代理 (${PROXY_HTTP}) 进行连接。"
    else
        echo_error "测试失败：APT 未能通过代理连接。请检查 Clash 服务是否运行正常以及代理配置是否正确。"
    fi
}

# 测试 Docker 代理是否生效
test_docker_proxy() {
    check_root
    if is_tun_enabled; then
        echo_info "TUN 模式已开启，Docker 流量将自动通过代理。跳过配置文件检查。"
        return
    fi
    local docker_proxy_file="/etc/systemd/system/docker.service.d/http-proxy.conf"
    if [ ! -f "$docker_proxy_file" ]; then
        echo_warn "未找到 Docker 代理配置文件，跳过测试。"
        return
    fi
    echo_info "正在检查 Docker 服务的环境变量..."
    if systemctl show --property=Environment docker | grep -q "HTTP_PROXY=${PROXY_HTTP}"; then
        echo_info "检查通过：Docker 服务的代理环境变量已正确设置。"
        echo_info "你可以尝试拉取一个镜像来进一步验证，例如: docker pull hello-world"
    else
        echo_error "检查失败：Docker 服务的代理环境变量未设置或不正确。"
        echo_warn "请确保你已在菜单中设置了 Docker 代理并重启了 Docker 服务。"
    fi
}

# 检查TUN模式是否已启用
is_tun_enabled() {
    # 检查 Docker 安装的 TUN 模式
    if [ -f "$COMPOSE_FILE" ] && grep -q "privileged: true" "$COMPOSE_FILE"; then
        return 0 # Docker TUN is enabled
    fi

    # 检查二进制安装的 TUN 模式
    local service_file="/etc/systemd/system/clash.service"
    if [ -f "$service_file" ] && grep -q "CAP_NET_ADMIN" "$service_file"; then
        return 0 # Binary TUN is enabled
    fi

    return 1 # TUN not enabled or not detectable
}

# 检查并警告不必要的操作
check_unnecessary_action() {
    if is_tun_enabled; then
        echo_warn "TUN 模式已开启，此操作可能是不必要的，因为 TUN 会接管全局流量。"
        read -p "是否仍要继续？(y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo_info "操作已取消。"
            return 1
        fi
    fi
    return 0
}

# --- 系统与网络辅助函数 ---

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        OS="Debian"
    elif [ -f /etc/redhat-release ]; then
        OS="CentOS" # or RHEL
    else
        OS=$(uname -s)
    fi
    echo "$OS"
}

# 通用包安装函数
install_package() {
    local package_name=$1
    local os_name
    os_name=$(detect_os)

    echo_info "正在为 $os_name 安装 '$package_name'..."
    # 使用 case 和通配符进行更灵活的匹配
    case "$os_name" in
        *Ubuntu*|*Debian*)
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package_name"
            ;;
        *CentOS*|*Red*Hat*)
            yum install -y "$package_name"
            ;;
        *)
            echo_error "不支持的操作系统: $os_name。请手动安装 '$package_name'。"
            return 1
            ;;
    esac
}

# 设置透明网关 (标准和TUN模式共用)
setup_standard_gateway() {
    check_root
    echo_info "正在配置透明网关..."

    # 1. 开启 IP 转发
    echo_info "正在开启内核 IP 转发并持久化..."
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    sysctl -p
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -ne 1 ]; then
        echo_error "开启 IP 转发失败！"
        exit 1
    fi

    # 2. 确保 iptables 已安装
    if ! command -v iptables &> /dev/null; then
        echo_warn "iptables 命令未找到。正在尝试自动安装..."
        install_package "iptables"
        if ! command -v iptables &> /dev/null; then
            echo_error "iptables 安装失败。请手动安装后重试。"
            exit 1
        fi
    fi
    
    # 3. 配置 iptables 规则
    echo_info "正在配置 iptables 规则 (使用 CLASH 自定义链)..."
    local lan_ip_range
    lan_ip_range=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)
    local server_ip
    server_ip=$(echo "$lan_ip_range" | cut -d'/' -f1)

    # 创建 CLASH 链
    iptables -t nat -N CLASH &>/dev/null
    # 清空旧规则
    iptables -t nat -F CLASH

    # 忽略发往 Clash 服务器自身和私有地址的流量
    iptables -t nat -A CLASH -d "$server_ip" -j RETURN
    iptables -t nat -A CLASH -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A CLASH -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A CLASH -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A CLASH -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A CLASH -d 224.0.0.0/4 -j RETURN
    iptables -t nat -A CLASH -d 240.0.0.0/4 -j RETURN

    # 将剩余 TCP 流量重定向到 Clash 的 redir-port
    if [[ "$ENABLE_TUN" != "y" ]]; then # 只有标准网关需要重定向TCP
        iptables -t nat -A CLASH -p tcp -j REDIRECT --to-port 7892
    fi

    # 清空 PREROUTING 链中的旧规则
    iptables -t nat -D PREROUTING -p tcp -j CLASH &>/dev/null
    iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 1053 &>/dev/null

    # 将 PREROUTING 链中的流量引导至 CLASH 链
    iptables -t nat -A PREROUTING -p tcp -j CLASH
    # 将 DNS 请求重定向到 Clash 的 DNS 端口
    iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 1053

    # 为局域网设备做 SNAT
    iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE &>/dev/null
    iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
    
    echo_info "iptables 规则配置完成。正在持久化规则..."
    
    # 4. 持久化 iptables 规则
    local os_name
    os_name=$(detect_os)
    case "$os_name" in
        *Ubuntu*|*Debian*)
            if ! command -v netfilter-persistent &> /dev/null; then
                install_package "iptables-persistent"
            fi
            # 预设答案，避免交互
            echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
            echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
            DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
            netfilter-persistent save
            ;;
        *CentOS*|*Red*Hat*)
            if ! command -v service &> /dev/null || ! systemctl list-unit-files | grep -q iptables.service; then
                install_package "iptables-services"
            fi
            service iptables save
            systemctl enable iptables
            ;;
        *)
            echo_warn "无法为 $os_name 自动持久化 iptables 规则。请手动操作。"
            ;;
    esac
    
    echo_info "透明网关配置完成。"
}


# 清除局域网网关设置
clear_gateway() {
    check_root
    echo_info "正在禁用内核 IP 转发..."
    sysctl -w net.ipv4.ip_forward=0
    sed -i '/^net.ipv4.ip_forward=1/d' /etc/sysctl.conf

    if command -v iptables &> /dev/null; then
        echo_info "正在清除 iptables 网关规则..."
        # 清除 PREROUTING 和 POSTROUTING 中的规则
        iptables -t nat -D PREROUTING -p tcp -j CLASH &>/dev/null
        iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 1053 &>/dev/null
        iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE &>/dev/null
        
        # 清空并删除 CLASH 链
        iptables -t nat -F CLASH &>/dev/null
        iptables -t nat -X CLASH &>/dev/null
        
        # 尝试保存规则
        local os_name
        os_name=$(detect_os)
        case "$os_name" in
            *Ubuntu*|*Debian*)
                if command -v netfilter-persistent &> /dev/null; then
                    echo_info "正在保存已清除的 iptables 规则..."
                    netfilter-persistent save
                fi
                ;;
            *CentOS*|*Red*Hat*)
                if command -v service &> /dev/null; then
                    echo_info "正在保存已清除的 iptables 规则..."
                    service iptables save
                fi
                ;;
        esac
    fi
    echo_info "网关设置已清除。"
}

# 卸载 Clash
uninstall_clash() {
    check_root
    echo_warn "警告：此操作将停止 Clash 服务，并永久删除所有相关配置和文件！"
    read -p "确定要卸载 Clash 吗？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo_info "操作已取消。"
        return
    fi

    echo_info "正在开始卸载流程..."
    
    # 1. 停止服务
    stop_clash_service
    stop_binary_service
    
    # 2. 清除网关设置
    clear_gateway
    
    # 3. 清除所有代理配置
    echo_info "正在清除所有代理配置..."
    clear_apt_proxy
    clear_docker_proxy
    clear_system_proxy
    
    # 4. 删除安装目录
    if [ -d "$INSTALL_DIR" ]; then
        echo_info "正在删除安装目录: $INSTALL_DIR"
        rm -rf "$INSTALL_DIR"
    fi
    
    echo_info "Clash 已成功卸载。"
}

# 显示菜单
show_menu() {
    clear
    echo "================================================="
    echo "            Clash 管理脚本"
    echo "================================================="
    echo " 1. 安装 Clash"
    echo " 2. 更新订阅"
    echo " 3. 查看当前 Clash 运行状态"
    echo " 4. 运行所有连接测试"
    echo " 5. 为软件/系统设置代理"
    echo " 6. 清除代理配置"
    echo " 7. 卸载 Clash"
    echo "-------------------------------------------------"
    echo " 0. 退出脚本"
    echo "================================================="
    read -p "请输入选项 [0-7]: " choice
    
    case $choice in
        1)
            install_clash
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        2)
            update_subscription
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        3)
            show_clash_status
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        4)
            run_all_tests
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        5)
            set_proxy_menu
            ;;
        6)
            clear_proxy_menu
            ;;
        7)
            uninstall_clash
            # 卸载后脚本的功能基本失效，直接退出
            if [ $? -eq 0 ]; then
                exit 0
            fi
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        0)
            exit 0
            ;;
        *)
            echo_error "无效选项，请输入 0 到 7 之间的数字。"
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
    esac
}

# --- 主程序 ---
main() {
    # 主循环，显示菜单
    while true; do
        show_menu
    done
}

# 执行主程序
main "$@"
