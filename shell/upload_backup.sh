#!/bin/bash

# -----------------------------------
# 脚本功能说明：
# 这个脚本用于将指定文件夹进行压缩，然后上传到WebDAV服务器。
# 上传路径格式为：<SERVER_ID>/<YEAR>/<MONTH>/<BACKUP_NAME>。
# 用户需要提供WebDAV的用户名、密码、服务器标识、WebDAV服务器URL以及待压缩的文件夹路径。
# 如果系统没有安装curl，脚本会自动安装curl。
# 新增功能：可以根据复杂的保留策略自动清理旧的备份。
#
# 输入参数说明：
# -u USERNAME    WebDAV用户名
# -p PASSWORD    WebDAV密码
# -f FOLDER_PATH 待压缩文件夹路径（默认：/root）
# -s SERVER_ID   服务器标识，用于构建上传路径
# -d DESTINATION_URL WebDAV服务器的URL
# -c             启用备份清理功能
#
# 输出：
# 脚本会将指定文件夹压缩并上传至WebDAV服务器，并打印出上传的路径和文件名。
# 如果启用了清理功能，脚本还会根据预设策略删除旧的备份。
#
# -----------------------------------

# 禁用未定义变量报错
set +u

# 设置默认值
SOURCE_FOLDER="/root"   # 默认为 /root 文件夹
CLEANUP=false           # 默认不启用清理功能

# 解析输入的参数
while getopts "u:p:f:s:d:c" opt; do
    case ${opt} in
        u) USER=${OPTARG} ;;          # WebDAV用户名
        p) PASSWORD=${OPTARG} ;;      # WebDAV密码
        f) SOURCE_FOLDER=${OPTARG} ;;  # 待压缩文件夹路径
        s) SERVER_ID=${OPTARG} ;;      # 服务器标识
        d) DESTINATION_URL=${OPTARG} ;; # WebDAV服务器的URL
        c) CLEANUP=true ;;             # 启用清理
        \?) echo "用法: $0 [-u USER] [-p PASS] [-f FOLDER] [-s SERVER_ID] [-d URL] [-c]"
            exit 1 ;;
    esac
done

# 检查是否提供了 USER、PASSWORD、SERVER_ID 和 DESTINATION_URL
if [ -z "$USER" ] || [ -z "$PASSWORD" ] || [ -z "$SERVER_ID" ] || [ -z "$DESTINATION_URL" ]; then
    echo "错误：用户名、密码、服务器标识和WebDAV服务器URL是必需的！"
    echo "用法: $0 -u USER -p PASS -f FOLDER -s SERVER_ID -d URL [-c]"
    exit 1
fi

# 输出传入的参数，帮助调试
echo "--- 参数信息 ---"
echo "用户名: $USER"
echo "密码: [已隐藏]"
echo "服务器标识: $SERVER_ID"
echo "WebDAV URL: $DESTINATION_URL"
echo "备份文件夹: $SOURCE_FOLDER"
echo "启用清理: $CLEANUP"
echo "----------------"

# -----------------------------------
# 辅助函数
# -----------------------------------

# 函数：URL编码
urlencode() {
    if command -v python3 &>/dev/null; then
        python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe="/"))' "$1"
    elif command -v python &>/dev/null; then
        python -c 'import sys, urllib; print urllib.quote(sys.argv[1], safe="/")' "$1"
    else
        echo "$1" | sed 's/ /%20/g'
    fi
}

