#!/bin/bash

# 脚本作用：此脚本用于重置 iptables 防火墙规则，设置默认策略为 ACCEPT，
# 清空当前规则，并将当前规则保存到 /etc/iptables.up.rules 文件中，然后恢复该规则。

# 设置默认策略为接受
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# 清空所有规则
iptables -F

# 保存当前规则到文件
iptables-save > /etc/iptables.up.rules

# 恢复规则
iptables-restore < /etc/iptables.up.rules

echo "iptables rules have been reset and saved."
