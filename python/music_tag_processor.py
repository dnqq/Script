import os
import shutil
from mutagen.easyid3 import EasyID3
from mutagen.flac import FLAC
from mutagen.oggvorbis import OggVorbis
from mutagen.mp4 import MP4
from mutagen.asf import ASF
from mutagen.wave import WAVE
from opencc import OpenCC

def is_music_file(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    return ext in {'.mp3', '.wav', '.flac', '.aac', '.ogg', 
                   '.m4a', '.wma', '.ape', '.opus'}

def preprocess_tag(tag_value):
    if not tag_value:
        return None
    processed = tag_value.replace('/', '&')
    cc = OpenCC('t2s')
    return cc.convert(processed)

def process_music_file(file_path, dest_dir):
    try:
        ext = os.path.splitext(file_path)[1].lower()
        audio = None

        # 根据文件类型加载音频文件
        if ext == '.mp3':
            audio = EasyID3(file_path)
        elif ext == '.flac':
            audio = FLAC(file_path)
        elif ext == '.ogg':
            audio = OggVorbis(file_path)
        elif ext == '.m4a':
            audio = MP4(file_path)
        elif ext == '.wma':
            audio = ASF(file_path)
        elif ext == '.wav':
            audio = WAVE(file_path)
        else:
            print(f"Unsupported format: {file_path}")
            return

        # 获取并预处理标签
        artist = preprocess_tag(audio.get('artist', [''])[0]) if 'artist' in audio else None
        title = preprocess_tag(audio.get('title', [''])[0]) if 'title' in audio else None
        album = preprocess_tag(audio.get('album', [''])[0]) if 'album' in audio else None

        # 设置默认值
        artist = artist or 'Unknown Artist'
        title = title or 'Unknown Title'
        album = album or 'Unknown Album'

        # 更新标签
        audio['artist'] = artist
        audio['title'] = title
        audio['album'] = album

        # 保存修改到原文件
        audio.save()

        # 构建新路径
        new_filename = f"{artist} - {title}{ext}"
        dest_path = os.path.join(dest_dir, artist, album, new_filename)
        os.makedirs(os.path.dirname(dest_path), exist_ok=True)

        # 复制文件到新位置
        shutil.copy2(file_path, dest_path)
        print(f"Processed: {os.path.basename(file_path)}")

    except Exception as e:
        print(f"Error processing {os.path.basename(file_path)}: {str(e)}")
        import traceback
        traceback.print_exc()

def process_music_files(source_folder, destination_folder):
    if not os.path.isdir(source_folder) or not os.path.isdir(destination_folder):
        print("Invalid source or destination directory")
        return

    for filename in os.listdir(source_folder):
        file_path = os.path.join(source_folder, filename)
        if os.path.isfile(file_path) and is_music_file(file_path):
            process_music_file(file_path, destination_folder)

if __name__ == "__main__":
    source_folder = "D:\\KwDownload\\song"
    destination_folder = "D:\\KwDownload\\song"
    process_music_files(source_folder, destination_folder)
