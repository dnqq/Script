#!/bin/bash
set -e

# 确保以 root 用户运行
if [[ $EUID -ne 0 ]]; then
   echo "请使用 root 权限运行此脚本（sudo ./install_tools.sh）"
   exit 1
fi

# 设置时区为上海
echo "正在设置时区为 Asia/Shanghai..."
timedatectl set-timezone Asia/Shanghai

# 更新系统并安装常用工具
echo "正在更新系统并安装常用工具..."
apt update
apt upgrade -y
apt -y install vim curl net-tools sudo nfs-common unzip wget

# 为所有用户配置自定义命令别名
echo "为所有用户配置自定义命令别名..."
cat > /etc/profile.d/custom-aliases.sh << EOF
alias vi='vim'
alias ll='ls -l'
alias ifconfig='ip addr'
EOF

# 显示当前时间和时区，确认修改生效
echo "当前时间和时区："
timedatectl

echo "安装完成！请重新打开终端以应用所有修改。"
