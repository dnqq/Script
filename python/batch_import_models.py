# -*- coding: utf-8 -*-
"""
程序主要功能描述:
该脚本用于向数据库中批量导入或同步API模型的渠道(channel)和能力(ability)配置。
它支持从预定义的模型库 (MODEL_LIBRARY) 中为指定的提供商 (如 OpenRouter, Google Gemini 等)
添加新的模型配置，或者将现有数据库中的模型配置与预设库同步，确保所有定义的模型
都已为现有的API密钥添加。脚本通过命令行交互方式获取用户输入，
包括选择操作类型、提供商、API密钥和要操作的模型。

程序的使用方法或调用示例:
1. 直接运行脚本: `python your_script_name.py`
2. 根据提示选择操作类型:
   - "1": 插入新提供商和模型 (需要输入提供商、API Key、可选的Base URL、选择要插入的模型)。
   - "2": 同步指定提供商的现有密钥与MODEL_LIBRARY (选择提供商，可选择同步所有密钥或指定密钥)。
   - "3": 同步所有提供商的现有密钥与MODEL_LIBRARY (可选择同步所有密钥或指定密钥)。

Author: ashin
"""

import mysql.connector
import time
import json

# --- 全局配置 ---

# 数据库连接配置字典
# 键是端口号字符串，值是mysql.connector所需的连接参数字典
DB_CONFIGS = {
    "3307": {
        'host': '127.0.0.1',      # 数据库主机地址
        'port': 3307,             # 数据库端口号
        'user': 'newapi',         # 数据库用户名
        'password': 'jDz4h2pbZHZe7mnY', # 数据库密码
        'database': 'newapi'      # 数据库名称
    },
    "3308": {
        'host': '127.0.0.1',
        'port': 3308,
        'user': 'newapi',
        'password': 'S72WHWi8nFQxRrnw',
        'database': 'newapi'
    }
}

# 提供商配置字典
# 键是提供商名称，值包含对应的 'channel_type' 和 'db_port' (关联到DB_CONFIGS)
PROVIDER_CONFIGS = {
    "OpenRouter": {"channel_type": 20, "db_port": "3308"},
    "Google Gemini": {"channel_type": 24, "db_port": "3308"},
    "硅基流动": {"channel_type": 40, "db_port": "3307"},
    "阿里云百练": {"channel_type": 17, "db_port": "3307"},
    "兼容OPENAI": {"channel_type": 1, "db_port": "3307"}
    # 可以添加更多提供商...
    # "DefaultProvider": {"channel_type": 43, "db_port": "3308"} # 示例默认配置
}

# 预设模型库字典
# 键是提供商名称，值是一个列表，每个元素是包含 'model_type' 和 'model_id' 的字典
# 'model_type' 是在系统中显示的、用户友好的模型名称后缀
# 'model_id' 是实际传递给API提供商的模型标识符
MODEL_LIBRARY = {
    "OpenRouter": [
        {"model_type": "gemini-2.5-pro-exp-03-25", "model_id": "google/gemini-2.5-pro-exp-03-25:free"},
        {"model_type": "DeepSeek-R1", "model_id": "deepseek/deepseek-r1:free"},
        {"model_type": "DeepSeek-V3", "model_id": "deepseek/deepseek-chat-v3-0324:free"}
    ],
    "Google Gemini": [
        {"model_type": "gemini-2.0-flash", "model_id": "gemini-2.0-flash"},
        {"model_type": "gemini-2.0-flash-thinking-exp", "model_id": "gemini-2.0-flash-thinking-exp"},
        {"model_type": "gemini-2.5-pro-exp-03-25", "model_id": "gemini-2.5-pro-exp-03-25"}
    ],
    "硅基流动": [
        {"model_type": "bge-m3", "model_id": "Pro/BAAI/bge-m3"},
        {"model_type": "bge-reranker-v2-m3", "model_id": "Pro/BAAI/bge-reranker-v2-m3"},
        {"model_type": "DeepSeek-V3", "model_id": "deepseek-ai/DeepSeek-V3"},
        {"model_type": "DeepSeek-R1", "model_id": "deepseek-ai/DeepSeek-R1"}
    ],
    "阿里云百练": [
        {"model_type": "DeepSeek-V3", "model_id": "deepseek-v3"}
    ],
    "兼容OPENAI": [
        {"model_type": "DeepSeek-V3", "model_id": "deepseek-ai/DeepSeek-V3 202541"},
        {"model_type": "DeepSeek-R1", "model_id": "deepseek-ai/DeepSeek-R1 202541"}
    ]
}

# 提供商默认基础URL字典
# 键是提供商名称，值是默认的API Base URL。如果为空字符串，则表示使用系统默认或不需要特定Base URL
DEFAULT_BASE_URLS = {
    "OpenRouter": "",
    "Google Gemini": "",
    "硅基流动": "",
    "阿里云百练": "",
    "兼容OPENAI": ""
}

# --- 核心功能函数 ---

