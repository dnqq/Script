#!/bin/bash

# 检查是否提供了新域名作为参数
if [ -z "$1" ]; then
  echo "用法: $0 <新域名>"
  exit 1
fi

NEW_DOMAIN=$1
CONFIG_FILE="/opt/XrayR/config/config.yml"

# 检查配置文件是否存在
if [ ! -f "$CONFIG_FILE" ]; then
  echo "错误: 配置文件 $CONFIG_FILE 未找到!"
  exit 1
fi

# 使用 sed 命令替换 ApiHost 和 CertDomain 的主域名，保留子域名部分
sed -i "s|\(ApiHost: \"https://[^.]*\.\)[^"]*\"|\1${NEW_DOMAIN}\"|g" $CONFIG_FILE
sed -i "s|\(CertDomain: \"[^.]*\.\)[^"]*\"|\1${NEW_DOMAIN}\"|g" $CONFIG_FILE

echo "配置文件 $CONFIG_FILE 已更新。"
echo "ApiHost 和 CertDomain 的主域名已更改为: $NEW_DOMAIN"

# 进入 XrayR 目录并重启 docker-compose
echo "正在重启 XrayR..."
cd /opt/XrayR || exit
docker compose restart

echo "XrayR 重启完成。"