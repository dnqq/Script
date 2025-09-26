#!/bin/bash

# ========================================================
# 脚本功能：一键新增 FRP 服务并重启 FRP 客户端
#
# 该脚本用于向 FRP 客户端配置文件中添加新的服务代理，并重启 FRP 客户端服务。
#
# 主要功能：
# 1. 接受服务配置参数（名称、类型、本地IP、本地端口、远程端口）
# 2. 将新的服务配置添加到 frpc.toml 配置文件中
# 3. 自动识别 FRP 是二进制安装还是 Docker 安装
# 4. 根据安装方式重启相应的 FRP 客户端服务
#
# 使用方法：
# 1. 交互式运行脚本：
#    sudo ./frp_service.sh
#
# 2. 命令行参数运行脚本（使用命名参数）：
#    sudo ./frp_service.sh -n "服务名称" -l 3000 -r 3000
#
# 3. 命令行参数运行脚本（可选参数）：
#    sudo ./frp_service.sh -n "服务名称" -l 3000 -r 3000 -t tcp -i 127.0.0.1
#
#    参数说明：
#    -n, --name      服务名称（必需）
#    -l, --local     本地端口（必需）
#    -r, --remote    远程端口（必需）
#    -t, --type      服务类型，默认为 tcp
#    -i, --ip        本地IP，默认为 127.0.0.1（二进制安装）或宿主机IP（docker安装）
#
# ========================================================

# 检查 FRP 安装方式
check_frp_installation() {
    # 检查二进制安装
    if [ -f "/opt/frp_client/frpc" ]; then
        INSTALL_TYPE="binary"
        FRPC_CONFIG="/opt/frp_client/frpc.toml"
        echo "检测到 FRP 二进制安装"
        return
    fi
    
    # 检查 Docker 安装
    if command -v docker &> /dev/null; then
        # 检查是否存在 frpc 容器
        if docker ps -a --format "{{.Names}}" | grep -q "^frpc$"; then
            INSTALL_TYPE="docker"
            FRPC_CONFIG="/opt/frp_client/frpc.toml"
            echo "检测到 FRP Docker 安装"
            return
        fi
    fi
    
    echo "错误：未检测到 FRP 客户端安装"
    exit 1
}

# 获取宿主机IP（用于Docker安装）
get_host_ip() {
    # 尝试多种方式获取宿主机IP
    if command -v hostname &> /dev/null; then
        HOST_IP=$(hostname -I | awk '{print $1}')
        if [ -n "$HOST_IP" ]; then
            echo "$HOST_IP"
            return
        fi
    fi
    
    if command -v ip &> /dev/null; then
        HOST_IP=$(ip route get 1.1.1.1 | awk '{print $7}')
        if [ -n "$HOST_IP" ]; then
            echo "$HOST_IP"
            return
        fi
        
        HOST_IP=$(ip addr | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1 | head -n 1)
        if [ -n "$HOST_IP" ]; then
            echo "$HOST_IP"
            return
        fi
    fi
    
    # 如果无法获取宿主机IP，返回默认值
    echo "127.0.0.1"
}

# 重启 FRP 服务
restart_frp() {
    if [ "$INSTALL_TYPE" = "binary" ]; then
        echo "正在重启 FRP 二进制服务..."
        systemctl restart frpc
        
        # 验证 FRP 客户端是否成功重启
        if systemctl is-active --quiet frpc; then
            echo "FRP 二进制服务重启成功！"
            echo "FRP 运行日志:"
            journalctl -u frpc -n 10 --no-pager
        else
            echo "FRP 二进制服务重启失败，请检查配置文件和日志。"
            exit 1
        fi
    elif [ "$INSTALL_TYPE" = "docker" ]; then
        echo "正在重启 FRP Docker 服务..."
        docker restart frpc
        
        # 验证 FRP 容器是否成功重启
        if docker ps --format "{{.Names}}" | grep -q "^frpc$"; then
            echo "FRP Docker 服务重启成功！"
            echo "FRP 容器日志:"
            docker logs frpc --tail 10
        else
            echo "FRP Docker 服务重启失败，请检查容器状态。"
            exit 1
        fi
    fi
}

