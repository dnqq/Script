#!/bin/bash

# 脚本名称: iptables_redirect.sh
# 脚本效果: 通过 iptables 设置端口转发规则，将外部请求通过指定的中转端口转发到目标服务器的指定端口。
#          支持目标为域名或 IP 地址。如果传入的是域名，脚本会解析域名为 IP 地址。
#          所有的规则将保存到 /etc/iptables.up.rules，重启后保持生效。
# 
# 使用方式:
#   ./iptables_redirect.sh <transfer_port> <target_domain_or_ip> <target_port>
#
# 参数说明:
#   <transfer_port>    - 中转端口，外部访问的端口
#   <target_domain_or_ip> - 目标服务器的域名或 IP 地址
#   <target_port>      - 目标服务器的端口
#
# 示例:
#   ./iptables_redirect.sh 34002 example.com 34001
#   这将把 34002 端口的请求转发到 example.com 的 34001 端口。

# 获取传入的参数
TRANSFER_PORT=$1
TARGET=$2
TARGET_PORT=$3

# 判断是否传入了所有必需的参数
if [ -z "$TRANSFER_PORT" ] || [ -z "$TARGET" ] || [ -z "$TARGET_PORT" ]; then
    # 如果有参数缺失，输出使用说明并退出脚本
    echo "Usage: $0 <transfer_port> <target> <target_port>"
    exit 1
fi

# 判断目标是域名还是 IP 地址
if [[ "$TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    # 如果是 IP 地址，直接使用
    TARGET_IP=$TARGET
else
    # 如果是域名，解析成 IP 地址
    TARGET_IP=$(dig +short $TARGET)

    # 检查域名解析是否成功
    if [ -z "$TARGET_IP" ]; then
        # 如果解析失败，输出错误信息并退出脚本
        echo "Error: Unable to resolve domain name $TARGET"
        exit 1
    fi
fi

# 打印正在操作的规则，方便调试和确认
echo "Setting up port forwarding: $TRANSFER_PORT -> $TARGET_IP:$TARGET_PORT"

# 删除可能已存在的原有规则（清理旧的 NAT 规则）
iptables -t nat -D PREROUTING -p tcp --dport $TRANSFER_PORT -j DNAT --to-destination $TARGET_IP:$TARGET_PORT
iptables -t nat -D POSTROUTING -p tcp -d $TARGET_IP --dport $TARGET_PORT -j MASQUERADE

# 添加新的规则：PREROUTING 链用于将外部请求转发到目标服务器的指定端口
iptables -t nat -A PREROUTING -p tcp --dport $TRANSFER_PORT -j DNAT --to-destination $TARGET_IP:$TARGET_PORT

# 添加新的规则：POSTROUTING 链用于修改发往目标服务器的请求，确保源地址保持一致
iptables -t nat -A POSTROUTING -p tcp -d $TARGET_IP --dport $TARGET_PORT -j MASQUERADE

# 保存规则到配置文件（用于重启后保持规则）
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules

# 输出成功信息
echo "Port forwarding setup complete: $TRANSFER_PORT -> $TARGET_IP:$TARGET_PORT"
