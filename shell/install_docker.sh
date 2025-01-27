#!/bin/bash

# 开启错误检测：如果脚本中任何命令执行失败，则立即退出
set -e  

# 定义颜色输出
GREEN="\e[32m"
RESET="\e[0m"

# **🔍 1. 检查 Docker 是否已安装**
if command -v docker &> /dev/null; then
    # 获取当前已安装的 Docker 版本
    INSTALLED_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')

    echo -e "${GREEN}✅ 检测到 Docker 已安装，当前版本：$INSTALLED_VERSION${RESET}"
    
    # 提示用户是否升级 Docker
    read -p "⬆️ 是否升级 Docker？(y/n): " UPGRADE_DOCKER
    if [[ "$UPGRADE_DOCKER" == "y" || "$UPGRADE_DOCKER" == "Y" ]]; then
        echo -e "${GREEN}🔄 开始升级 Docker...${RESET}"
        
        # 更新软件包索引
        sudo apt update

        # 重新安装最新版本的 Docker
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        echo -e "${GREEN}✅ Docker 升级完成！${RESET}"
    else
        echo -e "${GREEN}⏭️ 跳过 Docker 升级.${RESET}"
    fi
else
    echo -e "${GREEN}🐳 开始安装 Docker...${RESET}"

    # **🔄 2. 更新系统软件包**
    sudo apt update && sudo apt upgrade -y

    # **📦 3. 安装必要的依赖包**
    sudo apt install -y ca-certificates curl gnupg

    # **🔑 4. 添加 Docker 官方 GPG 密钥**
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # **🌍 5. 添加 Docker 官方软件源**
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # **🔄 6. 更新软件包索引**
    sudo apt update

    # **🐳 7. 安装 Docker 及其相关组件**
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo -e "${GREEN}✅ Docker 安装完成！${RESET}"
fi

# **⚙️ 8. 确保 Docker 服务正在运行并开机自启**
echo -e "${GREEN}⚙️ 确保 Docker 运行中...${RESET}"
sudo systemctl enable --now docker

# **🚀 9. 允许非 root 用户使用 Docker（可选）**
read -p "🚀 是否允许当前用户 ($USER) 免 sudo 运行 Docker？(y/n): " ADD_USER
if [[ "$ADD_USER" == "y" || "$ADD_USER" == "Y" ]]; then
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ 用户 $USER 已添加到 docker 组，请重新登录或重启系统生效.${RESET}"
fi

# **🌏 10. 配置国内 Docker 镜像加速（可选）**
read -p "🌏 是否配置国内 Docker 镜像加速？(y/n): " SET_MIRROR
if [[ "$SET_MIRROR" == "y" || "$SET_MIRROR" == "Y" ]]; then
    echo -e "${GREEN}⚡ 配置国内镜像加速...${RESET}"
    
    # 创建 Docker 配置目录（如果不存在）
    sudo mkdir -p /etc/docker

    # 写入国内镜像源配置
    cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://hub-mirror.c.163.com",
    "https://registry.docker-cn.com"
  ]
}
EOF

    # **🔄 11. 重启 Docker 以应用镜像加速**
    sudo systemctl restart docker
    echo -e "${GREEN}✅ 镜像加速配置完成.${RESET}"
fi

# **🎉 12. 提示用户安装完成**
echo -e "${GREEN}🎉 Docker 安装与配置已完成！请使用 'docker run hello-world' 进行测试.${RESET}"
