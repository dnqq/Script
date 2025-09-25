#!/bin/bash

# ========================================================
# 脚本功能：一键新增 FRP 服务并重启 FRP 客户端
#
# 该脚本用于向 FRP 客户端配置文件中添加新的服务代理，并重启 FRP 客户端服务。
#
# 主要功能：
# 1. 接受服务配置参数（名称、类型、本地IP、本地端口、远程端口）
# 2. 将新的服务配置添加到 /opt/frp_client/frpc.toml 文件中
# 3. 重启 FRP 客户端服务使配置生效
#
# 使用方法：
# 1. 交互式运行脚本：
#    sudo ./add_frp_service.sh
#
# 2. 命令行参数运行脚本：
#    sudo ./add_frp_service.sh "服务名称" "tcp" "127.0.0.1" 3000 3000
#
# ========================================================

# FRP 客户端配置文件路径
FRPC_CONFIG="/opt/frp_client/frpc.toml"

# 检查配置文件是否存在
if [ ! -f "$FRPC_CONFIG" ]; then
    echo "错误：FRP 客户端配置文件不存在，请先安装 FRP 客户端"
    exit 1
fi

# 获取服务配置参数
if [ $# -eq 5 ]; then
    # 从命令行参数获取
    PROXY_NAME="$1"
    PROXY_TYPE="$2"
    LOCAL_IP="$3"
    LOCAL_PORT="$4"
    REMOTE_PORT="$5"
else
    # 交互式获取参数
    echo "请输入服务配置信息："
    read -p "服务名称: " PROXY_NAME
    read -p "服务类型 (tcp/udp/http/https): " PROXY_TYPE
    read -p "本地IP (默认为127.0.0.1): " LOCAL_IP
    read -p "本地端口: " LOCAL_PORT
    read -p "远程端口: " REMOTE_PORT
    
    # 设置默认值
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="127.0.0.1"
    fi
fi

# 验证参数
if [ -z "$PROXY_NAME" ] || [ -z "$PROXY_TYPE" ] || [ -z "$LOCAL_IP" ] || [ -z "$LOCAL_PORT" ] || [ -z "$REMOTE_PORT" ]; then
    echo "错误：所有参数都必须提供"
    exit 1
fi

# 验证端口是否为数字
if ! [[ "$LOCAL_PORT" =~ ^[0-9]+$ ]] || ! [[ "$REMOTE_PORT" =~ ^[0-9]+$ ]]; then
    echo "错误：端口必须为数字"
    exit 1
fi

# 检查服务是否已存在
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

# 添加新的服务配置到配置文件末尾
cat >> "$FRPC_CONFIG" <<EOF

[[proxies]]
name = "$PROXY_NAME"
type = "$PROXY_TYPE"
localIP = "$LOCAL_IP"
localPort = $LOCAL_PORT
remotePort = $REMOTE_PORT

EOF

echo "服务 '$PROXY_NAME' 已添加到 FRP 配置文件中"

# 重启 FRP 客户端服务
echo "正在重启 FRP 客户端服务..."
systemctl restart frpc

# 验证 FRP 客户端是否成功重启
if systemctl is-active --quiet frpc; then
    echo "FRP 客户端重启成功！"
else
    echo "FRP 客户端重启失败，请检查配置文件和日志。"
    exit 1
fi

echo "服务 '$PROXY_NAME' 已成功添加并生效"