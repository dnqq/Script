import os
import shutil
from mutagen.easyid3 import EasyID3
from mutagen.flac import FLAC
from mutagen.oggvorbis import OggVorbis
from mutagen.mp4 import MP4
from mutagen.asf import ASF
from mutagen.wave import WAVE
from opencc import OpenCC

cc = OpenCC('t2s')

def is_music_file(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    return ext in {'.mp3', '.wav', '.flac', '.aac', '.ogg',
                   '.m4a', '.wma', '.ape', '.opus'}

def preprocess_tag(tag_value):
    if not tag_value:
        return None
    processed = str(tag_value).replace('/', '&')
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

        # 遍历并预处理所有标签
        for key in list(audio.keys()):
            # ASF, the value is an ASFValue object.
            if isinstance(audio, ASF):
                tag = audio[key]
                if hasattr(tag, 'value') and isinstance(tag.value, str):
                    audio[key] = preprocess_tag(tag.value)
                continue

            # For other formats, values are lists of strings
            values = audio[key]
            if isinstance(values, list):
                processed_values = [preprocess_tag(v) if isinstance(v, str) else v for v in values]
                audio[key] = processed_values

        # 获取用于构建路径的特定标签
        def get_first_tag(tag_name):
            value = audio.get(tag_name)
            if not value:
                return None
            if isinstance(value, list):
                return value[0] if value and isinstance(value[0], str) else None
            if isinstance(value, str):
                return value
            if hasattr(value, 'value') and isinstance(value.value, str):
                return value.value
            return None

        artist = get_first_tag('artist') or 'Unknown Artist'
        title = get_first_tag('title') or 'Unknown Title'
        album = get_first_tag('album') or 'Unknown Album'
        albumartist = get_first_tag('albumartist')

        # 保存修改到原文件
        audio.save()

        # 构建新路径
        path_artist = albumartist or artist
        new_filename = f"{artist} - {title}{ext}"
        dest_path = os.path.join(dest_dir, path_artist, album, new_filename)
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
    source_folder = "D:\\ashin\\Desktop\\音乐临时文件夹"
    destination_folder = "D:\\ashin\\Desktop\\音乐临时文件夹"
    process_music_files(source_folder, destination_folder)