# 获取服务配置参数
get_service_config() {
    # 初始化变量
    PROXY_NAME=""
    PROXY_TYPE="tcp"
    LOCAL_PORT=""
    REMOTE_PORT=""
    
    # 设置默认本地IP
    if [ "$INSTALL_TYPE" = "docker" ]; then
        LOCAL_IP=$(get_host_ip)
    else
        LOCAL_IP="127.0.0.1"
    fi
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                PROXY_NAME="$2"
                shift 2
                ;;
            -t|--type)
                PROXY_TYPE="$2"
                shift 2
                ;;
            -i|--ip)
                LOCAL_IP="$2"
                shift 2
                ;;
            -l|--local)
                LOCAL_PORT="$2"
                shift 2
                ;;
            -r|--remote)
                REMOTE_PORT="$2"
                shift 2
                ;;
            -h|--help)
                echo "FRP 服务新增脚本"
                echo "=================="
                echo "使用方法："
                echo "  交互式运行脚本："
                echo "    sudo ./frp_service.sh"
                echo ""
                echo "  命令行参数运行脚本（使用命名参数）："
                echo "    sudo ./frp_service.sh -n \"服务名称\" -l 3000 -r 3000"
                echo ""
                echo "  命令行参数运行脚本（可选参数）："
                echo "    sudo ./frp_service.sh -n \"服务名称\" -l 3000 -r 3000 -t tcp -i 127.0.0.1"
                echo ""
                echo "参数说明："
                echo "  -n, --name      服务名称（必需）"
                echo "  -l, --local     本地端口（必需）"
                echo "  -r, --remote    远程端口（必需）"
                echo "  -t, --type      服务类型，默认为 tcp"
                echo "  -i, --ip        本地IP，默认为 127.0.0.1（二进制安装）或宿主机IP（docker安装）"
                echo ""
                exit 0
                ;;
            *)
                echo "未知参数: $1"
                echo "使用 -h 或 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
    
    # 如果没有提供必需参数，则进行交互式输入
    if [ -z "$PROXY_NAME" ] || [ -z "$LOCAL_PORT" ] || [ -z "$REMOTE_PORT" ]; then
        echo "部分参数未通过命令行提供，将进行交互式输入..."
        
        if [ -z "$PROXY_NAME" ]; then
            read -p "服务名称: " PROXY_NAME
        fi
        
        if [ -z "$PROXY_TYPE" ]; then
            read -p "服务类型 (tcp/udp/http/https，默认tcp): " PROXY_TYPE
            if [ -z "$PROXY_TYPE" ]; then
                PROXY_TYPE="tcp"
            fi
        fi
        
        if [ -z "$LOCAL_IP" ]; then
            read -p "本地IP (默认自动获取): " LOCAL_IP
            if [ -z "$LOCAL_IP" ]; then
                if [ "$INSTALL_TYPE" = "docker" ]; then
                    LOCAL_IP=$(get_host_ip)
                    echo "检测到 Docker 安装，自动获取宿主机IP: $LOCAL_IP"
                else
                    LOCAL_IP="127.0.0.1"
                    echo "检测到二进制安装，本地IP: $LOCAL_IP"
                fi
            fi
        fi
        
        if [ -z "$LOCAL_PORT" ]; then
            read -p "本地端口: " LOCAL_PORT
        fi
        
        if [ -z "$REMOTE_PORT" ]; then
            read -p "远程端口: " REMOTE_PORT
        fi
    fi
    
    echo "使用配置:"
    echo "  服务名称: $PROXY_NAME"
    echo "  服务类型: $PROXY_TYPE"
    echo "  本地IP: $LOCAL_IP"
    echo "  本地端口: $LOCAL_PORT"
    echo "  远程端口: $REMOTE_PORT"
}

# 验证参数
validate_parameters() {
    if [ -z "$PROXY_NAME" ] || [ -z "$LOCAL_PORT" ] || [ -z "$REMOTE_PORT" ]; then
        echo "错误：服务名称、本地端口、远程端口都必须提供"
        exit 1
    fi
    
    # 验证端口是否为数字
    if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]] || ! [[ "$REMOTE_PORT" =~ ^[0-9]+$ ]]; then
        echo "错误：端口必须为数字"
        exit 1
    fi
    
    # 验证服务类型是否有效
    if [ "$PROXY_TYPE" != "tcp" ] && [ "$PROXY_TYPE" != "udp" ] && [ "$PROXY_TYPE" != "http" ] && [ "$PROXY_TYPE" != "https" ]; then
        echo "错误：服务类型必须为 tcp/udp/http/https 之一"
        exit 1
    fi
}

# 检查服务是否已存在
check_existing_service() {
    if grep -q "name = \"$PROXY_NAME\"" "$FRPC_CONFIG"; then
        echo "警告：服务名称 '$PROXY_NAME' 已存在，是否覆盖？(y/N)"
        read -p "确认: " CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            echo "操作已取消"
            exit 0
        fi
        # 删除已存在的服务配置
        sed -i "/\[\[proxies\]\]/,/^$/!b; /\[\[proxies\]\]/,/^$/ { /name = \"$PROXY_NAME\"/ { N;N;N;N;d; }; }" "$FRPC_CONFIG"
    fi
}

# 添加新的服务配置到配置文件末尾
add_service_config() {
    cat >> "$FRPC_CONFIG" <<EOF

[[proxies]]
name = "$PROXY_NAME"
type = "$PROXY_TYPE"
localIP = "$LOCAL_IP"
localPort = $LOCAL_PORT
remotePort = $REMOTE_PORT

EOF
       
       echo "新增服务配置:"
       echo "[[proxies]]"
       echo "name = \"$PROXY_NAME\""
       echo "type = \"$PROXY_TYPE\""
       echo "localIP = \"$LOCAL_IP\""
       echo "localPort = $LOCAL_PORT"
       echo "remotePort = $REMOTE_PORT"
       echo ""
       echo "服务 '$PROXY_NAME' 已添加到 FRP 配置文件中"
}

# 主程序逻辑
main() {
    echo "FRP 服务新增脚本"
    echo "=================="
    
    # 检查安装方式
    check_frp_installation
    
    # 检查配置文件是否存在
    if [ ! -f "$FRPC_CONFIG" ]; then
        echo "错误：FRP 客户端配置文件不存在"
        exit 1
    fi
    
    # 获取服务配置参数
    get_service_config "$@"
    
    # 验证参数
    validate_parameters
    
    # 检查服务是否已存在
    check_existing_service
    
    # 添加服务配置
    add_service_config
    
    # 重启 FRP 服务
    restart_frp
    
    echo "服务 '$PROXY_NAME' 已成功添加并生效"
}

# 执行主程序
main "$@"