#!/bin/bash

# 脚本名称: iptables_redirect_safe.sh
# 脚本效果: 安全地设置 iptables 端口转发，并使用 iptables-persistent 实现规则持久化。
#
# 特性:
#   1. 自动检查并提示安装 iptables-persistent。
#   2. 在保存新规则前，自动备份现有的持久化规则文件，确保万无一失。
#   3. 支持目标为域名或 IP 地址。
#   4. 需要以 root 权限运行。
#
# 使用方式:
#   sudo ./iptables_redirect_safe.sh <transfer_port> <target_domain_or_ip> <target_port>
#
# 示例:
#   sudo ./iptables_redirect_safe.sh 34002 example.com 34001
#   这将把发往本机 34002 端口的 TCP 请求，转发到 example.com 的 34001 端口。

# --- 安全检查 ---

# 1. 检查是否以 root 权限运行
if [ "$(id -u)" != "0" ]; then
   echo "错误: 此脚本需要以 root 权限运行。"
   echo "请尝试使用: sudo $0 $*"
   exit 1
fi

# 2. 检查 iptables-persistent 是否安装
if ! which netfilter-persistent >/dev/null 2>&1; then
    echo "--------------------------------------------------------------------"
    echo "错误: 核心依赖 'iptables-persistent' 未安装。"
    echo "此工具用于在系统重启后自动加载 iptables 规则。"
    echo ""
    echo "请运行以下命令进行安装:"
    echo "  sudo apt update"
    echo "  sudo apt install iptables-persistent"
    echo ""
    echo "在安装过程中，当被问及是否保存当前规则时，请选择 <Yes>。"
    echo "--------------------------------------------------------------------"
    exit 1
fi

# --- 参数处理 ---

# 获取传入的参数
TRANSFER_PORT=$1
TARGET=$2
TARGET_PORT=$3

# 判断是否传入了所有必需的参数
if [ -z "$TRANSFER_PORT" ] || [ -z "$TARGET" ] || [ -z "$TARGET_PORT" ]; then
    echo "用法: sudo $0 <中转端口> <目标域名或IP> <目标端口>"
    echo "示例: sudo $0 34002 example.com 34001"
    exit 1
fi

# --- 域名解析 ---

# 判断目标是域名还是 IP 地址
if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    TARGET_IP=$TARGET
else
    # 使用 dig 解析域名，优先获取 A 记录
    TARGET_IP=$(dig +short A "$TARGET" | head -n 1)

    if [ -z "$TARGET_IP" ]; then
        echo "错误: 无法将域名 '$TARGET' 解析为 IP 地址。"
        exit 1
    fi
     echo "--> 域名 '$TARGET' 已成功解析为 IP: $TARGET_IP"
fi

# --- 核心操作 ---

echo "--> 准备设置端口转发: 本机端口 $TRANSFER_PORT -> $TARGET_IP:$TARGET_PORT"

# 为防止重复添加，先尝试删除可能已存在的相同规则
# 使用 -C 检查规则是否存在，如果存在再删除，避免不必要的错误提示
iptables -t nat -C PREROUTING -p tcp --dport "$TRANSFER_PORT" -j DNAT --to-destination "$TARGET_IP:$TARGET_PORT" >/dev/null 2>&1 && \
    iptables -t nat -D PREROUTING -p tcp --dport "$TRANSFER_PORT" -j DNAT --to-destination "$TARGET_IP:$TARGET_PORT"
iptables -t nat -C POSTROUTING -p tcp -d "$TARGET_IP" --dport "$TARGET_PORT" -j MASQUERADE >/dev/null 2>&1 && \
    iptables -t nat -D POSTROUTING -p tcp -d "$TARGET_IP" --dport "$TARGET_PORT" -j MASQUERADE

# 添加新的转发规则
iptables -t nat -A PREROUTING -p tcp --dport "$TRANSFER_PORT" -j DNAT --to-destination "$TARGET_IP:$TARGET_PORT"
iptables -t nat -A POSTROUTING -p tcp -d "$TARGET_IP" --dport "$TARGET_PORT" -j MASQUERADE

echo "--> 新规则已成功应用到当前系统内存。"

# --- 持久化操作 (关键部分) ---

# 定义规则文件路径
RULES_FILE_V4="/etc/iptables/rules.v4"

# 1. 自动备份现有规则，确保万无一失
if [ -f "$RULES_FILE_V4" ]; then
    BACKUP_FILE="${RULES_FILE_V4}.bak_$(date +%Y%m%d_%H%M%S)"
    echo "--> 发现现有规则文件，正在备份到: $BACKUP_FILE"
    cp "$RULES_FILE_V4" "$BACKUP_FILE"
else
    echo "--> 未发现现有规则文件，将直接创建新文件。"
fi

# 2. 保存当前所有生效的 IPv4 规则（包括刚才添加的新规则和所有已存在的旧规则）
echo "--> 正在将当前所有 IPv4 规则保存到 $RULES_FILE_V4..."
iptables-save > "$RULES_FILE_V4"

# --- 完成 ---
echo "--------------------------------------------------------"
echo "✅ 操作成功！"
echo ""
echo "  转发规则: 本机端口 $TRANSFER_PORT -> $TARGET_IP:$TARGET_PORT"
echo "  所有规则已保存，系统重启后将自动生效。"
echo "  如果出现问题，您可以使用备份文件恢复: $BACKUP_FILE"
echo "--------------------------------------------------------"

exit 0

