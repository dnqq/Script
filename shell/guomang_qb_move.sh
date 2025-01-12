#!/bin/bash

# ----------------------------------------------------------------------------
# 脚本名称: move_files.sh
# 描述: 该脚本用于将指定目录下的国漫视频文件移动到 OneDrive，并按照指定的文件名格式重命名。
#       - 扫描目录中的所有视频文件（排除 .!qB 文件）。
#       - 提取文件名中的电视剧名称、集号、分辨率等信息。
#       - 将文件移动到 OneDrive 的目标目录，按照指定的格式重命名。
#       - 文件夹结构为：/od_shipin/media/国漫/电视剧名称/Season 01/电视剧名称 - S01E集号 - 分辨率.mp4
#       - 删除空文件夹。
#
# 原文件结构:
# 文件名格式： [GM-Team][国漫][电视剧名称][其它信息][年份][集号][编码信息][语言][分辨率].mp4
# 例如：
# - [GM-Team][国漫][完美世界][Perfect World][2021][184][AVC][GB][1080P].mp4
#
# 本脚本会解析以下部分：
# - 第三组：电视剧名称（如 "完美世界"）
# - 第五组：年份（如 "2021"）【本脚本会忽略】
# - 第六组：集号（如 "184"）
# - 最后一组：分辨率（如 "1080P"）
#
# 脚本会将文件移动并重命名为：
# - /od_shipin/media/国漫/电视剧名称/Season 01/电视剧名称 - S01E集号 - 分辨率.mp4
# 例如：完美世界 - S01E184 - 1080P.mp4
#
# 处理季号：
# - 如果文件名中包含季号（例如 "斗破苍穹 第5季"），则脚本会提取季号并使用它来构建文件夹路径。
# - 文件夹结构将会是：/od_shipin/media/国漫/电视剧名称/Season XX/
# - 文件名格式将是：电视剧名称 SXXEXX 分辨率.mp4，例如：完美世界 - S01E184 - 1080P.mp4
# ----------------------------------------------------------------------------

# 打印带时间戳和日志级别的日志函数
log_message_with_level() {
  level=$1
  message=$2
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $message"
}

# 默认源目录路径和目标目录路径
default_source_directory="/opt/1panel/apps/qbittorrent/qbittorrent/data"
default_onedrive_target_directory="/od_shipin/media/国漫"

# 获取命令行参数，如果没有传入则使用默认值
source_directory="${1:-$default_source_directory}"
onedrive_target_directory="${2:-$default_onedrive_target_directory}"

# 打印开始日志
log_message_with_level "INFO" "脚本开始运行"

# 检查源目录是否存在
if [ ! -d "$source_directory" ]; then
  log_message_with_level "ERROR" "目录 $source_directory 不存在"
  exit 1
fi

# 遍历源目录下的所有文件和文件夹
find "$source_directory" -mindepth 1 | while read -r path; do
  # 如果是文件夹且为空，删除该文件夹
  if [ -d "$path" ] && [ ! "$(ls -A "$path")" ]; then
    log_message_with_level "INFO" "删除空文件夹: $path"
    rmdir "$path" || log_message_with_level "ERROR" "无法删除空文件夹: $path"
  fi
  
  # 如果是文件且扩展名不是 .!.qB，进行处理
  if [ -f "$path" ] && [[ "$path" != *.!qB ]]; then
    # 提取文件名
    filename=$(basename "$path")
    
    # 使用正则表达式提取文件名中的信息：
    # - 第三组：电视剧名称
    # - 第五组：年份
    # - 第六组：集号
    # - 最后一组：分辨率
    if [[ "$filename" =~ \[[^\[]*\]\[[^\[]*\]\[([^\]]+)\]\[[^\[]*\]\[([0-9]{4})\]\[([0-9]+)\].*\[([^\]]+)\] ]]; then
      tv_show_name="${BASH_REMATCH[1]}"   # 提取电视剧名称
      episode_number="${BASH_REMATCH[3]}" # 提取集号
      resolution="${BASH_REMATCH[4]}"     # 提取分辨率
      log_message_with_level "INFO" "找到电视剧名称: $tv_show_name"
      log_message_with_level "INFO" "找到集号: $episode_number"
      log_message_with_level "INFO" "找到分辨率: $resolution"

      # 默认季号为 01，如果文件名中包含季号，则提取季号
      season_number="01"  # 默认季号为 01
      if [[ "$tv_show_name" =~ 第([0-9]+)季 ]]; then
        season_number="${BASH_REMATCH[1]}"  # 提取季号
        tv_show_name="${tv_show_name%% 第*}"  # 去掉季号部分
        log_message_with_level "INFO" "找到季号: S$season_number"
      fi

      # 构建目标目录路径：包含季号
      target_directory="$onedrive_target_directory/$tv_show_name/Season $season_number"
      mkdir -p "$target_directory" || { log_message_with_level "ERROR" "目录创建失败: $target_directory"; exit 1; }

      # 构建新的文件名，格式为：电视剧名称 S01E集号 分辨率.mp4
      new_filename="${tv_show_name} - S${season_number}E${episode_number} - ${resolution}.mp4"
      current_file_path="$source_directory/$filename"

      # 检查目标路径是否已经存在该文件
      if [ -e "$target_directory/$new_filename" ]; then
        log_message_with_level "INFO" "目标文件已存在，跳过文件: $target_directory/$new_filename"
      else
        # 尝试在源目录中重命名文件
        mv "$current_file_path" "$source_directory/$new_filename"
        if [ $? -ne 0 ]; then
          log_message_with_level "ERROR" "文件重命名失败: $current_file_path"
          continue  # 跳过文件的移动步骤，继续处理下一个文件
        fi

        # 移动文件到目标目录
        mv "$source_directory/$new_filename" "$target_directory/$new_filename" || log_message_with_level "ERROR" "文件移动失败: $source_directory/$new_filename 到 $target_directory/$new_filename"
      fi

    else
      # 文件名格式不符合预期时打印原文件路径
      log_message_with_level "WARNING" "文件名格式不符合预期，无法提取信息: $path"
    fi
  else
    log_message_with_level "INFO" "跳过文件 $path，扩展名为 .!qB"
  fi
done

# 打印结束日志
log_message_with_level "INFO" "脚本运行结束"
