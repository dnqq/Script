#!/bin/bash

# ----------------------------------------------------------------------------
# 脚本名称: move_tv_shows.sh
# 描述: 该脚本用于将指定目录下的电视剧文件移动到目标目录。
#       - 扫描源目录中的所有文件（排除 .!qB 文件）。
#       - 直接将文件移动到目标目录，不进行重命名。
#       - 删除处理后留下的空文件夹。
# ----------------------------------------------------------------------------

# 打印带时间戳的日志函数
log_message_with_level() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1 - $2"
}

# 默认源目录路径和目标目录路径
default_source_directory="/qBittorrent/complete/电视剧"
default_target_directory="/media/电视剧"

# 获取命令行参数，如果没有传入则使用默认值
source_directory="${1:-$default_source_directory}"
target_directory="${2:-$default_target_directory}"

# 打印开始日志
log_message_with_level "INFO" "电视剧移动脚本开始运行"
log_message_with_level "INFO" "源目录: $source_directory"
log_message_with_level "INFO" "目标目录: $target_directory"

# 检查源目录是否存在
if [ ! -d "$source_directory" ]; then
  log_message_with_level "ERROR" "源目录 $source_directory 不存在"
  exit 1
fi

# 检查并创建目标目录
if [ ! -d "$target_directory" ]; then
  log_message_with_level "INFO" "目标目录 $target_directory 不存在，正在创建..."
  mkdir -p "$target_directory"
  if [ $? -ne 0 ]; then
    log_message_with_level "ERROR" "创建目标目录 $target_directory 失败"
    exit 1
  fi
fi

# 遍历源目录下的所有文件
find "$source_directory" -type f -print0 | while IFS= read -r -d $'\0' file; do
  # 排除 .!qB 临时文件
  if [[ "$file" == *.!qB ]]; then
    log_message_with_level "INFO" "跳过 qBittorrent 临时文件: $file"
    continue
  fi

  filename=$(basename "$file")
  log_message_with_level "INFO" "准备移动文件: $filename"

  # 移动文件到目标目录
  mv "$file" "$target_directory/"
  if [ $? -eq 0 ]; then
    log_message_with_level "INFO" "成功移动文件到: $target_directory/$filename"
  else
    log_message_with_level "ERROR" "移动文件失败: $file"
  fi
done

# 删除源目录中的空文件夹
log_message_with_level "INFO" "开始清理源目录中的空文件夹..."
find "$source_directory" -mindepth 1 -type d -empty -delete -print | while read -r dir; do
  log_message_with_level "INFO" "已删除空文件夹: $dir"
done
log_message_with_level "INFO" "空文件夹清理完毕"


# 打印结束日志
log_message_with_level "INFO" "电视剧移动脚本运行结束"