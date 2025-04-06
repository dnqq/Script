#!/bin/bash

# ==================================================
# 程序的主要功能描述:
#   自动安装并配置 HAProxy 作为外部 Tinyproxy 实例的负载均衡器。
#   该脚本执行以下操作：
#   1. 创建指定的安装目录。
#   2. 生成 HAProxy 的配置文件 (haproxy.cfg)。如果提供了命令行参数
#      (Tinyproxy 服务器列表)，则会将这些服务器添加到配置中；否则，
#      会生成一个包含示例注释的模板文件，需要用户手动编辑。
#   3. 生成 Docker Compose 配置文件 (docker-compose.yml)，用于运行 HAProxy 服务。
#   4. 如果提供了服务器参数，则使用 Docker Compose 启动 HAProxy 服务。
#
# 程序的使用方法或调用示例:
#   1. 保存脚本: 将此内容保存为 install_haproxy_lb.sh。
#   2. 添加执行权限: chmod +x install_haproxy_lb.sh
#   3. 使用 root 用户或具有 Docker 权限的用户运行:
#      a) 带参数启动 (自动配置并启动 HAProxy):
#         sudo ./install_haproxy_lb.sh <服务器1IP>:<端口1>,<服务器2IP>:<端口2>[,<更多>]
#         例如: sudo ./install_haproxy_lb.sh 192.168.1.100:8888,192.168.1.101:8889
#      b) 不带参数运行 (仅生成配置文件，需手动编辑并启动):
#         sudo ./install_haproxy_lb.sh
#
# 启动后的代理入口: <运行HAProxy的服务器IP>:<HAPROXY_HOST_PORT配置的端口> (默认为 5556)
# 配置及数据存储路径: /root/app/haproxy_lb (可以通过修改下面的 INSTALL_DIR 变量更改)
#
# 重要提示:
#   - 当使用参数启动时，参数必须是逗号分隔的 "IP地址:端口号" 列表，中间不能有空格。
#   - 确保运行此脚本的服务器能够访问所有提供的 (或后续手动添加的) Tinyproxy 服务器的 IP 和端口。
#   - 确保所有后端 Tinyproxy 服务器已配置为允许来自运行此 HAProxy 脚本的服务器 IP 的连接请求。
#
# Author: ashin
# ==================================================

# --- Script Configuration Variables ---
# 定义 HAProxy 相关文件和配置的安装目录
# 请确保执行此脚本的用户对该路径具有创建目录和文件的权限。
INSTALL_DIR="/root/app/haproxy_lb"
# 定义 HAProxy 服务在宿主机上监听的端口号
# 客户端将通过 <宿主机IP>:<此端口> 来访问负载均衡服务。
HAPROXY_HOST_PORT="5556"
# 定义要使用的 HAProxy Docker 镜像及其版本标签
# 推荐使用官方稳定版本，例如 'haproxy:2.8', 'haproxy:latest'。
HAPROXY_IMAGE="haproxy:2.8"
# 定义 HAProxy 容器内部监听的端口号
# 这个端口需要在 haproxy.cfg 的 frontend 配置中被绑定 (`bind *:<端口>`)。
# 通常可以与宿主机端口 HAPROXY_HOST_PORT 保持一致，以便于理解。
HAPROXY_INTERNAL_PORT="5556"
# 定义后端服务器的负载均衡算法
# 可选值: roundrobin (轮询), leastconn (最少连接), source (源地址哈希) 等。
BALANCE_ALGORITHM="roundrobin"
# --- Configuration End ---

# --- Argument Handling ---
# 获取脚本的第一个命令行参数，该参数应为逗号分隔的 Tinyproxy 服务器列表 (格式: IP:Port,IP:Port)
# 如果没有提供参数，此变量将为空。
TINYPROXY_SERVERS_LIST=$1

# --- Prerequisite Checks ---
# 检查 'docker' 和 'docker compose' (v2) 命令是否存在且可执行
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    # 如果任一命令未找到，则输出错误信息并退出
    echo "错误：找不到 docker 或 docker compose 命令。" >&2 # 输出到 stderr
    echo "请确保 Docker 和 Docker Compose v2 已正确安装并运行。" >&2
    exit 1 # 以非零状态码退出，表示失败
fi

# --- Directory and File Preparation ---
echo "信息：正在创建安装目录: $INSTALL_DIR"
# 创建安装目录，使用 -p 选项可以避免在目录已存在时报错，并能创建多级父目录
mkdir -p "$INSTALL_DIR"
# 检查上一个命令（mkdir）的退出状态码。0 表示成功，非 0 表示失败。
if [ $? -ne 0 ]; then
    echo "错误：无法创建目录 $INSTALL_DIR。请检查权限或路径是否有效。" >&2
    exit 1 # 创建目录失败，退出脚本
