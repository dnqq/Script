#!/bin/bash

# ==============================================================================
# Mihomo 一键安装及管理脚本
#
# 功能:
#   - 自动在 Debian/Ubuntu/CentOS 服务器上使用 Docker 或 二进制文件 部署 Mihomo。
#   - 支持通过参数或交互式输入获取订阅链接。
#   - 自动下载并修改配置文件以适应服务器环境。
#   - 将 Mihomo 设置为开机自启动。
#   - 提供多种安装模式：标准代理、本机透明代理、局域网透明网关。
#   - 自动处理依赖安装、防火墙规则设置与持久化。
#
# 使用方法:
#   1. 赋予脚本执行权限: chmod +x install_mihomo.sh
#   2. 运行脚本:
#      - 显示菜单: sudo ./install_mihomo.sh
#
# 安装后信息:
#   - 软件目录: /opt/mihomo
#   - Docker Compose 文件: /opt/mihomo/docker-compose.yml
#   - 配置文件: /opt/mihomo/config.yaml
#   - HTTP 代理地址: http://127.0.0.1:7890
#   - SOCKS5 代理地址: socks5://127.0.0.1:7891
# ==============================================================================

# --- 配置变量 ---
# Mihomo 的安装和配置目录
INSTALL_DIR="/opt/mihomo"
# 配置文件路径
CONFIG_FILE="$INSTALL_DIR/data/config.yaml"
# Docker Compose 文件路径
COMPOSE_FILE="$INSTALL_DIR/docker-compose.yml"
# Mihomo 镜像
MIHOMO_IMAGE="metacubex/mihomo:latest"
# Mihomo 二进制文件基础下载链接
MIHOMO_BINARY_BASE_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.13/mihomo-linux-amd64-v1-v1.19.13.gz"
# GeoIP 数据库下载链接
GEOIP_METADB_URL="https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb"
# 加速代理地址
PROXY_URL_HUBPROXY="https://hubproxy.739999.xyz"
PROXY_URL_DEMO="https://demo.52013120.xyz"
# 代理地址
# 端口配置
MIHOMO_HTTP_PORT="7890"
MIHOMO_SOCKS_PORT="7891"
MIHOMO_REDIR_PORT="7892"
MIHOMO_TPROXY_PORT="7893"
MIHOMO_DNS_PORT="1053"
MIHOMO_EXTERNAL_CONTROLLER_PORT="9090"

# 代理地址
PROXY_HTTP="http://127.0.0.1:${MIHOMO_HTTP_PORT}"
PROXY_SOCKS5="socks5://127.0.0.1:${MIHOMO_SOCKS_PORT}"
IMAGE_PROXY_PREFIX=""
MIHOMO_BINARY_URL=""

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
  if [ -z "$SUB_URL" ]; then
    read -p "请输入您的订阅链接: " SUB_URL
    if [ -z "$SUB_URL" ]; then
      echo_error "订阅链接不能为空！"
      exit 1
    fi
  fi
}

# 选择镜像代理
select_image_proxy() {
  echo_info "请选择 Docker 镜像拉取方式:"
  echo " 1. 直接拉取"
  echo " 2. 使用 hubproxy.739999.xyz 加速 (默认)"
  echo " 3. 使用 demo.52013120.xyz 加速"
  read -p "请输入选项 [1-3, 默认 2]: " proxy_choice
  
  case $proxy_choice in
    1)
      IMAGE_PROXY_PREFIX=""
      echo_info "已选择直接拉取镜像。"
      ;;
    3)
      IMAGE_PROXY_PREFIX="demo.52013120.xyz/"
      echo_info "已选择使用 demo.52013120.xyz 加速。"
      ;;
    *) # 默认 2
      IMAGE_PROXY_PREFIX="hubproxy.739999.xyz/"
      echo_info "已选择使用 hubproxy.739999.xyz 加速。"
      ;;
  esac
}

# 选择二进制文件下载链接
select_binary_url() {
  echo_info "请选择 Mihomo 二进制文件下载源:"
  echo " 1. GitHub (直连)"
  echo " 2. GitHub (通过 hubproxy.739999.xyz 加速) (默认)"
  echo " 3. GitHub (通过 demo.52013120.xyz 加速)"
  read -p "请输入选项 [1-3, 默认 2]: " binary_choice

  case $binary_choice in
    1)
      MIHOMO_BINARY_URL="$MIHOMO_BINARY_BASE_URL"
      echo_info "已选择 GitHub (直连) 作为下载源。"
      ;;
    3)
      MIHOMO_BINARY_URL="${PROXY_URL_DEMO}/${MIHOMO_BINARY_BASE_URL}"
      echo_info "已选择 GitHub (通过 demo.52013120.xyz 加速) 作为下载源。"
      ;;
    *) # 默认 2
      MIHOMO_BINARY_URL="${PROXY_URL_HUBPROXY}/${MIHOMO_BINARY_BASE_URL}"
      echo_info "已选择 GitHub (通过 hubproxy.739999.xyz 加速) 作为下载源。"
      ;;
  esac
}

# 创建并准备目录
prepare_directory() {
  echo_info "正在创建配置目录: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR/data"
  if [ $? -ne 0 ]; then
    echo_error "创建目录 $INSTALL_DIR 失败。"
    exit 1
  fi
}

