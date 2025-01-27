#!/bin/bash

set -e  # 遇到错误时退出脚本

# 颜色输出
GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${GREEN}🔄 更新系统软件包...${RESET}"
sudo apt update && sudo apt upgrade -y

echo -e "${GREEN}📦 安装必要的软件包...${RESET}"
sudo apt install -y ca-certificates curl gnupg

echo -e "${GREEN}🔑 添加 Docker 官方 GPG 密钥...${RESET}"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo -e "${GREEN}🌍 添加 Docker 官方软件源...${RESET}"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo -e "${GREEN}🔄 更新软件包索引...${RESET}"
sudo apt update

echo -e "${GREEN}🐳 安装 Docker...${RESET}"
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo -e "${GREEN}✅ 验证 Docker 是否安装成功...${RESET}"
sudo docker version
sudo docker run --rm hello-world

echo -e "${GREEN}⚙️ 设置 Docker 开机自启...${RESET}"
sudo systemctl enable --now docker

# 允许非 root 用户运行 Docker（可选）
read -p "🚀 是否允许当前用户 ($USER) 免 sudo 运行 Docker？(y/n): " ADD_USER
if [[ "$ADD_USER" == "y" || "$ADD_USER" == "Y" ]]; then
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ 用户 $USER 已添加到 docker 组，请重新登录或重启系统生效.${RESET}"
fi

# 配置国内镜像加速（可选）
read -p "🌏 是否配置国内 Docker 镜像加速？(y/n): " SET_MIRROR
if [[ "$SET_MIRROR" == "y" || "$SET_MIRROR" == "Y" ]]; then
    echo -e "${GREEN}⚡ 配置国内镜像加速...${RESET}"
    sudo mkdir -p /etc/docker
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com",
    "https://registry.docker-cn.com"
  ]
}
EOF
    sudo systemctl restart docker
    echo -e "${GREEN}✅ 镜像加速配置完成.${RESET}"
fi

echo -e "${GREEN}🎉 Docker 安装完成！请使用 'docker run hello-world' 进行测试.${RESET}"
