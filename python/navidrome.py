# -*- coding: utf-8 -*-
import os
import requests
import hashlib
import random
import string
import json
import sys
import argparse
import time
import concurrent.futures
import threading

from dotenv import load_dotenv

# 在脚本早期加载 .env 文件
# 这会加载项目根目录下的 .env 文件中的变量
load_dotenv()

# --- 配置 ---
# 强烈建议使用环境变量来配置，以避免将敏感信息硬编码到代码中。
NAVIDROME_URL = os.environ.get("NAVIDROME_URL")
NAVIDROME_USER = os.environ.get("NAVIDROME_USER")
NAVIDROME_PASSWORD = os.environ.get("NAVIDROME_PASSWORD")

# --- AI 配置 ---
OPENAI_API_URL = os.environ.get("OPENAI_API_URL")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
OPENAI_API_MODEL = os.environ.get("OPENAI_API_MODEL", "Google Gemini/gemini-2.5-pro") # 使用的模型
MAX_WORKERS = 5 # 并发请求AI的线程数
SONG_RATING_WORKERS = 10 # 并发写回歌曲评分的线程数

# API 版本和客户端名称，通常不需要修改
API_VERSION = "1.16.1"
CLIENT_NAME = "Roo-Navidrome-Script"


RATING_LOG_FILE = "navidrome_ratings.log"
SONG_CACHE_FILE = "navidrome_songs.json" # 歌曲库缓存文件
ALBUM_CACHE_FILE = "navidrome_albums.json" # 专辑库缓存文件

def log_rating(song_title, album_name, artist, rating, reason):
    """将评分记录写入日志文件，只记录评分信息。"""
    try:
        # 清理理由中的换行符，以保证日志格式整洁
        clean_reason = " ".join(reason.split())
        with open(RATING_LOG_FILE, "a", encoding="utf-8") as f:
            log_entry = f"【{song_title}-{album_name}-{artist}-{rating}-{clean_reason}】"
            f.write(log_entry + "\n")
    except IOError as e:
        print(f"写入评分日志时出错: {e}")