# 下载 GeoIP 数据库
download_geoip_database() {
  echo_info "正在下载 GeoIP 数据库 (geoip.metadb)..."
  # 默认使用 hubproxy 加速
  local download_url="${PROXY_URL_HUBPROXY}/${GEOIP_METADB_URL}"
  
  if ! curl -L -o "$INSTALL_DIR/data/geoip.metadb" "$download_url"; then
    echo_warn "通过代理下载 GeoIP 数据库失败，尝试直连下载..."
    if ! curl -L -o "$INSTALL_DIR/data/geoip.metadb" "$GEOIP_METADB_URL"; then
      echo_error "下载 GeoIP 数据库失败！"
      echo_warn "您可以稍后手动下载 ${GEOIP_METADB_URL} 到 ${INSTALL_DIR}/data/ 目录。"
      return 1
    fi
  fi
  echo_info "GeoIP 数据库下载成功。"
  return 0
}

# 应用服务器特定的配置修改
apply_server_mods_to_config() {
  echo_info "正在为服务器环境优化配置文件..."
  # 安全地删除我们想要控制的单行配置，避免冲突和破坏文件
  sed -i -e '/^port:/d' \
         -e '/^socks-port:/d' \
         -e '/^mixed-port:/d' \
         -e '/^redir-port:/d' \
         -e '/^tproxy-port:/d' \
         -e '/^allow-lan:/d' \
         -e '/^external-controller:/d' \
         -e '/^log-level:/d' "$CONFIG_FILE"

  # 根据用户选择设置 allow-lan
  local allow_lan_value="false"
  if [[ "$ALLOW_LAN" =~ ^[Yy]$ ]]; then
    allow_lan_value="true"
  fi

  # 追加一个完整的、正确的服务器配置块
  cat <<EOF >> "$CONFIG_FILE"

# --- Appended by install_mihomo.sh for server environment (safe-append) ---
# The following settings override any previous definitions in this file.
port: ${MIHOMO_HTTP_PORT}
socks-port: ${MIHOMO_SOCKS_PORT}
redir-port: ${MIHOMO_REDIR_PORT}
tproxy-port: ${MIHOMO_TPROXY_PORT}
allow-lan: ${allow_lan_value}
external-controller: "0.0.0.0:${MIHOMO_EXTERNAL_CONTROLLER_PORT}"
log-level: info
EOF

  # 如果是网关模式，智能处理 DNS 配置
  if [[ "$SETUP_GATEWAY" =~ ^[Yy]$ ]]; then
    # 检查配置文件中是否已存在 dns: 配置
    if grep -q -E "^\s*dns:" "$CONFIG_FILE"; then
      echo_info "检测到现有 DNS 配置，正在为网关模式调整关键设置..."
      # 智能地修改或添加 'enable', 'listen', 和 'enhanced-mode'，最大限度保留用户原有配置
      
      # 1. 确保 enable: true
      if sed -n '/^\s*dns:/,/^[^[:space:]]/p' "$CONFIG_FILE" | grep -q '^\s*enable:'; then
        sed -i -E '/^\s*dns:/,/^[^[:space:]]/s/^(\s*enable:).*/\1 true/' "$CONFIG_FILE"
      else
        sed -i '/^\s*dns:/a \  enable: true' "$CONFIG_FILE"
      fi
      
      # 2. 确保 listen: 0.0.0.0:1053
      if sed -n '/^\s*dns:/,/^[^[:space:]]/p' "$CONFIG_FILE" | grep -q '^\s*listen:'; then
        sed -i -E "/^\s*dns:/,/^[^[:space:]]/s/^(\s*listen:).*/\1 0.0.0.0:${MIHOMO_DNS_PORT}/" "$CONFIG_FILE"
      else
        sed -i "/^\s*dns:/a \  listen: 0.0.0.0:${MIHOMO_DNS_PORT}" "$CONFIG_FILE"
      fi
      
      # 3. 确保 enhanced-mode: redir-host (网关模式所需)
      if sed -n '/^\s*dns:/,/^[^[:space:]]/p' "$CONFIG_FILE" | grep -q '^\s*enhanced-mode:'; then
        sed -i -E '/^\s*dns:/,/^[^[:space:]]/s/^(\s*enhanced-mode:).*/\1 redir-host/' "$CONFIG_FILE"
      else
        sed -i '/^\s*dns:/a \  enhanced-mode: redir-host' "$CONFIG_FILE"
      fi
      echo_info "DNS 配置已调整，保留了大部分原有设置。"
    else
      echo_info "未检测到 DNS 配置，正在为网关模式添加默认 DNS 设置..."
      cat <<EOF >> "$CONFIG_FILE"
dns:
  enable: true
  listen: 0.0.0.0:${MIHOMO_DNS_PORT}
  enhanced-mode: redir-host
  nameserver:
    - 114.114.114.114
    - 8.8.8.8
  fallback:
    - https://dns.google/dns-query
    - https://1.1.1.1/dns-query
EOF
    fi
  fi

  # 如果启用了TUN模式，则追加TUN配置
  if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]]; then
    # 同样检查是否已存在 tun: 配置
    if ! grep -q -E "^\s*tun:" "$CONFIG_FILE"; then
      echo_info "正在为配置文件添加 TUN 模式支持..."
      cat <<EOF >> "$CONFIG_FILE"
tun:
  enable: true
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true
EOF
    fi
  fi
  echo_info "配置文件优化完成。"
}