def get_config_by_provider(provider):
    """
    根据提供商名称获取其渠道类型 (channel_type) 和数据库配置。

    Args:
        provider (str): 提供商的名称 (必须是 PROVIDER_CONFIGS 中的键)。

    Returns:
        tuple: 包含渠道类型 (int) 和数据库配置字典 (dict) 的元组。
               如果提供商未在 PROVIDER_CONFIGS 中找到，则返回默认配置 (channel_type=43, db_port=3308)。
    """
    if provider in PROVIDER_CONFIGS:
        # 从 PROVIDER_CONFIGS 获取该提供商的配置
        config = PROVIDER_CONFIGS[provider]
        # 根据配置中的 db_port 从 DB_CONFIGS 获取数据库连接信息
        db_config = DB_CONFIGS[config["db_port"]]
        return config["channel_type"], db_config
    else:
        # 如果提供商未配置，使用硬编码的默认值 (例如，默认渠道类型43，默认数据库端口3308)
        print(f"警告: 提供商 '{provider}' 未在 PROVIDER_CONFIGS 中配置，使用默认配置 (type=43, port=3308)")
        return 43, DB_CONFIGS["3308"] # 提供一个默认的回退配置

def insert_data(key, provider, model_type, model_id, base_url, channel_type=None):
    """
    向数据库的 channels 表和 abilities 表插入指定模型的数据。
    对于每个模型，会插入三条 channel 记录：
    1.  基础模型渠道 (e.g., 'Provider-ModelType')
    2.  负载均衡渠道 (e.g., 'Provider-ModelType-负载均衡')
    3.  主备切换渠道 (e.g., 'Provider-ModelType-主备切换')
    同时，会在 abilities 表中创建对应的关联记录。

    Args:
        key (str): API 密钥。
        provider (str): 提供商名称。
        model_type (str): 系统中使用的模型类型名称 (来自 MODEL_LIBRARY)。
        model_id (str): 实际传递给API提供商的模型标识符 (来自 MODEL_LIBRARY)。
        base_url (str): API 的基础 URL。
        channel_type (int, optional): 渠道类型。如果为 None，将根据 provider 自动获取。默认为 None。
    """
    # 如果未显式提供 channel_type，则根据提供商自动获取
    if channel_type is None:
        channel_type, db_config = get_config_by_provider(provider)
    else:
        # 如果明确指定了 channel_type，仍然需要根据 provider 获取正确的数据库配置
        _, db_config = get_config_by_provider(provider)

    print(f"信息: 正在使用数据库端口 {db_config['port']}，渠道类型 {channel_type} 为模型 '{provider}/{model_type}' 插入数据。")

    conn = None # 初始化数据库连接对象
    cursor = None # 初始化游标对象
    try:
        # 建立数据库连接
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()

        # 获取当前的 Unix 时间戳 (秒)
        current_time = int(time.time())

        # 用于存储成功插入的 channel 记录的自增 ID
        inserted_channel_ids = []

        # 准备要插入 channels 表的三条记录的数据结构
        # 1. 基础模型记录
        # 2. 负载均衡记录 (通常用于模型分组，名称和tag不同)
        # 3. 主备切换记录 (通常用于模型分组，名称和tag不同)
        channel_data = [
            {
                # --- 通用字段 ---
                'type': channel_type,        # 渠道类型
                'key': key,                  # API 密钥
                'base_url': base_url,        # API 基础 URL
                'created_time': current_time,# 创建时间戳
                'test_time': current_time + 975, # 下次测试时间 (当前时间 + 偏移)
                'response_time': 0,          # 初始响应时间
                'used_quota': 0,             # 初始已用配额
                'priority': 1,               # 优先级
                'auto_ban': 1,               # 是否自动禁用 (1:是, 0:否)
                'status': 1,                 # 状态 (1:启用, 2:禁用) - 硬编码为启用
                'weight': 1,                 # 权重 - 硬编码为1
                'group': 'default',          # 分组 - 硬编码为'default'
                # --- 特定记录字段 ---
                'name': f'{provider}-{model_type}', # 渠道名称 (基础)
                'models': f'{provider}/{model_type}',# 支持的模型列表 (基础)
                # 模型映射: 将系统模型名映射到提供商模型ID，使用JSON格式存储
                'model_mapping': json.dumps({f'{provider}/{model_type}': model_id}, ensure_ascii=False),
                'tag': None                  # 标签 (基础模型无特定标签)
            },
            { # 负载均衡记录
                'type': channel_type,
                'key': key,
                'base_url': base_url,
                'created_time': current_time + 81, # 创建时间略微错开
                'test_time': current_time + 974, # 测试时间略微错开
                'response_time': 0,
                'used_quota': 0,
                'priority': 1,
                'auto_ban': 1,
                'status': 1,
                'weight': 1,
                'group': 'default',
                'name': f'{provider}-{model_type}-负载均衡', # 渠道名称 (负载均衡)
                'models': f'All/{model_type}-balance',    # 支持的模型列表 (负载均衡)
                'model_mapping': json.dumps({f'All/{model_type}-balance': model_id}, ensure_ascii=False),
                'tag': f'{model_type}-负载均衡'           # 标签 (负载均衡)
            },
            { # 主备切换记录
                'type': channel_type,
                'key': key,
                'base_url': base_url,
                'created_time': current_time + 81, # 创建时间与负载均衡相同
                'test_time': current_time + 974, # 测试时间与负载均衡相同
                'response_time': 0,
                'used_quota': 0,
                'priority': 1,
                'auto_ban': 1,
                'status': 1,
                'weight': 1,
                'group': 'default',
                'name': f'{provider}-{model_type}-主备切换', # 渠道名称 (主备切换)
                'models': f'All/{model_type}-primary',    # 支持的模型列表 (主备切换)
                'model_mapping': json.dumps({f'All/{model_type}-primary': model_id}, ensure_ascii=False),
                'tag': f'{model_type}-主备切换'           # 标签 (主备切换)
            }
        ]

        # 循环插入三条 channel 记录
        for data in channel_data:
            # SQL 插入语句 (注意 'key', 'group' 是 MySQL 关键字，需要用反引号括起来)
            sql = """
            INSERT INTO channels (
                type, `key`, name, base_url, models, model_mapping,
                created_time, test_time, response_time, used_quota,
                priority, auto_ban, tag, status, weight, `group`
            ) VALUES (
                %(type)s, %(key)s, %(name)s, %(base_url)s, %(models)s, %(model_mapping)s,
                %(created_time)s, %(test_time)s, %(response_time)s, %(used_quota)s,
                %(priority)s, %(auto_ban)s, %(tag)s, %(status)s, %(weight)s, %(group)s
            )
            """
            # 执行 SQL 语句
            cursor.execute(sql, data)
            # 获取刚刚插入记录的自增 ID
            inserted_id = cursor.lastrowid
            # 将 ID 添加到列表中，以便后续插入 abilities 表
            inserted_channel_ids.append(inserted_id)
            print(f"成功: 已插入 channel 记录，ID: {inserted_id}, 名称: {data['name']}")
            # print(f"调试: model_mapping: {data['model_mapping']}") # 打印 model_mapping 用于调试

        # 检查是否成功获取了三个 channel ID
        if len(inserted_channel_ids) != 3:
            raise Exception("错误: 未能成功插入所有三个 channel 记录，无法继续插入 abilities。")

        # 准备插入 abilities 表的数据，关联刚刚插入的 channels
        abilities_data = [
            { # 基础模型的 ability
                'group': 'default',                  # 分组
                'model': f'{provider}/{model_type}', # 模型名称 (与 channel 的 models 对应)
                'channel_id': inserted_channel_ids[0], # 关联的 channel ID
                'enabled': 1,                        # 是否启用 (1:是)
                'priority': 0,                       # 优先级 (基础模型优先级通常较低或为0)
                'weight': 0,                         # 权重 (基础模型权重通常为0，由分组管理)
                'tag': None                          # 标签
            },
            { # 负载均衡模型的 ability
                'group': 'default',
                'model': f'All/{model_type}-balance', # 模型名称 (与 channel 的 models 对应)
                'channel_id': inserted_channel_ids[1], # 关联的 channel ID
                'enabled': 1,
                'priority': 1,                       # 优先级 (分组模型通常有优先级)
                'weight': 0,                         # 权重
                'tag': f'{model_type}-负载均衡'        # 标签 (与 channel 的 tag 对应)
            },
            { # 主备切换模型的 ability
                'group': 'default',
                'model': f'All/{model_type}-primary', # 模型名称 (与 channel 的 models 对应)
                'channel_id': inserted_channel_ids[2], # 关联的 channel ID
                'enabled': 1,
                'priority': 1,                       # 优先级
                'weight': 0,                         # 权重
                'tag': f'{model_type}-主备切换'        # 标签 (与 channel 的 tag 对应)
            }
        ]

        # 循环插入三条 ability 记录
        for data in abilities_data:
            # SQL 插入语句 (注意 'group' 是关键字)
            sql = """
            INSERT INTO abilities (
                `group`, model, channel_id, enabled, priority, weight, tag
            ) VALUES (
                %(group)s, %(model)s, %(channel_id)s, %(enabled)s, %(priority)s, %(weight)s, %(tag)s
            )
            """
            # 执行 SQL 语句
            cursor.execute(sql, data)
            print(f"成功: 已插入 ability 记录，关联 Channel ID: {data['channel_id']}, 模型: {data['model']}")

        # 所有插入操作成功，提交数据库事务
        conn.commit()
        print(f"成功: 模型 '{provider}/{model_type}' 的所有数据已成功插入数据库！")

    except mysql.connector.Error as err:
        # 捕获数据库操作相关的错误
        print(f"数据库错误: {err}")
        if conn is not None:
            # 如果发生错误，回滚事务，撤销本次操作中的所有更改
            print("信息: 正在回滚数据库事务...")
            conn.rollback()
            print("信息: 事务已回滚。")
    except Exception as e:
        # 捕获其他可能的异常 (例如前面检查 inserted_channel_ids 长度失败)
        print(f"发生意外错误: {e}")
        if conn is not None:
            # 同样需要回滚
            print("信息: 正在回滚数据库事务...")
            conn.rollback()
            print("信息: 事务已回滚。")
    finally:
        # 无论成功还是失败，最后都需要关闭数据库连接和游标
        if cursor is not None:
            cursor.close()
        if conn is not None and conn.is_connected():
            conn.close()
            # print("信息: 数据库连接已关闭。") # 可以取消注释此行以确认连接关闭