class NavidromeClient:
    """
    一个用于与 Navidrome (Subsonic API) 服务器交互的客户端。
    """

    def __init__(self, base_url, username, password, api_version=API_VERSION, client_name=CLIENT_NAME):
        self.base_url = base_url.rstrip('/')
        self.api_endpoint = f"{self.base_url}/rest"
        self.username = username
        self.password = password
        self.api_version = api_version
        self.client_name = client_name
        self.session = requests.Session()

    @staticmethod
    def _generate_salt(length=10):
        letters_and_digits = string.ascii_letters + string.digits
        return ''.join(random.choice(letters_and_digits) for _ in range(length))

    def _generate_token(self, salt):
        salted_password = (self.password + salt).encode('utf-8')
        return hashlib.md5(salted_password).hexdigest()

    def _make_request(self, endpoint, params=None):
        if params is None:
            params = {}

        salt = self._generate_salt()
        token = self._generate_token(salt)

        base_params = {
            'u': self.username,
            't': token,
            's': salt,
            'v': self.api_version,
            'c': self.client_name,
            'f': 'json'
        }
        
        all_params = {**base_params, **params}

        try:
            response = self.session.get(f"{self.api_endpoint}/{endpoint}", params=all_params)
            response.raise_for_status()
            
            try:
                data = response.json()
            except json.JSONDecodeError:
                # 对于非JSON响应（理论上不应发生在我们调用的端点上）
                return response.text

            api_response = data.get('subsonic-response', {})
            if api_response.get('status') == 'failed':
                error = api_response.get('error', {})
                raise ConnectionError(f"API Error: {error.get('message')} (Code: {error.get('code')})")
            
            return api_response

        except requests.exceptions.RequestException as e:
            print(f"HTTP 请求失败: {e}")
            raise
        except json.JSONDecodeError:
            print("无法解析服务器响应为 JSON。")
            print(f"响应内容: {response.text}")
            raise

    def ping(self):
        print("正在 Ping 服务器...")
        try:
            response = self._make_request("ping")
            if response.get('status') == 'ok':
                print("服务器连接成功！")
                return True
            else:
                print("服务器连接失败。")
                return False
        except ConnectionError as e:
            print(e)
            return False

    def get_statistics(self):
        """
        获取媒体库统计信息。
        注意: Navidrome 的某些版本似乎不包含 'getStatistics' 端点，会导致 404 错误。
        此方法通过手动统计歌曲、专辑和艺术家来解决此问题，这在首次运行时可能较慢，
        但会利用现有的缓存机制。
        """
        print("正在获取媒体库统计信息 (通过计算条目)...")
        try:
            # 使用现有的带缓存功能来获取所有歌曲。
            # 这在首次运行时会比较慢，因为它需要获取所有专辑和歌曲。
            all_songs = self.get_all_songs(use_cache=True)
            if all_songs is None:
                print("无法获取歌曲列表，无法计算统计数据。")
                return None

            # get_all_songs 内部会获取并缓存专辑列表，所以这里再次调用应该会命中缓存。
            all_albums = self.get_album_list(list_type='alphabeticalByName', use_cache=True)
            if all_albums is None:
                print("无法获取专辑列表，无法计算统计数据。")
                return None

            # 从歌曲列表中计算唯一的艺术家数量
            artist_count = len(set(song.get('artist') for song in all_songs if song.get('artist')))

            stats = {
                'songCount': len(all_songs),
                'albumCount': len(all_albums),
                'artistCount': artist_count
            }
            print("统计信息计算完成。")
            return stats
        except Exception as e:
            print(f"计算统计信息时发生意外错误: {e}")
            return None

    def set_rating(self, item_id, rating):
        try:
            rating = max(1, min(int(rating), 5))
            print(f"  -> 正在为 ID {item_id} 设置评分为 {rating} 星...")
            response = self._make_request("setRating", params={'id': item_id, 'rating': rating})
            if response.get('status') == 'ok':
                print(f"  -> 成功为 ID {item_id} 设置评分。")
                return True
            else:
                print(f"  -> 未能为 ID {item_id} 设置评分。")
                return False
        except (ConnectionError, ValueError) as e:
            print(f"  -> 为 ID {item_id} 设置评分时出错: {e}")
            return False

    def get_album_list(self, list_type="random", silent=False, use_cache=True):
        """获取专辑列表，并支持缓存。仅对'alphabeticalByName'类型启用缓存。"""
        # 只有当获取所有专辑时才使用缓存
        is_cacheable = list_type == 'alphabeticalByName'

        if use_cache and is_cacheable and os.path.exists(ALBUM_CACHE_FILE):
            if not silent:
                print(f"发现专辑缓存文件，正在从 '{ALBUM_CACHE_FILE}' 读取...")
            try:
                with open(ALBUM_CACHE_FILE, 'r', encoding='utf-8') as f:
                    all_albums = json.load(f)
                if not silent:
                    print(f"成功从缓存加载 {len(all_albums)} 张专辑。")
                return all_albums
            except (IOError, json.JSONDecodeError) as e:
                if not silent:
                    print(f"读取专辑缓存文件时出错: {e}。将从网络获取。")

        all_albums = []
        offset = 0
        size = 500
        if not silent:
            print(f"开始获取类型为 '{list_type}' 的完整专辑列表...")
        while True:
            if not silent:
                print(f"正在获取专辑，偏移量: {offset}, 数量: {size}...")
            try:
                params = {'type': list_type, 'size': size, 'offset': offset}
                response = self._make_request("getAlbumList", params=params)
                album_list_data = response.get('albumList', {})
                albums = album_list_data.get('album', [])
                if not albums:
                    if not silent:
                        print("已获取所有专辑。")
                    break
                all_albums.extend(albums)
                offset += len(albums)
                if len(albums) < size:
                    break
            except ConnectionError as e:
                if not silent:
                    print(f"获取专辑列表时出错: {e}")
                return None
        if not silent:
            print(f"总共成功获取到 {len(all_albums)} 张专辑。")

        # 只有当获取所有专辑时才写入缓存
        if is_cacheable:
            try:
                if not silent:
                    print(f"正在将 {len(all_albums)} 张专辑写入缓存文件 '{ALBUM_CACHE_FILE}'...")
                with open(ALBUM_CACHE_FILE, "w", encoding="utf-8") as f:
                    json.dump(all_albums, f, ensure_ascii=False)
                if not silent:
                    print("专辑缓存写入成功。")
            except IOError as e:
                if not silent:
                    print(f"写入专辑缓存文件时出错: {e}")

        return all_albums

    def get_album_songs(self, album_id, silent=False):
        if not silent:
            print(f"正在获取专辑 ID 为 '{album_id}' 的歌曲...")
        try:
            response = self._make_request("getAlbum", params={'id': album_id})
            album_data = response.get('album', {})
            songs = album_data.get('song', [])
            if not silent:
                print(f"成功获取到 {len(songs)} 首歌曲。")
            return songs
        except ConnectionError as e:
            if not silent:
                print(f"获取专辑歌曲时出错: {e}")
            return None

    def get_all_songs(self, use_cache=True):
        """获取库中所有歌曲的列表，并支持缓存。"""
        if use_cache and os.path.exists(SONG_CACHE_FILE):
            print(f"发现歌曲缓存文件，正在从 '{SONG_CACHE_FILE}' 读取...")
            try:
                with open(SONG_CACHE_FILE, 'r', encoding='utf-8') as f:
                    all_songs = json.load(f)
                print(f"成功从缓存加载 {len(all_songs)} 首歌曲。")
                return all_songs
            except (IOError, json.JSONDecodeError) as e:
                print(f"读取缓存文件时出错: {e}。将从网络获取。")

        print("未找到或无法使用缓存，开始从服务器获取所有歌曲...")
        print("步骤 1/2: 获取所有专辑...")
        all_albums = self.get_album_list(list_type='alphabeticalByName', silent=True, use_cache=use_cache)
        if not all_albums:
            print("未能获取到专辑列表。")
            return []

        all_songs = []
        total_albums = len(all_albums)
        print(f"获取到 {total_albums} 张专辑，现在开始获取每张专辑的歌曲...")
        print("步骤 2/2: 遍历专辑获取歌曲...")

        for i, album in enumerate(all_albums):
            album_id = album.get('id')
            album_name = album.get('name', '未知专辑')
            
            print(f"\r正在处理: ({i+1}/{total_albums}) {album_name.ljust(50)}", end="", flush=True)
            
            if album_id:
                songs = self.get_album_songs(album_id, silent=True)
                if songs:
                    for song in songs:
                        song['albumName'] = album_name
                    all_songs.extend(songs)
        
        print(f"\n总共成功获取到 {len(all_songs)} 首歌曲。")

        # 将获取到的歌曲写入缓存文件
        try:
            print(f"正在将 {len(all_songs)} 首歌曲写入缓存文件 '{SONG_CACHE_FILE}'...")
            with open(SONG_CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump(all_songs, f, ensure_ascii=False)
            print("缓存写入成功。")
        except IOError as e:
            print(f"写入歌曲缓存文件时出错: {e}")

        return all_songs

    def get_playlists(self):
        """获取所有播放列表。"""
        print("正在获取所有播放列表...")
        try:
            response = self._make_request("getPlaylists")
            playlists_data = response.get('playlists', {})
            playlists = playlists_data.get('playlist', [])
            print(f"成功获取到 {len(playlists)} 个播放列表。")
            return playlists
        except ConnectionError as e:
            print(f"获取播放列表时出错: {e}")
            return None

    def get_playlist(self, playlist_id):
        """获取指定播放列表的详细信息和歌曲。"""
        print(f"正在获取播放列表 ID '{playlist_id}' 的详细信息...")
        try:
            response = self._make_request("getPlaylist", params={'id': playlist_id})
            playlist_data = response.get('playlist', {})
            songs = playlist_data.get('entry', [])
            # 为了与其他歌曲列表格式保持一致，重命名字段
            for song in songs:
                song['userRating'] = song.pop('rating', None)
            print(f"成功获取到 {len(songs)} 首歌曲。")
            return playlist_data
        except ConnectionError as e:
            print(f"获取播放列表歌曲时出错: {e}")
            return None

    def update_playlist(self, playlist_id, song_ids_to_add=None, song_indexes_to_remove=None):
        """更新播放列表，可以添加歌曲或移除歌曲。"""
        if song_ids_to_add is None and song_indexes_to_remove is None:
            print("没有要执行的操作。")
            return False
        
        params = {'playlistId': playlist_id}
        action_log = []
        if song_ids_to_add:
            params['songIdToAdd'] = song_ids_to_add
            action_log.append(f"添加 {len(song_ids_to_add)} 首歌曲")
        if song_indexes_to_remove:
            params['songIndexToRemove'] = song_indexes_to_remove
            action_log.append(f"移除 {len(song_indexes_to_remove)} 首歌曲")

        print(f"正在更新播放列表 ID '{playlist_id}': {', '.join(action_log)}...")
        try:
            # updatePlaylist 端点不返回任何内容，成功时状态码为 200
            response = self._make_request("updatePlaylist", params=params)
            # 检查 'subsonic-response' 的状态
            if response.get('status') == 'ok':
                print("播放列表更新成功。")
                return True
            else:
                # 即使 HTTP 状态码是 200，也可能在响应体中报告失败
                print(f"更新播放列表失败: {response}")
                return False
        except ConnectionError as e:
            print(f"更新播放列表时出错: {e}")
            return False

def show_statistics(client):
    stats = client.get_statistics()
    if stats:
        print("\n--- 音乐库统计信息 ---")
        print(f"  🎵 歌曲数量: {stats.get('songCount', 'N/A')}")
        print(f"  💿 专辑数量: {stats.get('albumCount', 'N/A')}")
        print(f"  🎤 艺术家数量: {stats.get('artistCount', 'N/A')}")
        print("------------------------\n")
    else:
        print("未能获取统计信息。")

def show_rating_statistics(client, use_cache=True):
    """功能3：统计并显示歌曲的星级分布。"""
    print("\n--- 开始统计歌曲星级 ---")
    all_songs = client.get_all_songs(use_cache=use_cache)
    if not all_songs:
        print("未能获取到任何歌曲，无法统计。")
        return

    ratings_count = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
    rated_songs_count = 0
    for song in all_songs:
        rating = song.get('userRating')
        if rating and 1 <= int(rating) <= 5:
            ratings_count[int(rating)] += 1
            rated_songs_count += 1
    
    print("\n--- 歌曲星级统计结果 ---")
    print(f"总共扫描歌曲数: {len(all_songs)}")
    print(f"已评分歌曲数: {rated_songs_count}")
    for star, count in ratings_count.items():
        print(f"{star} 星: {count} 首")
    print("------------------------\n")

def show_all_song_ratings(client, use_cache=True):
    """功能4：将所有已评分歌曲的列表保存到文件中。"""
    print("\n--- 开始获取所有已评分歌曲 ---")
    all_songs = client.get_all_songs(use_cache=use_cache)
    if not all_songs:
        print("未能获取到任何歌曲。")
        return
        
    rated_songs = [s for s in all_songs if s.get('userRating')]
    
    if not rated_songs:
        print("音乐库中没有已评分的歌曲。")
        return

    output_filename = "all_song_ratings.txt"
    try:
        with open(output_filename, "w", encoding="utf-8") as f:
            f.write("--- 全部已评分歌曲列表 ---\n")
            # 按星级降序排序
            for song in sorted(rated_songs, key=lambda x: int(x.get('userRating')), reverse=True):
                line = f"【{song.get('title', 'N/A')}-{song.get('albumName', 'N/A')}-{song.get('artist', 'N/A')}-{song.get('userRating')}】\n"
                f.write(line)
        print(f"\n成功将 {len(rated_songs)} 首已评分歌曲的信息保存到文件: {output_filename}")
    except IOError as e:
        print(f"\n写入文件时出错: {e}")
    print("--------------------------\n")

def _call_ai_for_batch(batch_id, album_batch_data):
    """
    将单个批次的数据发送给AI。这是一个阻塞函数，设计为在单独的线程中运行。
    它返回AI的原始响应内容和用于生成该请求的原始数据。
    """
    if not album_batch_data:
        return None, None

    prompt_data = []
    for album_info in album_batch_data:
        prompt_data.append({
            "album_id": album_info["album_id"],
            "album_name": album_info["album_name"],
            "artist": album_info["artist"],
            "rate_album": album_info["rate_album"],
            "songs": album_info["songs_to_rate"]
        })

    prompt = f"""
你是一位专业的音乐评论家。请根据以下指示和评分标准，为这个批次中的每一张专辑以及专辑中的每一首歌曲进行评分。

### 评论家心态与核心哲学 (重要！)
在开始评分前，你必须代入一位极其挑剔和审慎的行业标杆的角色。你的目标不是发现优点，而是衡量作品是否能经受住时间的考验。
- **4星 (★★★★) 代表“卓越”**: 这是对绝大多数制作精良、情感动人、艺术上成功的作品的最高肯定。获得4星意味着这件作品已经非常出色。
- **5星 (★★★★★) 代表“里程碑”**: 这个评价必须极为吝啬地给出。它不仅要求作品在技术上无懈可击，更要求其在概念上具有革命性、能够定义一个时代或流派、或是在情感上达到了人类体验的极致。它必须是那种十年后依然会被反复讨论的杰作。
- **核心准则**: 在评分时，请不断自问：“这首歌/专辑真的达到了里程碑级别吗？”如果答案不是斩钉截铁的“是”，那么它就不应该获得5星。在撰写理由时，请避免空泛的赞美，要能精准地指出作品的卓越之处以及存在的些许遗憾。

### 评分标准与权重 (已调整)
为了公正地评价所有类型的音乐，你的评分标准需要根据歌曲是否为纯音乐进行调整。请注意，“开创性”的权重已被提升，以更好地筛选出真正具有突破性的作品。

1.  **对于带歌词的歌曲，请使用以下标准：**
    *   音乐性 (Music): 包括旋律、编曲、制作、节奏、和声等。**权重 1.5**。
    *   歌词艺术 (Lyrics): 包括歌词的深度、创意、叙事性、诗意等。权重 1.5。
    *   情感内核 (Emotion): 歌曲或专辑传达的情感浓度和感染力。权重 1.0。
    *   开创性/影响力 (Innovation/Influence): 作品在音乐风格上的创新或其潜在影响力。**权重 1.0**。

2.  **对于纯音乐（Instrumental），请使用以下调整后的标准：**
    *   音乐性 (Music): **权重 1.5** (标准同上)。
    *   概念与结构艺术 (Conceptual & Structural Artistry): 权重 1.5。此项评估乐曲在没有歌词引导下的叙事能力、主题发展、结构设计以及氛围塑造的艺术性。
    *   情感内核 (Emotion): 权重 1.0 (标准同上)。
    *   开创性/影响力 (Innovation/Influence): **权重 1.0** (标准同上)。

### 评分转换规则
请将你的评分结果转换为 1-5 的整数星级。请严格遵守以下转换门槛与描述：
- **5星 (里程碑): 4.6 - 5.0**
- **4星 (卓越): 3.8 - 4.5**
- **3星 (佳作): 2.8 - 3.7**
- **2星 (尚可): 1.8 - 2.7**
- **1星 (有待提高): 0 - 1.7**

### 任务要求
- **专辑评分**: 请根据专辑的整体概念、艺术价值和历史影响力进行独立评价，给出评分和评分理由。此评分不应是歌曲评分的简单平均。如果专辑信息中的 `rate_album` 为 false，请在返回的 JSON 中将 `album_rating` 和 `album_rating_reason` 设为 null。
- **歌曲评分**: 请根据下面提供的每首歌曲的标题和艺术家，结合你的知识库进行评价，给出评分和评分理由。如果歌曲列表为空，则只对专辑评分。
- **输出格式**: 你的回答必须是且仅是一个格式正确的 JSON 数组，不包含任何其他文字、解释或代码块标记。

### 待评分的专辑和歌曲列表:
{json.dumps(prompt_data, ensure_ascii=False, indent=2)}

### ！！！重要：格式要求与常见错误修正
你的回答**必须**是一个完美、无误、严格遵守RFC 8259标准的JSON数组。任何微小的格式错误都将导致整个流程失败。

**常见致命错误示例：**
- **错误**: `{{ "f8682052d9002dbf51c84422a68ba765", "rating": 5, ...}}` (缺少 "id" 键名)
- **正确**: `{{ "id": "f8682052d9002dbf51c84422a68ba765", "rating": 5, ...}}`

请在生成最终结果前，仔细检查每一个对象是否都包含了正确的键名（如 "id", "rating", "reason"）。

### 你的回答 JSON 结构必须如下:
[
  {{
    "album_id": "<与输入匹配的专辑ID>",
    "album_rating": <1-5的整数星级 或 null>,
    "album_rating_reason": "<对专辑评分的详细理由 或 null>",
    "song_ratings": [
      {{ "id": "<与输入匹配的歌曲ID>", "rating": <1-5的整数星级>, "reason": "<对这首歌评分的理由>" }},
      ...
    ]
  }},
  ...
]
"""
    max_retries = 3
    retry_delay = 5
    for attempt in range(max_retries):
        try:
            print(f"  - [批次 {batch_id}] 正在请求 AI 对 {len(prompt_data)} 张专辑进行评分... (尝试 {attempt + 1}/{max_retries})")
            ai_response = requests.post(
                OPENAI_API_URL,
                headers={
                    "Authorization": f"Bearer {OPENAI_API_KEY}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": OPENAI_API_MODEL,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.2
                },
                timeout=600
            )
            ai_response.raise_for_status()
            ai_data = ai_response.json()
            content_str = ai_data['choices'][0]['message']['content'].strip()
            
            # 清理AI返回内容中可能存在的Markdown代码块
            if content_str.startswith("```json"):
                content_str = content_str[7:-3].strip()
            elif content_str.startswith("```"):
                content_str = content_str[3:-3].strip()

            ai_content = json.loads(content_str)
            return ai_content, prompt_data
        except requests.exceptions.RequestException as e:
            print(f"  - [批次 {batch_id}] 调用 AI API 时出错: {e}")
            if attempt < max_retries - 1:
                print(f"  - [批次 {batch_id}] 将在 {retry_delay} 秒后重试...")
                time.sleep(retry_delay)
                retry_delay *= 2
            else:
                print(f"  - [批次 {batch_id}] 已达到最大重试次数，放弃处理此批次。")
                return None, prompt_data
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            print(f"  - [批次 {batch_id}] 解析或处理 AI 响应时出错: {e}")
            print(f"  - [批次 {batch_id}] 原始响应: {ai_response.text if 'ai_response' in locals() else 'N/A'}")
            print(f"  - [批次 {batch_id}] 放弃处理此批次。")
            return None, prompt_data
    return None, prompt_data

def _process_ai_results(client, batch_id, ai_content, prompt_data, all_songs_in_batch_map):
    """处理AI返回的单个批次的结果，并将评分写回Navidrome。"""
    print(f"  - [批次 {batch_id}] 开始处理AI返回的评分结果...")
    
    # 使用线程池并发写回评分
    with concurrent.futures.ThreadPoolExecutor(max_workers=SONG_RATING_WORKERS, thread_name_prefix=f'RatingWriter_B{batch_id}') as executor:
        for album_result in ai_content:
            album_id = album_result.get('album_id')
            album_rating = album_result.get('album_rating')
            
            original_album_name = "未知专辑"
            for album_info in prompt_data:
                if album_info['album_id'] == album_id:
                    original_album_name = album_info['album_name']
                    break

            if album_rating is not None:
                album_rating_reason = album_result.get('album_rating_reason', 'AI 未提供理由。')
                print(f"  - [批次 {batch_id}] AI 对专辑 '{original_album_name}' 的评分理由: {album_rating_reason}")
                executor.submit(client.set_rating, album_id, album_rating)

            song_ratings = album_result.get('song_ratings', [])
            if song_ratings:
                print(f"  - [批次 {batch_id}] AI 已返回专辑 '{original_album_name}' 的 {len(song_ratings)} 首歌曲的评分。正在并发写回服务器...")
                for rating_info in song_ratings:
                    song_id_to_rate = rating_info.get('id')
                    song_rating = rating_info.get('rating')
                    song_rating_reason = rating_info.get('reason', 'AI 未提供理由。')
                    
                    song_title = "未知标题"
                    song_artist = "未知艺术家"
                    if song_id_to_rate in all_songs_in_batch_map:
                        song_details = all_songs_in_batch_map[song_id_to_rate]
                        song_title = song_details.get('title', '未知标题')
                        song_artist = song_details.get('artist', '未知艺术家')
                    
                    print(f"  - [批次 {batch_id}] 歌曲 '{song_title}' 的评分理由: {song_rating_reason}")
                    if song_id_to_rate and song_rating is not None:
                        # 记录评分到日志文件
                        log_rating(song_title, original_album_name, song_artist, song_rating, song_rating_reason)
                        executor.submit(client.set_rating, song_id_to_rate, song_rating)
    print(f"  - [批次 {batch_id}] 所有评分已提交写回。")


def rate_albums_with_ai(client, debug=False, overwrite=False, use_cache=True):
    """功能2：使用 AI 并发为专辑和其中的歌曲评分，并写回 Navidrome。"""
    if not OPENAI_API_URL or not OPENAI_API_KEY:
        print("\n错误：请先配置 OPENAI_API_URL 和 OPENAI_API_KEY 环境变量或在脚本中直接修改。")
        return

    print(f"\n--- 开始使用 AI 为歌曲评分 (并发数: {MAX_WORKERS}) ---")

    # 步骤 1: 统一获取所有歌曲
    print("正在获取所有歌曲信息（如果存在缓存则从缓存加载）...")
    all_songs = client.get_all_songs(use_cache=use_cache)
    if not all_songs:
        print("未能获取到任何歌曲，无法继续。")
        return
    
    # 步骤 2: 将歌曲按 albumId 组织
    songs_by_album_id = {}
    for song in all_songs:
        # 确保歌曲字典里有 albumId，get_all_songs 应该已经处理了
        album_id_for_song = song.get('albumId')
        if album_id_for_song:
            if album_id_for_song not in songs_by_album_id:
                songs_by_album_id[album_id_for_song] = []
            songs_by_album_id[album_id_for_song].append(song)

    # 步骤 3: 获取所有专辑信息
    print("正在获取所有专辑列表...")
    all_albums = client.get_album_list(list_type='alphabeticalByName', use_cache=use_cache)
    if not all_albums:
        print("未能获取到专辑列表，无法继续。")
        return

    if debug:
        print("\n--- 调试模式已开启，仅处理前 10 张专辑 ---")
        all_albums = all_albums[:10]

    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS, thread_name_prefix='AIBatchCaller') as executor:
        futures = {}
        
        album_batch_for_ai = []
        songs_in_batch_count = 0
        all_songs_in_batch_map = {}
        batch_id_counter = 1

        total_albums = len(all_albums)
        for i, album in enumerate(all_albums):
            album_id = album.get('id')
            album_name = album.get('name', '未知专辑')
            album_artist = album.get('artist', '未知艺术家')
            
            print(f"\n({i+1}/{total_albums}) 正在检查专辑: {album_name} - {album_artist}")

            if not album_id:
                print("  - 警告：专辑缺少 ID，已跳过。")
                continue

            rate_album_flag = overwrite or not album.get('userRating')
            if not rate_album_flag:
                print(f"  - 专辑 '{album_name}' 已有评分 ({album.get('userRating')} 星)，且未开启覆盖模式，跳过专辑评分。")

            songs_in_album = songs_by_album_id.get(album_id, [])
            if not songs_in_album:
                print(f"  - 信息：专辑 '{album_name}' 在歌曲库中没有找到对应歌曲，已跳过。")
                continue

            songs_to_rate_in_album = []
            temp_song_map = {}

            for song in songs_in_album:
                if overwrite or not song.get('userRating'):
                    song_id = song.get('id')
                    if song_id:
                        songs_to_rate_in_album.append({"id": song_id, "title": song.get('title', '未知标题')})
                        temp_song_map[song_id] = song
                else:
                    print(f"  - 歌曲 '{song.get('title')}' 已有评分 ({song.get('userRating')} 星)，跳过。")

            if not songs_to_rate_in_album and not rate_album_flag:
                print("  - 此专辑及所有歌曲均已有评分，无需处理。")
                continue

            # 检查是否需要提交当前批次
            if album_batch_for_ai and (songs_in_batch_count + len(songs_to_rate_in_album)) > 50:
                print(f"\n--- 批次歌曲数达到上限，正在将批次 {batch_id_counter} 提交到工作线程池 ---")
                future = executor.submit(_call_ai_for_batch, batch_id_counter, list(album_batch_for_ai))
                futures[future] = (batch_id_counter, dict(all_songs_in_batch_map))
                
                album_batch_for_ai.clear()
                all_songs_in_batch_map.clear()
                songs_in_batch_count = 0
                batch_id_counter += 1

            album_data_for_ai = {
                "album_id": album_id, "album_name": album_name, "artist": album_artist,
                "rate_album": rate_album_flag, "songs_to_rate": songs_to_rate_in_album
            }
            album_batch_for_ai.append(album_data_for_ai)
            songs_in_batch_count += len(songs_to_rate_in_album)
            all_songs_in_batch_map.update(temp_song_map)
            print(f"  - 已将专辑 '{album_name}' 添加到批次 {batch_id_counter}。当前批次: {len(album_batch_for_ai)} 张专辑, {songs_in_batch_count} 首歌曲。")

        # 提交最后一批
        if album_batch_for_ai:
            print(f"\n--- 正在将最后一个批次 {batch_id_counter} 提交到工作线程池 ---")
            future = executor.submit(_call_ai_for_batch, batch_id_counter, list(album_batch_for_ai))
            futures[future] = (batch_id_counter, dict(all_songs_in_batch_map))

        print("\n--- 所有专辑已分组完毕并提交，等待 AI 响应和处理... ---")
        # 按完成顺序处理结果
        for future in concurrent.futures.as_completed(futures):
            batch_id, song_map = futures[future]
            try:
                ai_content, prompt_data = future.result()
                if ai_content:
                    _process_ai_results(client, batch_id, ai_content, prompt_data, song_map)
                else:
                    print(f"  - [批次 {batch_id}] 未能从 AI 获取有效结果，跳过处理。")
            except Exception as exc:
                print(f'  - [批次 {batch_id}] 处理时产生意外错误: {exc}')

    print("\n--- 所有专辑评分处理完毕 ---")