# 函数：清理旧的备份
cleanup_backups() {
    echo "开始清理旧的备份..."
    
    if ! date -d "2020-01-01" &>/dev/null; then
        echo "错误：此脚本的清理功能需要 GNU 'date' 命令。"
        return 1
    fi
    
    local current_ts=$(date +%s)
    declare -A kept_daily kept_weekly kept_monthly kept_yearly

    local encoded_server_id=$(urlencode "$SERVER_ID")
    local base_url="$DESTINATION_URL/$encoded_server_id"
    local host_url=$(echo "$DESTINATION_URL" | grep -oP 'https?://[^/]+')
    
    echo "正在从 $base_url/ 递归获取备份列表..."
    
    # 使用 awk 解析 PROPFIND XML 响应，这种方法比 grep 更健壮
    # 注意：XML 标签是区分大小写的，使用 D:href
    # 使用 awk 解析 PROPFIND XML 响应，这种方法比 grep 更健壮
    # 注意：XML 标签是区分大小写的，使用 D:href
    local all_files_raw=$(curl -s -u "$USER:$PASSWORD" -X PROPFIND "$base_url/" --header "Depth: infinity" |
        awk -F'</?D:href>' '{for (i=2; i<=NF; i+=2) print $i}' |
        grep '\.tar\.gz$')

    if [ -z "$all_files_raw" ]; then
        echo "在 $base_url/ 的子目录中未找到任何备份文件。"
        return
    fi

    local all_files=$(echo "$all_files_raw" | sort -r)

    for full_path in $all_files; do
        local file=$(basename "$full_path")
        local backup_date_str=$(echo "$file" | grep -oP '(?<=_backup_)[0-9]{8}')
        
        if [ -z "$backup_date_str" ]; then
            echo "警告: 跳过无法解析日期的文件: $file"
            continue
        fi

        local backup_ts=$(date -d "$backup_date_str" +%s)
        local days_diff=$(((current_ts - backup_ts) / 86400))
        local backup_date_ymd=$(date -d "$backup_date_str" +%Y-%m-%d)
        local year_week=$(date -d "$backup_date_str" +%Y-%U)
        local year_month=$(date -d "$backup_date_str" +%Y-%m)
        local backup_year=$(date -d "$backup_date_str" +%Y)

        if [ "$days_diff" -le 30 ]; then
            echo "保留 (30天内): $file"
            continue
        fi

        if [ "$days_diff" -le 90 ]; then
            if [ -z "${kept_daily[$backup_date_ymd]}" ]; then
                echo "保留 (90天内每天一份): $file"
                kept_daily[$backup_date_ymd]=1
                continue
            fi
        fi

        if [ "$days_diff" -le 180 ]; then
            if [ -z "${kept_weekly[$year_week]}" ]; then
                echo "保留 (180天内每周一份): $file"
                kept_weekly[$year_week]=1
                continue
            fi
        fi

        if [ "$days_diff" -le 1095 ]; then
            if [ -z "${kept_monthly[$year_month]}" ]; then
                echo "保留 (3年内每月一份): $file"
                kept_monthly[$year_month]=1
                continue
            fi
        fi
        
        if [ -z "${kept_yearly[$backup_year]}" ]; then
            echo "保留 (每年一份): $file"
            kept_yearly[$backup_year]=1
            continue
        fi

        local delete_url="$host_url$full_path"
        echo "删除: $file"
        curl -s -o /dev/null -w "删除状态: %{http_code}\n" -u "$USER:$PASSWORD" -X DELETE "$delete_url"
    done
    echo "备份清理完成。"
}

# -----------------------------------
# 主流程
# -----------------------------------

echo "1. 生成备份文件名..."
BACKUP_NAME="${SERVER_ID}_$(basename "$SOURCE_FOLDER")_backup_$(date +'%Y%m%d_%H%M%S').tar.gz"
echo "备份文件名: $BACKUP_NAME"

echo "2. 正在压缩文件夹: $SOURCE_FOLDER..."
tar -czf "$BACKUP_NAME" -C "$(dirname "$SOURCE_FOLDER")" "$(basename "$SOURCE_FOLDER")"
if [ $? -ne 0 ]; then echo "错误：压缩文件夹失败。"; rm -f "$BACKUP_NAME"; exit 1; fi
echo "压缩完成。"

if ! command -v curl &> /dev/null; then
    echo "curl未安装，尝试自动安装..."
    if [ -f /etc/debian_version ]; then sudo apt-get update && sudo apt-get install -y curl
    elif [ -f /etc/redhat-release ]; then sudo yum install -y curl
    else echo "无法识别系统类型，请手动安装curl。"; rm -f "$BACKUP_NAME"; exit 1; fi
fi

YEAR=$(date +'%Y')
MONTH=$(date +'%m')
UPLOAD_PATH_ENCODED="$(urlencode "$SERVER_ID")/$YEAR/$MONTH/$(urlencode "$BACKUP_NAME")"
FULL_DEST_URL="$DESTINATION_URL/$UPLOAD_PATH_ENCODED"

echo "3. 正在上传文件到: $FULL_DEST_URL"
curl -s -o /dev/null -w "上传状态: %{http_code}\n" -T "$BACKUP_NAME" "$FULL_DEST_URL" --user "$USER:$PASSWORD" --ftp-create-dirs

echo "4. 删除本地临时文件: $BACKUP_NAME"
rm -f "$BACKUP_NAME"

if [ "$CLEANUP" = true ]; then
    echo "5. 开始执行备份清理..."
    cleanup_backups
fi

echo "操作完成！"
