#!/bin/bash

# ========================================================
# 脚本功能：一键部署 FRP 服务端
#
# 该脚本用于在 Linux 服务器上自动化部署 FRP 服务端（frps）。FRP（Fast Reverse Proxy）是一款高性能的反向代理应用，
# 通过该脚本，用户可以快速安装和配置 FRP 服务端，便于进行内网穿透。脚本支持自动识别服务器架构（AMD64、ARM64、ARM），
# 支持指定 FRP 版本，也可以自动获取最新版本。并且会自动生成 Web 控制台登录密码和认证 Token，配置并启用 Systemd 服务，
# 设置开机自启，确保 FRP 服务可以在服务器重启后自动启动。
#
# 主要功能：
# 1. 自动识别服务器架构（AMD64/ARM64/ARM），并下载对应版本的 FRP。
# 2. 支持指定 FRP 版本，若未指定则自动获取最新版本。
# 3. 生成随机的 Web 控制台密码和认证 Token。
# 4. 自动生成并配置 FRP 服务端配置文件（frps.toml）。
# 5. 自动创建 Systemd 服务文件并设置 FRP 服务开机自启。
# 6. 验证 FRP 服务是否成功启动，只有成功启动后才会输出部署成功信息。
#
# 使用方法：
# 1. 直接运行脚本（使用最新版本，如获取失败则使用默认 FRP 版本：0.61.1）：
#    sudo ./deploy_frps.sh
#
# 2. 指定 FRP 版本运行脚本（例如：0.62.0）：
#    sudo ./deploy_frps.sh 0.62.0
#
# 3. 脚本执行过程中会下载 FRP 包并自动解压，配置 FRP 服务端，生成认证 Token 和 Web 控制台密码，
#    并设置 FRP 服务为开机自启。
#
# 4. 执行完毕后，脚本会输出 FRP 服务端部署结果，包括：
#    - Web 控制台地址
#    - Web 控制台登录用户名（默认为 admin）
#    - Web 控制台密码（随机生成）
#    - FRP 认证 Token（随机生成）
#
# 注意：
# - 脚本会自动安装 `jq`（如果未安装的话），用于解析 GitHub API 获取最新 FRP 版本。
# - 请确保服务器上已安装 wget 和 curl 工具。
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
        FRP_ARCH="arm"    # 32 位 ARM 架构
        ;;
    *)
        echo "不支持的架构: $ARCH"  # 如果架构不支持，输出错误信息并退出
        exit 1
        ;;
esac

# 检查是否传入 FRP 版本参数
if [ -z "$1" ]; then
    # 如果没有传入参数，获取最新版本
    FRP_VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | jq -r .tag_name | sed 's/^v//')
    
    if [ -z "$FRP_VERSION" ]; then
        FRP_VERSION=$DEFAULT_FRP_VERSION  # 如果获取失败，使用默认版本
    fi
else
    FRP_VERSION=$1  # 如果传入了参数，使用传入的版本
fi

# 输出最终使用的 FRP 版本
echo "使用的 FRP 版本: $FRP_VERSION"

# FRP 安装目录
FRP_DIR="/root/app/frp"
# Systemd 服务名称
FRP_SERVICE="frps.service"

# 创建 FRP 目录
mkdir -p $FRP_DIR  # 创建安装目录
cd $FRP_DIR        # 进入安装目录

# 下载 FRP
FRP_PACKAGE="frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz"  # 根据版本和架构生成下载包名称
wget https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_PACKAGE}  # 下载 FRP 安装包

# 解压安装包
tar -zxvf $FRP_PACKAGE  # 解压下载的安装包

# 移动文件到 FRP 目录
mv frp_${FRP_VERSION}_linux_${FRP_ARCH}/* $FRP_DIR  # 将解压后的文件移动到安装目录
rm -rf frp_${FRP_VERSION}_linux_${FRP_ARCH}*        # 删除解压后的临时文件夹

# 设置 FRP 二进制文件可执行权限
chmod +x $FRP_DIR/frps  # 赋予 frps 可执行权限

# 生成随机的 auth.token 和 Web 控制台密码
generate_random_string() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 18 | head -n 1  # 生成 18 位随机字符串（仅包含字母和数字）
}

AUTH_TOKEN=$(generate_random_string)  # 生成随机的 auth.token
WEB_PASSWORD=$(generate_random_string)  # 生成随机的 Web 控制台密码

# 创建 FRP 服务端配置文件（TOML 格式）
cat > $FRP_DIR/frps.toml <<EOF
bindPort = 7000  # FRP 服务端监听端口
auth.token = "$AUTH_TOKEN"  # 客户端连接认证 Token

# Web 控制台配置
webServer.addr = "0.0.0.0"  # 控制台监听地址（0.0.0.0 表示允许公网访问）
webServer.port = 7500       # 控制台监听端口
webServer.user = "admin"    # 控制台登录用户名
webServer.password = "$WEB_PASSWORD"  # 控制台登录密码
EOF

# 如果 Systemd 服务文件不存在，则创建它
if [ ! -f "/etc/systemd/system/$FRP_SERVICE" ]; then
    cat > /etc/systemd/system/$FRP_SERVICE <<EOF
[Unit]
Description=Frp Server Service  # 服务描述
After=network.target            # 在网络服务启动后启动

[Service]
Type=simple
User=root                       # 以 root 用户运行
Restart=on-failure              # 失败时自动重启
RestartSec=5s                   # 重启间隔时间
ExecStart=$FRP_DIR/frps -c $FRP_DIR/frps.toml  # 启动命令

[Install]
WantedBy=multi-user.target      # 多用户模式下启用
EOF
fi

# 重新加载 Systemd 配置
systemctl daemon-reload  # 重新加载 Systemd 配置，使新服务生效

# 设置开机自启
systemctl enable $FRP_SERVICE  # 设置 FRP 服务开机自启

# 启动 FRP 服务
systemctl start $FRP_SERVICE  # 启动 FRP 服务

# 验证 FRP 服务是否成功启动
if systemctl is-active --quiet $FRP_SERVICE; then
    # 服务启动成功，输出部署结果
    echo "FRP服务端部署完成！"
    echo "FRP 版本: $FRP_VERSION"
    echo "Web 控制台地址: http://<服务器IP>:7500"
    echo "用户名: admin"
    echo "密码: $WEB_PASSWORD"
    echo "认证 Token (auth.token): $AUTH_TOKEN"
else
    # 服务启动失败，输出错误信息
    echo "FRP 服务启动失败，请检查日志以获取更多信息。"
    exit 1
fi
