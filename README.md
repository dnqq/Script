# Script

这是一个实用脚本集合，包含多种类型的脚本用于自动化各种任务。集合包括Shell脚本、Python脚本、PowerShell脚本、Tampermonkey脚本和批处理脚本。

## 目录

- [Shell 脚本](#shell-脚本)
- [Python 脚本](#python-脚本)
- [PowerShell 脚本](#powershell-脚本)
- [Tampermonkey 脚本](#tampermonkey-脚本)
- [批处理脚本](#批处理脚本)

## Shell 脚本

### 文件管理
1. **delete_empty_folders.sh** - 删除空文件夹
   
   指定目标文件夹参数（必须）:
   ```bash
   curl -s https://script.739999.xyz/shell/delete_empty_folders.sh | bash -s /path/to/your/folder
   ```
   
   在当前目录运行:
   ```bash
   curl -s https://script.739999.xyz/shell/delete_empty_folders.sh | bash -s .
   ```

2. **clean_empty_dirs.sh** - 清理空目录
   ```bash
   curl -s https://script.739999.xyz/shell/clean_empty_dirs.sh | bash
   ```

3. **find_empty_dirs.sh** - 查找空目录
   ```bash
   curl -s https://script.739999.xyz/shell/find_empty_dirs.sh | bash
   ```

4. **enable_swap.sh** - 启用交换空间
   ```bash
   curl -s https://script.739999.xyz/shell/enable_swap.sh | bash
   ```

### 备份工具
5. **upload_backup.sh** - 备份文件夹到 WebDAV
   
   所有参数都是必需的：
   - -u - WebDAV 用户名  
   - -p - WebDAV 密码  
   - -f - 待压缩文件夹路径  
   - -s - 服务器标识，用于构建上传路径  
   - -d - WebDAV 服务器的 URL  
   
   ```bash
   curl -s https://script.739999.xyz/shell/upload_backup.sh | bash -s -- -u your_username -p your_password -s your_server_id -d https://dav.com/dav -f /path/to/folder
   ```

### 网络工具
6. **iptables_redirect.sh** - iptables 端口转发
   
   所有参数都是必需的：
   - transfer_port - 本地端口  
   - target_domain_or_ip - 目标服务器域名或 IP（域名会被解析成 IP 后写入规则）  
   - target_port - 目标服务器端口  
   
   ```bash
   curl -s https://script.739999.xyz/shell/iptables_redirect.sh | bash -s <transfer_port> <target_domain_or_ip> <target_port>
   ```

7. **iptables_reset.sh** - iptables 清除所有规则
   ```bash
   curl -s https://script.739999.xyz/shell/iptables_reset.sh | bash
   ```

### Docker 安装工具
8. **install_docker.sh** - 一键安装 Docker
   ```bash
   curl -s https://script.739999.xyz/shell/install_docker.sh | bash
   ```

### 应用程序安装脚本
9. **install_alist.sh** - 一键部署 Alist 文件列表程序
   ```bash
   curl -s https://script.739999.xyz/shell/install_alist.sh | bash
   ```
   
   服务启动后，将监听以下端口:
   - Web界面: `5244` - 访问地址：http://localhost:5244

10. **install_freshrss.sh** - 一键部署 FreshRSS 阅读器
    ```bash
    curl -s https://script.739999.xyz/shell/install_freshrss.sh | bash
    ```
    
    服务启动后，将监听以下端口:
    - Web界面: `8080` - 访问地址：http://localhost:8080

11. **install_frpc.sh** - 一键安装 frp 客户端
    
    无参数运行，使用最新版本:
    ```bash
    curl -O https://script.739999.xyz/shell/install_frpc.sh && chmod +x install_frpc.sh && ./install_frpc.sh
    ```
    
    指定版本（可选参数）:
    ```bash
    curl -O https://script.739999.xyz/shell/install_frpc.sh && chmod +x install_frpc.sh && ./install_frpc.sh 0.61.1
    ```
    
    安装过程中会要求输入:
    - FRP服务端IP地址
    - FRP服务端认证Token
    
    服务启动后，将监听以下端口:
    - Web管理界面: `7500` - 访问地址：http://localhost:7500
    - 默认用户名: `admin`
    - 密码: 安装过程中随机生成（执行脚本时会显示）

12. **install_frps.sh** - 一键安装 frp 服务端
    
    无参数运行，使用最新版本:
    ```bash
    curl -s https://script.739999.xyz/shell/install_frps.sh | bash
    ```
    
    指定版本（可选参数）:
    ```bash
    curl -s https://script.739999.xyz/shell/install_frps.sh | bash -s 0.61.1
    ```
    
    服务启动后，将监听以下端口:
    - FRP服务端口: `7000`
    - Web管理界面: `7500` - 访问地址：http://localhost:7500
    - 默认用户名: `admin`
    - 密码: 安装过程中随机生成（执行脚本时会显示）
    - 认证Token: 安装过程中随机生成（执行脚本时会显示）

13. **install_memos.sh** - 一键部署 Memos 笔记应用
    ```bash
    curl -s https://script.739999.xyz/shell/install_memos.sh | bash
    ```
    
    服务启动后，将监听以下端口:
    - Web界面: `5230` - 访问地址：http://localhost:5230

14. **install_new_api.sh** - 一键部署 new-api 服务
    
    方法1：下载后执行
    ```bash
    curl -O https://script.739999.xyz/shell/install_new_api.sh && chmod +x install_new_api.sh && ./install_new_api.sh
    ```
    
    方法2：直接执行
    ```bash
    curl -s https://script.739999.xyz/shell/install_new_api.sh | bash
    ```
    
    服务启动后，将监听以下端口:
    - Web界面: `3000` - 访问地址：http://localhost:3000

15. **install_nginx_proxy_manager.sh** - 一键部署 nginx_proxy_manager
    ```bash
    curl -s https://script.739999.xyz/shell/install_nginx_proxy_manager.sh | bash
    ```
    
    服务启动后，将监听以下端口:
    - HTTP: `80`
    - HTTPS: `443`
    - 管理界面: `34999` - 访问地址：http://localhost:34999
    - 默认登录信息:
      - 用户名: `admin@example.com`
      - 密码: `changeme`

16. **install_rsshub.sh** - 一键部署 RSSHub RSS生成器
    ```bash
    curl -s https://script.739999.xyz/shell/install_rsshub.sh | bash
    ```
    
    服务启动后，将监听以下端口:
    - Web界面: `1200` - 访问地址：http://localhost:1200

17. **install_syncthing.sh** - 一键部署 Syncthing 文件同步工具
    ```bash
    curl -s https://script.739999.xyz/shell/install_syncthing.sh | bash
    ```
    
    服务启动后，将监听以下端口:
    - Web管理界面: `8384` - 访问地址：http://localhost:8384
    - 数据传输端口: `22000` (TCP/UDP)
    - 本地发现端口: `21027` (UDP)

18. **install_tools.sh** - Debian/Ubuntu 一键安装常用工具
    ```bash
    curl -s https://script.739999.xyz/shell/install_tools.sh | bash
    ```

### 特定用途脚本
19. **guomang_qb_move.sh** - 国漫 QB 移动脚本
    ```bash
    curl -s https://script.739999.xyz/shell/guomang_qb_move.sh | bash
    ```

## Python 脚本

1. **music_tag_processor.py** - 音乐标签处理工具
   
   这个脚本可以批量处理音乐文件的标签，功能包括：
   - 支持多种音频格式：MP3、FLAC、OGG、M4A、WMA、WAV
   - 自动转换繁体标签为简体
   - 按照"艺术家/专辑"目录结构整理音乐文件
   - 标准化文件命名为"艺术家 - 标题"格式
   
   直接运行（需要先修改脚本中的source_folder和destination_folder路径）:
   ```python
   python music_tag_processor.py
   ```

## PowerShell 脚本

1. **SetNetwork.ps1** - Windows网络配置管理工具
   
   这个脚本提供了一个交互式界面，用于快速切换Windows网络配置：
   - 支持固定IP和DHCP配置模式
   - 可以设置不同的网关和DNS服务器
   - 提供一键清除DNS缓存功能
   - 显示当前网络配置状态
   
   以管理员权限运行
   
   设置执行策略:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
   ```
   
   执行脚本:
   ```powershell
   .\SetNetwork.ps1
   ```

## Tampermonkey 脚本

1. **ICVE课程资源下载.js** - 职教云课程资源批量下载工具
   
   这个脚本增强了职教云（ICVE）平台的功能，允许用户批量下载课程资源：
   - 支持按类型筛选资源（视频、文档、PPT）
   - 提供文件路径提示和文件去重功能
   - 显示下载队列状态
   - 支持一键复制资源链接
   
   安装方法：
   1. 安装Tampermonkey浏览器扩展
   2. 创建新脚本并粘贴代码
   3. 保存并启用脚本
   4. 访问ICVE课程页面，脚本将自动激活

## 批处理脚本

批处理脚本目录暂无内容。


## 许可

这些脚本仅供学习和个人使用，请遵守相关法律法规。