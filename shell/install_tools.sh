#!/bin/bash

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
apt -y install vim curl net-tools sudo nfs-common parted lvm2 unzip

# 定义别名并追加到 ~/.bashrc
echo "配置自定义命令别名..."
grep -qxF "alias vi='vim'" ~/.bashrc || echo "alias vi='vim'" >> ~/.bashrc
grep -qxF "alias ll='ls -l'" ~/.bashrc || echo "alias ll='ls -l'" >> ~/.bashrc
grep -qxF "alias ifconfig='ip addr'" ~/.bashrc || echo "alias ifconfig='ip addr'" >> ~/.bashrc

# 使配置生效
echo "重新加载 shell 配置..."
source ~/.bashrc

# 显示当前时间和时区，确认修改生效
echo "当前时间和时区："
timedatectl

echo "安装完成！请重新打开终端以应用所有修改。"
