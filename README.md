# Script

## delete_empty_folders.sh 删除空文件夹 
### 修改/path/to/your/folder
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/delete_empty_folders.sh | bash -s /path/to/your/folder
``
### 在当前目录运行
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/delete_empty_folders.sh | bash -s .
``

## install_docker.sh 一键安装docker
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_docker.sh | bash
``

## install_tools.sh debian/ubuntu 一键安装常用工具
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/install_tools.sh | bash
``

## iptables_redirect.sh iptables端口转发
### 修改参数
transfer_port 本地端口
target_domain_or_ip 目标服务器域名或IP，域名会被解析成IP后写入规则
target_port 目标服务器端口
``curl -s https://raw.githubusercontent.com/AshinLin/Script/main/shell/iptables_redirect.sh | bash -s <transfer_port> <target_domain_or_ip> <target_port>
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

