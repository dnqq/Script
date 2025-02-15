#!/bin/bash

# 默认 FRP 版本
DEFAULT_FRP_VERSION="0.61.1"

# 检查是否传入 FRP 版本参数
if [ -z "$1" ]; then
    FRP_VERSION=$DEFAULT_FRP_VERSION
else
    FRP_VERSION=$1
fi

FRP_DIR="/root/app/frp"
FRP_SERVICE="frps.service"

# 获取服务器架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        FRP_ARCH="amd64"
        ;;
    aarch64)
        FRP_ARCH="arm64"
        ;;
    armv7l)
        FRP_ARCH="arm"
        ;;
    *)
        echo "不支持的架构: $ARCH"
        exit 1
        ;;
esac

# 创建FRP目录
mkdir -p $FRP_DIR
cd $FRP_DIR

# 下载FRP
FRP_PACKAGE="frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz"
wget https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${FRP_PACKAGE}

# 解压
tar -zxvf $FRP_PACKAGE

# 移动文件到FRP目录
mv frp_${FRP_VERSION}_linux_${FRP_ARCH}/* $FRP_DIR
rm -rf frp_${FRP_VERSION}_linux_${FRP_ARCH}*

# 设置 FRP 二进制文件可执行权限
chmod +x $FRP_DIR/frps

# 生成随机 auth.token 和 webServer.password
generate_random_string() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 18 | head -n 1
}

AUTH_TOKEN=$(generate_random_string)
WEB_PASSWORD=$(generate_random_string)

# 创建FRP服务端配置文件（TOML格式）
cat > $FRP_DIR/frps.toml <<EOF
bindPort = 7000
auth.token = "$AUTH_TOKEN"

# Web 控制台配置
webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "admin"
webServer.password = "$WEB_PASSWORD"
EOF

# 创建Systemd服务文件
cat > /etc/systemd/system/$FRP_SERVICE <<EOF
[Unit]
Description=Frp Server Service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=$FRP_DIR/frps -c $FRP_DIR/frps.toml

[Install]
WantedBy=multi-user.target
EOF

# 重新加载Systemd配置
systemctl daemon-reload

# 启动FRP服务
systemctl start $FRP_SERVICE

# 设置开机自启
systemctl enable $FRP_SERVICE

# 输出状态
systemctl status $FRP_SERVICE

echo "FRP服务端部署完成！"
echo "FRP 版本: $FRP_VERSION"
echo "Web 控制台地址: http://<服务器IP>:7500"
echo "用户名: admin"
echo "密码: $WEB_PASSWORD"
echo "认证 Token (auth.token): $AUTH_TOKEN"