# 下载并修改配置
setup_config() {
  # 1. 检查是否已存在配置文件
  if [ -f "$CONFIG_FILE" ]; then
    read -p "检测到已存在的配置文件 (config.yaml)，是否要下载新配置并覆盖它？(y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      echo_info "已选择不下载新配置。将仅对现有配置文件进行二次处理..."
      apply_server_mods_to_config
      return 0 # 任务完成
    fi
  fi

  # 2. 如果需要下载 (文件不存在或用户选择覆盖)
  get_user_input # 获取 SUB_URL
  
  # 保存订阅链接以备将来更新
  echo "$SUB_URL" > "$INSTALL_DIR/.subscription_url"
  if [ $? -ne 0 ]; then
    echo_error "保存订阅链接失败。"
    exit 1
  fi
  echo_info "订阅链接已保存，用于后续更新。"

  # 3. 调用统一的函数进行下载和处理
  _fetch_and_process_config "$SUB_URL" || exit 1
}

# 创建 Docker Compose 文件
create_compose_file() {
  echo_info "正在创建 Docker Compose 文件: $COMPOSE_FILE"
  
  local compose_content
  if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]]; then
    echo_info "正在为 Docker Compose 文件添加 TUN 模式支持..."
    compose_content=$(cat <<EOF
services:
  mihomo:
    image: ${IMAGE_PROXY_PREFIX}${MIHOMO_IMAGE}
    container_name: mihomo
    restart: always
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    network_mode: "host"
    volumes:
      - ${INSTALL_DIR}/data:/root/.config/mihomo
EOF
)
  else
    compose_content=$(cat <<EOF
services:
  mihomo:
    image: ${IMAGE_PROXY_PREFIX}${MIHOMO_IMAGE}
    container_name: mihomo
    restart: always
    network_mode: "host"
    volumes:
      - ${INSTALL_DIR}/data:/root/.config/mihomo
EOF
)
  fi
  echo "$compose_content" > "$COMPOSE_FILE"
}

# 检查 Mihomo 是否正在运行 (Docker 或 systemd)
is_mihomo_running() {
    # 检查 docker 是否安装，如果安装了再检查容器状态
    if command -v docker &> /dev/null && [ -n "$(docker ps -q -f name=mihomo)" ]; then
        return 0 # true
    fi
    # 检查 systemd 服务状态
    if systemctl is-active --quiet mihomo; then
        return 0 # true
    fi
    return 1 # false
}

# 等待 Mihomo 服务启动并准备就绪
wait_for_mihomo() {
    echo_info "正在等待 Mihomo 服务完全启动..."
    local max_retries=10
    local retry_count=0
    local retry_sleep=3 # 每3秒检查一次

    # 首先，确保服务在 systemd 或 Docker 中被报告为“正在运行”
    if ! is_mihomo_running; then
        echo_error "Mihomo 服务未能启动。"
        return 1
    fi

    echo_info "服务已启动，正在等待 API 接口就绪..."
    while [ $retry_count -lt $max_retries ]; do
        # 检查 external-controller 端口是否可访问
        if curl --silent --max-time 2 "http://127.0.0.1:${MIHOMO_EXTERNAL_CONTROLLER_PORT}/" > /dev/null; then
            echo_info "Mihomo API 接口已响应。"
            echo_info "等待 5 秒以确保代理链和规则完全加载..."
            sleep 5
            echo_info "Mihomo 服务已准备就绪。"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo_info "等待 API 接口... (${retry_count}/${max_retries})，将在 ${retry_sleep} 秒后重试。"
            sleep $retry_sleep
        fi
    done

    echo_error "在 $(($max_retries * $retry_sleep + 5)) 秒内 Mihomo API 未能响应。"
    echo_warn "将继续执行后续步骤，但可能会失败。"
    return 1
}

# 从现有配置和系统状态推断出当前的运行模式
_infer_current_state() {
    echo_info "正在从现有配置和系统状态推断运行模式..."
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

    if command -v iptables-save &> /dev/null && iptables-save | grep -q -- '-j CLASH'; then
        echo_info "检测到活动的 iptables 网关规则，将以网关模式更新配置。"
        SETUP_GATEWAY='y'
    else
        SETUP_GATEWAY='n'
    fi
}

