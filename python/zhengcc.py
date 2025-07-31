import requests
import json
import time
import os

# --- 配置 ---
# 将 DEBUG 设置为 True 以只获取前10道题进行测试
DEBUG = False
# 两次请求之间的延迟（秒），以避免对服务器造成太大压力
REQUEST_DELAY = 0.5
# 输出文件路径
OUTPUT_FILE_PATH = r"D:\ashin\Desktop\公共营养师理论试题三级.txt"

def get_all_question_ids(session):
    """
    调用 getPracticeQuestionList 接口获取所有试题ID。
    """
    url = "http://ctjph5.zhengcc.cn/api/study/StudentPractice/getPracticeQuestionList"
    data = {'knowledgeId': 'fuwyanxqkxdr9avegz1hq'}
    
    print("步骤 1: 获取所有试题ID...")
    try:
        response = session.post(url, data=data)
        response.raise_for_status()
        response_data = response.json()
        
        if response_data.get("code") == 1:
            # 根据用户反馈，试题ID在 "questionList" 中
            question_list = response_data.get("questionList", [])
            ques_ids = [q["id"] for q in question_list if "id" in q]
            print(f"成功获取到 {len(ques_ids)} 个试题ID。")
            return ques_ids
        else:
            print(f"获取试题ID失败: {response_data.get('msg')}")
            return None
            
    except requests.exceptions.RequestException as e:
        print(f"请求失败: {e}")
    except json.JSONDecodeError:
        print("解析JSON响应失败。")
    return None

def get_question_details(session, question_id):
    """
    根据试题ID获取试题详情。
    """
    url = "http://ctjph5.zhengcc.cn/api/study/StudentPractice/getPracticeQuestion"
    data = {'quesId': question_id}
    
    try:
        response = session.post(url, data=data)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"获取试题详情失败 (ID: {question_id}): {e}")
    except json.JSONDecodeError:
        print(f"解析试题详情JSON响应失败 (ID: {question_id})。")
    return None

def format_question(question_data, index):
    """
    将试题数据格式化为指定的输出格式。
    """
    if not question_data or question_data.get("code") != 1:
        return f"{index}. 无法解析此题。"

    info = question_data.get("questionInfo", {})
    content = info.get("content", "无题干")
    
    # 移除HTML标签
    while '<' in content and '>' in content:
        start = content.find('<')
        end = content.find('>')
        content = content[:start] + content[end+1:]

    # 替换括号
    content = content.replace('（   ）', '( )')

    options_str = ""
    correct_answers = []
    
    try:
        # selectJson 是一个字符串，需要再次解析
        options = json.loads(info.get("selectJson", "[]"))
        
        for i, option in enumerate(options):
            letter = chr(ord('A') + i)
            options_str += f"{letter}. {option['Content']}\n"
            if option.get("IsAnswer") == 1:
                correct_answers.append(letter)

    except json.JSONDecodeError:
        options_str = "解析选项失败。\n"

    answer_key = ";".join(correct_answers)
    
    return f"{index}. {content}\n{options_str}答案：{answer_key}"


def main():
    """
    主函数
    """
    headers = {
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'zh-CN,zh;q=0.9',
        'cache-control': 'no-cache',
        # Cookie 需要保持最新才能成功请求
        'cookie': 'auth=',
        'origin': 'http://ctjph5.zhengcc.cn',
        'pragma': 'no-cache',
        'referer': 'http://ctjph5.zhengcc.cn/practice/fuwyanxqkxdr9avegz1hq',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36'
    }
    
    with requests.Session() as session:
        session.headers.update(headers)
        
        question_ids = get_all_question_ids(session)
        
        if not question_ids:
            print("无法获取试题ID，程序退出。请检查您的Cookie是否有效。")
            return

        if DEBUG:
            print(f"\n--- 调试模式开启，仅处理前 {min(10, len(question_ids))} 道题 ---")
            question_ids = question_ids[:10]
        
        print("\n步骤 2: 开始获取并格式化试题...")
        
        try:
            # 确保目录存在
            os.makedirs(os.path.dirname(OUTPUT_FILE_PATH), exist_ok=True)
            
            with open(OUTPUT_FILE_PATH, 'w', encoding='utf-8') as f:
                for i, q_id in enumerate(question_ids):
                    details = get_question_details(session, q_id)
                    formatted_question = format_question(details, i + 1)
                    print(f"正在处理第 {i+1} 题...")
                    f.write(formatted_question + "\n\n") # 写入文件并增加空行
                    
                    # 停顿一下，避免请求过于频繁
                    time.sleep(REQUEST_DELAY)
            
            print(f"\n所有试题处理完毕，已保存到文件: {OUTPUT_FILE_PATH}")

        except IOError as e:
            print(f"\n写入文件时出错: {e}")
            print("请检查文件路径是否正确以及您是否有写入权限。")


if __name__ == "__main__":
    main()