#!/bin/bash

set -e  # 遇到错误时退出脚本

# 颜色输出
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

# 检测系统类型
echo -e "${GREEN}🔍 检测系统类型...${RESET}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [ -f /etc/redhat-release ]; then
    OS="rhel"
else
    echo -e "${RED}❌ 无法确定系统类型${RESET}"
    exit 1
fi

echo -e "${GREEN}🖥️ 检测到系统: $OS${RESET}"

# 更新系统软件包
echo -e "${GREEN}🔄 更新系统软件包...${RESET}"
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    sudo apt update && sudo apt upgrade -y
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
    sudo yum update -y
else
    echo -e "${RED}❌ 不支持的系统类型: $OS${RESET}"
    exit 1
fi

# 安装必要的软件包
echo -e "${GREEN}📦 安装必要的软件包...${RESET}"
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    sudo apt install -y ca-certificates curl gnupg lsb-release
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
else
    echo -e "${RED}❌ 不支持的系统类型: $OS${RESET}"
    exit 1
fi

# 添加 Docker 仓库
echo -e "${GREEN}🔑 添加 Docker 仓库...${RESET}"
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
    sudo yum-config-manager --add-repo https://download.docker.com/linux/$OS/docker-ce.repo
else
    echo -e "${RED}❌ 不支持的系统类型: $OS${RESET}"
    exit 1
fi

# 安装 Docker
echo -e "${GREEN}🐳 安装 Docker...${RESET}"
if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "fedora" ]; then
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    echo -e "${RED}❌ 不支持的系统类型: $OS${RESET}"
    exit 1
fi

# 启动 Docker
echo -e "${GREEN}🚀 启动 Docker 服务...${RESET}"
sudo systemctl start docker

# 验证 Docker 安装
echo -e "${GREEN}✅ 验证 Docker 是否安装成功...${RESET}"
sudo docker version
sudo docker run --rm hello-world

# 设置 Docker 开机自启
echo -e "${GREEN}⚙️ 设置 Docker 开机自启...${RESET}"
sudo systemctl enable docker

echo -e "${GREEN}🎉 Docker 安装完成！请使用 'docker run hello-world' 进行测试.${RESET}"