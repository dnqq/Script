# Script

## delete_empty_folders.sh 删除空文件夹 
### 修改/path/to/your/folder
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/delete_empty_folders.sh | bash -s /path/to/your/folder
``
### 在当前目录运行
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/delete_empty_folders.sh | bash -s .
``

## install_tools.sh debian/ubuntu一键安装常用工具
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_tools.sh | bash
``

## upload_backup. 备份文件夹到webdav
### 修改参数
    u) USER=${OPTARG} ;;  # WebDAV用户名
    p) PASSWORD=${OPTARG} ;;  # WebDAV密码
    f) SOURCE_FOLDER=${OPTARG} ;;  # 待压缩文件夹路径
    s) SERVER_ID=${OPTARG} ;;  # 服务器标识
    d) DESTINATION_URL=${OPTARG} ;;  # WebDAV服务器的URL
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/upload_backup.sh | bash -s -- -u your_username -p your_password -s your_server_id -d https://dav.com/dav -f /path/to/folder
``