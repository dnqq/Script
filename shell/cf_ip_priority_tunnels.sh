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
DCV_UUID=""          # DCV UUID，用于设置主域名的DCV委派记录

# 服务配置
SERVICE_ADDRESS=""   # 本地服务地址 (例如: http://192.168.1.3:5244)

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要命令
check_dependencies() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "缺少必要依赖: $dep"
            if [[ "$dep" == "jq" ]]; then
                log_info "请安装jq来处理JSON数据"
            fi
            exit 1
        fi
    done
}

# Cloudflare API请求函数
cf_api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    if [[ -z "$CF_API_TOKEN" || -z "$CF_ACCOUNT_ID" ]]; then
        log_error "请先设置Cloudflare API Token和账户ID"
        exit 1
    fi
    
    local url="https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}${endpoint}"
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

# 获取tunnels列表
get_tunnels() {
    log_info "正在获取Cloudflare tunnels列表..."
    local response=$(cf_api_request "GET" "/cfd_tunnel")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        echo "$response" | jq -r '.result[] | "ID: \(.id) | Name: \(.name) | Status: \(.status)"'
        return 0
    else
        log_error "获取tunnels列表失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"'
        return 1
    fi
}

# 创建新tunnel
create_tunnel() {
    local tunnel_name="$1"
    log_info "正在创建新的tunnel: $tunnel_name"
    
    local data=$(jq -n --arg name "$tunnel_name" '{
        name: $name
    }')
    
    local response=$(cf_api_request "POST" "/cfd_tunnel" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        local tunnel_id=$(echo "$response" | jq -r '.result.id')
        log_success "成功创建tunnel: $tunnel_name (ID: $tunnel_id)"
        echo "$tunnel_id"
        return 0
    else
        log_error "创建tunnel失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"'
        return 1
    fi
}

# 为tunnel添加应用程序路由
add_application_route() {
    local tunnel_id="$1"
    local domain="$2"
    local service="$3"
    
    log_info "正在为tunnel $tunnel_id 添加应用程序路由: $domain -> $service"
    
    local data=$(jq -n --arg hostname "$domain" --arg service "$service" '{
        config: {
            ingress: [
                {
                    hostname: $hostname,
                    service: $service
                },
                {
                    service: "http_status:404"
                }
            ]
        }
    }')
    
    local response=$(cf_api_request "PUT" "/cfd_tunnel/${tunnel_id}/config" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        log_success "成功添加应用程序路由: $domain -> $service"
        return 0
    else
        log_error "添加应用程序路由失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"'
        return 1
    fi
}

# 设置自定义主机名
set_custom_hostname() {
    local domain="$1"
    local zone_id="$2"
    local origin_domain="$3"  # 可选参数，用于SAAS配置
    
    log_info "正在设置自定义主机名: $domain"
    
    # 首先检查是否已存在
    local existing_response=$(cf_api_request "GET" "/custom_hostnames?hostname=${domain}")
    
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
        data=$(jq -n --arg hostname "$domain" --arg zone_id "$zone_id" --arg origin "$origin_domain" '{
            hostname: $hostname,
            ssl: {
                method: "http",
                type: "dv"
            },
            custom_origin_server: $origin
        }')
    else
        # 普通配置
        data=$(jq -n --arg hostname "$domain" --arg zone_id "$zone_id" '{
            hostname: $hostname,
            ssl: {
                method: "http",
                type: "dv"
            }
        }')
    fi
    
    local response=$(cf_api_request "POST" "/custom_hostnames" "$data")
    
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
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"'
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
    local existing_response=$(cf_api_request "GET" "/dns_records?zone_id=${zone_id}&name=${record_name}&type=${record_type}")
    
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
    
    local response=$(cf_api_request "POST" "/dns_records" "$data")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        log_success "成功设置DNS记录: $record_name ($record_type) -> $record_content"
        return 0
    else
        log_error "设置DNS记录失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"'
        return 1
    fi
}

# 获取zone ID
get_zone_id() {
    local domain="$1"
    log_info "正在获取域名 $domain 的zone ID"
    
    local response=$(cf_api_request "GET" "/zones?name=${domain}")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        local zone_id=$(echo "$response" | jq -r '.result[0].id')
        if [[ -n "$zone_id" && "$zone_id" != "null" ]]; then
            log_success "获取zone ID成功: $zone_id"
            echo "$zone_id"
            return 0
        else
            log_error "未找到域名 $domain 的zone ID"
            return 1
        fi
    else
        log_error "获取zone ID失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"'
        return 1
    fi
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
        echo -n "请输入DCV UUID (如果不知道可留空，稍后会显示): "
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
        get_tunnels
        
        # 选择或创建tunnel
        echo
        echo "请选择操作："
        echo "1) 使用现有tunnel"
        echo "2) 创建新tunnel"
        echo -n "输入选项 (1 或 2): "
        read -r choice
        
        if [[ "$choice" == "1" ]]; then
            echo -n "请输入要使用的tunnel ID: "
            read -r tunnel_id
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
    
    # 为tunnel添加应用程序路由
    log_info "=== 为tunnel添加应用程序路由 ==="
    add_application_route "$tunnel_id" "$PRIMARY_DOMAIN" "$SERVICE_ADDRESS"
    add_application_route "$tunnel_id" "$ORIGIN_DOMAIN" "$SERVICE_ADDRESS"

    # 设置回源域名SAAS自定义主机名
    log_info "=== 设置回源域名SAAS自定义主机名 ==="
    local origin_hostname_id=$(set_custom_hostname "$ORIGIN_DOMAIN" "$origin_zone_id" "$PRIMARY_DOMAIN")
    if [[ $? -ne 0 ]]; then
        log_error "设置回源域名SAAS自定义主机名失败，退出脚本"
        exit 1
    fi
    
    # 获取DCV UUID
    log_info "=== 获取DCV UUID ==="
    if [[ -z "$DCV_UUID" ]]; then
        # 如果用户没有提供DCV_UUID，则从回源域名的自定义主机名中获取
        DCV_UUID=$(get_dcv_uuid "$origin_hostname_id")
        if [[ $? -ne 0 || -z "$DCV_UUID" ]]; then
            log_error "获取DCV UUID失败，退出脚本"
            exit 1
        fi
        log_success "获取DCV UUID成功: $DCV_UUID"
        echo "请复制上面的DCV UUID，以便后续使用"
    fi
    
    # 设置主域名自定义主机名
    log_info "=== 设置主域名自定义主机名 ==="
    set_custom_hostname "$PRIMARY_DOMAIN" "$primary_zone_id"
    if [[ $? -ne 0 ]]; then
        log_error "设置主域名自定义主机名失败，退出脚本"
        exit 1
    fi
    
# 设置主域名的DCV委派记录
    log_info "=== 设置主域名DCV委派记录 ==="
    set_dcv_delegation "$primary_zone_id" "$PRIMARY_DOMAIN" "$ORIGIN_DOMAIN" "$DCV_UUID"
    
    # 设置speed子域名CNAME记录 (speed.主域名 -> cf.090227.xyz)
    log_info "=== 设置speed子域名CNAME记录 ==="
    set_dns_record "$primary_zone_id" "speed.$PRIMARY_DOMAIN" "CNAME" "cf.090227.xyz"
    
    # 设置主域名CNAME记录 (主域名 -> speed.主域名)
    log_info "=== 设置主域名CNAME记录 ==="
    set_dns_record "$primary_zone_id" "$PRIMARY_DOMAIN" "CNAME" "speed.$PRIMARY_DOMAIN"

log_success "所有配置已完成！"

}

# 获取DCV UUID
get_dcv_uuid() {
    local hostname_id="$1"
    log_info "正在获取自定义主机名 $hostname_id 的DCV UUID"
    
    local response=$(cf_api_request "GET" "/custom_hostnames/${hostname_id}")
    
    if echo "$response" | jq -e '.success' > /dev/null; then
        # 从ssl_validation_records中提取DCV UUID
        local dcv_uuid=$(echo "$response" | jq -r '.result.ssl_validation_records[0].txt_value' | cut -d'.' -f2)
        if [[ -n "$dcv_uuid" && "$dcv_uuid" != "null" ]]; then
            log_success "获取DCV UUID成功: $dcv_uuid"
            echo "$dcv_uuid"
            return 0
        else
            log_error "未找到自定义主机名 $hostname_id 的DCV UUID"
            return 1
        fi
    else
        log_error "获取DCV UUID失败"
        echo "$response" | jq -r '.errors[] | "Error: \(.code) - \(.message)"'
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
    local dcv_target="${origin_domain}.${dcv_uuid}.dcv.cloudflare.com"
    
    # 设置_acme-challenge记录指向回源域名的DCV验证端点
    set_dns_record "$zone_id" "_acme-challenge.${primary_domain}" "CNAME" "$dcv_target"
}
    
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
            --dcv-uuid)
                DCV_UUID="$2"
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
                echo "  --dcv-uuid UUID          DCV UUID，用于设置主域名的DCV委派记录"
                echo "  --service-address ADDR   本地服务地址 (例如: http://192.168.1.3:5244)"
                echo "  --tunnel-id ID           直接指定tunnel ID（可选）"
                echo "  --tunnel-name NAME       新tunnel名称（可选）"
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

# 执行主函数
parse_args "$@"
main "$@"