fi

# 切换当前工作目录到安装目录
# 使用 '|| { ... }' 结构在 cd 命令失败时执行错误处理代码块
cd "$INSTALL_DIR" || { echo "错误：无法进入目录 $INSTALL_DIR"; exit 1; }
echo "信息：当前工作目录已切换到: $(pwd)" # 显示确认信息

# --- Generate HAProxy Configuration File (haproxy.cfg) ---
echo "信息：正在生成 HAProxy 配置文件: $INSTALL_DIR/haproxy.cfg"
# 使用 'cat <<EOF > filename' 结构 (here document) 将多行文本写入 haproxy.cfg 文件
# 这会覆盖已存在的同名文件
cat <<EOF > haproxy.cfg
# HAProxy 基础配置 - 由 install_haproxy_lb.sh 脚本自动生成

# 全局配置段
global
    log stdout format raw local0 info # 将 HAProxy 日志发送到标准输出 (stdout)，以便 Docker 可以捕获
    daemon                             # 以守护进程模式运行 HAProxy (在容器中通常需要，除非使用特定入口点)

# 默认配置段，应用于未显式覆盖这些设置的 frontend 和 backend
defaults
    log     global                   # 继承 global 段的日志设置
    mode    tcp                      # 设置默认工作模式为 TCP (适用于代理 TCP 连接，如 SSH、原始套接字代理等)
    option  tcplog                   # 启用 TCP 连接的日志记录格式
    timeout connect 10s              # 等待与后端服务器建立连接的超时时间 (10秒)
    timeout client  1m               # 客户端连接在无活动时的最大空闲时间 (1分钟)
    timeout server  1m               # 服务器端连接在无活动时的最大空闲时间 (1分钟)

# 前端定义：处理入站连接
frontend ft_proxy
    # HAProxy 在容器内部监听所有接口 (*) 的指定端口 (由变量 $HAPROXY_INTERNAL_PORT 定义)
    bind *:${HAPROXY_INTERNAL_PORT}
    mode tcp                         # 此前端工作在 TCP 模式
    default_backend bk_tinyproxies   # 将所有进入此前端的流量转发到名为 bk_tinyproxies 的后端

# 后端定义：包含实际提供服务的服务器组
backend bk_tinyproxies
    mode tcp                         # 此后端也工作在 TCP 模式
    balance ${BALANCE_ALGORITHM}     # 使用变量 $BALANCE_ALGORITHM 定义的负载均衡算法
    # 健康检查配置：启用 TCP 健康检查来探测后端服务器是否可用
    option tcp-check                 # 使用基本的 TCP 连接尝试作为健康检查方法

    # --- 后端 Tinyproxy 服务器列表将在此处添加 ---
    # (如果提供了命令行参数，服务器列表会由脚本自动添加)
    # (如果没有提供参数，用户需要手动在此处添加服务器条目)
EOF

# --- Generate Docker Compose File (docker-compose.yml) ---
# (无论是否提供了服务器参数，都需要生成 Docker Compose 文件)
echo "信息：正在生成 Docker Compose 文件: $INSTALL_DIR/docker-compose.yml"
# 使用 here document 将 Docker Compose 配置写入 docker-compose.yml
cat <<EOF > docker-compose.yml
version: '3.8' # 指定 Docker Compose 文件格式版本

services: # 定义服务列表
  haproxy: # 定义名为 'haproxy' 的服务
    image: ${HAPROXY_IMAGE} # 使用脚本配置中指定的 Docker 镜像
    container_name: haproxy_lb_service # 为此服务创建的容器指定一个固定的名称
    volumes: # 定义数据卷挂载
      # 将宿主机当前目录下的 haproxy.cfg 文件挂载到容器内的 HAProxy 配置路径
      # 使用 :ro 后缀表示在容器内为只读挂载，防止容器意外修改配置文件
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    ports: # 定义端口映射
      # 将宿主机的 ${HAPROXY_HOST_PORT} 端口映射到容器内部的 ${HAPROXY_INTERNAL_PORT} 端口
      # 格式为 "HOST_PORT:CONTAINER_PORT"
      - "${HAPROXY_HOST_PORT}:${HAPROXY_INTERNAL_PORT}"
    restart: unless-stopped # 配置容器的重启策略：除非手动停止，否则总是在退出时尝试重启
    # logging: # 配置容器的日志记录驱动和选项 (可选)
    #   driver: "json-file" # 使用 json-file 日志驱动 (Docker 默认)
    #   options: # 日志驱动的特定选项
    #     max-size: "10m" # 单个日志文件的最大大小 (10 MB)
    #     max-file: "3"   # 最多保留的日志文件数量 (3 个)
    # 网络配置：默认情况下，容器会连接到默认的 bridge 网络。
    # 由于 HAProxy 需要访问外部 Tinyproxy IP，通常不需要特殊的 Docker 网络配置，
    # 除非存在复杂的网络路由需求或需要将 HAProxy 置于特定子网。
