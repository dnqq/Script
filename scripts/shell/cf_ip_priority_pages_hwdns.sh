#!/bin/bash

# Cloudflare NS记录配置脚本
# 功能：
# 1. 为主域名添加指定的NS记录

# Cloudflare API配置
CF_API_TOKEN=""      # Cloudflare API令牌，用于身份验证
CF_ACCOUNT_ID=""     # Cloudflare账户ID

# 域名配置
PRIMARY_DOMAIN=""    # 主域名 (例如: demo.aaa.com)


# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Log Functions ---
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# --- Dependency and System Functions ---

# 自动安装jq
install_jq() {
    # Check for root privileges and set sudo command if needed
    local SUDO_CMD=""
    if [[ $EUID -ne 0 ]]; then
        if command -v sudo &> /dev/null; then
            SUDO_CMD="sudo"
        else
            log_error "需要root权限来安装jq，并且sudo命令未找到。"
            exit 1
        fi
    fi

    # 检测操作系统类型
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux系统
        if command -v apt &> /dev/null; then
            # Debian/Ubuntu系统
            log_info "检测到Debian/Ubuntu系统，使用apt安装jq"
            $SUDO_CMD apt update && $SUDO_CMD apt install -y jq
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL系统
            log_info "检测到CentOS/RHEL系统，使用yum安装jq"
            $SUDO_CMD yum install -y jq
        elif command -v dnf &> /dev/null; then
            # Fedora系统
            log_info "检测到Fedora系统，使用dnf安装jq"
            $SUDO_CMD dnf install -y jq
        elif command -v pacman &> /dev/null; then
            # Arch Linux系统
            log_info "检测到Arch Linux系统，使用pacman安装jq"
            $SUDO_CMD pacman -Sy jq --noconfirm
        elif command -v apk &> /dev/null; then
            # Alpine Linux系统
            log_info "检测到Alpine Linux系统，使用apk安装jq"
            $SUDO_CMD apk add jq
        else
            log_error "不支持的Linux包管理器，请手动安装jq"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS系统
        if command -v brew &> /dev/null; then
            log_info "检测到Homebrew，使用brew安装jq"
            brew install jq
        else
            log_error "请先安装Homebrew，然后安装jq"
            exit 1
        fi
    else
        log_error "不支持的操作系统，请手动安装jq"
        exit 1
    fi

    # 验证安装是否成功
    if command -v jq &> /dev/null; then
        log_success "jq安装成功"
    else
        log_error "jq安装失败，请手动安装"
        exit 1
    fi
}

# 检查必要命令
check_dependencies() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "缺少必要依赖: $dep"
            if [[ "$dep" == "jq" ]]; then
                log_info "正在尝试自动安装jq..."
                install_jq
            else
                exit 1
            fi
        fi
    done
}

# --- Cloudflare API Functions ---

# Cloudflare API请求函数
cf_api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    if [[ -z "$CF_API_TOKEN" || -z "$CF_ACCOUNT_ID" ]]; then
        log_error "请先设置Cloudflare API Token和账户ID"
        exit 1
    fi
    
    local url="https://api.cloudflare.com/client/v4${endpoint}"
    local headers=(
        "-H" "Authorization: Bearer ${CF_API_TOKEN}"
        "-H" "Content-Type: application/json"
    )
    
    local response
    if [[ "$method" == "GET" ]]; then
        response=$(curl -s -X GET "${headers[@]}" "$url")
    elif [[ "$method" == "POST" ]]; then
        if [[ -n "$data" ]]; then
            response=$(curl -s -X POST "${headers[@]}" "$url" -d "$data")
        else
            response=$(curl -s -X POST "${headers[@]}" "$url")
        fi
    elif [[ "$method" == "PUT" ]]; then
        response=$(curl -s -X PUT "${headers[@]}" "$url" -d "$data")
    elif [[ "$method" == "PATCH" ]]; then
        response=$(curl -s -X PATCH "${headers[@]}" "$url" -d "$data")
    elif [[ "$method" == "DELETE" ]]; then
        response=$(curl -s -X DELETE "${headers[@]}" "$url")
    else
        log_error "不支持的HTTP方法: $method"
        return 1
    fi
    
    echo "$response"
}



