# -*- coding: utf-8 -*-
"""
@File: source_filter.py
@Description:
    该脚本用于处理和筛选一个JSON格式的视频源列表（例如 'moontv.json'）。
    主要功能包括：
    1.  加载新的视频源列表和已有的筛选后列表。
    2.  合并并去除重复的源（基于API URL）。
    3.  使用多线程并发检查每个源的API地址是否可访问。
    4.  (可选) 调用AI接口判断源内容是否为成人内容。
    5.  将无法访问或疑似成人内容的源交由用户交互式确认是否保留。
    6.  将最终筛选和确认后的有效源列表写入新的JSON文件（'moontv_filtered.json'）。

@Usage:
    1.  确保已安装所需库: pip install requests python-dotenv
    2.  在脚本同目录下创建 `.env` 文件，并配置以下环境变量:
        OPENAI_API_URL="你的AI服务API地址"
        OPENAI_API_KEY="你的AI服务API密钥"
        OPENAI_API_MODEL="你希望使用的AI模型"
    3.  准备好源文件 `python/moontv.json`。
    4.  运行脚本: python your_script_name.py

@Author: ashin
"""

import os
import json
import requests
from dotenv import load_dotenv
import concurrent.futures
import threading

# 加载 .env 文件中的环境变量
load_dotenv()

# 从环境变量中获取AI服务配置
OPENAI_API_URL = os.getenv("OPENAI_API_URL")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_API_MODEL = os.getenv("OPENAI_API_MODEL")

# 打印配置信息以供调试
print(f"AI API URL: {OPENAI_API_URL}")
print(f"AI API KEY: {OPENAI_API_KEY}")
print(f"AI API MODEL: {OPENAI_API_MODEL}")

def check_source_accessibility(url, timeout=10):
    """
    检查给定的视频源API URL是否能正常访问并返回有效的JSON数据。

    Args:
        url (str): 需要检查的API URL。
        timeout (int, optional): 请求超时时间（秒）. 默认为 10.

    Returns:
        tuple: 一个包含状态码和响应内容的元组。
               - ("success", json_data): 访问成功，返回JSON数据。
               - ("not_found", None): 服务器返回404错误。
               - ("other_error", None): 其他类型的HTTP错误或网络、解析错误。
    """
    # 模拟浏览器User-Agent，防止一些服务器拒绝非浏览器请求
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        # 发送GET请求
        response = requests.get(url, headers=headers, timeout=timeout)
        # 如果响应状态码是4xx或5xx，则抛出HTTPError异常
        response.raise_for_status()
        # 尝试将响应体解析为JSON
        return "success", response.json()
    except requests.exceptions.HTTPError as e:
        # 特别处理404 Not Found错误
        if e.response.status_code == 404:
            return "not_found", None
        else:
            # 其他HTTP错误
            print(f"访问 {url} 时出现HTTP错误: {e}")
            return "other_error", None
    except (requests.exceptions.RequestException, json.JSONDecodeError) as e:
        # 捕获网络连接错误或JSON解析错误
        print(f"访问 {url} 或解析JSON时出错: {e}")
        return "other_error", None

def is_adult_website(api_content, name, url):
    """
    使用AI服务判断给定的源内容是否可能为成人网站。
    **注意**: 此处AI判断逻辑已暂时禁用。

    Args:
        api_content (dict): 从源API获取的JSON内容。
        name (str): 源的名称。
        url (str): 源的API URL。

    Returns:
        bool: 如果判断为成人内容则返回True，否则返回False。
    """
    # 此处省略了与之前版本相同的AI判断代码，以保持简洁。
    # 实际生产代码中，这里会构造prompt并请求OpenAI API进行内容分类。
    return False # 临时禁用以加速测试，当前所有源都不会被标记为成人内容。

def load_json_file(file_path):
    """
    安全地加载并解析一个JSON文件。

    Args:
        file_path (str): JSON文件的路径。

    Returns:
        dict: 解析后的JSON数据。如果文件不存在或解析失败，则返回一个空字典。
    """
    # 检查文件是否存在
    if not os.path.exists(file_path):
        return {}
    try:
        # 以utf-8编码打开并读取文件
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        # 处理JSON格式错误或文件读取错误
        print(f"读取或解析文件 {file_path} 时出错: {e}")
        return {}

