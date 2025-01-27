#!/bin/bash

# 参数
TRANSFER_PORT=$1
TARGET=$2
TARGET_PORT=$3

# 判断参数是否传入
if [ -z "$TRANSFER_PORT" ] || [ -z "$TARGET" ] || [ -z "$TARGET_PORT" ]; then
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
        echo "Error: Unable to resolve domain name $TARGET"
        exit 1
    fi
fi

# 删除原有规则
iptables -t nat -D PREROUTING -p tcp --dport $TRANSFER_PORT -j DNAT --to-destination $TARGET_IP:$TARGET_PORT
iptables -t nat -D POSTROUTING -p tcp -d $TARGET_IP --dport $TRANSFER_PORT -j MASQUERADE

# 添加新规则
iptables -t nat -A PREROUTING -p tcp --dport $TRANSFER_PORT -j DNAT --to-destination $TARGET_IP:$TARGET_PORT
iptables -t nat -A POSTROUTING -p tcp -d $TARGET_IP --dport $TRANSFER_PORT -j MASQUERADE

# 保存规则
iptables-save > /etc/iptables.up.rules
iptables-restore < /etc/iptables.up.rules
