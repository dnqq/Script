#!/bin/bash

# ==================================================
# 脚本名称: install_XrayR.sh
# 脚本作用: 自动安装并配置 XrayR 服务
# 使用方式:
#   1. 直接运行: curl -s https://xxx.xyz/shell/install_XrayR.sh | bash
#   2. 带参数运行: curl -s https://xxx.xyz/shell/install_XrayR.sh | bash -s -- "api_host" "api_key" "node_id" "cert_domain" "email" "cf_token"
# ==================================================

# 定义默认值
DEFAULT_API_HOST=""
DEFAULT_API_KEY=""
DEFAULT_NODE_ID="6"
DEFAULT_CERT_DOMAIN=""
DEFAULT_EMAIL=""
DEFAULT_CF_TOKEN=""

# 从命令行参数获取值
API_HOST=${1:-$DEFAULT_API_HOST}
API_KEY=${2:-$DEFAULT_API_KEY}
NODE_ID=${3:-$DEFAULT_NODE_ID}
CERT_DOMAIN=${4:-$DEFAULT_CERT_DOMAIN}
EMAIL=${5:-$DEFAULT_EMAIL}
CF_TOKEN=${6:-$DEFAULT_CF_TOKEN}

# 定义安装目录
INSTALL_DIR="/opt/XrayR"

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 切换到安装目录
cd "$INSTALL_DIR" || { echo "无法进入目录 $INSTALL_DIR"; exit 1; }

# 克隆 XrayR 项目
git clone https://github.com/XrayR-project/XrayR-release .
rm -rf config/config.yml

# 创建配置文件
cat <<EOF > config/config.yml
Log:
  Level: none # Log level: none, error, warning, info, debug
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
  -
    PanelType: "NewV2board" # Panel type: SSpanel, V2board, PMpanel, , Proxypanel
    ApiConfig:
      ApiHost: "{{API_HOST}}"
      ApiKey: "{{API_KEY}}"
      NodeID: {{NODE_ID}}
      NodeType: Trojan # Node type: V2ray, Shadowsocks, Trojan, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
      RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: dns # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "{{CERT_DOMAIN}}" # Domain to cert
        CertFile: /etc/XrayR/cert/certificates/CertDomain.cert # Provided if the CertMode is file
        KeyFile: /etc/XrayR/cert/certificates/CertDomain.key
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: {{EMAIL}}
        DNSEnv: # DNS ENV option used by DNS provider
          CF_DNS_API_TOKEN: {{CF_TOKEN}}
EOF

# 如果没有通过参数传入值，则交互式获取
if [ -z "$API_HOST" ]; then
    read -p "请输入面板地址 (ApiHost): " API_HOST
fi

if [ -z "$API_KEY" ]; then
    read -p "请输入面板密钥 (ApiKey): " API_KEY
fi

if [ -z "$NODE_ID" ]; then
    read -p "请输入节点ID (NodeID): " NODE_ID
fi

if [ -z "$CERT_DOMAIN" ]; then
    read -p "请输入域名 (CertDomain): " CERT_DOMAIN
fi

if [ -z "$EMAIL" ]; then
    read -p "请输入邮箱 (Email): " EMAIL
fi

if [ -z "$CF_TOKEN" ]; then
    read -p "请输入 Cloudflare API Token: " CF_TOKEN
fi

# 替换配置文件中的参数
sed -i "s|{{API_HOST}}|${API_HOST}|g" config/config.yml
sed -i "s|{{API_KEY}}|${API_KEY}|g" config/config.yml
sed -i "s|{{NODE_ID}}|${NODE_ID}|g" config/config.yml
sed -i "s|{{CERT_DOMAIN}}|${CERT_DOMAIN}|g" config/config.yml
sed -i "s|{{EMAIL}}|${EMAIL}|g" config/config.yml
sed -i "s|{{CF_TOKEN}}|${CF_TOKEN}|g" config/config.yml

# 启动 XrayR 服务
docker compose up -d

# 检查服务是否启动成功
if [ $? -eq 0 ]; then
  echo "XrayR 服务已成功启动！"
  echo "配置文件路径：$INSTALL_DIR/config/config.yml"
else
  echo "XrayR 服务启动失败，请检查配置是否正确。"
fi


