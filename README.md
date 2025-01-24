# Script

## 删除空文件夹 delete_empty_folders.sh
### 修改/path/to/your/folder
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/delete_empty_folders.sh | bash -s /path/to/your/folder
``
### 在当前目录运行
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/delete_empty_folders.sh | bash -s .
``

## 备份文件夹到webdav upload_backup.sh
### 修改参数
    u) USER=${OPTARG} ;;  # WebDAV用户名
    p) PASSWORD=${OPTARG} ;;  # WebDAV密码
    f) SOURCE_FOLDER=${OPTARG} ;;  # 待压缩文件夹路径
    s) SERVER_ID=${OPTARG} ;;  # 服务器标识
     d) DESTINATION_URL=${OPTARG} ;;  # WebDAV服务器的URL
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/upload_backup.sh | bash -s -u your_username -p your_password -s your_server_id -d https://alist.739999.xyz/dav -f /path/to/folder
``