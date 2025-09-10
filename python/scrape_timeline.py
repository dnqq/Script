import requests
import json
import time
import os
from urllib.parse import unquote, urlparse, urlunparse
import hashlib
import re # 导入正则表达式模块
from Crypto.Cipher import AES

# =================================================================================
#  辅助函数：文件名清理
# =================================================================================

def sanitize_filename(name: str) -> str:
    """
    移除文件名或文件夹名中的非法字符，确保路径有效。
    """
    if not name:
        return ""
    # 移除Windows和Linux下常见的非法字符: < > : " / \ | ? *
    # 同时也将'©'替换为空
    return re.sub(r'[\\/*?:"<>|©]', "", name).strip()

# =================================================================================
#  整合的解密模块
# =================================================================================

def encrypt_md5(text: str) -> str:
    """计算字符串的MD5哈希值，与JS中的CryptoJS.MD5(t).toString()行为一致"""
    return hashlib.md5(text.encode('utf-8')).hexdigest()

def decrypt_aes(ciphertext_hex: str, key: str) -> str:
    """复现JavaScript中的AES解密逻辑"""
    try:
        aes_key_str = (key * 16)[-16:]
        aes_key = aes_key_str.encode('utf-8')
        iv_str = encrypt_md5(aes_key_str)[8:24]
        iv = iv_str.encode('utf-8')
        ciphertext_bytes = bytes.fromhex(ciphertext_hex)
        cipher = AES.new(aes_key, AES.MODE_CBC, iv)
        decrypted_padded = cipher.decrypt(ciphertext_bytes)
        unpadded = decrypted_padded.rstrip(b'\x00')
        return unpadded.decode('utf-8')
    except (ValueError, UnicodeDecodeError) as e:
        print(f"  [解密错误] Key: '{key}', Ciphertext: '{ciphertext_hex[:10]}...'. Error: {e}")
        return ciphertext_hex

def decrypt_url(url: str, key: str) -> str:
    """复现JavaScript中的decryptUrl函数，解密URL中的文件名部分"""
    if not url or not key:
        return url
    try:
        parsed_url = urlparse(url)
        path, filename = os.path.split(parsed_url.path)
        basename, extension = os.path.splitext(filename)
        if len(basename) >= 32:
            ciphertext = basename[:32]
            rest_of_basename = basename[32:]
            decrypted_part = decrypt_aes(ciphertext, key)
            new_basename = decrypted_part + rest_of_basename
            new_filename = new_basename + extension
            new_path = os.path.join(path, new_filename).replace('\\', '/')
            return urlunparse(parsed_url._replace(path=new_path))
        else:
            return url
    except Exception as e:
        print(f"  [URL解析错误] URL: '{url}'. Error: {e}")
        return url

# =================================================================================
#  您的主代码
# =================================================================================

def scrape_topic_ordered_by_date(base_url, topic, headers, debug_mode=False, max_debug_pages=10):
    all_unique_items = []
    seen_ids = set()
    current_id = ""
    current_no = "99999999"
    page_num = 0
    try:
        display_topic = unquote(topic)
    except:
        display_topic = topic
    while True:
        page_num += 1
        params = {"topic": topic, "date": "30000101", "order": "date", "no": current_no, "id": current_id}
        print(f"--- 正在抓取主题 '{display_topic}' 的第 {page_num} 页 ---")
        try:
            response = requests.get(base_url, headers=headers, params=params, timeout=15)
            response.raise_for_status()
            response_json = response.json()
            if response_json.get("status") == 1 and response_json.get("data"):
                items_on_page = response_json["data"]
                if not items_on_page:
                    print(f"主题 '{display_topic}' 第 {page_num} 页: API返回数据为空。")
                    break
                new_items_this_page = []
                min_no_on_current_page = float('inf')
                for item in items_on_page:
                    item_id = item["id"]
                    if item_id not in seen_ids:
                        all_unique_items.append(item)
                        seen_ids.add(item_id)
                        new_items_this_page.append(item)
                    try:
                        min_no_on_current_page = min(min_no_on_current_page, int(item.get('no', float('inf'))))
                    except (ValueError, TypeError):
                        pass
                new_count_this_page = len(new_items_this_page)
                total_unique_items_count = len(all_unique_items)
                print(f"主题 '{display_topic}' 第 {page_num} 页: 获取 {len(items_on_page)} 条，新增 {new_count_this_page} 条，总计 {total_unique_items_count} 条。")
                if new_count_this_page == 0:
                    print(f"主题 '{display_topic}' 第 {page_num} 页: 未发现新项目，爬取完成。")
                    break
                current_id = items_on_page[-1]["id"]
                if min_no_on_current_page != float('inf'):
                    current_no = str(min_no_on_current_page)
            else:
                print(f"主题 '{display_topic}' 第 {page_num} 页: 响应异常或无数据。状态: {response_json.get('status')}, 消息: {response_json.get('msg')}")
                break
        except requests.exceptions.RequestException as e:
            print(f"主题 '{display_topic}' 第 {page_num} 页: 请求失败 - {e}")
            break
        time.sleep(0.5)
    print(f"--- 主题 '{display_topic}' 爬取结束，共 {len(all_unique_items)} 条数据 ---")
    return all_unique_items