# 下载并处理配置文件 (下载 + 二次处理)
_fetch_and_process_config() {
    local sub_url="$1"
    
    echo_info "正在从订阅链接下载配置文件: $sub_url"
    if ! curl -L -A "clash" -o "$CONFIG_FILE" "$sub_url"; then
        echo_error "下载订阅文件失败！请检查链接是否正确以及网络是否通畅。"
        return 1
    fi

    echo_info "下载完成，正在进行二次处理..."
    apply_server_mods_to_config
    return 0
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

# 查看 Mihomo 运行状态
show_mihomo_status() {
    check_root
    clear
    echo "================================================="
    echo "            Mihomo 运行状态检查"
    echo "================================================="

    # 1. Mihomo Core Status
    echo -n "Mihomo 核心状态: "
    local install_type="未知"
    if command -v docker &> /dev/null && [ -n "$(docker ps -q -f name=mihomo)" ]; then
        install_type="Docker"
        print_status "运行中" 0
        echo "  - 安装方式: $install_type"
    elif systemctl is-active --quiet mihomo; then
        install_type="二进制"
        print_status "运行中" 0
        echo "  - 安装方式: $install_type"
    else
        print_status "未运行" 1
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo_warn "未找到配置文件，无法获取详细配置信息。"
        echo "================================================="
        return
    fi

    echo "-------------------------------------------------"
    echo "配置详情:"
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
    if command -v iptables-save &> /dev/null && iptables-save | grep -q -- '-j MIHOMO'; then
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
    echo "-------------------------------------------------"
    echo "代理地址信息:"
    local server_ip
    # 尝试获取主网卡的 IP 地址
    server_ip=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1 | cut -d'/' -f1)

    # 从配置文件读取端口，如果失败则使用默认值
    local http_port
    local socks_port
    http_port=$(grep -E "^port:" "$CONFIG_FILE" | sed 's/port: *//' | tr -d '\r')
    socks_port=$(grep -E "^socks-port:" "$CONFIG_FILE" | sed 's/socks-port: *//' | tr -d '\r')
    
    http_port=${http_port:-7890}
    socks_port=${socks_port:-7891}

    echo "  - 本机 HTTP 代理: http://127.0.0.1:${http_port}"
    echo "  - 本机 SOCKS5 代理: socks5://127.0.0.1:${socks_port}"

    if grep -q "allow-lan: true" "$CONFIG_FILE"; then
        if [ -n "$server_ip" ]; then
            echo "  - 局域网 HTTP 代理: http://${server_ip}:${http_port}"
            echo "  - 局域网 SOCKS5 代理: socks5://${server_ip}:${socks_port}"
        else
            echo "  - 局域网代理: (无法自动检测局域网 IP)"
        fi
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

    SUB_URL=$(cat "$sub_url_file")
    if [ -z "$SUB_URL" ]; then
        echo_error "订阅链接为空。请检查文件: $sub_url_file"
        return 1
    fi
    
    echo_info "正在使用已保存的链接更新订阅: $SUB_URL"
    
    # 调用统一的函数来从系统状态推断出所有必要的模式变量
    _infer_current_state
    
    # 调用统一的函数进行下载和处理
    if ! _fetch_and_process_config "$SUB_URL"; then
        return 1 # 如果下载或处理失败，则中止
    fi
    
    echo_info "订阅已更新。正在尝试应用新配置..."
    if [ -f "$COMPOSE_FILE" ]; then
        echo_info "检测到 Docker 安装。正在启动/重启容器以应用新配置..."
        local compose_cmd="docker compose"
        if command -v docker-compose &> /dev/null; then
            compose_cmd="docker-compose"
        fi
        (cd "$INSTALL_DIR" && $compose_cmd up -d --force-recreate)

        echo_info "等待容器重启..."
        sleep 5 # Give container time to be created
        if [ -n "$(docker ps -q -f name=mihomo)" ]; then
            wait_for_mihomo
            echo_info "Mihomo (Docker) 服务已成功启动/重启。"
        else
            echo_error "Mihomo (Docker) 服务未能启动。请使用 'cd ${INSTALL_DIR} && $compose_cmd logs' 查看日志。"
        fi
    elif [ -f "/etc/systemd/system/mihomo.service" ]; then
        echo_info "检测到二进制安装。正在启动/重启服务以应用新配置..."
        systemctl restart mihomo
        if systemctl is-active --quiet mihomo; then
            wait_for_mihomo
            echo_info "Mihomo (二进制) 服务已成功启动/重启。"
        else
            echo_error "Mihomo (二进制) 服务未能启动。请使用 'journalctl -u mihomo' 查看日志。"
        fi
    else
        echo_warn "未检测到有效的 Mihomo 安装。配置文件已更新，请手动启动服务。"
    fi
}

# 启动 Mihomo 服务
start_mihomo_service() {
  echo_info "正在使用 Docker Compose 启动 Mihomo 服务..."
  # 优先使用 docker compose (v2)，如果不存在则使用 docker-compose (v1)
  if command -v docker-compose &> /dev/null; then
    (cd "$INSTALL_DIR" && docker-compose up -d)
  else
    (cd "$INSTALL_DIR" && docker compose up -d)
  fi
}

# 停止并移除 Mihomo 服务
stop_mihomo_service() {
    echo_info "正在停止并移除旧的 Mihomo 容器..."
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
    
    # 停止并移除 Mihomo 二进制服务
    stop_binary_service() {
        echo_info "正在停止并移除 Mihomo 二进制服务..."
        if systemctl is-active --quiet mihomo; then
            systemctl stop mihomo
            systemctl disable mihomo
            echo_info "Mihomo 服务已停止并禁用。"
        fi
        if [ -f "/etc/systemd/system/mihomo.service" ]; then
            rm -f "/etc/systemd/system/mihomo.service"
            systemctl daemon-reload
            echo_info "Mihomo systemd 服务文件已移除。"
        fi
        # 不删除二进制文件本身，以便于重新安装
        # rm -f "$INSTALL_DIR/mihomo"
    }

# 自动安装 - Docker
install_mihomo_docker() {
  check_root
  check_docker

  # 检查并停止现有服务
  if is_mihomo_running; then
    read -p "检测到 Mihomo 已在运行。是否要停止现有服务并使用 Docker 重新安装？(y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      echo_info "操作已取消。"
      return
    fi
    stop_mihomo_service
    stop_binary_service
    # 在重新安装前，主动清理旧的网关规则，确保一个干净的状态
    echo_info "检测到重装操作，正在强制清理旧的网关规则..."
    clear_gateway
  fi

  select_image_proxy
  
  prepare_directory

  # Prompts are removed, variables are now set by install_mihomo()
  ALLOW_LAN=${ALLOW_LAN:-n}
  ENABLE_TUN=${ENABLE_TUN:-n}

  setup_config
  download_geoip_database
  create_compose_file
  start_mihomo_service

  # 检查启动结果
  echo_info "等待容器启动..."
  sleep 5 # 等待容器有足够时间创建
  if [ -n "$(docker ps -q -f name=mihomo)" ]; then
    wait_for_mihomo
    echo_info "============================================================"
    echo_info "Mihomo 服务已成功启动！"
    
    if [[ "$SETUP_GATEWAY" =~ ^[Yy]$ ]]; then
        if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]]; then
            setup_tun_gateway
        else
            setup_standard_gateway
        fi
    fi

    echo_info ""
    echo_info "代理地址如下:"
    echo_info "  - HTTP 代理: $PROXY_HTTP"
    echo_info "  - SOCKS5 代理: $PROXY_SOCKS5"
    echo_info "============================================================"
    echo_info "正在进行自动代理测试..."
    test_proxy
  else
    echo_error "Mihomo 服务启动失败。请运行 'cd ${INSTALL_DIR} && docker compose logs' 查看日志。"
  fi
}