EOF

# --- Process Based on Command-Line Arguments ---
# 检查变量 $TINYPROXY_SERVERS_LIST 是否非空 (即，是否在运行脚本时提供了第一个参数)
if [ -n "$TINYPROXY_SERVERS_LIST" ]; then
    # === Scenario 1: Server List Provided via Argument ===
    echo "信息：检测到服务器参数，将尝试添加到 haproxy.cfg 并启动服务..."

    # 初始化一个计数器，用于为后端服务器生成唯一的名称 (如 tinyproxy_1, tinyproxy_2)
    server_count=1
    # 备份当前的内部字段分隔符 (IFS)，通常是空格、制表符、换行符
    OLD_IFS=$IFS
    # 将 IFS 设置为逗号，以便后续可以使用 for 循环按逗号分割服务器列表字符串
    IFS=','
    # 遍历由逗号分隔的 $TINYPROXY_SERVERS_LIST 字符串中的每个条目
    for server_entry in $TINYPROXY_SERVERS_LIST; do
        # 使用 Bash 正则表达式匹配检查当前条目是否符合 "非冒号字符:数字端口号" 的格式
        # ^[^:]+ 匹配开头的一个或多个非冒号字符 (IP 或主机名)
        # : 匹配冒号
        # [0-9]+$ 匹配结尾的一个或多个数字 (端口号)
        if [[ "$server_entry" =~ ^[^:]+:[0-9]+$ ]]; then
            # 如果格式有效，则构造 HAProxy 后端服务器配置行并追加到 haproxy.cfg 文件末尾
            # server <名称> <地址:端口> check fall <次数> rise <次数> inter <间隔>
            # check: 启用健康检查
            # fall 3: 连续 3 次健康检查失败后，将服务器标记为下线
            # rise 2: 服务器下线后，连续 2 次健康检查成功后，将其重新标记为上线
            # inter 5s: 健康检查的时间间隔为 5 秒
            echo "    server tinyproxy_${server_count} ${server_entry} check fall 3 rise 2 inter 5s" >> haproxy.cfg
            echo "  -> 已添加后端服务器: tinyproxy_${server_count} (${server_entry})"
            # 增加服务器计数器
            ((server_count++))
        else
            # 如果条目格式无效，则输出警告信息，跳过此条目
            echo "警告：跳过格式错误的服务器条目 '$server_entry'。预期格式为 'IP地址:端口号'。" >&2
        fi
    done # 结束 for 循环
    # 恢复原始的 IFS 设置，避免影响后续的命令行为
    IFS=$OLD_IFS

    # 检查在处理完所有参数后，是否至少添加了一个有效的服务器
    # 如果 server_count 仍然是 1，表示没有成功添加任何服务器
    if [ "$server_count" -eq 1 ]; then
      echo "错误：提供的参数 '$TINYPROXY_SERVERS_LIST' 中没有找到有效的 Tinyproxy 服务器条目。" >&2
      echo "服务未启动。请检查参数格式或手动编辑 ${INSTALL_DIR}/haproxy.cfg 文件后，" >&2
      echo "在此目录 (${INSTALL_DIR}) 运行 'sudo docker compose up -d' 来启动服务。" >&2
      exit 1 # 退出脚本，因为没有可用的后端服务器
    fi

    # --- Start the Service ---
    echo "信息：正在使用 Docker Compose 启动 HAProxy 服务..."
    # 在当前目录 (应为 $INSTALL_DIR) 执行 docker compose up 命令
    # -d 选项表示在后台 (detached mode) 运行容器
    docker compose up -d

    # --- Feedback on Startup Result ---
    # 检查上一个命令 (docker compose up -d) 的退出状态码
    if [ $? -eq 0 ]; then
      # === Startup Successful ===
      echo ""
      echo "--------------------------------------------------"
      echo " HAProxy 负载均衡服务已成功启动！"
      echo "--------------------------------------------------"
      echo " 代理入口地址: <你的服务器IP>:${HAPROXY_HOST_PORT}"
      echo " 配置文件路径: ${INSTALL_DIR}/haproxy.cfg"
      echo " Compose 文件路径: ${INSTALL_DIR}/docker-compose.yml"
      echo ""
      echo " 已配置的后端 Tinyproxy 服务器列表:"
      # 从 haproxy.cfg 文件中过滤出以 'server tinyproxy_' 开头的行，并移除行首的 'server ' 部分，以显示已添加的服务器信息
      grep -E '^\s*server\s+tinyproxy_' ${INSTALL_DIR}/haproxy.cfg | sed 's/^\s*server\s*//'
      echo ""
      echo " 重要提示:"
      echo "   - 请确保防火墙规则允许客户端通过 TCP 访问 <你的服务器IP>:${HAPROXY_HOST_PORT}。"
      echo "   - 请确保此 HAProxy 服务器 (${HOSTNAME} / <你的服务器IP>) 的 IP 地址已被添加到所有后端 Tinyproxy 服务器的 'Allow' 配置指令中。"
      echo "   - 如需修改后端服务器列表或 HAProxy 配置，请先编辑 ${INSTALL_DIR}/haproxy.cfg 文件。"
      echo "   - 编辑完成后，在此目录 (${INSTALL_DIR}) 下运行 'sudo docker compose restart' 命令来应用更改并重启 HAProxy 服务。"
      echo "--------------------------------------------------"
    else
      # === Startup Failed ===
      echo "错误：HAProxy 服务启动失败。" >&2
      echo "请进行故障排查：" >&2
      echo "  1. 检查 Docker 服务是否正在运行 (systemctl status docker)。" >&2
      echo "  2. 检查宿主机端口 ${HAPROXY_HOST_PORT} 是否已被其他进程占用 (sudo ss -tulnp | grep ${HAPROXY_HOST_PORT})。" >&2
      echo "  3. 查看 HAProxy 容器的日志获取详细错误信息: cd ${INSTALL_DIR} && sudo docker compose logs haproxy_lb_service" >&2
      echo "  4. 检查生成的 HAProxy 配置文件是否有语法错误: cat ${INSTALL_DIR}/haproxy.cfg" >&2
      exit 1 # 启动失败，退出脚本
    fi