def main():
    headers = {
        "Host": "api.nguaduot.cn",
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:142.0) Gecko/20100101 Firefox/142.0",
        "Accept": "*/*",
        "Accept-Language": "zh-CN,zh;q=0.8,zh-TW;q=0.7,zh-HK;q=0.5,en-US;q=0.3,en;q=0.2",
        "Accept-Encoding": "gzip, deflate, br, zstd",
        "Timeline-User": "",
        "Timeline-Pwd": "",
        "Timeline-Device": "275a7402402c1105684d069b1af24c34",
        "Timeline-Client": "timelineweb",
        "Origin": "https://qingbz.timeline.ink",
        "Connection": "keep-alive",
        "Referer": "https://qingbz.timeline.ink/",
        "Sec-Fetch-Dest": "empty",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Site": "cross-site",
        "Priority": "u=4"
    }
    base_api_url = "https://api.nguaduot.cn/snake/v4"
    topics_to_scrape = ["AI"]
    for topic in topics_to_scrape:
        display_topic = unquote(topic)
        print(f"\n{'='*50}")
        print(f"开始处理主题: {display_topic}")
        print(f"{'='*50}")
        topic_data = scrape_topic_ordered_by_date(base_api_url, topic, headers, debug_mode=False)
        safe_topic_name = display_topic.replace(' ', '_').replace('/', '_')
        filename = f"snake_v4_topic_{safe_topic_name}_{len(topic_data)}_items.json"
        with open(filename, "w", encoding="utf-8") as f:
            json.dump(topic_data, f, ensure_ascii=False, indent=4)
        print(f"主题 '{display_topic}' 的数据已保存到: {filename}")
        print(f"\n开始下载主题 '{display_topic}' 的图片...")
        download_images_from_json(filename)
        time.sleep(2)
    print(f"\n{'='*50}")
    print("所有主题爬取完成！")
    print(f"{'='*50}")

def download_images_from_json(json_file_path, base_download_dir="D:/ashin/Pictures/timeline_ink"):
    """
    根据新的路径规则下载图片，并处理回退逻辑。
    """
    try:
        with open(json_file_path, 'r', encoding='utf-8') as file:
            data = json.load(file)

        print(f"开始处理文件: {json_file_path}")
        print(f"图片总数: {len(data)}")
        
        success_count = 0
        failed_count = 0
        skipped_count = 0
        
        for i, item in enumerate(data):
            try:
                # 1. 获取 copyright，如果为空则回退为 "未知"
                copyright_folder = item.get('copyright') or "未知"

                # 2. 获取分类，如果 catewhatname 为空，则用 catehowname，如果都为空，则用 "未分类"
                category_folder = item.get('catewhatname') or item.get('catehowname') or "未分类"

                # 3. 清理文件夹名称中的非法字符
                safe_copyright_folder = sanitize_filename(copyright_folder)
                safe_category_folder = sanitize_filename(category_folder)

                # 4. 构建最终的下载目录
                download_dir = os.path.join(base_download_dir, safe_copyright_folder, safe_category_folder)
                os.makedirs(download_dir, exist_ok=True)
                
                # 5. 构建完整的文件路径
                file_extension = item.get('ext', '.jpg')
                file_name = f"{item['id']}{file_extension}"
                file_path = os.path.join(download_dir, file_name)
                
                # 检查文件是否已存在
                if os.path.exists(file_path):
                    print(f"  ({i+1}/{len(data)}) 文件已存在，跳过: {file_path}")
                    skipped_count += 1
                    continue
                
                encrypted_url = item.get('imgurl')
                raw_provider = item.get('rawprovider')
                
                if not encrypted_url or not raw_provider:
                    print(f"  ({i+1}/{len(data)}) 缺少 imgurl 或 rawprovider，跳过")
                    failed_count += 1
                    continue
                
                print(f"  ({i+1}/{len(data)}) 正在解密 ID: {item.get('id')}")
                decrypted_url = decrypt_url(encrypted_url, raw_provider)
                
                if download_image(decrypted_url, file_path):
                    print(f"  下载成功: {file_path}")
                    success_count += 1
                else:
                    print(f"  下载失败: {file_name}")
                    failed_count += 1
                
                time.sleep(0.5)
                
            except Exception as e:
                print(f"处理第{i+1}项时出错: {str(e)}")
                failed_count += 1
        
        print(f"\n下载完成统计:")
        print(f"成功: {success_count}")
        print(f"失败: {failed_count}")
        print(f"跳过 (已存在): {skipped_count}")
        
    except FileNotFoundError:
        print(f"错误: 找不到文件 {json_file_path}")
    except json.JSONDecodeError:
        print(f"错误: 无法解析JSON文件 {json_file_path}")
    except Exception as e:
        print(f"发生错误: {str(e)}")

def download_image(img_url, file_path):
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            "Accept": "image/webp,image/apng,image/*,*/*;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8"
        }
        response = requests.get(img_url, headers=headers, allow_redirects=True, timeout=30, stream=True)
        if response.status_code == 200:
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return True
        else:
            print(f"  HTTP错误 {response.status_code}: {img_url}")
            return False
    except requests.exceptions.RequestException as e:
        print(f"  网络请求错误 {img_url}: {str(e)}")
        return False
    except Exception as e:
        print(f"  下载图片失败 {img_url}: {str(e)}")
        return False

if __name__ == "__main__":
    main()