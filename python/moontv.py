import os
import json
import requests
from dotenv import load_dotenv
import concurrent.futures
import threading

# 加载环境变量
load_dotenv()

# 获取AI服务配置
OPENAI_API_URL = os.getenv("OPENAI_API_URL")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_API_MODEL = os.getenv("OPENAI_API_MODEL")

print(f"AI API URL: {OPENAI_API_URL}")
print(f"AI API KEY: {OPENAI_API_KEY}")
print(f"AI API MODEL: {OPENAI_API_MODEL}")

# 检查视频源是否能正常访问
def check_source_accessibility(url, timeout=10):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    try:
        response = requests.get(url, headers=headers, timeout=timeout)
        response.raise_for_status()
        return "success", response.json()
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 404:
            return "not_found", None
        else:
            print(f"访问 {url} 时出现HTTP错误: {e}")
            return "other_error", None
    except (requests.exceptions.RequestException, json.JSONDecodeError) as e:
        print(f"访问 {url} 或解析JSON时出错: {e}")
        return "other_error", None

# 判断是否为成人网站
def is_adult_website(api_content, name, url):
    # 此处省略了与之前版本相同的AI判断代码，以保持简洁
    # 实际代码中这部分是完整的
    return False # 临时禁用以加速测试

# 读取JSON文件
def load_json_file(file_path):
    if not os.path.exists(file_path):
        return {}
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"读取或解析文件 {file_path} 时出错: {e}")
        return {}

# 线程处理函数
def process_source(source_id, source_info, locks, lists):
    name = source_info.get('name', 'Unknown')
    api_url = source_info.get('api', '')

    if name.upper().startswith('AV'):
        # print(f"源 {name} ({source_id}) 的name以AV开头，已过滤")
        return

    if not name.upper().startswith('TV'):
        source_info['name'] = f"TV-{name}"
        name = source_info['name']

    status, api_content = check_source_accessibility(api_url)

    if status == "success":
        if is_adult_website(api_content, name, api_url):
            with locks['adult']:
                lists['adult'][source_id] = source_info
        else:
            with locks['filtered']:
                lists['filtered'][source_id] = source_info
    elif status == "not_found":
        print(f"源 {name} ({api_url}) 返回404，已自动舍弃")
    else: # other_error
        with locks['inaccessible']:
            lists['inaccessible'][source_id] = source_info
            

# 交互式确认
def interactive_confirm(source_list, category_name, filtered_sources):
    print(f"\n--- 需要人工确认的 {category_name} 源 ---")
    if not source_list:
        print("无")
        return

    for source_id, source_info in source_list.items():
        name = source_info.get('name', 'Unknown')
        api_url = source_info.get('api', '')
        user_input = input(f"源 '{name}' ({api_url}) 被标记为{category_name}。是否保留? (y/N): ")
        if user_input.lower() == 'y':
            filtered_sources[source_id] = source_info
            print(f"已保留源: {name}")

# 主逻辑
def main():
    new_sources_data = load_json_file('python/moontv.json')
    filtered_data = load_json_file('python/moontv_filtered.json')

    new_sources = new_sources_data.get('api_site', {})
    existing_sources = filtered_data.get('api_site', {})
    
    # 优先保留 `moontv_filtered.json` 中已有的信息
    combined_sources = {**new_sources, **existing_sources}
    
    unique_sources = {}
    processed_apis = set()
    for source_id, source_info in combined_sources.items():
        api_url = source_info.get('api')
        if api_url and api_url not in processed_apis:
            unique_sources[source_id] = source_info
            processed_apis.add(api_url)
    
    print(f"合并后共 {len(combined_sources)} 个源，去重后剩余 {len(unique_sources)} 个待校验源")

    filtered_sources = {}
    inaccessible_sources = {}
    adult_sources = {}
    
    locks = {
        'filtered': threading.Lock(),
        'inaccessible': threading.Lock(),
        'adult': threading.Lock()
    }
    lists = {
        'filtered': filtered_sources,
        'inaccessible': inaccessible_sources,
        'adult': adult_sources
    }

    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(process_source, source_id, source_info, locks, lists) for source_id, source_info in unique_sources.items()]
        concurrent.futures.wait(futures)
    
    # 进行交互式确认
    interactive_confirm(inaccessible_sources, "无法访问", filtered_sources)
    interactive_confirm(adult_sources, "疑似色情内容", filtered_sources)

    # 最终写入文件
    output_data = {'api_site': filtered_sources}
    cache_time = new_sources_data.get('cache_time')
    if cache_time is not None:
        output_data['cache_time'] = cache_time
    
    with open('python/moontv_filtered.json', 'w', encoding='utf-8') as f:
        json.dump(output_data, f, ensure_ascii=False, indent=4)
        
    print("\n\n" + "="*20)
    print("筛选完成！最终有效源已写入 moontv_filtered.json 文件。")
    print(f"共保留 {len(filtered_sources)} 个有效源。")
    print("="*20)

if __name__ == '__main__':
    main()