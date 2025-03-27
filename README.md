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
   ```bash
   # 修改 `/path/to/your/folder`
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/delete_empty_folders.sh | bash -s /path/to/your/folder
   
   # 在当前目录运行
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/delete_empty_folders.sh | bash -s .
   ```

2. **clean_empty_dirs.sh** - 清理空目录
   ```bash
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/clean_empty_dirs.sh | bash
   ```

3. **find_empty_dirs.sh** - 查找空目录
   ```bash
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/find_empty_dirs.sh | bash
   ```

4. **enable_swap.sh** - 启用交换空间
   ```bash
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/enable_swap.sh | bash
   ```

### 备份工具
5. **upload_backup.sh** - 备份文件夹到 WebDAV
   ```bash
   # 修改参数：  
   # -u - WebDAV 用户名  
   # -p - WebDAV 密码  
   # -f - 待压缩文件夹路径  
   # -s - 服务器标识，用于构建上传路径  
   # -d - WebDAV 服务器的 URL  
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/upload_backup.sh | bash -s -- -u your_username -p your_password -s your_server_id -d https://dav.com/dav -f /path/to/folder
   ```

### 网络工具
6. **iptables_redirect.sh** - iptables 端口转发
   ```bash
   # 修改参数：  
   # transfer_port - 本地端口  
   # target_domain_or_ip - 目标服务器域名或 IP（域名会被解析成 IP 后写入规则）  
   # target_port - 目标服务器端口  
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/iptables_redirect.sh | bash -s <transfer_port> <target_domain_or_ip> <target_port>
   ```

7. **iptables_reset.sh** - iptables 清除所有规则
   ```bash
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/iptables_reset.sh | bash
   ```

### Docker 安装工具
8. **install_docker.sh** - 一键安装 Docker
   ```bash
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_docker.sh | bash
   ```

### 应用程序安装脚本
9. **install_alist.sh** - 一键部署 Alist 文件列表程序
   ```bash
   curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_alist.sh | bash
   ```

10. **install_freshrss.sh** - 一键部署 FreshRSS 阅读器
    ```bash
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_freshrss.sh | bash
    ```

11. **install_frpc.sh** - 一键安装 frp 客户端
    ```bash
    # 默认版本
    curl -O https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_frpc.sh && chmod +x install_frpc.sh && ./install_frpc.sh
    
    # 指定版本
    curl -O https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_frpc.sh && chmod +x install_frpc.sh && ./install_frpc.sh 0.61.1
    ```

12. **install_frps.sh** - 一键安装 frp 服务端
    ```bash
    # 默认版本
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_frps.sh | bash
    
    # 指定版本
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_frps.sh | bash -s 0.61.1
    ```

13. **install_memos.sh** - 一键部署 Memos 笔记应用
    ```bash
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_memos.sh | bash
    ```

14. **install_nginx_proxy_manager.sh** - 一键部署 nginx_proxy_manager
    ```bash
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_nginx_proxy_manager.sh | bash
    ```

15. **install_rsshub.sh** - 一键部署 RSSHub RSS生成器
    ```bash
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_rsshub.sh | bash
    ```

16. **install_syncthing.sh** - 一键部署 Syncthing 文件同步工具
    ```bash
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_syncthing.sh | bash
    ```

17. **install_tools.sh** - Debian/Ubuntu 一键安装常用工具
    ```bash
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_tools.sh | bash
    ```

### 特定用途脚本
18. **guomang_qb_move.sh** - 国漫 QB 移动脚本
    ```bash
    curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/guomang_qb_move.sh | bash
    ```

## Python 脚本

1. **music_tag_processor.py** - 音乐标签处理工具
   
   这个脚本可以批量处理音乐文件的标签，功能包括：
   - 支持多种音频格式：MP3、FLAC、OGG、M4A、WMA、WAV
   - 自动转换繁体标签为简体
   - 按照"艺术家/专辑"目录结构整理音乐文件
   - 标准化文件命名为"艺术家 - 标题"格式
   
   使用方法：
   ```python
   # 修改脚本中的source_folder和destination_folder路径
   python music_tag_processor.py
   ```

## PowerShell 脚本

1. **SetNetwork.ps1** - Windows网络配置管理工具
   
   这个脚本提供了一个交互式界面，用于快速切换Windows网络配置：
   - 支持固定IP和DHCP配置模式
   - 可以设置不同的网关和DNS服务器
   - 提供一键清除DNS缓存功能
   - 显示当前网络配置状态
   
   使用方法：
   ```powershell
   # 以管理员权限运行
   # 可能需要先设置执行策略：Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
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