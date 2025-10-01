# Script

这是一个实用脚本集合，包含多种类型的脚本用于自动化各种任务。集合包括Shell脚本、Python脚本、PowerShell脚本、Tampermonkey脚本和批处理脚本。

## 目录

- [Shell 脚本](#shell-脚本-总览)
- [Python 脚本](#python-脚本-总览)
- [PowerShell 脚本](#powershell-脚本-总览)
- [Tampermonkey 脚本](#tampermonkey-脚本-总览)
- [批处理脚本](#批处理脚本)

## 脚本总览

<details open>
<summary>详细目录</summary>

<h3 id="shell-脚本-总览">Shell 脚本</h3>

- **文件管理**
  - [`manage_empty_dirs.sh`](#manage_empty_dirs.sh) - 管理空目录（查找、删除、安全清理）
  - [`enable_swap.sh`](#enable_swap.sh) - 一键为 Debian 系统创建并启用 Swap 分区
- **备份工具**
  - [`upload_backup.sh`](#upload_backup.sh) - 备份文件夹到 WebDAV
- **网络工具**
  - [`iptables_redirect.sh`](#iptables_redirect.sh) - iptables 端口转发
  - [`iptables_reset.sh`](#iptables_reset.sh) - iptables 清除所有规则
  - [`manage_ipv6.sh`](#manage_ipv6.sh) - 一键启用或禁用 Debian/Ubuntu 系统的 IPv6
- **应用程序安装脚本**
  - [`install_alist.sh`](#install_alist.sh) - 一键部署 Alist 文件列表程序
  - [`install_docker.sh`](#install_docker.sh) - 一键安装 Docker
  - [`install_freshrss.sh`](#install_freshrss.sh) - 一键部署 FreshRSS 阅读器
  - [`install_frpc.sh`](#install_frpc.sh) - 一键安装 frp 客户端
  - [`install_frps.sh`](#install_frps.sh) - 一键安装 frp 服务端
  - [`install_memos.sh`](#install_memos.sh) - 一键部署 Memos 笔记应用
  - [`install_mihomo.sh`](#install_mihomo.sh) - 一键部署 Mihomo 代理服务
  - [`install_new_api.sh`](#install_new_api.sh) - 一键部署 new-api 服务
  - [`install_nginx_proxy_manager.sh`](#install_nginx_proxy_manager.sh) - 一键部署 nginx_proxy_manager
  - [`install_rsshub.sh`](#install_rsshub.sh) - 一键部署 RSSHub RSS生成器
  - [`install_syncthing.sh`](#install_syncthing.sh) - 一键部署 Syncthing 文件同步工具
  - [`install_tools.sh`](#install_tools.sh) - Debian/Ubuntu 一键安装常用工具
  - [`install_vaultwarden.sh`](#install_vaultwarden.sh) - 一键部署 Vaultwarden 密码管理器
  - [`install_XrayR.sh`](#install_XrayR.sh) - 一键部署 XrayR 代理服务
- **特定用途脚本**
  - [`frp_service.sh`](#frp_service.sh) - 一键新增 FRP 服务并重启 FRP 客户端
  - [`qb_move_guomang.sh`](#qb_move_guomang.sh) - 国漫整理与移动脚本
  - [`qb_move_movies.sh`](#qb_move_movies.sh) - 移动电影文件
  - [`qb_move_tv_shows.sh`](#qb_move_tv_shows.sh) - 移动电视剧文件

<h3 id="python-脚本-总览">Python 脚本</h3>

- [`music_tag_processor.py`](#music_tag_processor.py) - 音乐标签处理工具
- [`navidrome.py`](#navidrome.py) - Navidrome AI 音乐管理助手
- [`moontv.py`](#moontv.py) - 视频源筛选与管理工具

<h3 id="powershell-脚本-总览">PowerShell 脚本</h3>

- [`SetNetwork.ps1`](#SetNetwork.ps1) - Windows网络配置管理工具
- [`Setup-ApiWallpaper.ps1`](#Setup-ApiWallpaper.ps1) - API壁纸自动更换工具

<h3 id="tampermonkey-脚本-总览">Tampermonkey 脚本</h3>

- [`ICVE课程资源下载（合集版）.js`](#ICVE课程资源下载合集版js) - 职教云课程资源批量下载工具
- [`ICVE课程资源下载（单文件版）.js`](#ICVE课程资源下载单文件版js) - 职教云课程资源单文件下载工具
- [`SPOC答题.js`](#SPOC答题js) - 智慧职教 SPOC 自动答题工具
- [`MOOC答题.js`](#MOOC答题js) - 智慧职教 MOOC 自动答题工具

</details>

## Shell 脚本

### 文件管理
<a id="manage_empty_dirs.sh"></a>
1. **manage_empty_dirs.sh** - 管理空目录

   一个多功能脚本，用于查找、删除和安全地清理空目录。

   **用法:**
   ```bash
   curl -s https://script.sqmn.eu.org/shell/manage_empty_dirs.sh | bash -s [action] [path]
   ```

   **参数说明:**
   - `action`: 操作类型 (必需)
     - `find`: 查找并列出指定路径下的所有空目录。
     - `delete`: 查找并删除空目录，执行前有简单的确认提示。
     - `clean`: 安全地清理空目录，提供倒计时确认和详细的删除结果统计，防止误操作。
   - `path`: 目标路径 (可选, 默认为当前目录)

   **示例:**

   查找当前目录下的空目录:
   ```bash
   curl -s https://script.sqmn.eu.org/shell/manage_empty_dirs.sh | bash -s find
   ```

   删除 `/path/to/your/folder` 下的空目录:
   ```bash
   curl -s https://script.sqmn.eu.org/shell/manage_empty_dirs.sh | bash -s delete /path/to/your/folder
   ```

   安全清理 `/path/to/your/folder` 下的空目录:
   ```bash
   curl -s https://script.sqmn.eu.org/shell/manage_empty_dirs.sh | bash -s clean /path/to/your/folder
   ```

<a id="enable_swap.sh"></a>
2. **enable_swap.sh** - 一键为 Debian 系统创建并启用 Swap 分区
   
   默认创建 2G Swap:
   ```bash
   curl -s https://script.sqmn.eu.org/shell/enable_swap.sh | bash
   ```
   
   指定 Swap 大小（如 4G）:
   ```bash
   curl -s https://script.sqmn.eu.org/shell/enable_swap.sh | bash -s 4
   ```
   
   注意：
   - 需要 root 权限运行
   - 如果系统中已存在 Swap 分区，脚本不会重复创建
   - Swap 文件位置：`/swapfile`
   - 系统重启后会自动启用

### 备份工具
<a id="upload_backup.sh"></a>
3. **upload_backup.sh** - 备份文件夹到 WebDAV
   
   功能强大的备份脚本，支持多文件夹备份、文件排除和自动清理远程旧备份。

   **参数说明:**
   - `-u` - WebDAV 用户名 (必需)
   - `-p` - WebDAV 密码 (必需)
   - `-s` - 服务器标识，用于构建上传路径 (必需)
   - `-d` - WebDAV 服务器的 URL (必需)
   - `-f` - 待压缩的文件夹路径 (可选, 可多次使用, 默认: /root)
   - `-e` - 要排除的子文件夹或文件模式 (可选, 可多次使用, 相对路径)
   - `-c` - 启用远程备份自动清理功能 (可选)
   
   **基础用法:**
   ```bash
   curl -s https://script.sqmn.eu.org/shell/upload_backup.sh | bash -s -- -u your_username -p your_password -s your_server_id -d https://dav.com/dav -f /path/to/folder
   ```

   **高级用法 (多文件夹备份并排除文件):**
   ```bash
   curl -s https://script.sqmn.eu.org/shell/upload_backup.sh | bash -s -- \
   -u your_username \
   -p your_password \
   -s your_server_id \
   -d https://dav.com/dav \
   -f /var/www/project1 \
   -f /home/user/documents \
   -e 'node_modules' \
   -e '*.log' \
   -c
   ```

### 网络工具
<a id="iptables_redirect.sh"></a>
4. **iptables_redirect.sh** - iptables 端口转发
   
   所有参数都是必需的：
   - transfer_port - 本地端口
   - target_domain_or_ip - 目标服务器域名或 IP（域名会被解析成 IP 后写入规则）
   - target_port - 目标服务器端口
   
   ```bash
   curl -s https://script.sqmn.eu.org/shell/iptables_redirect.sh | bash -s <transfer_port> <target_domain_or_ip> <target_port>
   ```

<a id="iptables_reset.sh"></a>
5. **iptables_reset.sh** - iptables 清除所有规则
   ```bash
   curl -s https://script.sqmn.eu.org/shell/iptables_reset.sh | bash
   ```

<a id="manage_ipv6.sh"></a>
6. **manage_ipv6.sh** - 一键启用或禁用 Debian/Ubuntu 系统的 IPv6
  
  该脚本通过修改 `/etc/sysctl.conf` 来启用或禁用 IPv6。

  **用法:**
  ```bash
  curl -s https://script.sqmn.eu.org/shell/manage_ipv6.sh | bash -s [action]
  ```

  **参数说明:**
  - `action`: 操作类型 (必需)
    - `disable`: 禁用 IPv6
    - `enable`: 启用 IPv6
  
  **示例:**

  禁用 IPv6:
  ```bash
  curl -s https://script.sqmn.eu.org/shell/manage_ipv6.sh | bash -s disable
  ```

  启用 IPv6:
  ```bash
  curl -s https://script.sqmn.eu.org/shell/manage_ipv6.sh | bash -s enable
  ```
  
  注意：
  - 需要 root 权限运行
  - `sysctl` 命令会立即应用配置到内核，但为确保所有服务（如 Docker）都应用新设置，**强烈建议**在执行脚本后重新启动系统。

### 应用程序安装脚本
<a id="install_alist.sh"></a>
7. **install_alist.sh** - 一键部署 Alist 文件列表程序
    ```bash
    curl -s https://script.sqmn.eu.org/shell/install_alist.sh | bash
    ```
    
    服务启动后，将监听以下端口:
    - Web界面: `5244` - 访问地址：http://localhost:5244

<a id="install_docker.sh"></a>
8. **install_docker.sh** - 一键安装 Docker
   ```bash
   curl -s https://script.sqmn.eu.org/shell/install_docker.sh | bash
   ```

<a id="install_freshrss.sh"></a>
9. **install_freshrss.sh** - 一键部署 FreshRSS 阅读器
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_freshrss.sh | bash
     ```
     
     服务启动后，将监听以下端口:
     - Web界面: `8080` - 访问地址：http://localhost:8080

<a id="install_frpc.sh"></a>
10. **install_frpc.sh** - 一键安装 frp 客户端
     
     无参数运行，使用最新版本:
     ```bash
     curl -O https://script.sqmn.eu.org/shell/install_frpc.sh && chmod +x install_frpc.sh && ./install_frpc.sh
     ```
     
     指定版本（可选参数）:
     ```bash
     curl -O https://script.sqmn.eu.org/shell/install_frpc.sh && chmod +x install_frpc.sh && ./install_frpc.sh 0.61.1
     ```
     
     安装过程中会要求输入:
     - FRP服务端IP地址
     - FRP服务端认证Token
     
     服务启动后，将监听以下端口:
     - Web管理界面: `7500` - 访问地址：http://localhost:7500
     - 默认用户名: `admin`
     - 密码: 安装过程中随机生成（执行脚本时会显示）

<a id="install_frps.sh"></a>
11. **install_frps.sh** - 一键安装 frp 服务端
     
     无参数运行，使用最新版本:
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_frps.sh | bash
     ```
     
     指定版本（可选参数）:
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_frps.sh | bash -s 0.61.1
     ```
     
     服务启动后，将监听以下端口:
     - FRP服务端口: `7000`
     - Web管理界面: `7500` - 访问地址：http://localhost:7500
     - 默认用户名: `admin`
     - 密码: 安装过程中随机生成（执行脚本时会显示）
     - 认证Token: 安装过程中随机生成（执行脚本时会显示）

<a id="install_memos.sh"></a>
12. **install_memos.sh** - 一键部署 Memos 笔记应用
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_memos.sh | bash
     ```
     
     服务启动后，将监听以下端口:
     - Web界面: `5230` - 访问地址：http://localhost:5230

<a id="install_mihomo.sh"></a>
13. **install_mihomo.sh** - 一键部署 Mihomo 代理服务

     功能全面的 Mihomo 管理脚本，支持 Docker 或二进制文件部署，提供菜单式交互，极大简化在服务器上配置和使用代理的过程。

     - **核心功能**:
       - **多种部署方式**: 支持 Docker 和 二进制文件 两种安装方式。
       - **多种代理模式**: 支持标准代理、本机透明代理 (TUN)、局域网透明网关。
       - **菜单驱动**: 提供清晰的菜单，用于安装、更新订阅、查看状态、测试、设置和清除代理、卸载等。
       - **代理测试**: 内置连通性测试，可快速检查代理可用性。
       - **系统代理设置**: 一键为 APT, Docker, 和当前系统环境设置或清除 HTTP 代理。
       - **统一目录**: 所有相关文件（配置、Compose 文件）均存放在 `/opt/mihomo`。

     - **推荐用法 (显示菜单)**:
       ```bash
       curl -LO https://script.sqmn.eu.org/shell/install_mihomo.sh && chmod +x install_mihomo.sh && ./install_mihomo.sh
       ```

     - **功能菜单选项**:
       1.  安装 Mihomo
       2.  更新订阅
       3.  查看当前 Mihomo 运行状态
       4.  运行所有连接测试
       5.  为软件/系统设置代理
       6.  清除代理配置
       7.  卸载 Mihomo
       0.  退出脚本

<a id="install_new_api.sh"></a>
14. **install_new_api.sh** - 一键部署 new-api 服务
     
     直接执行：
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_new_api.sh | bash
     ```
     
     服务启动后，将监听以下端口:
     - Web界面: `3000` - 访问地址：http://localhost:3000

<a id="install_nginx_proxy_manager.sh"></a>
15. **install_nginx_proxy_manager.sh** - 一键部署 nginx_proxy_manager
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_nginx_proxy_manager.sh | bash
     ```
     
     服务启动后，将监听以下端口:
     - HTTP: `80`
     - HTTPS: `443`
     - 管理界面: `34999` - 访问地址：http://localhost:34999
     - 默认登录信息:
       - 用户名: `admin@example.com`
       - 密码: `changeme`

<a id="install_rsshub.sh"></a>
16. **install_rsshub.sh** - 一键部署 RSSHub RSS生成器
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_rsshub.sh | bash
     ```
     
     服务启动后，将监听以下端口:
     - Web界面: `1200` - 访问地址：http://localhost:1200

<a id="install_syncthing.sh"></a>
17. **install_syncthing.sh** - 一键部署 Syncthing 文件同步工具
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_syncthing.sh | bash
     ```
     
     服务启动后，将监听以下端口:
     - Web管理界面: `8384` - 访问地址：http://localhost:8384
     - 数据传输端口: `22000` (TCP/UDP)
     - 本地发现端口: `21027` (UDP)

<a id="install_tools.sh"></a>
18. **install_tools.sh** - Debian/Ubuntu 一键安装常用工具
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_tools.sh | bash
     ```

<a id="install_vaultwarden.sh"></a>
19. **install_vaultwarden.sh** - 一键部署 Vaultwarden 密码管理器
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_vaultwarden.sh | bash
     ```
     
     服务启动后，将监听以下端口:
     - Web界面: `8687` - 访问地址：http://localhost:8687
     - 数据存储路径: `/opt/vaultwarden/vw-data`
     - 管理员Token: 安装时自动生成（请妥善保管，用于访问管理界面）

<a id="install_XrayR.sh"></a>
20. **install_XrayR.sh** - 一键部署 XrayR 代理服务
     
     带参数安装：
     ```bash
     curl -s https://script.sqmn.eu.org/shell/install_XrayR.sh | bash -s -- "api_host" "api_key" "node_id" "cert_domain" "email" "cf_token"
     ```
     
     安装过程中需要提供以下信息：
     - 面板地址 (ApiHost)
     - 面板密钥 (ApiKey)
     - 节点ID (NodeID)
     - 域名 (CertDomain)
     - 邮箱 (Email)
     - Cloudflare API Token
     
     配置文件路径：`/opt/XrayR/config/config.yml`

### 特定用途脚本
<a id="frp_service.sh"></a>
21. **frp_service.sh** - 一键新增 FRP 服务并重启 FRP 客户端

    这个脚本用于向 FRP 客户端配置文件中添加新的服务代理，并重启 FRP 客户端服务。

    **主要功能**:
    - 接受服务配置参数（名称、类型、本地IP、本地端口、远程端口）
    - 将新的服务配置添加到 frpc.toml 配置文件中
    - 自动识别 FRP 是二进制安装还是 Docker 安装
    - 根据安装方式重启相应的 FRP 客户端服务

    **使用方法**:

    1. 交互式运行脚本：
    ```bash
    curl -LO https://script.sqmn.eu.org/shell/frp_service.sh && chmod +x frp_service.sh && ./frp_service.sh
    ```

    2. 命令行参数运行脚本（使用命名参数）：
    ```bash
    curl -s https://script.sqmn.eu.org/shell/frp_service.sh | bash -s -- -n "服务名称" -l 3000 -r 3000
    ```

    3. 命令行参数运行脚本（可选参数）：
    ```bash
    curl -s https://script.sqmn.eu.org/shell/frp_service.sh | bash -s -- -n "服务名称" -l 3000 -r 3000 -t tcp -i 127.0.0.1
    ```

    **参数说明**:
    - `-n, --name`      服务名称（必需）
    - `-l, --local`     本地端口（必需）
    - `-r, --remote`    远程端口（必需）
    - `-t, --type`      服务类型，默认为 tcp
    - `-i, --ip`        本地IP，默认为 127.0.0.1（二进制安装）或宿主机IP（docker安装）

<a id="qb_move_guomang.sh"></a>
22. **qb_move_guomang.sh** - 国漫整理与移动脚本

    该脚本专门用于整理从 qBittorrent 下载的国漫视频文件，并将其移动到指定的媒体库目录（如 OneDrive）。

    - **核心功能**:
      - 扫描源目录中的视频文件（排除 `.!qB` 临时文件）。
      - **智能解析文件名**: 从 `[GM-Team][国漫][电视剧名称][...][集号][...][分辨率].mp4` 格式的文件名中自动提取电视剧名称、集号和分辨率。
      - **自动季号处理**: 如果剧集名称中包含 "第X季"，会自动提取季号。
      - **标准化重命名**: 将文件重命名为 `电视剧名称 - SXXEXX - 分辨率.mp4` 的标准格式。
      - **创建目录结构**: 在目标路径下，按 `电视剧名称/Season XX/` 的结构创建文件夹。
      - 自动清理处理后留下的空文件夹。

    - **默认目录**:
      - 源目录: `/opt/1panel/apps/qbittorrent/qbittorrent/data`
      - 目标目录: `/od_shipin/media/国漫`

    - **基础用法** (使用默认目录):
      ```bash
      curl -s https://script.sqmn.eu.org/shell/qb_move_guomang.sh | bash
      ```

    - **自定义目录用法**:
      ```bash
      curl -s https://script.sqmn.eu.org/shell/qb_move_guomang.sh | bash -s "/path/to/source" "/path/to/target"
      ```

<a id="qb_move_movies.sh"></a>
23. **qb_move_movies.sh** - 移动电影文件

    该脚本用于将指定目录下的电影文件移动到目标目录。

    - **功能**:
      - 扫描源目录中的所有文件（排除 `.!qB` 临时文件）。
      - 直接将文件移动到目标目录，不进行重命名。
      - 删除处理后留下的空文件夹。

    - **默认目录**:
      - 源目录: `/qBittorrent/complete/电影`
      - 目标目录: `/media/电影`

    - **基础用法**:
      ```bash
      curl -s https://script.sqmn.eu.org/shell/qb_move_movies.sh | bash
      ```

    - **自定义目录用法**:
      ```bash
      curl -s https://script.sqmn.eu.org/shell/qb_move_movies.sh | bash -s "/path/to/source" "/path/to/target"
      ```

<a id="qb_move_tv_shows.sh"></a>
24. **qb_move_tv_shows.sh** - 移动电视剧文件

    该脚本用于将指定目录下的电视剧文件移动到目标目录。

    - **功能**:
      - 扫描源目录中的所有文件（排除 `.!qB` 临时文件）。
      - 直接将文件移动到目标目录，不进行重命名。
      - 删除处理后留下的空文件夹。

    - **默认目录**:
      - 源目录: `/qBittorrent/complete/电视剧`
      - 目标目录: `/media/电视剧`

    - **基础用法**:
      ```bash
      curl -s https://script.sqmn.eu.org/shell/qb_move_tv_shows.sh | bash
      ```

    - **自定义目录用法**:
      ```bash
      curl -s https://script.sqmn.eu.org/shell/qb_move_tv_shows.sh | bash -s "/path/to/source" "/path/to/target"
      ```

## Python 脚本

<a id="music_tag_processor.py"></a>
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
   
<a id="navidrome.py"></a>
2. **navidrome.py** - Navidrome AI 音乐管理助手
   
   这是一个强大的 Navidrome 辅助工具，利用 AI（如 GPT、Gemini 等）来自动化音乐管理任务。

   **核心功能**:
   - **AI 批量评分**:
     - 并发处理整个音乐库，为专辑和歌曲进行 1-5 星评级。
     - AI 会根据歌曲的音乐性、歌词、情感和创新性等多个维度进行综合评价，并提供详细的评分理由。
     - 支持跳过已有评分的歌曲或强制覆盖评分。
     - 评分过程和理由会被记录到日志文件 `navidrome_ratings.log` 中。
   - **AI 歌单扩展**:
     - 分析现有歌单的风格、主题和情绪。
     - 从整个曲库中智能推荐最匹配的歌曲来扩展歌单。
     - 提供每首推荐歌曲的详细理由。
   - **数据缓存与同步**:
     - 对 Navidrome 的歌曲和专辑数据进行本地缓存（`navidrome_songs.json`, `navidrome_albums.json`），大幅提升后续操作的速度。
     - 支持强制与服务器同步数据，刷新本地缓存。
   - **统计功能**:
     - 显示音乐库的歌曲、专辑、艺术家总数。
     - 统计并展示已评分歌曲的星级分布。
     - 将所有已评分歌曲的列表导出到文件 `all_song_ratings.txt`。

   **如何使用**:
   1. **安装依赖**:
      ```bash
      pip install requests python-dotenv
      ```
   2. **配置环境**:
      - 复制 `.env.example` 文件为 `.env`。
      - 编辑 `.env` 文件，填入你的 Navidrome 服务器地址、用户名、密码以及 AI 服务的 API URL、Key 和模型名称。
   3. **运行脚本**:
      - 脚本提供了交互式菜单来选择不同功能。
      ```bash
      python python/navidrome.py
      ```
   4. **命令行参数**:
      - `--debug`: 使用调试模式，仅处理少量数据。
      - `--no-cache`: 运行时强制从服务器获取最新数据，不使用本地缓存。
      - `--clear-cache`: 启动时清空所有本地缓存文件。

<a id="moontv.py"></a>
3. **moontv.py** - 视频源筛选与管理工具

  这是一个用于处理和筛选 JSON 格式视频源列表的自动化脚本。它能合并新旧源、并发检查源的有效性，并通过用户交互来处理无法访问或内容可疑的源。

  **核心功能**:
  - **合并与去重**:
    - 自动加载 `moontv.json` (新源) 和 `moontv_filtered.json` (已筛选过的源)。
    - 基于 API URL 合并两个列表并移除重复项，优先保留已筛选过的数据。
  - **并发有效性检查**:
    - 使用多线程并发请求每个源的 API，快速检测其是否可访问。
    - 自动舍弃返回 404 错误的源。
  - **内容审查与交互式确认**:
    - (可选) 可配置 AI 服务（如 OpenAI/Gemini）来分析源内容，识别并标记疑似成人内容的源。
    - 对于无法访问或被标记的源，提供交互式命令行界面，由用户最终确认是否保留。
  - **结果输出**:
    - 将经过筛选和确认的有效源列表保存到 `moontv_filtered.json`，以备后续使用。

  **如何使用**:
  1. **安装依赖**:
     ```bash
     pip install requests python-dotenv
     ```
  2. **配置环境**:
     - 复制 `.env.example` 文件为 `.env`。
     - (可选) 如果需要使用 AI 内容审查功能，请在 `.env` 文件中填入你的 AI 服务 API 地址、密钥和模型名称。
  3. **准备源文件**:
     - 确保 `python/moontv.json` 文件存在且包含需要处理的视频源。
  4. **运行脚本**:
     ```bash
     python python/moontv.py
     ```

## PowerShell 脚本

<a id="SetNetwork.ps1"></a>
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

<a id="Setup-ApiWallpaper.ps1"></a>
2. **Setup-ApiWallpaper.ps1** - API壁纸自动更换工具

   这是一个全自动的 Windows 桌面壁纸管理工具，通过调用 API 接口定时下载并更换桌面壁纸。

   **核心功能**:
   - **自动化配置**: 一键创建壁纸更换脚本和 Windows 定时任务
   - **灵活配置**: 可自定义 API 地址和更换间隔（分钟）
   - **静默运行**: 使用 VBScript 包装器，后台运行完全无窗口干扰
   - **智能下载**: 自动添加 User-Agent 请求头，兼容各种 API
   - **详细日志**: 记录每次壁纸更换过程，便于调试和追踪
   - **文件验证**: 自动验证下载文件的有效性，防止损坏图片

   **如何使用**:

   1. **下载并运行安装脚本**:
      ```powershell
      # 下载脚本
      Invoke-WebRequest -Uri "https://script.sqmn.eu.org/PowerShell/Setup-ApiWallpaper.ps1" -OutFile "Setup-ApiWallpaper.ps1"

      # 以普通用户权限运行（不需要管理员权限）
      .\Setup-ApiWallpaper.ps1
      ```

   2. **配置参数**:
      - **API URL**: 输入壁纸 API 地址，或直接回车使用默认值 `https://random.sqmn.eu.org`
      - **更换间隔**: 输入间隔分钟数，或直接回车使用默认值 `10` 分钟

   3. **自动创建的文件**:
      - `%USERPROFILE%\Documents\AutoApiWallpaper\Set-ApiWallpaper.ps1` - 壁纸设置脚本
      - `%USERPROFILE%\Documents\AutoApiWallpaper\Run-Silent.vbs` - 静默运行包装器
      - `%USERPROFILE%\Documents\AutoApiWallpaper\api_wallpaper.jpg` - 下载的壁纸文件
      - `%USERPROFILE%\Documents\AutoApiWallpaper\wallpaper.log` - 运行日志

   4. **查看日志**:
      ```powershell
      Get-Content "$env:USERPROFILE\Documents\AutoApiWallpaper\wallpaper.log"
      ```

   5. **管理定时任务**:
      - 任务名称: `Auto API Wallpaper Changer`
      - 在"任务计划程序"中可以查看、暂停或删除任务
      - 或使用 PowerShell 命令:
        ```powershell
        # 查看任务状态
        Get-ScheduledTask -TaskName "Auto API Wallpaper Changer"

        # 手动运行一次
        Start-ScheduledTask -TaskName "Auto API Wallpaper Changer"

        # 禁用任务
        Disable-ScheduledTask -TaskName "Auto API Wallpaper Changer"

        # 删除任务
        Unregister-ScheduledTask -TaskName "Auto API Wallpaper Changer" -Confirm:$false
        ```

   **技术特点**:
   - 使用 Windows API (`SystemParametersInfo`) 直接设置壁纸，立即生效
   - 支持自定义壁纸样式（默认为"填充"模式，自动适配屏幕）
   - VBScript 包装器确保完全静默运行，无任何窗口闪现
   - 完善的错误处理和 UTF-8 编码日志记录

   **注意事项**:
   - 脚本会在 1 分钟后首次执行，之后按设置的间隔定期执行
   - 如果 API 返回 403 错误，脚本会自动添加浏览器 User-Agent 重试
   - 壁纸文件会被覆盖更新，不会占用过多磁盘空间
   - 定时任务即使在电池供电时也会运行

## Tampermonkey 脚本

<a id="ICVE课程资源下载合集版js"></a>
1. **ICVE课程资源下载（合集版）.js** - 职教云课程资源批量下载工具

   在 ICVE 课程主页提供一个功能强大的资源管理器，用于批量下载课程所有资源。

   - **核心功能**:
     - **资源管理器**: 弹出一个独立的界面，集中管理所有课程文件。
     - **批量下载**: 支持多选、全选文件，并加入下载队列进行批量下载。
     - **类型筛选**: 可按视频、文档、PPT等类型筛选文件。
     - **状态跟踪**: 清晰显示每个文件的下载状态（等待、下载中、完成、失败）。
     - **去重与路径提示**: 自动去除重复资源，并显示文件在课程中的路径。
     - **获取直链**: 支持一键复制单个文件的下载地址。
   - **使用页面**: `https://zyk.icve.com.cn/icve-study/coursePreview/courseIndex`

<a id="ICVE课程资源下载单文件版js"></a>
2. **ICVE课程资源下载（单文件版）.js** - 职教云课程资源单文件下载工具

   在 ICVE 课程的单个文件预览页面，添加一个悬浮按钮，用于快速下载当前页面正在预览的文件。

   - **核心功能**:
     - **精准下载**: 自动检测当前页面的文件并提供下载按钮。
     - **状态显示**: 按钮会显示文件检测、下载就绪、下载失败等状态。
     - **简单易用**: 无需复杂操作，进入页面即可下载。
   - **使用页面**: `*://zyk.icve.com.cn/icve-study/coursePreview/courseware?*`

<a id="SPOC答题js"></a>
3. **SPOC答题.js** - 智慧职教 SPOC 自动答题工具

   在智慧职教（SPOC）的作业或考试页面，通过 AI 实现一键自动答题。

   - **核心功能**:
     - **一键完成**: 点击 "AI一键答题" 按钮，自动完成页面上所有题目。
     - **全页处理**: 一次性提取页面所有题目（单选、多选、判断），发送给 AI 进行解答。
     - **自动填写**: 解析 AI 返回的答案并自动在页面上选择对应选项。
   - **配置要求**:
     - **需要自行配置 AI 接口**。请在脚本开头的配置区域填入你的 AI API 地址、API Key 和模型名称。
   - **使用页面**: `https://zjy2.icve.com.cn/study/spocjobTest*`

<a id="MOOC答题js"></a>
4. **MOOC答题.js** - 智慧职教 MOOC 自动答题工具

   在智慧职教（MOOC）的考试页面，通过 AI 实现逐题自动解答并自动跳转。

   - **核心功能**:
     - **逐题自动答题**: 点击 "AI一键答题" 后，脚本会自动解答当前题目，然后点击 "下一题"，并循环此过程。
     - **智能跳转**: 完成一题后，自动跳转到下一题，直到完成所有题目。
   - **配置要求**:
     - **需要自行配置 AI 接口**。请在脚本开头的配置区域填入你的 AI API 地址、API Key 和模型名称。
   - **使用页面**: `https://ai.icve.com.cn/preview-exam/*`

## 批处理脚本

批处理脚本目录暂无内容。


## 许可

这些脚本仅供学习和个人使用，请遵守相关法律法规。