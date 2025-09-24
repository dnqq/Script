#!/bin/bash

# Cloudflare Tunnel优选IP配置脚本
# 功能：
# 1. 获取Cloudflare tunnels列表
# 2. 为tunnels添加应用程序路由
# 3. 设置SAAS自定义主机名
# 4. 配置DNS记录

# Cloudflare API配置
CF_API_TOKEN=""      # Cloudflare API令牌，用于身份验证
CF_ACCOUNT_ID=""     # Cloudflare账户ID

# 域名配置
PRIMARY_DOMAIN=""    # 主域名 (例如: demo.aaa.com)
ORIGIN_DOMAIN=""     # 回源域名 (例如: demo.bbb.com)
DCV_UUID=""          # DCV UUID，需要用户手动输入

# 服务配置
SERVICE_ADDRESS=""   # 本地服务地址 (例如: http://192.168.1.3:5244)

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

# 获取tunnels列表并显示
# Usage: get_tunnels tunnel_ids_array
get_tunnels() {
    local -n tunnel_ids_ref=$1 # Use a nameref
    tunnel_ids_ref=() # Clear the array

    log_info "正在获取Cloudflare tunnels列表..."
    local response=$(cf_api_request "GET" "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel?is_deleted=false")
    
    if ! echo "$response" | jq -e '.success' > /dev/null; then
        log_error "获取tunnels列表失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"' >&2
        return 1
    fi

    local tunnels_count=$(echo "$response" | jq -r '.result | length')
    if [[ "$tunnels_count" -eq 0 ]]; then
        log_warning "未找到任何活动的tunnels。"
        return 0
    fi

    log_info "发现以下tunnels:"
    local i=0
    while [ $i -lt $tunnels_count ]; do
        local tunnel_info=$(echo "$response" | jq -r ".result[$i]")
        local id=$(echo "$tunnel_info" | jq -r '.id')
        local name=$(echo "$tunnel_info" | jq -r '.name')
        local status=$(echo "$tunnel_info" | jq -r '.status')
        
        echo "$((i+1))) Name: $name | Status: $status | ID: $id"
        tunnel_ids_ref+=("$id")
        i=$((i+1))
    done
    
    return 0
}