# 创建 systemd 服务文件
create_systemd_service() {
    echo_info "正在创建 systemd 服务文件..."
    local service_content
    service_content=$(cat <<EOF
[Unit]
Description=Mihomo daemon
After=network.target

[Service]
Type=simple
User=root
ExecStart=$INSTALL_DIR/mihomo -d $INSTALL_DIR/data
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
    echo "$service_content" > /etc/systemd/system/mihomo.service
    echo_info "正在重新加载 systemd..."
    systemctl daemon-reload
}

# 自动安装 - 二进制
install_mihomo_binary() {
    check_root

    # 检查并停止现有服务
    if is_mihomo_running; then
        read -p "检测到 Mihomo 已在运行。是否要停止现有服务并使用二进制文件重新安装？(y/N): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            echo_info "操作已取消。"
            return
        fi
        stop_mihomo_service
        stop_binary_service
        # 在重新安装前，主动清理旧的网关规则，确保一个干净的状态
        echo_info "检测到重装操作，正在强制清理旧的网关规则..."
        clear_gateway
    fi

    prepare_directory

    # Prompts are removed, variables are now set by install_mihomo()
    ALLOW_LAN=${ALLOW_LAN:-n}
    ENABLE_TUN=${ENABLE_TUN:-n}

    if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]] && ! command -v ip &> /dev/null; then
        echo_error "启用 TUN 模式需要 'ip' 命令 (通常由 'iproute2' 包提供)，但未找到该命令。"
        echo_warn "将禁用 TUN 模式继续安装。"
        ENABLE_TUN='n'
    fi

    setup_config
    download_geoip_database

    local should_download_binary=true
    if [ -f "$INSTALL_DIR/mihomo" ]; then
        read -p "检测到已存在的 Mihomo 二进制文件，是否要重新下载并覆盖它？(y/N): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            echo_info "已跳过下载二进制文件。"
            should_download_binary=false
        fi
    fi

    if [ "$should_download_binary" = true ]; then
        select_binary_url
        echo_info "正在下载 Mihomo 二进制文件: $MIHOMO_BINARY_URL"
        if ! curl -L -o "$INSTALL_DIR/mihomo.gz" "$MIHOMO_BINARY_URL"; then
            echo_error "下载 Mihomo 二进制文件失败！"
            exit 1
        fi

        echo_info "正在解压二进制文件..."
        if ! gunzip -c "$INSTALL_DIR/mihomo.gz" > "$INSTALL_DIR/mihomo"; then
            echo_error "解压失败！"
            rm -f "$INSTALL_DIR/mihomo.gz"
            exit 1
        fi
        rm -f "$INSTALL_DIR/mihomo.gz"
    fi
    
    chmod +x "$INSTALL_DIR/mihomo"

    create_systemd_service

    echo_info "正在启动 Mihomo 服务..."
    systemctl start mihomo
    systemctl enable mihomo

    if systemctl is-active --quiet mihomo; then
        wait_for_mihomo
        echo_info "============================================================"
        echo_info "Mihomo 服务已成功启动！"

        if [[ "$SETUP_GATEWAY" =~ ^[Yy]$ ]]; then
            if [[ "$ENABLE_TUN" =~ ^[Yy]$ ]]; then
                setup_tun_gateway
            else
                setup_standard_gateway
            fi
        fi

        echo_info ""
        echo_info "代理地址如下:"
        echo_info "  - HTTP 代理: $PROXY_HTTP"
        echo_info "  - SOCKS5 代理: $PROXY_SOCKS5"
        echo_info "============================================================"
        echo_info "正在进行自动代理测试..."
        test_proxy
    else
        echo_error "Mihomo 服务启动失败。请运行 'journalctl -u mihomo' 查看日志。"
    fi
}

