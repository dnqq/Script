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
        \?) echo "Usage: $0 [-u USERNAME] [-p PASSWORD] [-f FOLDER_PATH] [-s SERVER_ID] [-d DESTINATION_URL] [-c]" ;; # 如果参数错误，输出用法
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
# -----------------------------------
# 备份清理功能
# -----------------------------------

# 函数：清理旧的备份
# 根据复杂的保留策略删除WebDAV上的旧备份
# 注意：此功能依赖 GNU date 和 GNU grep。
cleanup_backups() {
    echo "开始清理旧的备份..."
    
    # 获取当前日期用于计算
    # date on macOS doesn't support -d, this requires GNU date.
    # On macOS, you can use `gdate` from `coreutils`.
    if ! date -d "2020-01-01" &>/dev/null; then
        echo "错误：此脚本的清理功能需要 GNU 'date' 命令。"
        echo "在 macOS 上, 请运行 'brew install coreutils' 并使用 'gdate'。"
        return 1
    fi
    
    local current_ts=$(date +%s)
    
    # 使用关联数组来跟踪已保留的备份
    declare -A kept_daily
    declare -A kept_weekly
    declare -A kept_monthly
    declare -A kept_yearly

    echo "正在从 WebDAV 获取备份列表..."
    # 使用 PROPFIND 递归获取所有文件。深度为 infinity 可能不被所有服务器支持。
    # 我们将尝试深度为 infinity，如果失败，则需要更复杂的逐级遍历。
    local all_files_raw=$(curl -s -u "$USER:$PASSWORD" -X PROPFIND "$DESTINATION_URL/$SERVER_ID/" --header "Depth: infinity" | grep -oP '(?<=<d:href>).*(?=</d:href>)' | grep '\.tar\.gz$')

    if [ -z "$all_files_raw" ]; then
        echo "在 $DESTINATION_URL/$SERVER_ID/ 未找到备份文件或无法列出文件。"
        return
    fi

    # 为了处理文件名中的URL编码（例如空格变为%20），我们需要解码
    # 这里我们用一个简单的 sed 替换，更复杂的需要一个专门的函数
    local all_files=$(echo "$all_files_raw" | sed 's/%20/ /g')

    # 按文件名反向排序，这样最新的文件会先被处理
    # 这有助于在“保留第一个”策略中保留最新的那个
    all_files=$(echo "$all_files" | sort -r)

    for full_path in $all_files; do
        local file=$(basename "$full_path")
        
        # 从文件名中提取日期 YYYYMMDD
        local backup_date_str=$(echo "$file" | grep -oP '(?<=_backup_)[0-9]{8}')
        if [ -z "$backup_date_str" ]; then
            echo "警告: 跳过无法解析日期的文件: $file"
            continue
        fi

        local backup_ts=$(date -d "$backup_date_str" +%s)
        local days_diff=$(((current_ts - backup_ts) / 86400))

        local backup_date_ymd=$(date -d "$backup_date_str" +%Y-%m-%d)
        local year_week=$(date -d "$backup_date_str" +%Y-%U) # 年份-周数
        local year_month=$(date -d "$backup_date_str" +%Y-%m) # 年份-月份
        local backup_year=$(date -d "$backup_date_str" +%Y)   # 年份

        # 策略1: 保留最近30天的所有备份
        if [ "$days_diff" -le 30 ]; then
            echo "保留 (30天内): $file"
            continue
        fi

        # 策略2: 保留3个月内（90天），每天一份
        if [ "$days_diff" -le 90 ]; then
            if [ -z "${kept_daily[$backup_date_ymd]}" ]; then
                echo "保留 (90天内每天一份): $file"
                kept_daily[$backup_date_ymd]=1
                continue
            fi
        fi

        # 策略3: 保留6个月内（180天），每周一份
        if [ "$days_diff" -le 180 ]; then
            if [ -z "${kept_weekly[$year_week]}" ]; then
                echo "保留 (180天内每周一份): $file"
                kept_weekly[$year_week]=1
                continue
            fi
        fi

        # 策略4: 保留3年内（1095天），每月一份
        if [ "$days_diff" -le 1095 ]; then
            if [ -z "${kept_monthly[$year_month]}" ]; then
                echo "保留 (3年内每月一份): $file"
                kept_monthly[$year_month]=1
                continue
            fi
        fi
        
        # 策略5: 每年一份
        if [ -z "${kept_yearly[$backup_year]}" ]; then
            echo "保留 (每年一份): $file"
            kept_yearly[$backup_year]=1
            continue
        fi

        # 如果不符合任何保留策略，则删除
        # 构造完整的 URL 进行删除
        local delete_url="$DESTINATION_URL$full_path"
        echo "删除: $file (URL: $delete_url)"
        curl -s -u "$USER:$PASSWORD" -X DELETE "$delete_url"
        # 检查curl的退出码
        if [ $? -eq 0 ]; then
            echo "成功删除: $file"
        else
            echo "错误: 删除失败: $file"
        fi
    done
    echo "备份清理完成。"
}
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
# 7. 如果启用了清理功能，则执行清理
if [ "$CLEANUP" = true ]; then
    echo "-----------------------------------"
    cleanup_backups
fi
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
