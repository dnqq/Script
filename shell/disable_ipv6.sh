#!/bin/bash

# 检查是否以 root 身份运行
if [ "$(id -u)" -ne 0 ]; then
  echo "此脚本必须以 root 身份运行" >&2
  exit 1
fi

# 禁用 IPv6
echo "正在禁用 IPv6..."
cat >> /etc/sysctl.conf << EOF

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

# 应用更改
sysctl -p

echo "IPv6 已被禁用。建议重新启动以确保所有服务都应用新设置。"

exit 0