# 安装 Mihomo (主入口)
install_mihomo() {
    check_root
    clear
    # 重置网关设置标志
    SETUP_GATEWAY='n'

    echo "================================================="
    echo "                Mihomo 安装向导"
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
            install_mihomo_docker
            ;;
        2)
            echo_info "模式: 二进制, 标准代理服务器"
            ALLOW_LAN='y'
            ENABLE_TUN='n'
            install_mihomo_binary
            ;;
        3)
            echo_info "模式: Docker, 本机透明代理 (TUN)"
            ALLOW_LAN='y' # 本机透明代理也需要允许局域网连接，以便其他设备使用
            ENABLE_TUN='y'
            install_mihomo_docker
            ;;
        4)
            echo_info "模式: 二进制, 本机透明代理 (TUN)"
            ALLOW_LAN='y' # 本机透明代理也需要允许局域网连接，以便其他设备使用
            ENABLE_TUN='y'
            install_mihomo_binary
            ;;
        5)
            echo_info "模式: Docker, 标准代理服务网关"
            ALLOW_LAN='y'
            ENABLE_TUN='n'
            SETUP_GATEWAY='y'
            install_mihomo_docker
            ;;
        6)
            echo_info "模式: Docker, TUN 网关"
            ALLOW_LAN='y'
            ENABLE_TUN='y'
            SETUP_GATEWAY='y'
            install_mihomo_docker
            ;;
        7)
            echo_info "模式: 二进制, 标准代理服务网关"
            ALLOW_LAN='y'
            ENABLE_TUN='n'
            SETUP_GATEWAY='y'
            install_mihomo_binary
            ;;
        8)
            echo_info "模式: 二进制, TUN 网关"
            ALLOW_LAN='y'
            ENABLE_TUN='y'
            SETUP_GATEWAY='y'
            install_mihomo_binary
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
    
    if ! is_mihomo_running; then
        echo_error "Mihomo 服务未运行，无法进行测试。"
        return 1
    fi

    echo_info "第一部分: IP 地址变更测试"
    echo -n "正在获取本机公网 IP ... "
    direct_ip=$(curl -4 --silent --max-time 5 ip.sb)
    if [ -n "$direct_ip" ]; then
        echo -e "\033[33m${direct_ip}\033[0m"
    else
        echo -e "\033[31m获取失败\033[0m"
    fi

    echo -n "正在通过 HTTP 代理 ($PROXY_HTTP) 获取公网 IP ... "
    proxy_ip_http=$(curl -4 -x "$PROXY_HTTP" --silent --max-time 10 ip.sb)
    if [ -n "$proxy_ip_http" ]; then
        echo -e "\033[32m${proxy_ip_http}\033[0m"
    else
        echo -e "\033[31m获取失败\033[0m"
    fi

    echo -n "正在通过 SOCKS5 代理 ($PROXY_SOCKS5) 获取公网 IP ... "
    proxy_ip_socks=$(curl -4 -x "$PROXY_SOCKS5" --silent --max-time 10 ip.sb)
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
        if curl -4 -x "$PROXY_HTTP" --head --silent --fail --max-time 5 "$site" > /dev/null; then
            echo -e "\033[32m连接成功\033[0m"
        else
            echo -e "\033[31m连接失败\033[0m"
        fi
    done

    echo_info "使用 SOCKS5 代理进行测试..."
    for site in "${test_sites[@]}"; do
        echo -n "  - 正在测试: $site ... "
        if curl -4 -x "$PROXY_SOCKS5" --head --silent --fail --max-time 5 "$site" > /dev/null; then
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
        echo_info "测试成功：APT 正在通过 Mihomo 代理 (${PROXY_HTTP}) 进行连接。"
    else
        echo_error "测试失败：APT 未能通过代理连接。请检查 Mihomo 服务是否运行正常以及代理配置是否正确。"
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
    # 优先：直接检查活动的 TUN 网络接口，这是最可靠的方法
    if command -v ip &> /dev/null; then
        local tun_if
        tun_if=$(ip -o link show | awk -F': ' '/(clash|Meta|utun|tun)/ && !/ip6tnl/ && /state (UP|UNKNOWN)/ {print $2; exit}')
        if [ -z "$tun_if" ]; then
            # 某些系统下 TUN 接口可能没有特殊名称，通过 IP 地址回退查找
            tun_if=$(ip -o -f inet addr show | awk '/198.18.0.1/ {print $2}' | head -n 1)
        fi
        if [ -n "$tun_if" ]; then
            return 0 # Found active TUN interface
        fi
    fi

    # 其次：检查 Docker 配置文件
    if [ -f "$COMPOSE_FILE" ] && (grep -q "NET_ADMIN" "$COMPOSE_FILE" || grep -q "/dev/net/tun" "$COMPOSE_FILE"); then
        return 0 # Docker TUN is configured
    fi

    # 再次：检查二进制安装的 systemd 服务文件
    local service_file="/etc/systemd/system/mihomo.service"
    if [ -f "$service_file" ] && grep -q "CAP_NET_ADMIN" "$service_file"; then
        return 0 # Binary TUN is configured
    fi

    # 最后：作为后备，直接检查 Mihomo 配置文件
    if [ -f "$CONFIG_FILE" ]; then
        if grep -q -E "^\s*tun:" "$CONFIG_FILE"; then
            if sed -n '/^\s*tun:/,/^[^[:space:]]/p' "$CONFIG_FILE" | grep -q '^\s*enable:\s*true'; then
                return 0 # Config TUN is enabled
            fi
        fi
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
            DEBIAN_FRONTEND=noninteractive apt-get update
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

# 设置透明网关 (标准 REDIR-HOST 模式)
setup_standard_gateway() {
    check_root
    echo_info "正在配置透明网关 (标准 REDIR-HOST 模式)..."

    # 1. 开启 IP 转发
    enable_ip_forwarding

    # 2. 确保 iptables 已安装
    ensure_iptables_installed

    # 3. 配置 iptables 规则
    configure_standard_gateway_rules
}

# 设置透明网关 (TUN 模式)
setup_tun_gateway() {
    check_root
    echo_info "正在配置透明网关 (TUN 模式)..."

    # 1. 开启 IP 转发
    enable_ip_forwarding

    # 2. 确保 iptables 和 iproute2 已安装
    ensure_iptables_installed
    if ! command -v ip &> /dev/null; then
        echo_warn "'ip' 命令未找到。正在尝试安装 'iproute2'..."
        install_package "iproute2"
        if ! command -v ip &> /dev/null; then
            echo_error "'iproute2' 安装失败。TUN 网关配置需要 'ip' 命令。"
            exit 1
        fi
    fi

    # 3. 配置 iptables 规则
    configure_tun_gateway_rules
}