def _select_playlist(client):
    """显示所有播放列表并让用户选择一个。"""
    playlists = client.get_playlists()
    if not playlists:
        print("未能获取到任何播放列表，或者您的库中没有播放列表。")
        return None, None

    print("\n--- 请选择一个要扩展的播放列表 ---")
    for i, p in enumerate(playlists):
        print(f"{i + 1}. {p.get('name', '未知名称')} ({p.get('songCount', 0)} 首歌曲)")
    print("0. 返回主菜单")

    while True:
        try:
            choice = int(input("请输入你的选择: "))
            if 0 < choice <= len(playlists):
                selected_playlist = playlists[choice - 1]
                return selected_playlist.get('id'), selected_playlist.get('name')
            elif choice == 0:
                return None, None
            else:
                print("无效的选择，请输入列表中的数字。")
        except ValueError:
            print("无效的输入，请输入一个数字。")

def _call_ai_for_playlist_extension(playlist_name, playlist_songs, all_songs):
    """构建prompt并调用AI，以获取歌单扩展建议。"""
    print("\n正在准备数据并请求 AI 进行分析...")

    # 提取所需信息
    playlist_song_info = [
        f"- {s.get('title', 'N/A')} (艺术家: {s.get('artist', 'N/A')}, 专辑: {s.get('album', 'N/A')})"
        for s in playlist_songs
    ]
    
    # 从所有歌曲中排除已经存在于歌单中的歌曲
    playlist_song_ids = {s.get('id') for s in playlist_songs}
    candidate_songs = [s for s in all_songs if s.get('id') not in playlist_song_ids]

    candidate_song_info = [
        f"id:{s.get('id')} | {s.get('title', 'N/A')} (艺术家: {s.get('artist', 'N/A')}, 专辑: {s.get('albumName', 'N/A')})"
        for s in candidate_songs
    ]

    print(f"已准备好 {len(playlist_song_info)} 首歌单歌曲和 {len(candidate_song_info)} 首候选歌曲的信息。")

    prompt = f"""
你是一位专业的音乐策展人，拥有深厚的音乐知识和卓越的品味。你的任务是为一个已有的歌单进行扩展。

### 任务背景
- **歌单名称**: "{playlist_name}"
- **核心任务**: 分析这个歌单已有的歌曲，理解其音乐风格、主题、情绪或流派，然后从一个更大的曲库中，挑选出最适合加入这个歌单的歌曲。

### 歌单已有歌曲列表:
```
{"\n".join(playlist_song_info)}
```

### 待选的候选歌曲库 (格式: id:歌曲ID | 歌曲名 (艺术家: 艺术家名, 专辑: 专辑名)):
```
{"\n".join(candidate_song_info)}
```

### 分析与推荐要求
1.  **风格分析**: 首先，请简要分析一下原歌单的整体风格、情绪和特点。
2.  **推荐歌曲**: 根据你的分析，从候选歌曲库中挑选出你认为最应该被添加进来的歌曲。
3.  **提供理由**: 对你推荐的每一首歌曲，请给出一句精炼的推荐理由，解释为什么它适合这个歌单。
4.  **数量限制**: 最多推荐 20 首歌曲。如果候选歌曲库中没有合适的歌曲，请返回一个空的 `recommendations` 数组。
5.  **输出格式**: 你的回答必须是且仅是一个格式正确的 JSON 对象，不包含任何其他文字、解释或代码块标记。JSON 结构必须如下所示：

    ```json
    {{
      "analysis": "这里是你对原歌单的风格分析。",
      "recommendations": [
        {{
          "id": "歌曲ID",
          "title": "歌曲名",
          "artist": "艺术家名",
          "reason": "推荐这首歌的理由。"
        }},
        ...
      ]
    }}
    ```

### ！！！重要：格式要求
- 你的回答**必须**是一个完美、无误、严格遵守RFC 8259标准的JSON对象。
- `id` 字段必须与候选歌曲库中提供的ID完全一致。
- 如果你认为没有任何歌曲适合加入，请返回一个空的 `recommendations` 数组。

现在，请开始你的分析和推荐。
"""
    max_retries = 3
    retry_delay = 10
    for attempt in range(max_retries):
        try:
            print(f"正在请求 AI... (尝试 {attempt + 1}/{max_retries})")
            ai_response = requests.post(
                OPENAI_API_URL,
                headers={
                    "Authorization": f"Bearer {OPENAI_API_KEY}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": OPENAI_API_MODEL,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.3,
                    "response_format": {"type": "json_object"} # 请求JSON输出
                },
                timeout=600
            )
            ai_response.raise_for_status()
            ai_data = ai_response.json()
            content_str = ai_data['choices'][0]['message']['content'].strip()
            
            # 清理AI返回内容中可能存在的Markdown代码块
            if content_str.startswith("```json"):
                content_str = content_str[7:-3].strip()
            elif content_str.startswith("```"):
                content_str = content_str[3:-3].strip()

            ai_content = json.loads(content_str)
            return ai_content
        except requests.exceptions.RequestException as e:
            print(f"调用 AI API 时出错: {e}")
            if attempt < max_retries - 1:
                print(f"将在 {retry_delay} 秒后重试...")
                time.sleep(retry_delay)
                retry_delay *= 2
            else:
                print("已达到最大重试次数，放弃。")
                return None
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            print(f"解析或处理 AI 响应时出错: {e}")
            print(f"原始响应: {ai_response.text if 'ai_response' in locals() else 'N/A'}")
            return None
    return None