# 创建新tunnel
create_tunnel() {
    local tunnel_name="$1"
    log_info "正在创建新的tunnel: $tunnel_name"
    
    local data=$(jq -n --arg name "$tunnel_name" '{
        name: $name
    }')
    
    local response=$(cf_api_request "POST" "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        local tunnel_id=$(echo "$response" | jq -r '.result.id')
        log_success "成功创建tunnel: $tunnel_name (ID: $tunnel_id)"
        echo "$tunnel_id"
        return 0
    else
        log_error "创建tunnel失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"' >&2
        return 1
    fi
}

# 为tunnel设置应用程序路由（增量更新）
set_application_routes() {
    local tunnel_id="$1"
    local service="$2"
    shift 2 # Remove tunnel_id and service from args
    local domains=("$@") # The rest are domains
    local ret_val=0
    
    # 开启调试模式，打印执行的每条命令
    log_info "--- DEBUG: Entering set_application_routes ---"
    set -x

    log_info "正在为tunnel $tunnel_id 更新应用程序路由..."

    # 1. 获取当前配置
    log_info "正在获取tunnel $tunnel_id 的现有配置..."
    local config_response=$(cf_api_request "GET" "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/config")
    
    # 打印原始API响应
    log_info "--- DEBUG: Raw config response from API ---"
    echo "$config_response"
    log_info "----------------------------------------"

    if ! echo "$config_response" | jq -e '.success' > /dev/null; then
        log_error "获取tunnel配置失败"
        echo "$config_response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"' >&2
        ret_val=1
    else
        # 提取完整的现有配置和ingress规则，如果配置为null，则视为空对象{}
        local existing_config=$(echo "$config_response" | jq '.result.config // {}')
        
        if [[ $(echo "$existing_config" | jq 'length') -eq 0 ]]; then
            log_warning "从API获取的现有隧道配置为空。这可能是因为此隧道之前是通过DNS CNAME记录进行路由，而不是通过Ingress规则配置的。"
        else
            log_info "已成功获取现有的Ingress规则配置。"
        fi

        log_info "--- DEBUG: Existing config ---"
        echo "$existing_config"
        log_info "----------------------------"

        # 如果ingress不存在，则初始化为空数组
        local existing_ingress=$(echo "$existing_config" | jq '.ingress // [] | map(select(.service != "http_status:404"))')
        
        log_info "--- DEBUG: Existing ingress rules (before update) ---"
        echo "$existing_ingress"
        log_info "---------------------------------------------------"

        # 2. 合并新旧规则
        local updated_ingress="$existing_ingress"
        local new_rule_added=false
        for domain in "${domains[@]}"; do
            # 检查域名是否已存在
            local is_existing=$(echo "$updated_ingress" | jq -e --arg hostname "$domain" '.[] | select(.hostname == $hostname)')
            if [[ -n "$is_existing" ]]; then
                log_warning "路由 $domain -> $service 已存在，跳过添加"
            else
                log_info "  - 添加新路由: $domain -> $service"
                local new_rule=$(jq -n --arg hostname "$domain" --arg service "$service" '{hostname: $hostname, service: $service}')
                
                log_info "--- DEBUG: New rule to add ---"
                echo "$new_rule"
                log_info "--- DEBUG: updated_ingress before merge ---"
                echo "$updated_ingress"
                log_info "--------------------------------"

                # 使用更健壮的方式合并JSON，避免潜在的echo/pipe问题
                updated_ingress=$(jq -n --argjson current "${updated_ingress:-[]}" --argjson rule "$new_rule" '$current + [$rule]')
                new_rule_added=true
                
                log_info "--- DEBUG: updated_ingress after merge ---"
                echo "$updated_ingress"
                log_info "-------------------------------"
            fi
        done

        if ! $new_rule_added; then
            log_info "没有新的路由需要添加。"
        fi

        # 3. 添加回最后的404规则
        updated_ingress=$(jq -n --argjson current "${updated_ingress:-[]}" '$current + [{service: "http_status:404"}]')

        # 4. 构建最终的完整配置并上传
        local updated_config=$(jq -n --argjson config "${existing_config:-'{}'}" --argjson ingress "${updated_ingress:-[]}" '$config | .ingress = $ingress')
        local data=$(jq -n --argjson config "$updated_config" '{config: $config}')
        
        log_info "--- DEBUG: 更新前的配置 (existing_config) ---"
        echo "$existing_config" | jq .
        log_info "--- DEBUG: 更新后的完整配置 (data) ---"
        echo "$data" | jq .
        log_info "--------------------------"

        log_info "正在上传更新后的配置..."
        local response=$(cf_api_request "PUT" "/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${tunnel_id}/config" "$data")

        log_info "--- DEBUG: API响应 ---"
        echo "$response" | jq .
        log_info "----------------------"

        if echo "$response" | jq -e '.success' > /dev/null; then
            log_success "成功为tunnel $tunnel_id 更新了应用程序路由"
            ret_val=0
        else
            log_error "更新应用程序路由失败"
            # The full response is already printed above
            ret_val=1
        fi
    fi
    
    # 关闭调试模式
    set +x
    log_info "--- DEBUG: Exiting set_application_routes ---"
    return $ret_val
}

# 获取zone ID
get_zone_id() {
    local domain="$1"
    local temp_domain="$domain"
    log_info "正在获取域名 $domain 的zone ID"

    while true; do
        local response=$(cf_api_request "GET" "/zones?name=${temp_domain}")
        
        if ! echo "$response" | jq -e '.success' > /dev/null; then
            log_error "获取zone ID时API请求失败 (查询域名: ${temp_domain})"
            echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"' >&2
            return 1 # Exit on real API error
        fi

        local zone_id=$(echo "$response" | jq -r '.result[0].id')
        if [[ -n "$zone_id" && "$zone_id" != "null" ]]; then
            log_success "为 $domain 找到Zone ID: $zone_id (匹配域名: $temp_domain)"
            echo "$zone_id"
            return 0
        fi

        if ! echo "$temp_domain" | grep -q '\.'; then
            break
        fi
        
        temp_domain="${temp_domain#*.}"
    done

    log_error "未找到域名 $domain 的zone ID"
    return 1
}

# 设置自定义主机名
set_custom_hostname() {
    local domain="$1"
    local zone_id="$2"
    local origin_domain="$3"  # 可选参数，用于SAAS配置
    
    log_info "正在设置自定义主机名: $domain"
    
    # 首先检查是否已存在
    local existing_response=$(cf_api_request "GET" "/zones/${zone_id}/custom_hostnames?hostname=${domain}")
    
    if echo "$existing_response" | jq -e '.success' > /dev/null; then
        local count=$(echo "$existing_response" | jq -r '.result_info.count')
        if [[ "$count" -gt 0 ]]; then
            log_warning "自定义主机名 $domain 已存在，跳过创建"
            # 获取现有的自定义主机名ID
            local hostname_id=$(echo "$existing_response" | jq -r '.result[0].id')
            echo "$hostname_id"
            return 0
        fi
    fi
    
    # 创建自定义主机名数据
    local data=""
    if [[ -n "$origin_domain" ]]; then
        # SAAS配置
        # For SAAS, custom_origin_server points to the service origin.
        # The logic here seems to set it to the primary domain, which might be part of a complex DCV setup.
        # A more common setup is to point it to the tunnel CNAME directly.
        data=$(jq -n --arg hostname "$domain" --arg origin "$origin_domain" '{
            hostname: $hostname,
            ssl: {
                method: "http",
                type: "dv"
            },
            custom_origin_server: $origin
        }')
    else
        # 普通配置
        data=$(jq -n --arg hostname "$domain" '{
            hostname: $hostname,
            ssl: {
                method: "http",
                type: "dv"
            }
        }')
    fi
    
    local response=$(cf_api_request "POST" "/zones/${zone_id}/custom_hostnames" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        local hostname_id=$(echo "$response" | jq -r '.result.id')
        if [[ -n "$origin_domain" ]]; then
            log_success "成功设置回源域名SAAS自定义主机名: $domain (源域名: $origin_domain)"
        else
            log_success "成功设置自定义主机名: $domain"
        fi
        
        echo "$hostname_id"
        return 0
    else
        log_error "设置自定义主机名失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"' >&2
        return 1
    fi
}


# 设置DNS记录
set_dns_record() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="$3"
    local record_content="$4"
    
    log_info "正在设置DNS记录: $record_name ($record_type) -> $record_content"
    
    # 首先检查是否已存在相同的记录
    local existing_response=$(cf_api_request "GET" "/zones/${zone_id}/dns_records?name=${record_name}&type=${record_type}")
    
    if echo "$existing_response" | jq -e '.success' > /dev/null; then
        local count=$(echo "$existing_response" | jq -r '.result_info.count')
        if [[ "$count" -gt 0 ]]; then
            log_warning "DNS记录 $record_name ($record_type) 已存在，跳过创建"
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

# 设置主域名的DCV委派记录
set_dcv_delegation() {
    local zone_id="$1"
    local primary_domain="$2"
    local origin_domain="$3"
    local dcv_uuid="$4"
    
    log_info "正在设置主域名的DCV委派记录"
    
    # 构造DCV委派记录的目标值
    local dcv_target="${primary_domain}.${dcv_uuid}.dcv.cloudflare.com"
    
    # 设置_acme-challenge记录指向回源域名的DCV验证端点
    set_dns_record "$zone_id" "_acme-challenge.${primary_domain}" "CNAME" "$dcv_target"
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
            --origin-domain)
                ORIGIN_DOMAIN="$2"
                shift 2
                ;;
            --service-address)
                SERVICE_ADDRESS="$2"
                shift 2
                ;;
            --tunnel-id)
                TUNNEL_ID="$2"
                shift 2
                ;;
            --dcv-uuid)
                DCV_UUID="$2"
                shift 2
                ;;
            --tunnel-name)
                TUNNEL_NAME="$2"
                shift 2
                ;;
            -h|--help)
                echo "Cloudflare Tunnel优选IP配置脚本"
                echo "使用方法: $0 [选项]"
                echo ""
                echo "选项:"
                echo "  --api-token TOKEN        Cloudflare API令牌"
                echo "  --account-id ID          Cloudflare账户ID"
                echo "  --primary-domain DOMAIN  主域名 (例如: demo.aaa.com)"
                echo "  --origin-domain DOMAIN   回源域名 (例如: demo.bbb.com)"
                echo "  --service-address ADDR   本地服务地址 (例如: http://192.168.1.3:5244)"
                echo "  --tunnel-id ID           直接指定tunnel ID（可选）"
                echo "  --tunnel-name NAME       新tunnel名称（可选）"
                echo "  --dcv-uuid UUID          DCV UUID"
                echo "  -h, --help               显示帮助信息"
                echo ""
                echo "示例:"
                echo "  $0 --api-token xxx --account-id yyy --primary-domain demo.aaa.com --origin-domain demo.bbb.com --service-address http://192.168.1.3:5244"
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
    
    if [[ -z "$ORIGIN_DOMAIN" ]]; then
        echo -n "请输入回源域名: "
        read -r ORIGIN_DOMAIN
    fi
    
    if [[ -z "$SERVICE_ADDRESS" ]]; then
        echo -n "请输入本地服务地址 (例如 http://192.168.1.3:5244): "
        read -r SERVICE_ADDRESS
    fi

    if [[ -z "$DCV_UUID" ]]; then
        echo -n "请输入DCV UUID: "
        read -r DCV_UUID
    fi

    # 获取或创建tunnel
    local tunnel_id=""
    
    # 如果通过参数指定了tunnel ID，则直接使用
    if [[ -n "$TUNNEL_ID" ]]; then
        tunnel_id="$TUNNEL_ID"
        log_info "使用指定的tunnel ID: $tunnel_id"
    # 如果通过参数指定了tunnel名称，则创建新tunnel
    elif [[ -n "$TUNNEL_NAME" ]]; then
        tunnel_id=$(create_tunnel "$TUNNEL_NAME")
        if [[ $? -ne 0 ]]; then
            log_error "创建tunnel失败，退出脚本"
            exit 1
        fi
    else
        # 获取tunnels列表
        echo
        log_info "=== 获取Cloudflare tunnels列表 ==="
        declare -a tunnel_ids
        get_tunnels tunnel_ids
        if [[ $? -ne 0 ]]; then
            log_error "获取tunnels列表时发生错误，退出脚本"
            exit 1
        fi
        
        # 选择或创建tunnel
        echo
        echo "请选择操作："
        if [[ ${#tunnel_ids[@]} -gt 0 ]]; then
            echo "1) 使用现有tunnel"
        fi
        echo "2) 创建新tunnel"
        echo -n "输入选项: "
        read -r choice
        
        if [[ "$choice" == "1" && ${#tunnel_ids[@]} -gt 0 ]]; then
            echo -n "请输入要使用的tunnel编号 (1-${#tunnel_ids[@]}): "
            read -r selection
            if [[ "$selection" =~ ^[0-9]+$ && "$selection" -ge 1 && "$selection" -le ${#tunnel_ids[@]} ]]; then
                tunnel_id=${tunnel_ids[$((selection-1))]}
                log_info "已选择tunnel ID: $tunnel_id"
            else
                log_error "无效的编号，退出脚本"
                exit 1
            fi
        elif [[ "$choice" == "2" ]]; then
            echo -n "请输入新tunnel名称: "
            read -r tunnel_name
            tunnel_id=$(create_tunnel "$tunnel_name")
            if [[ $? -ne 0 ]]; then
                log_error "创建tunnel失败，退出脚本"
                exit 1
            fi
        else
            log_error "无效选项，退出脚本"
            exit 1
        fi
    fi
    
    # 获取zone IDs
    log_info "=== 获取域名zone IDs ==="
    local primary_zone_id=$(get_zone_id "$PRIMARY_DOMAIN")
    if [[ $? -ne 0 ]]; then
        log_error "获取主域名zone ID失败，退出脚本"
        exit 1
    fi
    
    local origin_zone_id=$(get_zone_id "$ORIGIN_DOMAIN")
    if [[ $? -ne 0 ]]; then
        log_error "获取回源域名zone ID失败，退出脚本"
        exit 1
    fi
    
    # 检查DCV UUID
    log_info "=== 检查DCV UUID ==="
    if [[ -z "$DCV_UUID" ]]; then
        log_error "DCV UUID未设置，退出脚本"
        exit 1
    fi
    log_success "使用DCV UUID: $DCV_UUID"

    # 设置主域名的DCV委派记录
    log_info "=== 设置主域名DCV委派记录 ==="
    set_dcv_delegation "$primary_zone_id" "$PRIMARY_DOMAIN" "$ORIGIN_DOMAIN" "$DCV_UUID"
    

    # 为tunnel添加应用程序路由
    log_info "=== 为tunnel添加应用程序路由 ==="
    set_application_routes "$tunnel_id" "$SERVICE_ADDRESS" "$PRIMARY_DOMAIN" "$ORIGIN_DOMAIN"
    if [[ $? -ne 0 ]]; then
        log_error "设置应用程序路由失败，退出脚本"
        exit 1
    fi

    # 设置回源域名SAAS自定义主机名
    log_info "=== 设置回源域名SAAS自定义主机名 ==="
    local origin_hostname_id=$(set_custom_hostname "$PRIMARY_DOMAIN" "$origin_zone_id" "$ORIGIN_DOMAIN")
    if [[ $? -ne 0 ]]; then
        log_error "设置回源域名SAAS自定义主机名失败，退出脚本"
        exit 1
    fi
    
    # 设置speed子域名CNAME记录 (speed.主域名 -> cf.090227.xyz)
    log_info "=== 设置speed子域名CNAME记录 ==="
    set_dns_record "$primary_zone_id" "speed.$PRIMARY_DOMAIN" "CNAME" "cf.090227.xyz"
    
    # 设置主域名CNAME记录 (主域名 -> speed.主域名)
    log_info "=== 设置主域名CNAME记录 ==="
    set_dns_record "$primary_zone_id" "$PRIMARY_DOMAIN" "CNAME" "speed.$PRIMARY_DOMAIN"

    log_success "所有配置已完成！"
}

# --- Script Execution ---
parse_args "$@"
main "$@"