def insert_provider_models(provider, key, base_url=None, models=None):
    """
    为一个指定的提供商，使用同一个API密钥，插入多个模型的配置数据。

    Args:
        provider (str): 提供商名称。
        key (str): 该提供商的 API 密钥。
        base_url (str, optional): API 基础 URL。如果为 None 或空字符串，
                                  将尝试使用 DEFAULT_BASE_URLS 中的默认值。
                                  默认为 None。
        models (list, optional): 一个包含模型字典的列表 [{'model_type': str, 'model_id': str}, ...]。
                                 如果为 None，将使用 MODEL_LIBRARY 中该提供商的预设模型列表。
                                 默认为 None。
    """
    # 如果 base_url 未提供或为空，则从 DEFAULT_BASE_URLS 获取默认值
    if base_url is None or base_url == "":
        base_url = DEFAULT_BASE_URLS.get(provider, "") # 使用 .get() 避免 KeyError
        print(f"信息: 未提供 Base URL，使用默认值: '{base_url}'")

    # 如果 models 列表未提供，则从 MODEL_LIBRARY 获取预设列表
    if models is None:
        models = MODEL_LIBRARY.get(provider, []) # 使用 .get() 避免 KeyError
        if not models:
            # 如果 MODEL_LIBRARY 中也没有找到该提供商的模型，则打印错误并返回
            print(f"错误: 在 MODEL_LIBRARY 中未找到提供商 '{provider}' 的预设模型列表。无法继续。")
            return

    # 遍历模型列表，为每个模型调用 insert_data 函数
    total_models = len(models)
    print(f"\n信息: 即将为提供商 '{provider}' 使用 Key '{key[:5]}***' 插入 {total_models} 个模型...")
    for i, model in enumerate(models):
        print(f"\n[{i+1}/{total_models}] 开始处理模型: {provider}/{model['model_type']} (ID: {model['model_id']})")
        try:
            # 调用核心插入函数
            insert_data(
                key,
                provider,
                model["model_type"],
                model["model_id"],
                base_url
                # channel_type 会在 insert_data 内部自动获取
            )
            print(f"完成: 模型 {provider}/{model['model_type']} 数据处理完毕。\n")
            # 可以在两次插入之间添加短暂延时，如果需要避免过快操作数据库
            # time.sleep(0.1)
        except Exception as e:
            # 捕获 insert_data 可能抛出的异常，打印错误信息，但继续处理下一个模型
            print(f"错误: 在插入模型 {provider}/{model['model_type']} 时发生错误: {e}")
            print("信息: 继续处理下一个模型...")

    print(f"信息: 提供商 '{provider}' 的所有选定模型数据插入流程已完成。")