def extend_playlist_with_ai(client):
    """功能5：使用 AI 扩展现有播放列表。"""
    if not OPENAI_API_URL or not OPENAI_API_KEY:
        print("\n错误：请先配置 OPENAI_API_URL 和 OPENAI_API_KEY 环境变量或在脚本中直接修改。")
        return

    # 1. 让用户选择一个歌单
    playlist_id, playlist_name = _select_playlist(client)
    if not playlist_id:
        return

    print(f"\n已选择歌单: '{playlist_name}' (ID: {playlist_id})")

    # 2. 获取该歌单的歌曲
    playlist_data = client.get_playlist(playlist_id)
    if not playlist_data:
        print("无法获取歌单详情，操作中止。")
        return
    playlist_songs = playlist_data.get('entry', [])
    if not playlist_songs:
        print("这是一个空歌单，AI无法分析，请先添加一些歌曲。")
        return

    # 3. 获取曲库所有歌曲作为候选池
    print("\n为了给AI提供最全的候选池，正在获取曲库中的所有歌曲...")
    # 此处强制不使用缓存，以确保AI拿到的是最新的歌单和曲库差集
    all_songs = client.get_all_songs(use_cache=False)
    if not all_songs:
        print("无法获取曲库歌曲，操作中止。")
        return

    # 4. 调用AI进行分析和推荐
    ai_result = _call_ai_for_playlist_extension(playlist_name, playlist_songs, all_songs)

    if not ai_result or not ai_result.get('recommendations'):
        print("\nAI未能提供任何有效的歌曲推荐。")
        return

    print("\n--- AI 分析与推荐 ---")
    print(f"歌单风格分析: {ai_result.get('analysis', '无')}")
    
    recommendations = ai_result.get('recommendations', [])
    print("\n推荐加入以下歌曲:")
    for i, rec in enumerate(recommendations):
        print(f"  {i + 1}. {rec.get('title', 'N/A')} - {rec.get('artist', 'N/A')}")
        print(f"     理由: {rec.get('reason', 'N/A')}")

    # 5. 用户确认
    confirm = input("\n是否要将以上推荐的歌曲全部加入到歌单中？(y/N): ").lower()
    if confirm != 'y':
        print("操作已取消。")
        return

    # 6. 更新歌单
    song_ids_to_add = [rec.get('id') for rec in recommendations if rec.get('id')]
    if not song_ids_to_add:
        print("没有有效的歌曲ID可以添加。")
        return
        
    success = client.update_playlist(playlist_id, song_ids_to_add=song_ids_to_add)
    if success:
        print(f"\n成功将 {len(song_ids_to_add)} 首歌曲添加到播放列表 '{playlist_name}'。")
    else:
        print("\n更新播放列表失败。")

