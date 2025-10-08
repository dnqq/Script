#!/bin/bash
#
# 脚本名称: manage_root_password_login.sh
# 描述:       一键启用或禁用 root 用户的 SSH 密码登录。
# 用法:
#             bash manage_root_password_login.sh [action]
#             或者通过管道运行:
#             curl -sSL [URL_TO_SCRIPT] | bash -s [action]
#
# 参数:
#   enable    - 启用 root 密码登录 (将 PermitRootLogin 设置为 'yes')
#   disable   - 禁用 root 密码登录 (将 PermitRootLogin 设置为 'prohibit-password')
#

set -e # 遇到错误时立即退出

# --- 颜色定义 ---
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

# --- 函数定义 ---

# 日志函数
log_info() {
    echo -e "${GREEN}[信息] $1${RESET}"
}

log_warn() {
    echo -e "${YELLOW}[警告] $1${RESET}"
}

log_error() {
    echo -e "${RED}[错误] $1${RESET}" >&2
}

# 显示用法
usage() {
    echo "用法: $0 {enable|disable}"
    echo "  enable  - 启用 root 用户的 SSH 密码登录"
    echo "  disable - 禁用 root 用户的 SSH 密码登录"
    exit 1
}

# 重启 sshd 服务
restart_sshd() {
    log_info "正在重启 SSH 服务以应用更改..."
    if command -v systemctl &> /dev/null; then
        systemctl restart sshd
        log_info "sshd 服务已通过 systemctl 重启。"
    elif command -v service &> /dev/null; then
        service sshd restart
        log_info "sshd 服务已通过 service 命令重启。"
    else
        log_error "无法自动重启 sshd 服务。请手动重启以应用更改。"
    fi
}

# --- 主逻辑 ---

# 检查参数
if [ -z "$1" ]; then
    log_error "缺少操作参数。"
    usage
fi

# 检查是否以 root 用户身份运行
log_info "检查用户权限..."
if [ "$(id -u)" -ne 0 ]; then
  log_error "此脚本必须以 root 用户身份运行"
  exit 1
fi
log_info "权限检查通过。"

SSHD_CONFIG="/etc/ssh/sshd_config"

# 检查 sshd_config 文件是否存在
log_info "检查 SSH 配置文件是否存在于 $SSHD_CONFIG..."
if [ ! -f "$SSHD_CONFIG" ]; then
    log_error "$SSHD_CONFIG 未找到。"
    exit 1
fi
log_info "SSH 配置文件找到。"

# 根据参数执行操作
ACTION=$1
case "$ACTION" in
    enable)
        log_info "正在启用 root 密码登录..."
        if grep -q "^#\?PermitRootLogin" "$SSHD_CONFIG"; then
            sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"
        else
            echo "PermitRootLogin yes" >> "$SSHD_CONFIG"
        fi
        log_info "已将 'PermitRootLogin' 设置为 'yes'。"
        restart_sshd
        log_info "🎉 操作完成！Root 用户的 SSH 密码登录已被启用。"
        ;;
    disable)
        log_warn "禁用 root 密码登录前，请确保您已配置 SSH 密钥登录！"
        log_info "正在禁用 root 密码登录..."
        if grep -q "^#\?PermitRootLogin" "$SSHD_CONFIG"; then
            sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' "$SSHD_CONFIG"
        else
            echo "PermitRootLogin prohibit-password" >> "$SSHD_CONFIG"
        fi
        log_info "已将 'PermitRootLogin' 设置为 'prohibit-password'。"
        restart_sshd
        log_info "🎉 操作完成！Root 用户的 SSH 密码登录已被禁用。"
        ;;
    *)
        log_error "无效的操作参数: $ACTION"
        usage
        ;;
esac

exit 0