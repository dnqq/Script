#!/bin/bash
# 查找空目录并统计总数
# 用法：./find_empty_dirs.sh [搜索路径，默认为当前目录]

search_path="${1:-.}"
temp_file=$(mktemp)  # 创建临时文件存储结果

cleanup() {
  rm -f "$temp_file"  # 脚本退出时删除临时文件
}
trap cleanup EXIT

if find --version 2>/dev/null | grep -q GNU; then
  # GNU方案
  find "$search_path" -type d -empty -print > "$temp_file"
else
  # 兼容方案
  find "$search_path" -type d -exec bash -c '
    shopt -s nullglob dotglob
    files=("$1"/*)
    ((${#files[@]} == 0)) && echo "$1"
  ' _ {} \; > "$temp_file"
fi

# 显示结果并统计总数
if [ -s "$temp_file" ]; then
  echo "找到以下空目录："
  cat "$temp_file"
  echo -e "\n总计空目录数量：$(wc -l < "$temp_file")"
else
  echo "未找到空目录"
fi