def clear_caches():
    """清除本地的歌曲和专辑缓存文件。"""
    files_to_clear = {
        "歌曲": SONG_CACHE_FILE,
        "专辑": ALBUM_CACHE_FILE
    }
    for name, file_path in files_to_clear.items():
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
                print(f"已成功删除{name}缓存文件: {file_path}")
            except OSError as e:
                print(f"删除{name}缓存文件时出错: {e}")
        else:
            print(f"未找到{name}缓存文件，无需清除。")

def sync_data_from_server(client):
    """强制与服务器同步，重新生成所有本地缓存。"""
    print("\n--- 开始强制同步服务器数据 ---")
    print("步骤 1/3: 清理旧的本地缓存...")
    clear_caches()
    
    print("\n步骤 2/3: 正在从服务器获取并缓存所有专辑信息...")
    # 调用时禁用缓存会强制从网络获取并写入新缓存
    albums = client.get_album_list(list_type='alphabeticalByName', use_cache=False)
    if albums is not None:
        print(f"成功缓存 {len(albums)} 张专辑。")
    else:
        print("警告：未能获取或缓存专辑信息。")

    print("\n步骤 3/3: 正在从服务器获取并缓存所有歌曲信息...")
    # 同样，禁用缓存会强制重新获取和缓存
    songs = client.get_all_songs(use_cache=False)
    if songs is not None:
        print(f"成功缓存 {len(songs)} 首歌曲。")
    else:
        print("警告：未能获取或缓存歌曲信息。")
    
    print("\n--- 数据同步完成 ---")