else
    # === Scenario 2: No Server List Provided ===
    echo "信息：未提供服务器列表参数。已生成配置文件模板，但服务未启动。"

    # 因为没有提供服务器列表，向 haproxy.cfg 文件追加注释和示例，指导用户手动添加
    cat <<EOF >> haproxy.cfg

    # --- 请手动编辑此部分，添加您的后端 Tinyproxy 服务器 ---
    # 每行代表一个后端服务器。
    # 格式: server <唯一名称> <服务器IP地址>:<服务器端口号> <健康检查选项>
    # 健康检查选项 (示例):
    #   check        : 启用对此服务器的健康检查。
    #   fall 3       : 连续 3 次检查失败后，标记为不可用。
    #   rise 2       : 从不可用状态恢复时，需要连续 2 次检查成功才标记为可用。
    #   inter 5s     : 健康检查的时间间隔为 5 秒。
    #
    # 示例:
    # server tinyproxy_server1 192.168.1.100:8888 check fall 3 rise 2 inter 5s
    # server tinyproxy_server2 192.168.1.101:8889 check fall 3 rise 2 inter 5s
EOF

    # 输出详细的操作指南给用户
    echo ""
    echo "--------------------------------------------------"
    echo " HAProxy 配置模板已生成，请按以下步骤完成设置并启动服务"
    echo "--------------------------------------------------"
    echo " 1. 编辑 HAProxy 配置文件:"
    echo "    sudo nano ${INSTALL_DIR}/haproxy.cfg" # 提示使用 nano 编辑器，用户可自行选择
    echo ""
    echo " 2. 在文件末尾的 'backend bk_tinyproxies' 配置段中，按照示例格式添加您的 Tinyproxy 服务器地址和端口。"
    echo "    每个 Tinyproxy 服务器实例应单独占用一行。"
    echo ""
    echo " 3. 保存并关闭配置文件后，切换到安装目录并使用 Docker Compose 启动服务:"
    echo "    cd ${INSTALL_DIR}"
    echo "    sudo docker compose up -d"
    echo ""
    echo " 4. 服务成功启动后，您的代理入口地址将是: <您的服务器IP>:${HAPROXY_HOST_PORT}"
    echo ""
    echo " 重要提示:"
    echo "   - 添加完服务器并启动服务后，请确保防火墙规则允许客户端通过 TCP 访问 <您的服务器IP>:${HAPROXY_HOST_PORT}。"
    echo "   - 确保此 HAProxy 服务器 (${HOSTNAME} / <您的服务器IP>) 的 IP 地址已被添加到所有您在配置文件中添加的后端 Tinyproxy 服务器的 'Allow' 配置指令中。"
    echo "--------------------------------------------------"

fi # 结束主条件判断 (是否提供了参数)

# 可选步骤：切换回之前的目录 (如果需要保持脚本执行环境的整洁)
# 使用 '> /dev/null' 将 cd 命令自身的输出重定向到空设备，避免在脚本末尾打印目录路径
# cd - > /dev/null

# 脚本正常结束
exit 0
