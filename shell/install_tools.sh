#!/bin/bash

# 更新软件包索引并安装常用工具
echo "正在更新系统并安装常用工具..."
apt update && apt -y install vim curl net-tools ufw sudo nfs-common parted lvm2

# 定义别名并追加到 ~/.bashrc
echo "配置自定义命令别名..."
cat <<EOF >> ~/.bashrc
# 自定义命令别名
alias vi='vim'
alias ll='ls -l'
alias ifconfig='ip addr'
EOF

# 使配置生效
echo "重新加载 shell 配置..."
source ~/.bashrc

echo "安装完成！请重新打开终端以应用所有修改。"