def main():
    """主函数，显示菜单并处理用户输入。"""
    parser = argparse.ArgumentParser(description="Navidrome 音乐助手。")
    parser.add_argument("--debug", action="store_true", help="开启调试模式，只处理少量数据（例如前10张专辑）。")
    parser.add_argument("--no-cache", action="store_true", help="本次运行不使用任何缓存，强制从服务器获取最新数据。")
    parser.add_argument("--clear-cache", action="store_true", help="启动时清除所有本地缓存文件。")
    args = parser.parse_args()

    if args.clear_cache:
        clear_caches()
        # 如果未来有更多缓存，也在这里清除
        print("缓存清理完毕。")
        return

    # 检查必需的环境变量是否已设置
    if not all([NAVIDROME_URL, NAVIDROME_USER, NAVIDROME_PASSWORD, OPENAI_API_URL, OPENAI_API_KEY]):
        print("错误：一个或多个必要的环境变量缺失。请检查 .env 文件并确保以下变量已设置：")
        if not NAVIDROME_URL: print("- NAVIDROME_URL")
        if not NAVIDROME_USER: print("- NAVIDROME_USER")
        if not NAVIDROME_PASSWORD: print("- NAVIDROME_PASSWORD")
        if not OPENAI_API_URL: print("- OPENAI_API_URL")
        if not OPENAI_API_KEY: print("- OPENAI_API_KEY")
        return
    client = NavidromeClient(
        base_url=NAVIDROME_URL,
        username=NAVIDROME_USER,
        password=NAVIDROME_PASSWORD
    )
    if not client.ping():
        return
    
    # 将 use_cache 标志传递给需要它的函数
    use_cache_flag = not args.no_cache

    while True:
        print("\n--- Navidrome 助手菜单 ---")
        print("1. 音乐库统计")
        print("2. 使用 AI 为歌曲评分")
        print("3. 查看歌曲星级统计")
        print("4. 导出全部歌曲星级到文件")
        print("5. 使用 AI 扩展歌单")
        print("6. 同步服务器数据 (强制刷新缓存)")
        print("0. 退出")
        choice = input("请输入你的选择: ")
        if choice == '1':
            show_statistics(client)
        elif choice == '2':
            overwrite_choice = input("是否覆盖已有评分？(y/N): ").lower()
            overwrite = overwrite_choice == 'y'
            rate_albums_with_ai(client, debug=args.debug, overwrite=overwrite, use_cache=use_cache_flag)
        elif choice == '3':
            show_rating_statistics(client, use_cache=use_cache_flag)
        elif choice == '4':
            show_all_song_ratings(client, use_cache=use_cache_flag)
        elif choice == '5':
            extend_playlist_with_ai(client)
        elif choice == '6':
            sync_data_from_server(client)
        elif choice == '0':
            print("正在退出...")
            break
        else:
            print("无效的选择，请重新输入。")

if __name__ == "__main__":
    main()
