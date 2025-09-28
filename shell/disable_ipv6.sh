#!/bin/bash

# 检查是否以 root 身份运行
if [ "$(id -u)" -ne 0 ]; then
  echo "此脚本必须以 root 身份运行" >&2
  exit 1
fi

# 检查 IPv6 是否已被禁用
if grep -q "net.ipv6.conf.all.disable_ipv6 = 1" /etc/sysctl.conf; then
  echo "IPv6 已经被禁用，无需重复操作。"
  exit 0
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
echo "正在应用 sysctl 配置..."
sysctl -p > /dev/null

echo "IPv6 已成功禁用。建议重新启动以确保所有服务都应用新设置。"

exit 0