def get_existing_keys(provider, target_key=None):
    """
    查询数据库，获取指定提供商已存在的API密钥及其对应的Base URL列表。
    可以指定一个 target_key 只查询该密钥的信息。

    Args:
        provider (str): 提供商名称。
        target_key (str, optional): 如果提供此参数，则只查询与此密钥匹配的记录。
                                    默认为 None，查询该提供商的所有密钥。

    Returns:
        list: 一个包含字典的列表，每个字典代表一个找到的密钥及其信息，
              格式为: [{'key': str, 'base_url': str}, ...]。
              如果查询出错或未找到，返回空列表。
    """
    # 获取该提供商对应的数据库配置
    _, db_config = get_config_by_provider(provider)

    conn = None
    cursor = None
    keys_data = [] # 初始化结果列表

    try:
        # 建立数据库连接
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()

        # 获取该提供商的 channel_type，用于 SQL 查询过滤
        channel_type, _ = get_config_by_provider(provider)

        # 根据是否提供了 target_key 构建不同的 SQL 查询语句
        if target_key:
            # 查询特定密钥
            # 注意: name LIKE 匹配是为了兼容旧的命名方式 (Provider/Model) 和新的 (Provider-Model)
            # WHERE type = %s 确保只查询该提供商的渠道类型
            # AND `key` = %s 直接匹配目标密钥
            sql = """
            SELECT DISTINCT `key`, base_url
            FROM channels
            WHERE type = %s AND (`name` LIKE %s OR `name` LIKE %s) AND `key` = %s
            """
            # 使用 % 作为通配符，匹配 Provider-% 或 Provider/% 开头的名称
            params = (channel_type, f"{provider}-%", f"{provider}/%", target_key)
            print(f"调试: 执行查询特定密钥 '{target_key[:5]}***' (类型: {channel_type}, 提供商: {provider})")
        else:
            # 查询该提供商下的所有不同密钥
            sql = """
            SELECT DISTINCT `key`, base_url
            FROM channels
            WHERE type = %s AND (`name` LIKE %s OR `name` LIKE %s)
            """
            params = (channel_type, f"{provider}-%", f"{provider}/%")
            print(f"调试: 执行查询提供商 '{provider}' 的所有密钥 (类型: {channel_type})")

        # 执行查询
        cursor.execute(sql, params)

        # 获取所有查询结果
        results = cursor.fetchall()

        # 处理查询结果，构建返回的列表
        if results:
            print(f"信息: 查询到 {len(results)} 条与提供商 '{provider}' 相关" + (f" 且密钥为 '{target_key[:5]}***'" if target_key else "") + " 的记录。")
            for key, base_url in results:
                keys_data.append({"key": key, "base_url": base_url or ""}) # 如果 base_url 是 None，转为空字符串
        else:
            print(f"信息: 未在数据库中找到与提供商 '{provider}' 相关" + (f" 且密钥为 '{target_key[:5]}***'" if target_key else "") + " 的记录。")

        return keys_data

    except mysql.connector.Error as err:
        # 处理数据库错误
        print(f"数据库错误 (get_existing_keys): {err}")
        return [] # 返回空列表表示出错
    finally:
        # 关闭游标和连接
        if cursor is not None:
            cursor.close()
        if conn is not None and conn.is_connected():
            conn.close()


