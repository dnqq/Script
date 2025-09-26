#!/bin/bash

# 合并后的脚本，用于查找、删除和清理空目录
# 用法: ./manage_empty_dirs.sh [find|delete|clean] [path]

# --- 函数定义 ---

# 查找空目录
find_empty() {
  local search_path="${1:-.}"
  echo "在 '${search_path}' 中查找空目录..."
  find "$search_path" -type d -empty
  echo "查找完成。"
}

# 删除空目录（带简单确认）
delete_empty() {
  local target_path="${1:-.}"
  if [ ! -d "$target_path" ]; then
    echo "错误: 路径 '$target_path' 不存在或不是一个目录。"
    exit 1
  fi

  echo "将在 '${target_path}' 中删除以下空目录:"
  find "$target_path" -type d -empty -print
  
  read -p "确认删除这些空文件夹吗？(y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "操作已取消。"
    exit 0
  fi
  
  find "$target_path" -type d -empty -delete
  echo "空目录已删除。"
}

# 安全清理空目录（带倒计时和统计）
clean_empty() {
    local target_path="${1:-.}"
    local deleted_counter=0
    local failure_counter=0

    local tmp_lock
    tmp_lock=$(mktemp -t deldir.XXXXXX) || { echo "临时文件创建失败"; exit 1; }
    trap 'rm -f "$tmp_lock"' EXIT

    echo "正在深度扫描 '${target_path}' 中的空目录..."
    find "$target_path" -depth -type d -empty -print0 > "$tmp_lock"

    local total_count
    total_count=$(grep -cz '^' "$tmp_lock")

    if [[ $total_count -eq 0 ]]; then
        echo "未发现空目录。"
        exit 0
    fi

    echo "发现 ${total_count} 个空目录:"
    while IFS= read -r -d $'\0' path; do
        echo "  [目录] ${path//$'\n'/\\n}"
    done < "$tmp_lock"

    read -p "确认要永久删除这些目录？[y/N] " confirm
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        echo "操作已取消。"
        exit 0
    fi

    for i in {3..1}; do
        echo -ne "\r删除操作将在 ${i} 秒后开始，按 Ctrl+C 取消..."
        sleep 1
    done
    echo -e "\n开始删除..."

    while IFS= read -r -d $'\0' dirpath; do
        if rmdir -v "$dirpath" 2>/dev/null; then
            ((deleted_counter++))
        else
            ((failure_counter++))
            echo "[错误] 无法删除: $dirpath" >&2
        fi
    done < "$tmp_lock"

    echo "操作完成。"
    echo "成功删除: $deleted_counter"
    echo "删除失败: $failure_counter"

    [[ $failure_counter -gt 0 ]] && exit 1 || exit 0
}

# --- 主逻辑 ---

ACTION="$1"
TARGET_PATH="$2"

if [ -z "$ACTION" ]; then
  echo "用法: $0 [find|delete|clean] [path]"
  echo "  find   - 查找并列出空目录"
  echo "  delete - 查找并删除空目录（有确认）"
  echo "  clean  - 安全地清理空目录（有倒计时和统计）"
  exit 1
fi

# 如果路径为空，则默认为当前目录
if [ -z "$TARGET_PATH" ]; then
  TARGET_PATH="."
fi

case "$ACTION" in
  find)
    find_empty "$TARGET_PATH"
    ;;
  delete)
    delete_empty "$TARGET_PATH"
    ;;
  clean)
    clean_empty "$TARGET_PATH"
    ;;
  *)
    echo "错误: 未知操作 '$ACTION'。"
    echo "请使用 'find', 'delete', 或 'clean'。"
    exit 1
    ;;
esac