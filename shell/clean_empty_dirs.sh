#!/bin/bash
# 安全删除空目录脚本
# 功能：递归查找并交互式删除空目录，支持深度清理

target_path="${1:-$PWD}"
deleted_counter=0
failure_counter=0

# 创建临时文件（使用更安全的做法）
tmp_lock=$(mktemp -t deldir.XXXXXX) || { echo "临时文件创建失败"; exit 1; }
trap 'rm -f "$tmp_lock"' EXIT

# 检测GNU find
if find --version 2>/dev/null | grep -q GNU; then
  find "$target_path" -depth -type d -empty -print0 > "$tmp_lock"
else
  # BSD兼容模式：获取深度优先的空目录列表
  find "$target_path" -depth -type d -exec bash -c '
    shopt -s nullglob dotglob
    dir="$1"
    [[ $(echo "$dir"/* | wc -w) -eq 0 ]] && printf "%s\0" "$dir"
  ' _ {} \; > "$tmp_lock"
fi

# 统计结果
total_count=$(grep -cz '^' "$tmp_lock")

if [[ $total_count -eq 0 ]]; then
  echo "未发现空目录"
  exit 0
fi

# 显示找到的目录（安全转义特殊字符）
echo "发现 ${total_count} 个空目录:"
while IFS= read -r -d $'\0' path; do
  echo "  [目录] ${path//$'\n'/\\n}"
done < "$tmp_lock"

# 双重确认
read -p "确认要永久删除这些目录？[y/N] " confirm
case "$confirm" in
  [yY]*)
    # 增加删除保护延迟
    for i in {5..1}; do
      echo -ne "\r确认删除倒计时 ${i} 秒 (按 Ctrl+C 中止)..."
      sleep 1
    done
    echo -e "\n开始删除操作..."
    ;;
  *)
    echo "操作已取消"
    exit 0
    ;;
esac

# 执行删除操作
while IFS= read -r -d $'\0' dirpath; do
  if rmdir -v "$dirpath" 2>/dev/null; then
    ((deleted_counter++))
  else
    ((failure_counter++))
    echo "[错误] 无法删除目录: $dirpath" >&2
  fi
done < "$tmp_lock"

# 显示最终结果
echo "操作完成："
echo "成功删除目录数: $deleted_counter"
echo "删除失败目录数: $failure_counter"

# 可选：当存在失败项时返回非零状态码
[[ $failure_counter -gt 0 ]] && exit 1 || exit 0