def sync_new_models(provider, key_data, new_models):
    """
    为一个已存在的 API 密钥同步 (插入) 新增的模型列表。

    Args:
        provider (str): 提供商名称。
        key_data (dict): 包含 'key' 和 'base_url' 的字典，代表要同步的密钥及其信息。
        new_models (list): 一个包含新模型字典的列表 [{'model_type': str, 'model_id': str}, ...]。
                           这些是需要为该 key 添加的模型。
    """
    key = key_data["key"]
    base_url = key_data["base_url"] # 获取该密钥对应的 Base URL

    # 打印提示信息，只显示部分密钥以保护隐私
    print(f"\n信息: 开始为 API 密钥 {key[:5]}*** (Base URL: '{base_url}') 同步 {len(new_models)} 个新模型...")

    # 遍历需要新增的模型列表
    total_new = len(new_models)
    for i, model in enumerate(new_models):
        print(f"\n  [{i+1}/{total_new}] 正在插入新模型: {provider}/{model['model_type']} (ID: {model['model_id']})")
        try:
            # 调用核心插入函数 insert_data 来添加这个新模型的数据
            insert_data(
                key,
                provider,
                model["model_type"],
                model["model_id"],
                base_url
            )
            # print(f"  成功: 模型 {provider}/{model['model_type']} 已为密钥 {key[:5]}*** 添加。") # insert_data内部已有成功信息
        except Exception as e:
            # 如果插入单个模型时出错，打印错误并继续下一个
            print(f"  错误: 为密钥 {key[:5]}*** 插入模型 {provider}/{model['model_type']} 时失败: {str(e)}")
            print("  信息: 继续同步下一个模型...")

    print(f"完成: API 密钥 {key[:5]}*** 的新模型同步流程结束。")


def find_new_models(provider, db_config, target_key=None):
    """
    查找数据库中指定提供商 (以及可选的特定密钥) 相对于 MODEL_LIBRARY 缺失的模型。

    Args:
        provider (str): 提供商名称。
        db_config (dict): 用于连接数据库的配置字典。
        target_key (str, optional): 如果提供，则只查找此特定密钥下缺失的模型。
                                    否则，查找该提供商所有密钥共同拥有的模型，并找出库中有但数据库中没有的模型。
                                    默认为 None。

    Returns:
        list: 一个包含缺失模型字典的列表 [{'model_type': str, 'model_id': str}, ...]。
              如果出错或没有新模型，返回空列表。
    """
    conn = None
    cursor = None
    try:
        # 建立数据库连接
        conn = mysql.connector.connect(**db_config)
        cursor = conn.cursor()

        # 获取该提供商的 channel_type
        channel_type, _ = get_config_by_provider(provider)

        # 构建 SQL 查询语句以获取数据库中已存在的模型类型名称
        # 使用 SUBSTRING_INDEX 从 'models' 字段 (如 'Provider/ModelType' 或 'All/ModelType-balance') 提取模型类型部分
        # 我们只关心基础模型，所以需要过滤掉 '-balance' 和 '-primary' 后缀
        if target_key:
            # 查询特定密钥下的模型
            sql = """
            SELECT DISTINCT SUBSTRING_INDEX(models, '/', -1) as model_name
            FROM channels
            WHERE type = %s AND (`name` LIKE %s OR `name` LIKE %s) AND `key` = %s
            """
            params = (channel_type, f"{provider}-%", f"{provider}/%", target_key)
            print(f"调试: 查询密钥 '{target_key[:5]}***' 在数据库中已有的模型 (类型: {channel_type}, 提供商: {provider})")
        else:
            # 查询该提供商所有密钥共有的模型 (这逻辑可能不完全符合预期，
            # 因为不同key可能有不同模型。更常见的场景是针对特定key查找缺失模型，
            # 或者假设所有key都应有所有模型)
            # 当前实现是获取该提供商类型下出现过的所有基础模型名
            sql = """
            SELECT DISTINCT SUBSTRING_INDEX(models, '/', -1) as model_name
            FROM channels
            WHERE type = %s AND (`name` LIKE %s OR `name` LIKE %s)
            """
            params = (channel_type, f"{provider}-%", f"{provider}/%")
            print(f"调试: 查询提供商 '{provider}' 在数据库中出现过的所有模型 (类型: {channel_type})")

        # 执行查询
        cursor.execute(sql, params)
        results = cursor.fetchall() # 获取所有结果行

        # 处理查询结果，提取模型类型名称，并过滤掉负载均衡和主备切换的衍生名称
        existing_model_types = set() # 使用集合以便快速查找
        for row in results:
            model_name_suffix = row[0] # 获取 'ModelType' 或 'ModelType-balance' 等
            # 移除可能的 '-balance' 或 '-primary' 后缀以得到基础模型类型名称
            if model_name_suffix.endswith("-balance"):
                base_model_type = model_name_suffix[:-len("-balance")]
            elif model_name_suffix.endswith("-primary"):
                base_model_type = model_name_suffix[:-len("-primary")]
            else:
                base_model_type = model_name_suffix
            # 只有当模型名称不为空时才添加
            if base_model_type:
                existing_model_types.add(base_model_type)

        # 获取 MODEL_LIBRARY 中该提供商预设的所有模型
        library_models = MODEL_LIBRARY.get(provider, [])
        if not library_models:
            print(f"警告: MODEL_LIBRARY 中未定义提供商 '{provider}' 的模型。")
            return [] # 没有库模型，自然没有新模型

        # --- 调试输出 ---
        print(f"\n调试: 数据库中找到的 '{provider}' 基础模型类型:")
        if existing_model_types:
            for model_type in sorted(list(existing_model_types)):
                print(f"  - {model_type}")
        else:
            print("  (无)")

        print(f"\n调试: MODEL_LIBRARY 中定义的 '{provider}' 模型:")
        library_model_types = set()
        if library_models:
            for model in library_models:
                print(f"  - {model['model_type']} (ID: {model['model_id']})")
                library_model_types.add(model['model_type'])
        else:
             print("  (无)")
        # --- 调试结束 ---

        # 找出在 MODEL_LIBRARY 中存在，但在数据库中不存在 (existing_model_types) 的模型
        new_models = []
        for model in library_models:
            if model["model_type"] not in existing_model_types:
                new_models.append(model) # 将缺失的模型信息（字典）添加到新模型列表

        if new_models:
            print(f"信息: 发现 {len(new_models)} 个在 MODEL_LIBRARY 中但数据库" + (f" (密钥 {target_key[:5]}***)" if target_key else "") + f" 中缺失的模型。")
        else:
            print(f"信息: 数据库" + (f" (密钥 {target_key[:5]}***)" if target_key else "") + f" 已包含 MODEL_LIBRARY 中 '{provider}' 的所有模型。")

        return new_models # 返回找到的新模型列表

    except mysql.connector.Error as err:
        print(f"数据库错误 (find_new_models): {err}")
        return [] # 出错时返回空列表
    finally:
        if cursor is not None:
            cursor.close()
        if conn is not None and conn.is_connected():
            conn.close()


