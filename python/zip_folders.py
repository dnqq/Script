# -*- coding: utf-8 -*-
#
# 功能:
#   本脚本用于自动将指定根目录下的所有顶级文件夹分别压缩成独立的 .zip 文件。
#   压缩文件将被存放在根目录下的一个名为“压缩”的子目录中。
#   如果目标文件夹的 .zip 文件已经存在于“压缩”目录中，脚本将跳过该文件夹，避免重复压缩。
#
# 使用方法:
#   1. 直接运行脚本:
#      - 修改脚本末尾的 `TARGET_DIRECTORY` 变量为您想要扫描的目录路径。
#      - 然后执行 `python your_script_name.py`
#
#   2. 通过命令行参数指定目录:
#      - 执行 `python your_script_name.py "/path/to/your/folders"`
#      - 例如: `python your_script_name.py "D:/pram"`
#
# 作者: Author: ashin
#

import os
import shutil
import sys

def zip_folders_in_root(root_path='.'):
    """
    将指定根目录中的每个顶级文件夹压缩成一个 .zip 文件。
    压缩文件保存在名为“压缩”的子目录中。
    如果输出目录中已存在同名的 .zip 文件，则跳过该文件夹。

    Args:
        root_path (str): 要扫描的根目录路径。默认为当前目录。
    """
    # 打印正在扫描的目录的绝对路径，以便用户确认
    print(f"正在扫描目录: {os.path.abspath(root_path)}")

    # 定义并创建用于存放压缩文件的输出目录
    zip_output_dir = os.path.join(root_path, '压缩')
    if not os.path.exists(zip_output_dir):
        os.makedirs(zip_output_dir)
        print(f"创建压缩目录: {zip_output_dir}")

    # 尝试获取根目录下的所有文件和文件夹列表
    try:
        items = os.listdir(root_path)
    except FileNotFoundError:
        print(f"错误: 目录 '{root_path}' 不存在。")
        sys.exit(1) # 目录不存在则退出脚本

    # 标志位，用于判断是否在根目录下找到了任何文件夹
    found_folders = False
    
    # 遍历根目录下的每一个项目（文件或文件夹）
    for item_name in items:
        # 构造项目的完整路径
        item_path = os.path.join(root_path, item_name)

        # 检查当前项目是否是一个文件夹，并排除隐藏文件夹和脚本自己创建的“压缩”目录
        if os.path.isdir(item_path) and not item_name.startswith('.') and os.path.abspath(item_path) != os.path.abspath(zip_output_dir):
            found_folders = True # 找到了一个符合条件的文件夹
            
            # 构造最终生成的 .zip 文件的名称和完整路径
            zip_file_name = f"{item_name}.zip"
            zip_file_path = os.path.join(zip_output_dir, zip_file_name)

            # 检查同名的 .zip 文件是否已经存在，如果存在则跳过
            if os.path.exists(zip_file_path):
                print(f"跳过 '{item_name}': '{zip_file_name}' 已存在于 '{zip_output_dir}'。")
                continue # 继续下一次循环

            # 如果压缩文件不存在，则开始压缩过程
            print(f"正在压缩 '{item_name}' -> '{zip_file_path}'...")
            try:
                # 定义归档文件的基础名称（不包含 .zip 后缀）
                archive_base_name = os.path.join(zip_output_dir, item_name)
                
                # 使用 shutil.make_archive 进行压缩
                # base_name: 归档文件的路径和基本名称
                # format: 归档格式 ('zip', 'tar', etc.)
                # root_dir: 要归档的目录，归档时将以此目录为根，避免在压缩包内包含上层路径
                shutil.make_archive(base_name=archive_base_name, format='zip', root_dir=item_path)
                print(f"成功创建 '{zip_file_name}'。")
            except Exception as e:
                # 捕获并打印压缩过程中可能出现的任何异常
                print(f"压缩 '{item_name}' 时出错: {e}")
    
    # 如果遍历完所有项目后，一个文件夹都未找到，则通知用户
    if not found_folders:
        print("在指定目录下未找到任何需要压缩的文件夹。")

# 当脚本作为主程序执行时，运行以下代码
if __name__ == "__main__":
    # ====================================================================
    # 默认配置区域
    # 如果不通过命令行参数指定，脚本将使用此路径
    # 例如: 'C:/Users/YourUser/Desktop' 或 '/home/user/documents'
    # 使用 '.' 代表当前脚本所在的目录
    TARGET_DIRECTORY = 'D:/pram'
    # ====================================================================

    # 检查命令行参数的数量，如果大于1，则表示用户提供了路径参数
    if len(sys.argv) > 1:
        # 使用第一个命令行参数作为目标目录，并获取其绝对路径
        target_path = os.path.abspath(sys.argv[1])
        print(f"使用命令行参数指定的目录: {target_path}")
    else:
        # 如果没有命令行参数，则使用在脚本中定义的默认目录
        target_path = os.path.abspath(TARGET_DIRECTORY)
        print(f"使用脚本内定义的目录: {target_path}")

    # 在执行核心功能前，校验最终确定的路径是否是一个真实存在的目录
    if not os.path.isdir(target_path):
        print(f"错误: '{target_path}' 不是一个有效的目录。请检查路径是否正确。")
        sys.exit(1) # 如果路径无效，则退出脚本

    # 调用主函数，开始执行压缩逻辑
    zip_folders_in_root(target_path)
    
    # 所有操作完成后，打印结束信息
    print("\n脚本执行完毕。")
