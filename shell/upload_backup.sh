#!/bin/bash

# 禁用未定义变量报错
set +u

# 设置默认值
SOURCE_FOLDER="/root"   # 默认为 /root 文件夹

# 解析参数
while getopts "u:p:f:s:d:" opt; do
    case ${opt} in
        u) USER=${OPTARG} ;;  # WebDAV用户名
        p) PASSWORD=${OPTARG} ;;  # WebDAV密码
        f) SOURCE_FOLDER=${OPTARG} ;;  # 待压缩文件夹路径
        s) SERVER_ID=${OPTARG} ;;  # 服务器标识
        d) DESTINATION_URL=${OPTARG} ;;  # WebDAV服务器的URL
        \?) echo "Usage: $0 [-u USERNAME] [-p PASSWORD] [-f FOLDER_PATH] [-s SERVER_ID] [-d DESTINATION_URL]" ;;
    esac
done

# 输出传入的参数，帮助调试
echo "USER: $USER"
echo "PASSWORD: $PASSWORD"
echo "SERVER_ID: $SERVER_ID"
echo "DESTINATION_URL: $DESTINATION_URL"
echo "SOURCE_FOLDER: $SOURCE_FOLDER"

# 检查是否提供了 USER、PASSWORD、SERVER_ID 和 DESTINATION_URL
if [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$SERVER_ID" ] || [ -z "$DESTINATION_URL" ]; then
    echo "用户名、密码、服务器标识和WebDAV服务器URL是必需的！"
    exit 1
fi

# 1. 生成备份文件名，去除 "__"，改为 "_"
BACKUP_NAME="${SERVER_ID}_$(basename "$SOURCE_FOLDER")_backup_$(date +'%Y%m%d_%H%M%S').tar.gz"

# 2. 压缩文件夹
tar -czf "$BACKUP_NAME" -C "$(dirname "$SOURCE_FOLDER")" "$(basename "$SOURCE_FOLDER")"

# 3. 检查是否安装了curl命令，如果没有则自动安装
if ! command -v curl &> /dev/null; then
    echo "curl未安装，尝试自动安装curl..."
    
    # 检测系统类型并安装curl
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu 系统
        echo "检测到Debian/Ubuntu系统，正在安装curl..."
        sudo apt-get update
        sudo apt-get install -y curl
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS 系统
        echo "检测到RHEL/CentOS系统，正在安装curl..."
        sudo yum install -y curl
    else
        echo "无法识别系统类型，请手动安装curl。"
        exit 1
    fi
fi

# 4. 使用curl上传文件到WebDAV
UPLOAD_PATH="$SERVER_ID/$BACKUP_NAME"
echo "上传文件到 WebDAV：$DESTINATION_URL/$UPLOAD_PATH"

curl -T "$BACKUP_NAME" "$DESTINATION_URL/$UPLOAD_PATH" --user "$USER:$PASSWORD"

# 5. 删除本地压缩文件（如果不再需要）
rm -f "$BACKUP_NAME"

# 完成
echo "操作完成！"