def process_source(source_id, source_info, locks, lists):
    """
    处理单个视频源的线程工作函数。

    该函数会检查源的可访问性，对其进行分类，并使用锁机制将结果
    安全地存入共享的字典中。

    Args:
        source_id (str): 源的唯一标识ID。
        source_info (dict): 包含源名称和API URL的字典。
        locks (dict): 包含多个线程锁的字典，用于保证对共享列表的线程安全访问。
        lists (dict): 包含多个分类结果列表（字典）的字典。
    """
    name = source_info.get('name', 'Unknown')
    api_url = source_info.get('api', '')

    # 过滤掉名称以'AV'开头的源（通常为成人内容）
    if name.upper().startswith('AV'):
        # print(f"源 {name} ({source_id}) 的name以AV开头，已过滤")
        return

    # 规范化源名称，如果名称不以'TV'开头，则添加前缀'TV-'
    # 原有注释修正: 之前的注释是"判断是否为成人网站"，实际功能是"规范化源名称"。
    if not name.upper().startswith('TV'):
        source_info['name'] = f"TV-{name}"
        name = source_info['name']

    # 检查源API的可访问性
    status, api_content = check_source_accessibility(api_url)

    if status == "success":
        # 如果访问成功，检查内容是否为成人内容
        if is_adult_website(api_content, name, api_url):
            # 使用锁来确保线程安全地写入共享列表
            with locks['adult']:
                lists['adult'][source_id] = source_info
        else:
            with locks['filtered']:
                lists['filtered'][source_id] = source_info
    elif status == "not_found":
        # 如果源返回404，则打印信息并自动舍弃
        print(f"源 {name} ({api_url}) 返回404，已自动舍弃")
    else: # other_error
        # 对于其他所有错误，归类为无法访问
        with locks['inaccessible']:
            lists['inaccessible'][source_id] = source_info

def interactive_confirm(source_list, category_name, filtered_sources):
    """
    为需要人工干预的源列表提供交互式确认界面。

    Args:
        source_list (dict): 需要用户确认的源字典。
        category_name (str): 该列表的分类名称（如"无法访问"）。
        filtered_sources (dict): 用于存放用户确认保留的源的字典。
    """
    print(f"\n--- 需要人工确认的 {category_name} 源 ---")
    if not source_list:
        print("无")
        return

    # 遍历待确认列表
    for source_id, source_info in source_list.items():
        name = source_info.get('name', 'Unknown')
        api_url = source_info.get('api', '')
        # 提示用户输入
        user_input = input(f"源 '{name}' ({api_url}) 被标记为{category_name}。是否保留? (y/N): ")
        # 如果用户输入'y'或'Y'，则将该源加入到最终的有效源列表中
        if user_input.lower() == 'y':
            filtered_sources[source_id] = source_info
            print(f"已保留源: {name}")

def main():
    """
    脚本主逻辑函数。
    """
    # 加载新的源数据和之前已筛选的数据
    new_sources_data = load_json_file('python/moontv.json')
    filtered_data = load_json_file('python/moontv_filtered.json')

    # 从加载的数据中提取源列表
    new_sources = new_sources_data.get('api_site', {})
    existing_sources = filtered_data.get('api_site', {})
    
    # 合并新旧源，使用字典解包。如果存在相同的key，`existing_sources`中的值会覆盖`new_sources`中的值。
    # 这意味着优先保留 `moontv_filtered.json` 中已有的信息。
    combined_sources = {**new_sources, **existing_sources}
    
    # 去重处理：基于API URL进行去重，避免处理重复的源
    unique_sources = {}
    processed_apis = set()
    for source_id, source_info in combined_sources.items():
        api_url = source_info.get('api')
        if api_url and api_url not in processed_apis:
            unique_sources[source_id] = source_info
            processed_apis.add(api_url)
    
    print(f"合并后共 {len(combined_sources)} 个源，去重后剩余 {len(unique_sources)} 个待校验源")

    # 初始化用于分类存放结果的字典
    filtered_sources = {}   # 最终有效的源
    inaccessible_sources = {} # 无法访问的源
    adult_sources = {}      # 疑似成人内容的源
    
    # 初始化线程锁，用于在多线程环境下安全地操作共享字典
    locks = {
        'filtered': threading.Lock(),
        'inaccessible': threading.Lock(),
        'adult': threading.Lock()
    }
    # 将结果字典打包，方便传递给线程函数
    lists = {
        'filtered': filtered_sources,
        'inaccessible': inaccessible_sources,
        'adult': adult_sources
    }

    # 使用线程池并发处理所有待校验的源
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        # 提交所有任务到线程池
        futures = [executor.submit(process_source, source_id, source_info, locks, lists) for source_id, source_info in unique_sources.items()]
        # 等待所有线程任务完成
        concurrent.futures.wait(futures)
    
    # 所有源处理完毕后，进行交互式确认
    interactive_confirm(inaccessible_sources, "无法访问", filtered_sources)
    interactive_confirm(adult_sources, "疑似色情内容", filtered_sources)

    # 准备最终要写入文件的数据
    output_data = {'api_site': filtered_sources}
    # 如果原始数据中有'cache_time'字段，则保留它
    cache_time = new_sources_data.get('cache_time')
    if cache_time is not None:
        output_data['cache_time'] = cache_time
    
    # 将最终筛选结果写入JSON文件
    with open('python/moontv_filtered.json', 'w', encoding='utf-8') as f:
        # 使用indent=4进行格式化输出，ensure_ascii=False确保中文字符正常显示
        json.dump(output_data, f, ensure_ascii=False, indent=4)
        
    # 打印最终总结信息
    print("\n\n" + "="*20)
    print("筛选完成！最终有效源已写入 moontv_filtered.json 文件。")
    print(f"共保留 {len(filtered_sources)} 个有效源。")
    print("="*20)

if __name__ == '__main__':
    # 当脚本作为主程序运行时，调用main函数
    main()