# 获取zone信息 (ID和托管域名)
get_zone_info() {
    local domain="$1"
    local temp_domain="$domain"
    log_info "正在获取域名 $domain 的zone信息"

    while true; do
        local response=$(cf_api_request "GET" "/zones?name=${temp_domain}")
        
        if ! echo "$response" | jq -e '.success' > /dev/null; then
            log_error "获取zone信息时API请求失败 (查询域名: ${temp_domain})"
            echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"' >&2
            return 1 # Exit on real API error
        fi

        local zone_id=$(echo "$response" | jq -r '.result[0].id')
        if [[ -n "$zone_id" && "$zone_id" != "null" ]]; then
            log_success "为 $domain 找到Zone ID: $zone_id (匹配域名: $temp_domain)"
            echo "$zone_id $temp_domain"
            return 0
        fi

        if ! echo "$temp_domain" | grep -q '\.'; then
            break
        fi
        
        temp_domain="${temp_domain#*.}"
    done

    log_error "未找到域名 $domain 的zone信息"
    return 1
}

# 设置DNS记录
set_dns_record() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="$3"
    local record_content="$4"
    
    log_info "正在添加DNS记录: $record_name ($record_type) -> $record_content"
    
    # 检查记录是否已存在
    local existing_response=$(cf_api_request "GET" "/zones/${zone_id}/dns_records?name=${record_name}&type=${record_type}&content=${record_content}")
    
    if echo "$existing_response" | jq -e '.success' > /dev/null; then
        local count=$(echo "$existing_response" | jq -r '.result_info.count')
        if [[ "$count" -gt 0 ]]; then
            log_warning "DNS记录 $record_name ($record_type) -> $record_content 已存在，跳过创建"
            return 0
        fi
    fi
    
    # 创建DNS记录
    local data=$(jq -n --arg name "$record_name" --arg type "$record_type" --arg content "$record_content" '{
        type: $type,
        name: $name,
        content: $content,
        ttl: 1,
        proxied: false
    }')
    
    local response=$(cf_api_request "POST" "/zones/${zone_id}/dns_records" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        log_success "成功设置DNS记录: $record_name ($record_type) -> $record_content"
        return 0
    else
        log_error "设置DNS记录失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"' >&2
        return 1
    fi
}

# --- Argument Parsing and Main Execution ---

# 参数解析函数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --api-token)
                CF_API_TOKEN="$2"
                shift 2
                ;;
            --account-id)
                CF_ACCOUNT_ID="$2"
                shift 2
                ;;
            --primary-domain)
                PRIMARY_DOMAIN="$2"
                shift 2
                ;;
            -h|--help)
                echo "Cloudflare NS记录配置脚本"
                echo "使用方法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --api-token TOKEN        Cloudflare API令牌"
                echo "  --account-id ID          Cloudflare账户ID"
                echo "  --primary-domain DOMAIN  主域名 (例如: demo.aaa.com)"
                echo "  -h, --help               显示帮助信息"
                echo ""
                echo "示例:"
                echo "  $0 --api-token xxx --account-id yyy --primary-domain demo.aaa.com"
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                echo "使用 -h 或 --help 查看帮助信息"
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    # 检查依赖
    check_dependencies
    
    # 获取用户输入
    if [[ -z "$CF_API_TOKEN" ]]; then
        echo -n "请输入Cloudflare API Token: "
        read -r CF_API_TOKEN
    fi
    
    if [[ -z "$CF_ACCOUNT_ID" ]]; then
        echo -n "请输入Cloudflare账户ID: "
        read -r CF_ACCOUNT_ID
    fi
    
    if [[ -z "$PRIMARY_DOMAIN" ]]; then
        echo -n "请输入主域名: "
        read -r PRIMARY_DOMAIN
    fi

    # 获取zone信息
    log_info "=== 获取域名zone信息 ==="
    local primary_zone_info
    primary_zone_info=$(get_zone_info "$PRIMARY_DOMAIN")
    if [[ $? -ne 0 ]]; then
        log_error "获取主域名zone信息失败，退出脚本"
        exit 1
    fi
    local primary_zone_id
    read -r primary_zone_id _ <<< "$primary_zone_info"
    
    # 定义需要添加的NS记录
    local ns_records=(
        "ns1.huaweicloud-dns.com."
        "ns1.huaweicloud-dns.cn."
        "ns1.huaweicloud-dns.net."
        "ns1.huaweicloud-dns.org."
    )

    # 为主域名添加NS记录
    log_info "=== 为主域名添加NS记录 ==="
    for ns_server in "${ns_records[@]}"; do
        set_dns_record "$primary_zone_id" "$PRIMARY_DOMAIN" "NS" "$ns_server"
    done

    log_success "所有配置已完成！"
}

# --- Script Execution ---
parse_args "$@"
main "$@"