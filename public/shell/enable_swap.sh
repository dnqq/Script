#!/bin/bash

# 脚本功能：一键为 Debian 系统创建并启用指定大小的 Swap 分区
# 使用说明：
# 1. 将脚本保存为 `enable_swap.sh` 文件。
# 2. 为脚本添加执行权限：`chmod +x enable_swap.sh`
# 3. 以 root 用户身份运行脚本：
#    - 默认创建 2G Swap：`sudo ./enable_swap.sh`
#    - 指定 Swap 大小（如 4G）：`sudo ./enable_swap.sh 4`
# 注意：如果系统中已存在 Swap 分区，脚本不会重复创建。

# 获取参数，默认为 2G
SWAP_SIZE=${1:-2}

# 检查参数是否为数字
if ! [[ "$SWAP_SIZE" =~ ^[0-9]+$ ]]; then
    echo "错误：参数必须是整数（如 2 表示 2G）。"
    exit 1
fi

# 检查是否已经存在 Swap 分区
if swapon --show | grep -q '/swapfile'; then
    echo "Swap 分区已经存在，无需再次创建。"
    exit 0
fi

# 创建指定大小的 Swap 文件
sudo fallocate -l ${SWAP_SIZE}G /swapfile

# 设置正确的权限
sudo chmod 600 /swapfile

# 将文件设置为 Swap 空间
sudo mkswap /swapfile

# 启用 Swap 文件
sudo swapon /swapfile

# 将 Swap 文件添加到 /etc/fstab 以在系统重启后自动启用
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

echo "Swap 分区已成功创建并启用，大小为 ${SWAP_SIZE}G。"