# 开启IP转发
enable_ip_forwarding() {
    echo_info "正在开启内核 IP 转发并持久化..."
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    sysctl -p
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -ne 1 ]; then
        echo_error "开启 IP 转发失败！"
        exit 1
    fi
}

# 确保iptables已安装
ensure_iptables_installed() {
    if ! command -v iptables &> /dev/null; then
        echo_warn "iptables 命令未找到。正在尝试自动安装..."
        install_package "iptables"
        if ! command -v iptables &> /dev/null; then
            echo_error "iptables 安装失败。请手动安装后重试。"
            exit 1
        fi
    fi
}

# 配置标准网关的iptables规则
configure_standard_gateway_rules() {
    echo_info "正在配置 iptables 规则 (标准 REDIR-HOST 模式)..."
    # 自动获取 LAN 和 WAN 接口
    local lan_ip_range
    lan_ip_range=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)
    local server_ip
    server_ip=$(echo "$lan_ip_range" | cut -d'/' -f1)
    local lan_if
    lan_if=$(ip -o -f inet addr show | awk '/scope global/ {print $2}' | head -n 1)
    local wan_if
    wan_if=$(ip route | grep default | awk '{print $5}' | head -n 1)
    
    # 设置默认端口
    local mihomo_redir_port=${MIHOMO_REDIR_PORT:-7892}
    local mihomo_dns_port=${MIHOMO_DNS_PORT:-1053}
    
    # 清理旧规则
    clear_all_rules

    # --- 配置 NAT 表 ---
    iptables -t nat -N MIHOMO
    # 绕过局域网和保留地址
    iptables -t nat -A MIHOMO -d 0.0.0.0/8 -j RETURN
    iptables -t nat -A MIHOMO -d 10.0.0.0/8 -j RETURN
    iptables -t nat -A MIHOMO -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A MIHOMO -d 169.254.0.0/16 -j RETURN
    iptables -t nat -A MIHOMO -d 172.16.0.0/12 -j RETURN
    iptables -t nat -A MIHOMO -d 192.168.0.0/16 -j RETURN
    iptables -t nat -A MIHOMO -d "$server_ip" -j RETURN
    # 重定向所有 TCP 流量到 redir-port
    iptables -t nat -A MIHOMO -p tcp -j REDIRECT --to-port "$mihomo_redir_port"

    # 将局域网接口的 TCP 流量引导至 MIHOMO 链
    iptables -t nat -A PREROUTING -i "$lan_if" -p tcp -j MIHOMO

    # DNS 劫持：将所有 DNS 请求重定向到 Mihomo
    iptables -t nat -A PREROUTING -i "$lan_if" -p udp --dport 53 -j REDIRECT --to-port "$mihomo_dns_port"
    iptables -t nat -A PREROUTING -i "$lan_if" -p tcp --dport 53 -j REDIRECT --to-port "$mihomo_dns_port"

    # SNAT：为局域网设备提供网络地址转换
    iptables -t nat -A POSTROUTING -o "$wan_if" -j MASQUERADE

    echo_info "IPv4 透明代理规则已应用 (TCP Redirect)"
    
    # --- IPv6 设置 ---
    block_ipv6_forwarding "$lan_if"

    echo_info "iptables 规则配置完成。正在持久化规则..."
    persist_iptables_rules
    
    echo_info "标准透明网关配置完成。"
}

# 配置TUN网关的iptables规则
configure_tun_gateway_rules() {
    echo_info "正在配置 TUN 透明网关 (全新简化模式)..."
    echo_info "此模式依赖 mihomo 配置中的 'auto-route: true'。"
    # --- 1. 自动检测接口 ---
    local lan_if
    lan_if=$(ip -o -f inet addr show | awk '/scope global/ {print $2}' | head -n 1)
    if [ -z "$lan_if" ]; then
        echo_error "未能自动检测到 LAN 接口。"
        return 1
    fi
    local wan_if
    wan_if=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [ -z "$wan_if" ]; then
        echo_error "未能自动检测到 WAN 接口。"
        return 1
    fi
    local tun_if
    local retry_count=0
    local max_retries=5
    local retry_sleep=3

    echo_info "正在等待 TUN 接口出现..."
    while [ $retry_count -lt $max_retries ]; do
        tun_if=$(ip -o link show | awk -F': ' '/(clash|Meta|utun|tun)/ && !/ip6tnl/ && /state (UP|UNKNOWN)/ {print $2; exit}')
        if [ -z "$tun_if" ]; then
            tun_if=$(ip -o -f inet addr show | awk '/198.18.0.1/ {print $2}' | head -n 1)
        fi
        
        if [ -n "$tun_if" ]; then
            echo_info "TUN 接口已找到: $tun_if"
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo_info "未找到 TUN 接口，将在 ${retry_sleep} 秒后重试 (${retry_count}/${max_retries})..."
            sleep $retry_sleep
        fi
    done

    if [ -z "$tun_if" ]; then
        echo_error "在 $(($max_retries * $retry_sleep)) 秒内未找到活动的 TUN 接口 (如 clash, Meta, utun)。请确保 Mihomo 已在 TUN 模式下成功启动。"
        return 1
    fi
    echo_info "检测到接口 -> LAN: ${lan_if}, WAN: ${wan_if}, TUN: ${tun_if}"
    # --- 2. 清理所有旧规则，避免冲突 ---
    clear_all_rules
    # --- 3. 开启内核转发功能 (核心步骤) ---

    # --- 4. 配置新的、简单的防火墙规则 ---
    echo_info "正在应用新的 IPv4 和 IPv6 防火墙规则..."
    
    # IPv4 规则
    # 允许已建立和相关的连接通过，这是最高效的规则，必须放在前面
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    # 允许从局域网到 TUN 接口的新连接
    iptables -A FORWARD -i "${lan_if}" -o "${tun_if}" -j ACCEPT
    # NAT 地址伪装，让局域网设备能通过 Armbian 的公网 IP 上网
    iptables -t nat -A POSTROUTING -o "${wan_if}" -j MASQUERADE
    # IPv6 规则
    # 允许已建立和相关的连接通过
    ip6tables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    # 允许从局域网到 TUN 接口的新连接
    ip6tables -A FORWARD -i "${lan_if}" -o "${tun_if}" -j ACCEPT
    # NAT 地址伪装 (非常重要！用于 IPv6 代理)
    ip6tables -t nat -A POSTROUTING -o "${wan_if}" -j MASQUERADE
    # (可选) 设置默认拒绝所有其他转发，更安全
    iptables -P FORWARD DROP
    ip6tables -P FORWARD DROP
    echo_info "防火墙规则配置完成。"
    # --- 5. 持久化规则 ---
    persist_iptables_rules
    echo_info "✅ TUN 透明网关配置完成！"
    echo_info "请确保你的局域网设备的网关和 DNS 指向 Armbian 的 LAN 口 IP。"
}

