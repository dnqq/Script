#!/bin/bash

# ==============================================================================
# Clash Docker 一键安装及管理脚本
#
# 功能:
#   - 自动在 Debian/Ubuntu 服务器上使用 Docker 和 Docker Compose 部署 Clash。
#   - 支持通过参数或交互式输入获取 Clash 订阅链接。
#   - 自动下载并修改配置文件以适应服务器环境。
#   - 将 Clash 设置为开机自启动。
#   - 提供菜单进行功能选择：安装、代理测试、为常用工具设置代理。
#
# 使用方法:
#   1. 确保服务器已安装 Docker 和 Docker Compose。
#   2. 赋予脚本执行权限: chmod +x install_clash.sh
#   3. 运行脚本:
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
# 代理地址
PROXY_HTTP="http://127.0.0.1:7890"
PROXY_SOCKS5="socks5://127.0.0.1:7891"

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

# 创建并准备目录
prepare_directory() {
  echo_info "正在创建配置目录: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
  if [ $? -ne 0 ]; then
    echo_error "创建目录 $INSTALL_DIR 失败。"
    exit 1
  fi
}

# 下载并修改 Clash 配置
setup_clash_config() {
  echo_info "正在从订阅链接下载配置文件..."
  if ! curl -L -A "clash" -o "$CONFIG_FILE" "$CLASH_SUB_URL"; then
    echo_error "下载订阅文件失败！请检查链接是否正确以及网络是否通畅。"
    exit 1
  fi

  echo_info "正在为服务器环境优化配置文件..."
  # 使用 sed 删除可能存在的旧配置，避免冲突
  sed -i -e '/^port:/d' \
         -e '/^socks-port:/d' \
         -e '/^allow-lan:/d' \
         -e '/^external-controller:/d' \
         -e '/^log-level:/d' "$CONFIG_FILE"

  # 追加新的标准配置
  cat <<EOF >> "$CONFIG_FILE"

# --- Appended by install_clash.sh for server environment ---
port: 7890
socks-port: 7891
allow-lan: false
external-controller: '0.0.0.0:9090'
log-level: info
EOF
  echo_info "配置文件优化完成。"
}

# 创建 Docker Compose 文件
create_compose_file() {
  echo_info "正在创建 Docker Compose 文件: $COMPOSE_FILE"
  cat <<EOF > "$COMPOSE_FILE"
version: '3.8'
services:
  clash:
    image: ${CLASH_IMAGE}
    container_name: clash
    restart: always
    network_mode: "host"
    volumes:
      - ${CONFIG_FILE}:/root/.config/clash/config.yaml
EOF
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

# 安装 Clash
install_clash() {
  check_root
  check_docker

  # 如果服务已在运行，询问是否要重新安装
  if [ "$(docker ps -q -f name=clash)" ]; then
    read -p "检测到 Clash 容器已在运行。是否要继续并覆盖现有配置？(y/N): " choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
      echo_info "操作已取消。"
      exit 0
    fi
    stop_clash_service
  fi

  get_user_input
  prepare_directory
  setup_clash_config
  create_compose_file
  start_clash_service

  # 检查启动结果
  sleep 3 # 等待容器启动
  if [ $? -eq 0 ] && [ "$(docker ps -q -f name=clash)" ]; then
    echo_info "============================================================"
    echo_info "Clash 服务已成功启动！"
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

# 代理测试
test_proxy() {
    echo_info "开始测试代理连通性..."
    local test_sites=(
        "https://www.github.com"
        "https://hub.docker.com"
        "https://www.google.com"
    )
    
    if [ -z "$(docker ps -q -f name=clash)" ]; then
        echo_error "Clash 容器未运行，无法进行测试。"
        return 1
    fi

    for site in "${test_sites[@]}"; do
        echo -n "正在测试: $site ... "
        # 使用 curl 测试，设置超时5秒，忽略输出，只关心返回码
        if curl -x "$PROXY_HTTP" --head --silent --fail --max-time 5 "$site" > /dev/null; then
            echo -e "\033[32m连接成功\033[0m"
        else
            echo -e "\033[31m连接失败\033[0m"
        fi
    done
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
    systemctl restart docker
    
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
        echo_info "正在重新加载 systemd 并重启 Docker 服务..."
        systemctl daemon-reload
        systemctl restart docker
        if [ $? -eq 0 ]; then
            echo_info "Docker 代理配置已清除。"
        else
            echo_error "Docker 服务重启失败，请手动检查。"
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

# 显示菜单
show_menu() {
    clear
    echo "================================================="
    echo "            Clash Docker 管理脚本"
    echo "================================================="
    echo " 1. 安装或重新安装 Clash"
    echo " 2. 测试代理连通性"
    echo " 3. 为 APT 设置代理"
    echo " 4. 为 Docker 设置代理"
    echo " 5. 为当前系统设置全局代理"
    echo " 6. 清除代理配置"
    echo "-------------------------------------------------"
    echo " 0. 退出脚本"
    echo "================================================="
    read -p "请输入选项 [0-6]: " choice
    
    case $choice in
        1)
            install_clash
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        2)
            test_proxy
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        3)
            set_apt_proxy
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        4)
            set_docker_proxy
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        5)
            set_system_proxy
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
        6)
            clear_proxy_menu
            ;;
        0)
            exit 0
            ;;
        *)
            echo_error "无效选项，请输入 0 到 6 之间的数字。"
            read -p $'\n按任意键返回菜单...' -n 1 -r -s
            ;;
    esac
}

# --- 主程序 ---
main() {
    # 支持一键安装: ./install_clash.sh install <sub_url>
    if [[ "$1" == "install" ]] && [ -n "$2" ]; then
        CLASH_SUB_URL="$2"
        install_clash
        exit 0
    fi

    # 如果没有参数，则显示菜单
    while true; do
        show_menu
    done
}

# 执行主程序
main "$@"
