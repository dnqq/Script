#!/bin/bash

# -----------------------------------
# 脚本功能说明：
# 这个脚本用于将指定文件夹进行压缩，然后上传到WebDAV服务器。
# 上传路径格式为：<SERVER_ID>/<YEAR>/<MONTH>/<BACKUP_NAME>。
# 用户需要提供WebDAV的用户名、密码、服务器标识、WebDAV服务器URL以及待压缩的文件夹路径。
# 如果系统没有安装curl，脚本会自动安装curl。

# 输入参数说明：
# -u USERNAME    WebDAV用户名
# -p PASSWORD    WebDAV密码
# -f FOLDER_PATH 待压缩文件夹路径（默认：/root）
# -s SERVER_ID   服务器标识，用于构建上传路径
# -d DESTINATION_URL WebDAV服务器的URL

# 输出：
# 脚本会将指定文件夹压缩并上传至WebDAV服务器，并打印出上传的路径和文件名。

# -----------------------------------

# 禁用未定义变量报错
set +u

# 设置默认值
SOURCE_FOLDER="/root"   # 默认为 /root 文件夹

# 解析输入的参数
while getopts "u:p:f:s:d:" opt; do
    case ${opt} in
        u) USER=${OPTARG} ;;  # WebDAV用户名
        p) PASSWORD=${OPTARG} ;;  # WebDAV密码
        f) SOURCE_FOLDER=${OPTARG} ;;  # 待压缩文件夹路径
        s) SERVER_ID=${OPTARG} ;;  # 服务器标识
        d) DESTINATION_URL=${OPTARG} ;;  # WebDAV服务器的URL
        \?) echo "Usage: $0 [-u USERNAME] [-p PASSWORD] [-f FOLDER_PATH] [-s SERVER_ID] [-d DESTINATION_URL]" ;;  # 如果参数错误，输出用法
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

# 1. 生成备份文件名
# 备份文件名格式：<SERVER_ID>_<SOURCE_FOLDER>_backup_<DATE>.tar.gz
BACKUP_NAME="${SERVER_ID}_$(basename "$SOURCE_FOLDER")_backup_$(date +'%Y%m%d_%H%M%S').tar.gz"

# 2. 压缩文件夹
# 使用 tar 命令将指定的文件夹压缩成一个 tar.gz 文件
tar -czf "$BACKUP_NAME" -C "$(dirname "$SOURCE_FOLDER")" "$(basename "$SOURCE_FOLDER")"

# 3. 检查是否安装了curl命令，如果没有则自动安装
# 如果 curl 命令未安装，则自动尝试安装 curl
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

# 4. 获取当前年份和月份，构建上传路径
# 使用当前日期的年份和月份来构建上传路径
YEAR=$(date +'%Y')
MONTH=$(date +'%m')
UPLOAD_PATH="$SERVER_ID/$YEAR/$MONTH/$BACKUP_NAME"  # 上传路径：<SERVER_ID>/<YEAR>/<MONTH>/<BACKUP_NAME>

# 5. 使用curl上传文件到WebDAV
# 通过curl上传压缩后的文件到WebDAV服务器
echo "上传文件到 WebDAV：$DESTINATION_URL/$UPLOAD_PATH"
curl -T "$BACKUP_NAME" "$DESTINATION_URL/$UPLOAD_PATH" --user "$USER:$PASSWORD"

# 6. 删除本地压缩文件（如果不再需要）
# 上传完成后删除本地的压缩文件，节省磁盘空间
rm -f "$BACKUP_NAME"

# 完成提示
echo "操作完成！"