def sync_provider_models(provider, target_key=None):
    """
    同步指定提供商的模型。
    它会查找数据库中该提供商的现有 API 密钥，然后对于每个密钥，
    检查其是否缺少 MODEL_LIBRARY 中定义的模型，如果缺少则进行添加。
    可以指定 target_key 只同步一个密钥。

    Args:
        provider (str): 要同步的提供商名称。
        target_key (str, optional): 如果提供，则只同步这个特定的 API 密钥。
                                    默认为 None，同步该提供商所有找到的密钥。

    Returns:
        int: 总共为该提供商添加的模型记录数量 (一个模型会添加多条记录，这里指模型种类数)。
    """
    print(f"\n--- 开始同步提供商: {provider} ---")

    # 1. 获取该提供商的数据库配置
    channel_type, db_config = get_config_by_provider(provider)

    # 2. 检查 MODEL_LIBRARY 是否有该提供商的模型定义
    all_library_models = MODEL_LIBRARY.get(provider, [])
    if not all_library_models:
        print(f"错误: MODEL_LIBRARY 中未找到提供商 '{provider}' 的预设模型。无法同步。")
        return 0 # 返回添加了 0 个模型

    print(f"\n信息: MODEL_LIBRARY 中为 '{provider}' 定义了 {len(all_library_models)} 个模型:")
    for i, model in enumerate(all_library_models):
        print(f"  {i+1}. {model['model_type']} (ID: {model['model_id']})")

    # 3. 获取数据库中存在的密钥列表
    existing_keys_data = []
    if target_key:
        # 如果指定了目标密钥，只查询这一个
        print(f"\n信息: 正在查找指定的 API 密钥: {target_key[:5]}***")
        existing_keys_data = get_existing_keys(provider, target_key)
        if not existing_keys_data:
            print(f"错误: 未在数据库中找到提供商 '{provider}' 的密钥 '{target_key}'。请检查输入。")
            return 0 # 未找到指定密钥，返回 0
        print(f"信息: 找到目标密钥 {target_key[:5]}***。")
    else:
        # 如果没有指定目标密钥，查询该提供商的所有密钥
        print(f"\n信息: 正在查找提供商 '{provider}' 在数据库中的所有现有 API 密钥...")
        existing_keys_data = get_existing_keys(provider)
        if not existing_keys_data:
            print(f"信息: 未在数据库中找到提供商 '{provider}' 的任何现有 API 密钥。可能需要先使用选项 '1' 添加。")
            return 0 # 未找到任何密钥，返回 0
        print(f"\n信息: 找到 {len(existing_keys_data)} 个 '{provider}' 的现有 API 密钥:")
        for i, key_data in enumerate(existing_keys_data):
            # 打印部分密钥和 Base URL
            masked_key = key_data["key"][:5] + "***"
            print(f"  {i+1}. Key: {masked_key} (Base URL: '{key_data['base_url']}')")

    # 4. 遍历每个找到的密钥，进行同步
    total_added_count = 0 # 记录总共添加了多少个新模型种类
    num_keys = len(existing_keys_data)
    for idx, key_data in enumerate(existing_keys_data):
        current_key = key_data["key"]
        print(f"\n[{idx+1}/{num_keys}] 开始处理密钥: {current_key[:5]}***")

        # 4.1 查找该密钥下缺失的模型
        # 注意：find_new_models 现在需要 db_config 作为参数
        missing_models = find_new_models(provider, db_config, current_key)

        # 4.2 如果有缺失的模型，则调用 sync_new_models 进行添加
        if missing_models:
            print(f"信息: 密钥 {current_key[:5]}*** 缺少 {len(missing_models)} 个模型，开始同步...")
            # 调用函数来为这个 key 添加这些 missing_models
            sync_new_models(provider, key_data, missing_models)
            total_added_count += len(missing_models) # 累加添加的模型种类数
            print(f"完成: 密钥 {current_key[:5]}*** 的模型同步已完成。")
        else:
            # 如果没有缺失的模型，打印提示信息
            print(f"信息: 密钥 {current_key[:5]}*** 已包含 MODEL_LIBRARY 中 '{provider}' 的所有模型，无需同步。")

    # 5. 同步完成，打印总结信息
    print(f"\n--- 提供商 {provider} 同步完成 ---")
    if total_added_count > 0:
        print(f"总结: 总共为提供商 '{provider}' 的 {num_keys} 个密钥添加了 {total_added_count} 种新模型（每种模型对应多条数据库记录）。")
    else:
        if existing_keys_data: # 只有在处理了至少一个key时才说它们都是最新的
             print(f"总结: 提供商 '{provider}' 的所有已检查密钥都已是最新状态，未添加新模型。")
        # else 分支的提示信息已在前面获取密钥时给出

    return total_added_count # 返回添加的模型种类总数