# 阻止IPv6转发
block_ipv6_forwarding() {
    local lan_if="$1"
    if command -v ip6tables &> /dev/null; then
        ip6tables -F FORWARD &>/dev/null
        ip6tables -D FORWARD -i "$lan_if" -j DROP &>/dev/null # 确保旧规则被移除
        ip6tables -A FORWARD -i "$lan_if" -j DROP
        echo_info "IPv6 转发已被阻止，防止流量泄露。"
    fi
}

# 持久化iptables规则
persist_iptables_rules() {
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
}

# 清除所有网关规则的通用函数
clear_all_rules() {
    echo_info "正在安全地清除所有现存的网关规则..."

    # 动态获取接口信息，用于精确删除规则
    local lan_if
    lan_if=$(ip -o -f inet addr show | awk '/scope global/ {print $2}' | head -n 1)
    local wan_if
    wan_if=$(ip route | grep default | awk '{print $5}' | head -n 1)
    local mihomo_dns_port=${MIHOMO_DNS_PORT:-1053}

    # 1. 清理策略路由和相关路由表
    ip rule del fwmark 1 table 100 &>/dev/null
    ip route flush table 100 &>/dev/null

    # 2. 重置默认策略
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    ip6tables -P INPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT

    # 3. 清空所有链
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    ip6tables -F
    ip6tables -t nat -F
    ip6tables -t mangle -F

    # 4. 删除所有非默认链
    iptables -X
    iptables -t nat -X
    iptables -t mangle -X
    ip6tables -X
    ip6tables -t nat -X
    ip6tables -t mangle -X
    
    echo_info "所有 iptables 规则已重置。"
}

# 清除局域网网关设置
clear_gateway() {
    check_root
    echo_info "正在禁用内核 IP 转发..."
    sysctl -w net.ipv4.ip_forward=0
    if [ -f /etc/sysctl.conf ]; then
        sed -i '/^net.ipv4.ip_forward=1/d' /etc/sysctl.conf
    fi

    if command -v iptables &> /dev/null; then
        clear_all_rules
        
        # 尝试保存规则
        local os_name
        os_name=$(detect_os)
        case "$os_name" in
            *Ubuntu*|*Debian*)
                if command -v netfilter-persistent &> /dev/null; then
                    echo_info "正在保存已清除的 iptables 规则..."
                    netfilter-persistent save >/dev/null 2>&1
                fi
                ;;
            *CentOS*|*Red*Hat*)
                if command -v service &> /dev/null && systemctl list-unit-files | grep -q iptables.service; then
                    echo_info "正在保存已清除的 iptables 规则..."
                    service iptables save >/dev/null 2>&1
                fi
                ;;
        esac
    fi
    echo_info "网关设置已清除。"
}

# 卸载 Mihomo
uninstall_mihomo() {
    check_root
    echo_warn "警告：此操作将停止 Mihomo 服务，并永久删除所有相关配置和文件！"
    read -p "确定要卸载 Mihomo 吗？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo_info "操作已取消。"
        return
    fi

    echo_info "正在开始卸载流程..."
    
    # 1. 停止服务
    stop_mihomo_service
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
    
    echo_info "Mihomo 已成功卸载。"
}

# 显示菜单
show_menu() {
    clear
    echo "================================================="
    echo "            Mihomo 管理脚本"
    echo "================================================="
    echo " 1. 安装 Mihomo"
    echo " 2. 更新订阅"
    echo " 3. 查看当前 Mihomo 运行状态"
    echo " 4. 运行所有连接测试"
    echo " 5. 为软件/系统设置代理"
    echo " 6. 清除代理配置"
    echo " 7. 卸载 Mihomo"
    echo "-------------------------------------------------"
    echo " 0. 退出脚本"
    echo "================================================="
    read -p "请输入选项 [0-7]: " choice
    
    case $choice in
        1)
            install_mihomo
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        2)
            update_subscription
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        3)
            show_mihomo_status
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
            uninstall_mihomo
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
