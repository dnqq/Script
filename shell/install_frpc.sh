#!/bin/bash

# ========================================================
# 脚本功能：一键部署 FRP 客户端并配置 Systemd 服务
#
# 该脚本用于在 Linux 服务器上自动化部署 FRP 客户端（frpc）。FRP（Fast Reverse Proxy）是一款高性能的反向代理应用，
# 通过该脚本，用户可以快速安装和配置 FRP 客户端，以便进行内网穿透。脚本支持自动识别服务器架构（AMD64、ARM64、ARM），
# 支持指定 FRP 版本，也可以自动获取最新版本。并且会自动生成客户端配置文件 `frpc.toml`，配置并启动客户端。
#
# 主要功能：
# 1. 自动识别服务器架构（AMD64/ARM64/ARM），并下载对应版本的 FRP 客户端。
# 2. 支持指定 FRP 版本，若未指定则自动获取最新版本。
# 3. 自动配置 FRP 客户端配置文件（frpc.toml）。
# 4. 配置 Systemd 服务，使 FRP 客户端能够随系统启动。
# 5. 启动 FRP 客户端服务。
#
# 使用方法：
# 1. 直接运行脚本（使用默认 FRP 版本：0.61.1）：
#    sudo ./instll_frpc.sh
#
# 2. 指定 FRP 版本运行脚本（例如：0.62.0）：
#    sudo ./instll_frpc.sh 0.62.0
#
# 3. 脚本执行过程中会下载 FRP 包并自动解压，配置 FRP 客户端。
#
# 4. 执行完毕后，脚本会启动 FRP 客户端，并根据配置连接到 FRP 服务端。
#
# ========================================================

# 默认 FRP 版本
DEFAULT_FRP_VERSION="0.61.1"

# 检查 jq 是否已安装，如果没有安装则进行安装
if ! command -v jq &> /dev/null; then
    echo "jq 未安装，正在安装 jq..."
    # 安装 jq
    sudo apt-get update
    sudo apt-get install -y jq
else
    echo "jq 已安装"
fi

# 获取服务器架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        FRP_ARCH="amd64"  # 64 位 x86 架构
        ;;
    aarch64)
        FRP_ARCH="arm64"  # 64 位 ARM 架构
        ;;
    armv7l)
        FRP_ARCH="arm"    # 32 位 ARM 构架
        ;;
    *)
        echo "不支持的架构: $ARCH"  # 如果架构不支持，输出错误信息并退出
        exit 1
        ;;
esac

# 获取最新 FRP 版本号，并去除首字母 'v'
FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | jq -r .tag_name | sed 's/^v//')

# 检查是否传入 FRP 版本参数
if [ -z "$1" ]; then
    if [ -z "$FRP_VERSION" ]; then
        FRP_VERSION=$DEFAULT_FRP_VERSION  # 如果获取失败，使用默认版本
    fi
else
    FRP_VERSION=$1  # 如果传入了参数，使用传入的版本
fi

# 输出最终使用的 FRP 版本
echo "使用的 FRP 版本: $FRP_VERSION"

# FRP 客户端安装目录
FRP_DIR="/root/app/frp_client"
# 创建 FRP 目录
mkdir -p $FRP_DIR  # 创建安装目录
cd $FRP_DIR        # 进入安装目录

# 下载 FRP 客户端
FRP_PACKAGE="frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz"  # 根据版本和架构生成下载包名称
wget https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_PACKAGE}  # 下载 FRP 安装包

# 解压安装包
tar -zxvf $FRP_PACKAGE  # 解压下载的安装包

# 移动文件到 FRP 客户端目录
mv frp_${FRP_VERSION}_linux_${FRP_ARCH}/* $FRP_DIR  # 将解压后的文件移动到安装目录
rm -rf frp_${FRP_VERSION}_linux_${FRP_ARCH}*        # 删除解压后的临时文件夹

# 设置 FRP 客户端二进制文件可执行权限
chmod +x $FRP_DIR/frpc  # 赋予 frpc 可执行权限

# 随机生成 Web 控制台密码（18 位，包含大小写字母和数字）
generate_random_password() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 18 | head -n 1
}

WEB_PASSWORD=$(generate_random_password)  # 生成随机的 Web 控制台密码

# 创建 FRP 客户端配置文件（TOML 格式）
cat > $FRP_DIR/frpc.toml <<EOF
[common]
server_addr = "<FRP_SERVER_IP>"  # 设置 FRP 服务端的 IP 地址
server_port = 7000               # 服务端监听端口
auth_token = "<AUTH_TOKEN>"       # 设置与 FRP 服务端一致的认证 Token

# Web 控制台配置
webServer.addr = "0.0.0.0"  # Web 控制台监听地址（0.0.0.0 表示允许公网访问）
webServer.port = 7500       # 控制台监听端口
webServer.user = "admin"    # 控制台登录用户名
webServer.password = "$WEB_PASSWORD"  # 控制台登录密码
EOF

# 询问用户输入 FRP 服务端的 IP 地址和认证 Token
read -p "请输入 FRP 服务端的 IP 地址: " SERVER_IP
read -p "请输入 FRP 服务端的认证 Token: " AUTH_TOKEN

# 替换配置文件中的占位符
sed -i "s|<FRP_SERVER_IP>|$SERVER_IP|" $FRP_DIR/frpc.toml
sed -i "s|<AUTH_TOKEN>|$AUTH_TOKEN|" $FRP_DIR/frpc.toml

# 创建 Systemd 服务文件
cat > /etc/systemd/system/frpc.service <<EOF
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/root/app/frp_client/frpc -c /root/app/frp_client/frpc.toml

[Install]
WantedBy=multi-user.target

EOF

# 重新加载 Systemd 配置
systemctl daemon-reload  # 重新加载 Systemd 配置，使新服务生效

# 设置开机自启
systemctl enable frpc  # 设置 FRP 客户端服务开机自启

# 启动 FRP 客户端
systemctl start frpc  # 启动 FRP 客户端服务

# 验证 FRP 客户端是否成功启动
if systemctl is-active --quiet frpc; then
    echo "FRP 客户端启动成功！"
    echo "客户端已连接到 FRP 服务端，开始进行内网穿透。"
    echo "Web 控制台密码: $WEB_PASSWORD"  # 打印 Web 控制台密码
else
    echo "FRP 客户端启动失败，请检查配置文件和日志。"
    exit 1
fi
