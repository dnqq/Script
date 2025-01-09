#!/bin/bash

# 检查是否传入了目标路径参数
if [ -z "$1" ]; then
  echo "请提供要清理空文件夹的路径。"
  exit 1
fi

# 获取目标路径
target_path="$1"

# 检查目标路径是否存在
if [ ! -d "$target_path" ]; then
  echo "提供的路径不存在或不是一个有效的目录。"
  exit 1
fi

# 模拟运行（只列出空文件夹，而不删除）
echo "以下空文件夹将被删除："
find "$target_path" -type d -empty -print

# 提示是否继续删除
read -p "确认删除这些空文件夹吗？(y/n): " confirm
if [[ "$confirm" != "y" ]]; then
  echo "操作已取消。"
  exit 0
fi

# 使用find命令查找并删除空文件夹
find "$target_path" -type d -empty -delete

echo "空文件夹已删除。"
