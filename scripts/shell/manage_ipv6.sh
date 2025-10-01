#!/bin/bash

#
# 一个用于启用或禁用 IPv6 的脚本
#

# --- 配置 ---
SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_CMD="/sbin/sysctl"

# --- 函数 ---

# 显示用法说明
usage() {
  echo "用法: $0 [disable|enable]"
  echo "  disable: 禁用 IPv6"
  echo "  enable:  启用 IPv6"
  exit 1
}

# 禁用 IPv6
disable_ipv6() {
  if grep -q "^\s*net.ipv6.conf.all.disable_ipv6\s*=\s*1" "$SYSCTL_CONF"; then
    echo "IPv6 已经被禁用，无需重复操作。"
    exit 0
  fi

  echo "正在禁用 IPv6..."
  # 为安全起见，先移除旧的（可能被注释的）配置
  sed -i '/net.ipv6.conf.all.disable_ipv6/d' "$SYSCTL_CONF"
  sed -i '/net.ipv6.conf.default.disable_ipv6/d' "$SYSCTL_CONF"
  sed -i '/net.ipv6.conf.lo.disable_ipv6/d' "$SYSCTL_CONF"
  sed -i '/# Disable IPv6/d' "$SYSCTL_CONF"

  # 添加新配置
  cat >> "$SYSCTL_CONF" << EOF

# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
  echo "IPv6 配置已更新为 [禁用]。"
}

# 启用 IPv6
enable_ipv6() {
  if ! grep -q "^\s*net.ipv6.conf.all.disable_ipv6\s*=\s*1" "$SYSCTL_CONF"; then
    echo "IPv6 已经是启用状态，无需操作。"
    exit 0
  fi

  echo "正在启用 IPv6..."
  # 通过注释掉相关行来启用 IPv6，而不是删除，这样更安全
  sed -i 's/^\(net.ipv6.conf.all.disable_ipv6\s*=\s*1\)/# \1/' "$SYSCTL_CONF"
  sed -i 's/^\(net.ipv6.conf.default.disable_ipv6\s*=\s*1\)/# \1/' "$SYSCTL_CONF"
  sed -i 's/^\(net.ipv6.conf.lo.disable_ipv6\s*=\s*1\)/# \1/' "$SYSCTL_CONF"
  
  echo "IPv6 配置已更新为 [启用]。"
}

# 应用 sysctl 配置
apply_changes() {
  echo "正在应用 sysctl 配置..."
  if ! $SYSCTL_CMD -p > /dev/null; then
    echo "错误：应用 sysctl 配置失败。" >&2
    exit 1
  fi
  echo "配置已成功应用到当前内核。对于新连接，更改将立即生效。"
  echo "为确保所有正在运行的服务（如 Docker, Nginx 等）都能完全应用新设置，建议重新启动系统。"
}

# --- 主逻辑 ---

# 检查是否以 root 身份运行
if [ "$(id -u)" -ne 0 ]; then
  echo "此脚本必须以 root 身份运行" >&2
  exit 1
fi

# 检查参数
if [ -z "$1" ]; then
  usage
fi

# 根据参数执行操作
case "$1" in
  disable)
    disable_ipv6
    ;;
  enable)
    enable_ipv6
    ;;
  *)
    usage
    ;;
esac

apply_changes
exit 0