def main():
    """
    主函数，程序的入口点。
    提供用户交互菜单，根据用户选择执行不同的操作：
    1. 插入新的提供商和模型。
    2. 同步指定提供商的现有密钥。
    3. 同步所有已配置提供商的现有密钥。
    """
    print("\n======================================")
    print("======= API 模型批量导入/同步工具 =======")
    print("======================================")

    # 显示操作选项菜单
    print("\n请选择操作类型:")
    print("  1. 插入新提供商和模型 (适用于首次添加密钥和模型)")
    print("  2. 同步指定提供商的现有密钥与 MODEL_LIBRARY (更新单个提供商)")
    print("  3. 同步所有提供商的现有密钥与 MODEL_LIBRARY (批量更新所有)")

    # 获取用户输入的操作类型，默认为 "1"
    op_type = input("\n请输入选项编号 (按 Enter 默认选 1): ").strip() or "1"

    try:
        # --- 操作类型 1: 插入新提供商和模型 ---
        if op_type == "1":
            print("\n--- 操作: 插入新提供商和模型 ---")
            # 选择提供商
            print("\n可用的提供商:")
            providers = list(PROVIDER_CONFIGS.keys())
            for i, provider in enumerate(providers):
                print(f"  {i+1}. {provider}")

            try:
                provider_idx_str = input("\n请选择提供商 (输入数字编号): ").strip()
                if not provider_idx_str.isdigit():
                    print("错误: 请输入数字。")
                    return
                provider_idx = int(provider_idx_str) - 1
                if not (0 <= provider_idx < len(providers)):
                    print("错误: 无效的提供商选项。")
                    return

                selected_provider = providers[provider_idx]
                print(f"\n已选择提供商: {selected_provider}")

                # 输入 API 密钥
                key = input(f"请输入 {selected_provider} 的 API 密钥: ").strip()
                if not key:
                    print("错误: API 密钥不能为空。")
                    return

                # 输入 Base URL (可选)
                default_url = DEFAULT_BASE_URLS.get(selected_provider, "")
                base_url_prompt = f"请输入 {selected_provider} 的 API 基础 URL "
                if default_url:
                    base_url_prompt += f"[可选, 按 Enter 使用默认值: '{default_url}']: "
                else:
                    base_url_prompt += "[可选, 按 Enter 跳过]: "
                base_url = input(base_url_prompt).strip()
                if not base_url: # 如果用户直接回车
                    base_url = default_url # 使用默认值 (可能是空字符串)

                # 显示该提供商可用的预设模型
                available_models = MODEL_LIBRARY.get(selected_provider, [])
                if not available_models:
                    print(f"错误: MODEL_LIBRARY 中未定义提供商 '{selected_provider}' 的模型。")
                    return

                print(f"\n{selected_provider} 在 MODEL_LIBRARY 中定义的模型:")
                for i, model in enumerate(available_models):
                    print(f"  {i+1}. {model['model_type']} (ID: {model['model_id']})")

                # 让用户选择要插入的模型
                selected_indices_str = input("\n请输入要插入的模型编号 (用逗号分隔, 例如 '1,3'。按 Enter 插入以上所有模型): ").strip()

                selected_models_to_insert = []
                if selected_indices_str:
                    try:
                        indices = [int(idx.strip()) - 1 for idx in selected_indices_str.split(",") if idx.strip().isdigit()]
                        # 过滤掉无效的索引
                        valid_indices = [idx for idx in indices if 0 <= idx < len(available_models)]
                        if not valid_indices:
                             print("警告: 未选择任何有效模型编号，将尝试插入所有模型。")
                             selected_models_to_insert = available_models
                        else:
                            selected_models_to_insert = [available_models[idx] for idx in valid_indices]
                            print(f"\n已选择 {len(selected_models_to_insert)} 个模型进行插入:")
                            for model in selected_models_to_insert:
                                print(f"  - {model['model_type']}")
                    except ValueError:
                        print("错误: 输入的编号格式不正确 (非数字或无效逗号分隔)。将尝试插入所有模型。")
                        selected_models_to_insert = available_models
                else:
                    # 用户直接回车，选择所有模型
                    print("\n信息: 将插入所有可用的模型。")
                    selected_models_to_insert = available_models

                # 执行插入操作
                if selected_models_to_insert:
                    insert_provider_models(selected_provider, key, base_url, selected_models_to_insert)
                else:
                    print("错误: 没有模型被选中或可用，无法执行插入。")


            except KeyboardInterrupt:
                print("\n操作已取消。")
            except Exception as e:
                print(f"\n处理提供商选择或模型插入时发生错误: {e}")

        # --- 操作类型 2: 同步指定提供商的模型 ---
        elif op_type == "2":
            print("\n--- 操作: 同步指定提供商的现有密钥与 MODEL_LIBRARY ---")
            # 选择提供商
            print("\n可用的提供商:")
            providers = list(PROVIDER_CONFIGS.keys())
            for i, provider in enumerate(providers):
                print(f"  {i+1}. {provider}")

            try:
                provider_idx_str = input("\n请选择要同步的提供商 (输入数字编号): ").strip()
                if not provider_idx_str.isdigit():
                    print("错误: 请输入数字。")
                    return
                provider_idx = int(provider_idx_str) - 1
                if not (0 <= provider_idx < len(providers)):
                    print("错误: 无效的提供商选项。")
                    return

                selected_provider = providers[provider_idx]
                print(f"\n已选择提供商: {selected_provider}")

                # 询问是否只同步特定密钥
                sync_specific_key_choice = input(f"是否只同步 {selected_provider} 的某个特定 API 密钥? (y/n, 默认 n): ").strip().lower() or "n"
                target_sync_key = None
                if sync_specific_key_choice == 'y':
                    target_sync_key = input(f"请输入要同步的 {selected_provider} API 密钥: ").strip()
                    if not target_sync_key:
                        print("错误: 未输入要同步的特定密钥。")
                        return
                    print(f"信息: 将只尝试同步密钥 {target_sync_key[:5]}***")

                # 执行同步操作 (传入提供商和可选的目标密钥)
                sync_provider_models(selected_provider, target_sync_key)

            except KeyboardInterrupt:
                print("\n操作已取消。")
            except Exception as e:
                print(f"\n处理提供商同步时发生错误: {e}")

        # --- 操作类型 3: 同步所有提供商的模型 ---
        elif op_type == "3":
            print("\n--- 操作: 同步所有提供商的现有密钥与 MODEL_LIBRARY ---")
            providers_to_sync = list(PROVIDER_CONFIGS.keys())
            total_providers = len(providers_to_sync)
            print(f"信息: 将尝试同步以下 {total_providers} 个提供商: {', '.join(providers_to_sync)}")

            # 询问是否只同步特定密钥 (适用于所有提供商)
            sync_specific_key_choice_all = input(f"是否只同步某个特定的 API 密钥 (如果该密钥存在于多个提供商下)? (y/n, 默认 n): ").strip().lower() or "n"
            target_sync_key_all = None
            if sync_specific_key_choice_all == 'y':
                target_sync_key_all = input("请输入要同步的 API 密钥: ").strip()
                if not target_sync_key_all:
                    print("错误: 未输入要同步的特定密钥。")
                    return
                print(f"信息: 将在所有提供商中尝试只同步密钥 {target_sync_key_all[:5]}***")

            # 遍历所有提供商进行同步
            total_models_added_across_all = 0
            errors_occurred = False
            for i, provider in enumerate(providers_to_sync):
                print(f"\n======= 处理提供商 [{i+1}/{total_providers}]: {provider} =======")
                try:
                    # 对每个提供商调用同步函数，传入可选的目标密钥
                    added_count = sync_provider_models(provider, target_sync_key_all)
                    total_models_added_across_all += added_count
                except KeyboardInterrupt:
                    print(f"\n操作在处理 {provider} 时被用户取消。")
                    errors_occurred = True
                    break # 中断整个循环
                except Exception as e:
                    print(f"\n处理提供商 {provider} 时发生严重错误: {e}")
                    errors_occurred = True
                    # 可以选择继续处理下一个提供商 (continue) 或中断 (break)
                    # 这里选择继续
                    continue

            # 打印最终总结
            print("\n======= 所有提供商同步操作完成 =======")
            if errors_occurred:
                print("警告: 在同步过程中发生了一个或多个错误。")
            print(f"总结: 所有提供商总共添加了 {total_models_added_across_all} 种新模型记录。")

        # --- 无效的操作类型 ---
        else:
            print(f"错误: 无效的操作类型选项 '{op_type}'。请输入 1, 2 或 3。")

    except KeyboardInterrupt:
        # 捕获顶层的 Ctrl+C 中断
        print("\n\n操作已被用户中断。程序退出。")
    except Exception as e:
        # 捕获其他未预料的全局错误
        print(f"\n发生未处理的异常: {e}")
        import traceback
        traceback.print_exc() # 打印详细的错误堆栈信息

    print("\n程序执行结束。")

# Python 程序入口点
if __name__ == "__main__":
    # 当脚本被直接执行时，调用 main() 函数
    main()
