#!/bin/bash

################################################################################
# OpenSearch Secure Setup Script - Public Access with TLS
# Purpose: Automated installation and configuration of OpenSearch cluster
# Target: Ubuntu-based systems (20.04/22.04/24.04)
# Author: Senior DevOps Engineer
# Version: 2.0.0
################################################################################

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Better word splitting

################################################################################
# CONFIGURATION SECTION - CUSTOMIZE THESE VALUES
################################################################################

# OpenSearch Version (latest stable as of Oct 2024)
OPENSEARCH_VERSION="2.17.1"
DASHBOARDS_VERSION="2.17.1"

# Installation Paths
OPENSEARCH_HOME="/opt/opensearch"
DASHBOARDS_HOME="/opt/opensearch-dashboards"
DATA_DIR="/var/lib/opensearch"
LOG_DIR="/var/log/opensearch"
CONFIG_DIR="/etc/opensearch"

# System User
OPENSEARCH_USER="opensearch"
OPENSEARCH_GROUP="opensearch"

# Network Configuration - PUBLIC ACCESS
OPENSEARCH_HOST="0.0.0.0"  # Bind to all interfaces
OPENSEARCH_PORT="9200"
DASHBOARDS_PORT="5601"

# Security Configuration - Multiple Users
ADMIN_USERNAME="admin"
ADMIN_PASSWORD="${OPENSEARCH_ADMIN_PASSWORD:-ChangeMe@2025!}"

# Define multiple team users (add more as needed)
declare -A TEAM_USERS=(
    ["teamuser1"]="${OPENSEARCH_TEAM1_PASSWORD:-TeamPass1@2025!}"
    ["teamuser2"]="${OPENSEARCH_TEAM2_PASSWORD:-TeamPass2@2025!}"
    ["analyst1"]="${OPENSEARCH_ANALYST1_PASSWORD:-AnalystPass@2025!}"
    ["developer1"]="${OPENSEARCH_DEV1_PASSWORD:-DevPass@2025!}"
)

# Allowed IP Addresses (comma-separated, no spaces)
# Leave empty for public access from anywhere
# Example: "203.0.113.0/24,198.51.100.50,192.168.1.0/24"
ALLOWED_IPS="${OPENSEARCH_ALLOWED_IPS:-}"

# JVM Heap Size (50% of available RAM, max 32GB recommended)
# For 2GB instance, use 512m to leave room for Dashboard and OS
JVM_HEAP_SIZE="${OPENSEARCH_HEAP_SIZE:-512m}"

# Cluster Configuration
CLUSTER_NAME="opensearch-cluster"
NODE_NAME="opensearch-node-1"

# TLS Configuration
ENABLE_DASHBOARDS_TLS="${OPENSEARCH_DASHBOARDS_TLS:-true}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# HELPER FUNCTIONS
################################################################################

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_system_resources() {
    local total_mem
    total_mem=$(free -m | awk '/^Mem:/{print $2}')

    local cpu_cores
    cpu_cores=$(nproc)
    
    log_info "System Resources: ${total_mem}MB RAM, ${cpu_cores} CPU cores"
    
    if [[ $total_mem -lt 900 ]]; then
        log_error "Less than 900MB RAM detected. OpenSearch requires minimum 1GB RAM."
        log_error "Current system has insufficient memory to run OpenSearch safely."
        exit 1
    elif [[ $total_mem -lt 1100 ]]; then
        log_warning "═══════════════════════════════════════════════════════════"
        log_warning "LOW MEMORY MODE: ~1GB RAM detected (${total_mem}MB)"
        log_warning "Setting ULTRA-LOW heap size (200m) for minimal operation"
        log_warning "═══════════════════════════════════════════════════════════"
        log_warning "IMPORTANT:"
        log_warning "  • Performance will be SEVERELY limited"
        log_warning "  • Only suitable for testing/development"
        log_warning "  • NOT recommended for production use"
        log_warning "  • Consider upgrading to 2GB+ RAM"
        log_warning "  • Dashboard may be slow to respond"
        log_warning "═══════════════════════════════════════════════════════════"
        JVM_HEAP_SIZE="200m"
        sleep 5  # Give user time to read warnings
    elif [[ $total_mem -lt 2048 ]]; then
        log_warning "Low RAM detected (${total_mem}MB). Setting minimal heap size (256m)."
        log_warning "Performance will be limited. Consider upgrading to 4GB+ for production."
        JVM_HEAP_SIZE="256m"
    elif [[ $total_mem -lt 3072 ]]; then
        log_warning "2GB RAM detected. Setting conservative heap size (512m)."
        log_warning "This leaves memory for Dashboard and OS. Performance may be limited."
        JVM_HEAP_SIZE="512m"
    elif [[ $total_mem -lt 4096 ]]; then
        log_info "3GB RAM detected. Setting heap size to 1g."
        JVM_HEAP_SIZE="1g"
    fi
    
    log_info "JVM Heap Size will be set to: $JVM_HEAP_SIZE"
}

validate_configuration() {
    log_info "Validating configuration..."
    
    # Check for strong passwords
    if [[ ${#ADMIN_PASSWORD} -lt 8 ]]; then
        log_error "Admin password must be at least 8 characters long"
        exit 1
    fi
    
    # Validate team user passwords
    for user in "${!TEAM_USERS[@]}"; do
        local pass="${TEAM_USERS[$user]}"
        if [[ ${#pass} -lt 8 ]]; then
            log_error "Password for user '$user' must be at least 8 characters long"
            exit 1
        fi
    done
    
    # Warn about public access
    if [[ -z "$ALLOWED_IPS" ]]; then
        log_warning "═══════════════════════════════════════════════════════════"
        log_warning "PUBLIC ACCESS MODE: OpenSearch will be accessible from ANY IP"
        log_warning "Ensure you use strong passwords and keep them secure!"
        log_warning "Consider setting OPENSEARCH_ALLOWED_IPS for IP restrictions"
        log_warning "═══════════════════════════════════════════════════════════"
        sleep 3
    fi
    
    log_success "Configuration validated"
}

################################################################################
# INSTALLATION FUNCTIONS
################################################################################

install_prerequisites() {
    log_info "Installing prerequisites..."
    
    apt-get update -qq
    apt-get install -y \
        curl \
        wget \
        gnupg \
        apt-transport-https \
        ca-certificates \
        openssl \
        ufw \
        jq \
        tar \
        gzip
    
    log_success "Prerequisites installed"
}

install_java() {
    log_info "Installing OpenJDK 21..."
    
    if command -v java &> /dev/null; then
        local java_version
        java_version=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
        log_info "Java already installed: $java_version"
    else
        apt-get install -y openjdk-21-jdk
    fi
    
    java -version
    log_success "Java installed successfully"
}

create_system_user() {
    log_info "Creating OpenSearch system user..."
    
    if id "$OPENSEARCH_USER" &>/dev/null; then
        log_info "User $OPENSEARCH_USER already exists"
    else
        useradd -r -m -U -d "$OPENSEARCH_HOME" -s /bin/bash "$OPENSEARCH_USER"
        log_success "User $OPENSEARCH_USER created"
    fi
}

create_directories() {
    log_info "Creating directory structure..."
    
    mkdir -p "$OPENSEARCH_HOME"
    mkdir -p "$DASHBOARDS_HOME"
    mkdir -p "$DATA_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "/etc/opensearch-dashboards"
    
    log_success "Directories created"
}

download_opensearch() {
    log_info "Downloading OpenSearch $OPENSEARCH_VERSION..."
    
    local download_url="https://artifacts.opensearch.org/releases/bundle/opensearch/$OPENSEARCH_VERSION/opensearch-$OPENSEARCH_VERSION-linux-x64.tar.gz"
    local tarball="/tmp/opensearch-${OPENSEARCH_VERSION}.tar.gz"
    
    if [[ -f "$tarball" ]]; then
        log_info "OpenSearch tarball already downloaded"
    else
        wget -q --show-progress "$download_url" -O "$tarball"
    fi
    
    log_info "Extracting OpenSearch..."
    tar -xzf "$tarball" -C "$OPENSEARCH_HOME" --strip-components=1
    
    log_success "OpenSearch downloaded and extracted"
}

download_dashboards() {
    log_info "Downloading OpenSearch Dashboards $DASHBOARDS_VERSION..."
    
    local download_url="https://artifacts.opensearch.org/releases/bundle/opensearch-dashboards/$DASHBOARDS_VERSION/opensearch-dashboards-$DASHBOARDS_VERSION-linux-x64.tar.gz"
    local tarball="/tmp/opensearch-dashboards-${DASHBOARDS_VERSION}.tar.gz"
    
    if [[ -f "$tarball" ]]; then
        log_info "Dashboards tarball already downloaded"
    else
        wget -q --show-progress "$download_url" -O "$tarball"
    fi
    
    log_info "Extracting OpenSearch Dashboards..."
    tar -xzf "$tarball" -C "$DASHBOARDS_HOME" --strip-components=1
    
    log_success "OpenSearch Dashboards downloaded and extracted"
}

generate_certificates() {
    log_info "Generating TLS certificates for public access..."
    
    local cert_dir="$CONFIG_DIR/certs"
    mkdir -p "$cert_dir"
    
    # Get server IP for certificate
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')
    local server_hostname
    server_hostname=$(hostname -f)
    
    # Generate root CA
    openssl genrsa -out "$cert_dir/root-ca-key.pem" 2048
    openssl req -new -x509 -sha256 -key "$cert_dir/root-ca-key.pem" \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=root.opensearch.local" \
        -out "$cert_dir/root-ca.pem" -days 730
    
    # Generate admin cert
    openssl genrsa -out "$cert_dir/admin-key-temp.pem" 2048
    openssl pkcs8 -inform PEM -outform PEM -in "$cert_dir/admin-key-temp.pem" \
        -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "$cert_dir/admin-key.pem"
    openssl req -new -key "$cert_dir/admin-key.pem" \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=admin.opensearch.local" \
        -out "$cert_dir/admin.csr"
    openssl x509 -req -in "$cert_dir/admin.csr" -CA "$cert_dir/root-ca.pem" \
        -CAkey "$cert_dir/root-ca-key.pem" -CAcreateserial \
        -sha256 -out "$cert_dir/admin.pem" -days 730
    
    # Generate node cert with SAN for IP and hostname
    cat > "$cert_dir/node.ext" <<EOF
subjectAltName = DNS:localhost,DNS:$server_hostname,IP:127.0.0.1,IP:$server_ip
EOF
    
    openssl genrsa -out "$cert_dir/node-key-temp.pem" 2048
    openssl pkcs8 -inform PEM -outform PEM -in "$cert_dir/node-key-temp.pem" \
        -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "$cert_dir/node-key.pem"
    openssl req -new -key "$cert_dir/node-key.pem" \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=$server_hostname" \
        -out "$cert_dir/node.csr"
    openssl x509 -req -in "$cert_dir/node.csr" -CA "$cert_dir/root-ca.pem" \
        -CAkey "$cert_dir/root-ca-key.pem" -CAcreateserial \
        -sha256 -out "$cert_dir/node.pem" -days 730 -extfile "$cert_dir/node.ext"
    
    # Generate dashboard cert (if TLS enabled)
    if [[ "$ENABLE_DASHBOARDS_TLS" == "true" ]]; then
        openssl genrsa -out "$cert_dir/dashboard-key-temp.pem" 2048
        openssl pkcs8 -inform PEM -outform PEM -in "$cert_dir/dashboard-key-temp.pem" \
            -topk8 -nocrypt -v1 PBE-SHA1-3DES -out "$cert_dir/dashboard-key.pem"
        openssl req -new -key "$cert_dir/dashboard-key.pem" \
            -subj "/C=US/ST=State/L=City/O=Organization/OU=IT/CN=$server_hostname" \
            -out "$cert_dir/dashboard.csr"
        openssl x509 -req -in "$cert_dir/dashboard.csr" -CA "$cert_dir/root-ca.pem" \
            -CAkey "$cert_dir/root-ca-key.pem" -CAcreateserial \
            -sha256 -out "$cert_dir/dashboard.pem" -days 730 -extfile "$cert_dir/node.ext"
    fi
    
    # Cleanup temp files
    rm -f "$cert_dir"/*-temp.pem "$cert_dir"/*.csr "$cert_dir"/*.srl "$cert_dir"/*.ext
    
    # Set permissions
    chmod 600 "$cert_dir"/*-key.pem
    chmod 644 "$cert_dir"/*.pem
    
    log_success "TLS certificates generated for $server_ip"
}

configure_opensearch() {
    log_info "Configuring OpenSearch for public access with TLS..."
    
    local config_file="$OPENSEARCH_HOME/config/opensearch.yml"
    
    cat > "$config_file" <<EOF
# OpenSearch Configuration - Public Access with TLS
# Generated by automated setup script

cluster.name: $CLUSTER_NAME
node.name: $NODE_NAME

# Paths
path.data: $DATA_DIR
path.logs: $LOG_DIR

# Network - PUBLIC ACCESS
network.host: $OPENSEARCH_HOST
http.port: $OPENSEARCH_PORT
transport.port: 9300

# Discovery (single-node setup)
discovery.type: single-node

# Security Plugin Configuration - TLS Enabled
plugins.security.ssl.transport.pemcert_filepath: certs/node.pem
plugins.security.ssl.transport.pemkey_filepath: certs/node-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: certs/root-ca.pem
plugins.security.ssl.transport.enforce_hostname_verification: false

plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.pemcert_filepath: certs/node.pem
plugins.security.ssl.http.pemkey_filepath: certs/node-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: certs/root-ca.pem

plugins.security.allow_unsafe_democertificates: false
plugins.security.allow_default_init_securityindex: true

plugins.security.authcz.admin_dn:
  - 'CN=admin.opensearch.local,OU=IT,O=Organization,L=City,ST=State,C=US'

plugins.security.nodes_dn:
  - 'CN=*.opensearch.local,OU=IT,O=Organization,L=City,ST=State,C=US'
  - 'CN=$(hostname -f),OU=IT,O=Organization,L=City,ST=State,C=US'

plugins.security.audit.type: internal_opensearch
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.restapi.roles_enabled: ["all_access", "security_rest_api_access"]

# Performance Tuning
bootstrap.memory_lock: true
indices.query.bool.max_clause_count: 10000

# CORS Configuration for public access
http.cors.enabled: true
http.cors.allow-origin: "*"
http.cors.allow-methods: OPTIONS, HEAD, GET, POST, PUT, DELETE
http.cors.allow-headers: X-Requested-With, X-Auth-Token, Content-Type, Content-Length, Authorization
EOF

    # Copy certificates to OpenSearch config
    cp -r "$CONFIG_DIR/certs" "$OPENSEARCH_HOME/config/"
    
    # Configure JVM options
    local jvm_options="$OPENSEARCH_HOME/config/jvm.options"
    sed -i "s/^-Xms.*/-Xms${JVM_HEAP_SIZE}/" "$jvm_options"
    sed -i "s/^-Xmx.*/-Xmx${JVM_HEAP_SIZE}/" "$jvm_options"
    
    # Add low-memory optimizations for systems with <=512m heap
    if [[ "$JVM_HEAP_SIZE" == "200m" ]] || [[ "$JVM_HEAP_SIZE" == "256m" ]] || [[ "$JVM_HEAP_SIZE" == "512m" ]]; then
        log_info "Applying low-memory JVM optimizations..."
        cat >> "$jvm_options" <<'JVMEOF'

## Low-Memory Optimizations (Auto-configured)
# Use G1GC for better performance with small heaps
-XX:+UseG1GC
-XX:MaxGCPauseMillis=200
-XX:InitiatingHeapOccupancyPercent=45
-XX:G1HeapRegionSize=1M

# Reduce memory overhead
-XX:+UseStringDeduplication
-XX:+ParallelRefProcEnabled

# Reduce metaspace for low memory
-XX:MetaspaceSize=128m
-XX:MaxMetaspaceSize=256m
JVMEOF
        log_success "Low-memory JVM optimizations applied"
    fi
    
    log_success "OpenSearch configured for public access"
}

configure_dashboards() {
    log_info "Configuring OpenSearch Dashboards for public access..."
    
    local config_file="$DASHBOARDS_HOME/config/opensearch_dashboards.yml"
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')
    
    cat > "$config_file" <<EOF
# OpenSearch Dashboards Configuration - Public Access
# Generated by automated setup script

server.port: $DASHBOARDS_PORT
server.host: "0.0.0.0"
server.name: "opensearch-dashboards"

opensearch.hosts: ["https://127.0.0.1:$OPENSEARCH_PORT"]
opensearch.ssl.verificationMode: none
opensearch.username: "$ADMIN_USERNAME"
opensearch.password: "$ADMIN_PASSWORD"

opensearch.requestHeadersAllowlist: ["authorization", "securitytenant"]

opensearch_security.multitenancy.enabled: true
opensearch_security.multitenancy.tenants.preferred: ["Private", "Global"]
opensearch_security.readonly_mode.roles: ["kibana_read_only"]

# TLS Configuration for Dashboards
EOF

    if [[ "$ENABLE_DASHBOARDS_TLS" == "true" ]]; then
        cat >> "$config_file" <<EOF
server.ssl.enabled: true
server.ssl.certificate: $CONFIG_DIR/certs/dashboard.pem
server.ssl.key: $CONFIG_DIR/certs/dashboard-key.pem
EOF
        log_info "Dashboards TLS enabled - will be accessible via HTTPS"
    else
        cat >> "$config_file" <<EOF
server.ssl.enabled: false
EOF
        log_info "Dashboards TLS disabled - will be accessible via HTTP"
    fi

    cat >> "$config_file" <<EOF

EOF

    log_success "OpenSearch Dashboards configured for public access"
}

set_permissions() {
    log_info "Setting file permissions..."
    
    chown -R "$OPENSEARCH_USER:$OPENSEARCH_GROUP" "$OPENSEARCH_HOME"
    chown -R "$OPENSEARCH_USER:$OPENSEARCH_GROUP" "$DASHBOARDS_HOME"
    chown -R "$OPENSEARCH_USER:$OPENSEARCH_GROUP" "$DATA_DIR"
    chown -R "$OPENSEARCH_USER:$OPENSEARCH_GROUP" "$LOG_DIR"
    chown -R "$OPENSEARCH_USER:$OPENSEARCH_GROUP" "$CONFIG_DIR"
    
    # Restrict permissions on sensitive files
    chmod 600 "$OPENSEARCH_HOME/config/opensearch.yml"
    chmod 600 "$DASHBOARDS_HOME/config/opensearch_dashboards.yml"
    
    log_success "Permissions set"
}

configure_system_limits() {
    log_info "Configuring system limits..."
    
    # Add limits for opensearch user
    cat >> /etc/security/limits.conf <<EOF

# OpenSearch limits
$OPENSEARCH_USER soft nofile 65536
$OPENSEARCH_USER hard nofile 65536
$OPENSEARCH_USER soft memlock unlimited
$OPENSEARCH_USER hard memlock unlimited
EOF

    # Get total memory
    local total_mem
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    
    # Disable swap only on systems with >1GB RAM
    # On 1GB systems, keep swap as safety net to prevent OOM
    if [[ $total_mem -gt 1100 ]]; then
        log_info "Disabling swap for better performance..."
        swapoff -a
        sed -i '/ swap / s/^/#/' /etc/fstab
    else
        log_warning "LOW MEMORY: Keeping swap enabled as safety measure"
        log_warning "This may impact performance but prevents OOM errors"
        # Ensure swap exists, create if needed
        if ! swapon --show | grep -q '/'; then
            log_info "Creating 1GB swap file for low-memory system..."
            if [[ ! -f /swapfile ]]; then
                dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                # Add to fstab if not present
                if ! grep -q '/swapfile' /etc/fstab; then
                    echo '/swapfile none swap sw 0 0' >> /etc/fstab
                fi
                log_success "1GB swap file created and enabled"
            fi
        fi
    fi
    
    # Increase virtual memory
    sysctl -w vm.max_map_count=262144
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
    
    # On low-memory systems, tune swappiness
    if [[ $total_mem -lt 1100 ]]; then
        sysctl -w vm.swappiness=10
        echo "vm.swappiness=10" >> /etc/sysctl.conf
        log_info "Set vm.swappiness=10 for low-memory optimization"
    fi
    
    log_success "System limits configured"
}

create_systemd_services() {
    log_info "Creating systemd services..."
    
    # OpenSearch service
    cat > /etc/systemd/system/opensearch.service <<EOF
[Unit]
Description=OpenSearch
Documentation=https://opensearch.org/docs/latest
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$OPENSEARCH_USER
Group=$OPENSEARCH_GROUP
Environment=OPENSEARCH_HOME=$OPENSEARCH_HOME
Environment=OPENSEARCH_PATH_CONF=$OPENSEARCH_HOME/config
WorkingDirectory=$OPENSEARCH_HOME

ExecStart=$OPENSEARCH_HOME/bin/opensearch

StandardOutput=journal
StandardError=journal

LimitNOFILE=65536
LimitNPROC=4096
LimitAS=infinity
LimitFSIZE=infinity
LimitMEMLOCK=infinity

TimeoutStopSec=0
KillMode=process
KillSignal=SIGTERM
SendSIGKILL=no
SuccessExitStatus=143

Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # OpenSearch Dashboards service
    # Adjust Node.js memory based on system RAM
    local node_memory="2048"
    local total_mem
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    
    if [[ $total_mem -lt 1100 ]]; then
        node_memory="512"  # Ultra-low for 1GB systems
        log_info "Setting Dashboard Node.js memory to ${node_memory}MB (low-memory mode)"
    elif [[ $total_mem -lt 2048 ]]; then
        node_memory="768"  # Low for <2GB systems
        log_info "Setting Dashboard Node.js memory to ${node_memory}MB"
    fi
    
    cat > /etc/systemd/system/opensearch-dashboards.service <<EOF
[Unit]
Description=OpenSearch Dashboards
Documentation=https://opensearch.org/docs/latest
Wants=network-online.target opensearch.service
After=network-online.target opensearch.service

[Service]
Type=simple
User=$OPENSEARCH_USER
Group=$OPENSEARCH_GROUP
Environment=NODE_OPTIONS="--max-old-space-size=${node_memory}"
WorkingDirectory=$DASHBOARDS_HOME

ExecStart=$DASHBOARDS_HOME/bin/opensearch-dashboards

StandardOutput=journal
StandardError=journal

Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    
    log_success "Systemd services created"
}

configure_security_users() {
    log_info "Configuring security users and roles..."
    
    # Check available memory
    local available_mem
    available_mem=$(free -m | awk '/^Mem:/{print $7}')
    log_info "Available memory: ${available_mem}MB"
    
    # On low memory systems, skip temporary OpenSearch startup to avoid OOM
    if [[ $available_mem -lt 800 ]]; then
        log_warning "Low memory detected (${available_mem}MB). Using direct configuration mode."
        log_info "Security will be initialized on first OpenSearch startup by systemd."
    fi
    
    # Clean up any existing processes and locks
    log_info "Cleaning up any existing OpenSearch processes..."
    pkill -9 -f "org.opensearch.bootstrap.OpenSearch" 2>/dev/null || true
    sleep 2
    rm -rf /var/lib/opensearch/nodes/*/node.lock 2>/dev/null || true
    
    # Configure user passwords
    log_info "Generating password hashes for users..."
    cd "$OPENSEARCH_HOME/plugins/opensearch-security/tools"
    
    export JAVA_HOME
    JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"
    
    # Generate admin password hash
    log_info "Hashing admin password..."
    local admin_hash
    admin_hash=$(bash hash.sh -p "$ADMIN_PASSWORD" 2>/dev/null)
    
    if [[ -z "$admin_hash" ]]; then
        log_error "Failed to generate password hash"
        exit 1
    fi
    
    # Create internal_users.yml with all users
    cat > "$OPENSEARCH_HOME/config/opensearch-security/internal_users.yml" <<EOF
---
_meta:
  type: "internalusers"
  config_version: 2

admin:
  hash: "$admin_hash"
  reserved: true
  backend_roles:
  - "admin"
  description: "Admin user with full access"

EOF

    # Add all team users
    for username in "${!TEAM_USERS[@]}"; do
        local password="${TEAM_USERS[$username]}"
        local user_hash
        user_hash=$(bash hash.sh -p "$password")
        
        cat >> "$OPENSEARCH_HOME/config/opensearch-security/internal_users.yml" <<EOF
$username:
  hash: "$user_hash"
  reserved: false
  backend_roles:
  - "admin"
  description: "Team user with full access"

EOF
        log_info "Configured user: $username"
    done

    # Security configuration files are now created
    # They will be automatically loaded when OpenSearch starts via systemd
    log_success "Security configuration files created"
    log_info "Security will be initialized on first OpenSearch startup"
    
    # Clean up
    rm -f /tmp/admin_hash.txt 2>/dev/null || true
    
    # Ensure no processes are running
    pkill -9 -f "org.opensearch.bootstrap.OpenSearch" 2>/dev/null || true
    sleep 1
    
    log_success "Security users configured - Total users: $((${#TEAM_USERS[@]} + 1))"
}

configure_firewall() {
    log_info "Configuring firewall for public access..."
    
    # Enable UFW if not already enabled
    ufw --force enable
    
    # Allow SSH (important!)
    ufw allow 22/tcp
    
    if [[ -n "$ALLOWED_IPS" ]]; then
        log_info "Restricting OpenSearch access to specified IPs..."
        IFS=',' read -ra IP_ARRAY <<< "$ALLOWED_IPS"
        for ip in "${IP_ARRAY[@]}"; do
            ufw allow from "$ip" to any port "$OPENSEARCH_PORT" proto tcp
            ufw allow from "$ip" to any port "$DASHBOARDS_PORT" proto tcp
            log_info "Allowed access from: $ip"
        done
    else
        log_info "Configuring PUBLIC ACCESS - OpenSearch accessible from anywhere"
        ufw allow "$OPENSEARCH_PORT"/tcp
        ufw allow "$DASHBOARDS_PORT"/tcp
    fi
    
    # Reload firewall
    ufw reload
    
    log_success "Firewall configured for public access"
}

################################################################################
# SERVICE MANAGEMENT
################################################################################

start_services() {
    log_info "Starting OpenSearch services..."
    
    systemctl enable opensearch
    systemctl start opensearch
    
    log_info "Waiting for OpenSearch to start (30-60 seconds)..."
    sleep 30
    
    systemctl enable opensearch-dashboards
    systemctl start opensearch-dashboards
    
    log_info "Waiting for Dashboards to start (30-45 seconds)..."
    log_info "Dashboard needs time to connect to OpenSearch and initialize..."
    sleep 30
    
    log_success "Services started"
}

health_check() {
    log_info "Running health checks..."
    
    local server_ip
    server_ip=$(hostname -I | awk '{print $1}')
    
    # Check OpenSearch
    log_info "Testing OpenSearch connection..."
    local opensearch_response
    opensearch_response=$(curl -k -s -u "$ADMIN_USERNAME:$ADMIN_PASSWORD" "https://127.0.0.1:$OPENSEARCH_PORT" || echo "failed")
    
    if [[ "$opensearch_response" == "failed" ]]; then
        log_error "OpenSearch health check failed"
        systemctl status opensearch --no-pager
        return 1
    else
        log_success "OpenSearch is healthy"
        echo "$opensearch_response" | jq -r '.version.number' | xargs -I {} log_info "OpenSearch version: {}"
    fi
    
    # Check Dashboards with retries
    log_info "Testing OpenSearch Dashboards..."
    local dashboard_protocol="http"
    if [[ "$ENABLE_DASHBOARDS_TLS" == "true" ]]; then
        dashboard_protocol="https"
    fi
    
    local dashboard_response
    local max_retries=6
    local retry_count=0
    local dashboard_ready=false
    
    while [[ $retry_count -lt $max_retries ]]; do
        dashboard_response=$(curl -k -s -o /dev/null -w "%{http_code}" "$dashboard_protocol://127.0.0.1:$DASHBOARDS_PORT/api/status" 2>/dev/null || echo "000")
        
        if [[ "$dashboard_response" == "200" ]] || [[ "$dashboard_response" == "302" ]]; then
            log_success "OpenSearch Dashboards is healthy and responding"
            dashboard_ready=true
            break
        else
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                log_info "Dashboard not ready yet (Status: $dashboard_response), waiting 10s... (attempt $retry_count/$max_retries)"
                sleep 10
            fi
        fi
    done
    
    if [[ "$dashboard_ready" == "false" ]]; then
        log_warning "Dashboard may still be initializing (Final Status: $dashboard_response)"
        log_warning "Check logs with: sudo journalctl -u opensearch-dashboards -f"
    fi
    
    echo ""
    log_success "═══════════════════════════════════════════════════════════════"
    log_success "  OpenSearch Setup Complete - PUBLIC ACCESS WITH TLS"
    log_success "═══════════════════════════════════════════════════════════════"
    echo ""
    log_info "Access URLs (Share these with your team):"
    echo ""
    echo "  🌐 OpenSearch API (HTTPS):"
    echo "     https://$server_ip:$OPENSEARCH_PORT"
    echo ""
    if [[ "$ENABLE_DASHBOARDS_TLS" == "true" ]]; then
        echo "  📊 Dashboards UI (HTTPS):"
        echo "     https://$server_ip:$DASHBOARDS_PORT"
    else
        echo "  📊 Dashboards UI (HTTP):"
        echo "     http://$server_ip:$DASHBOARDS_PORT"
    fi
    echo ""
    log_success "═══════════════════════════════════════════════════════════════"
    log_info "User Credentials:"
    echo ""
    echo "  👤 Admin Account:"
    echo "     Username: $ADMIN_USERNAME"
    echo "     Password: $ADMIN_PASSWORD"
    echo ""
    echo "  👥 Team Accounts:"
    for username in "${!TEAM_USERS[@]}"; do
        echo "     Username: $username"
        echo "     Password: ${TEAM_USERS[$username]}"
        echo ""
    done
    log_success "═══════════════════════════════════════════════════════════════"
    echo ""
    log_warning "⚠️  IMPORTANT SECURITY NOTES:"
    echo "  1. Change ALL default passwords immediately after first login"
    echo "  2. Store passwords securely (use a password manager)"
    echo "  3. Your browser may show certificate warnings (self-signed certs)"
    echo "     Click 'Advanced' → 'Proceed' to access the Dashboard"
    echo "  4. OpenSearch is publicly accessible - monitor access logs"
    if [[ -z "$ALLOWED_IPS" ]]; then
        echo "  5. Consider restricting IPs via OPENSEARCH_ALLOWED_IPS env var"
    fi
    echo ""
    log_warning "☁️  AWS/CLOUD USERS:"
    echo "  • Ensure Security Group allows inbound traffic on ports $OPENSEARCH_PORT and $DASHBOARDS_PORT"
    echo "  • Add rules for your IP or 0.0.0.0/0 (not recommended for production)"
    echo "  • Dashboard URL: $dashboard_protocol://$server_ip:$DASHBOARDS_PORT"
    echo "  • API URL: https://$server_ip:$OPENSEARCH_PORT"
    echo ""
    log_info "Quick Test Commands:"
    echo ""
    echo "  Test API access:"
    echo "  curl -k -u $ADMIN_USERNAME:$ADMIN_PASSWORD https://$server_ip:$OPENSEARCH_PORT"
    echo ""
    echo "  Test with team user:"
    local first_team_user="${!TEAM_USERS[0]}"
    echo "  curl -k -u $first_team_user:PASSWORD https://$server_ip:$OPENSEARCH_PORT"
    echo ""
    log_info "Service Management Commands:"
    echo "  systemctl status opensearch"
    echo "  systemctl status opensearch-dashboards"
    echo "  journalctl -u opensearch -f"
    echo "  journalctl -u opensearch-dashboards -f"
    echo ""
    log_info "Add More Users:"
    echo "  sudo $0 --add-user <username> <password>"
    echo ""
}

add_user() {
    local username="$1"
    local password="$2"

    if [[ -z "$username" || -z "$password" ]]; then
        log_error "Usage: $0 --add-user <username> <password>"
        exit 1
    fi

    if [[ ${#password} -lt 8 ]]; then
        log_error "Password must be at least 8 characters long"
        exit 1
    fi

    check_root

    log_info "Adding OpenSearch user '$username'..."

    cd "$OPENSEARCH_HOME/plugins/opensearch-security/tools"

    export JAVA_HOME
    JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"

    local hash
    hash=$(bash hash.sh -p "$password")

    # Check if user already exists
    if grep -q "^$username:" "$OPENSEARCH_HOME/config/opensearch-security/internal_users.yml"; then
        log_error "User '$username' already exists"
        exit 1
    fi

    cat >> "$OPENSEARCH_HOME/config/opensearch-security/internal_users.yml" <<EOF

$username:
  hash: "$hash"
  reserved: false
  backend_roles:
  - "admin"
  description: "Team user $username"
EOF

    bash securityadmin.sh \
        -cd "$OPENSEARCH_HOME/config/opensearch-security/" \
        -icl -nhnv \
        -cacert "$OPENSEARCH_HOME/config/certs/root-ca.pem" \
        -cert "$OPENSEARCH_HOME/config/certs/admin.pem" \
        -key "$OPENSEARCH_HOME/config/certs/admin-key.pem" \
        -h localhost

    log_success "User '$username' added successfully"
    log_info "Share these credentials with your team:"
    echo "  Username: $username"
    echo "  Password: $password"
}

list_users() {
    check_root
    
    log_info "Current OpenSearch users:"
    echo ""
    
    if [[ ! -f "$OPENSEARCH_HOME/config/opensearch-security/internal_users.yml" ]]; then
        log_error "OpenSearch not installed or configuration file not found"
        exit 1
    fi
    
    # Parse and display users
    grep -E "^[a-zA-Z0-9_-]+:" "$OPENSEARCH_HOME/config/opensearch-security/internal_users.yml" | \
    sed 's/:$//' | while read -r user; do
        if [[ "$user" != "_meta" ]]; then
            echo "  👤 $user"
        fi
    done
    echo ""
}

change_password() {
    local username="$1"
    local new_password="$2"

    if [[ -z "$username" || -z "$new_password" ]]; then
        log_error "Usage: $0 --change-password <username> <new_password>"
        exit 1
    fi

    if [[ ${#new_password} -lt 8 ]]; then
        log_error "Password must be at least 8 characters long"
        exit 1
    fi

    check_root

    log_info "Changing password for user '$username'..."

    cd "$OPENSEARCH_HOME/plugins/opensearch-security/tools"

    export JAVA_HOME
    JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"

    # Check if user exists
    if ! grep -q "^$username:" "$OPENSEARCH_HOME/config/opensearch-security/internal_users.yml"; then
        log_error "User '$username' does not exist"
        exit 1
    fi

    local new_hash
    new_hash=$(bash hash.sh -p "$new_password")

    # Update the password hash in the file
    sed -i "/^$username:/,/^[^ ]/ s|hash:.*|hash: \"$new_hash\"|" \
        "$OPENSEARCH_HOME/config/opensearch-security/internal_users.yml"

    bash securityadmin.sh \
        -cd "$OPENSEARCH_HOME/config/opensearch-security/" \
        -icl -nhnv \
        -cacert "$OPENSEARCH_HOME/config/certs/root-ca.pem" \
        -cert "$OPENSEARCH_HOME/config/certs/admin.pem" \
        -key "$OPENSEARCH_HOME/config/certs/admin-key.pem" \
        -h localhost

    log_success "Password changed successfully for user '$username'"
}

################################################################################
# CLEANUP FUNCTION
################################################################################

cleanup_opensearch() {
    log_warning "Starting OpenSearch cleanup/uninstall..."
    
    read -r -p "Are you sure you want to remove OpenSearch? This will delete all data! (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Cleanup cancelled"
        return
    fi
    
    # Stop services
    systemctl stop opensearch-dashboards opensearch || true
    systemctl disable opensearch-dashboards opensearch || true
    
    # Remove systemd services
    rm -f /etc/systemd/system/opensearch.service
    rm -f /etc/systemd/system/opensearch-dashboards.service
    systemctl daemon-reload
    
    # Remove installation directories
    rm -rf "$OPENSEARCH_HOME"
    rm -rf "$DASHBOARDS_HOME"
    rm -rf "$DATA_DIR"
    rm -rf "$LOG_DIR"
    rm -rf "$CONFIG_DIR"
    rm -rf /etc/opensearch-dashboards
    
    # Remove user
    userdel -r "$OPENSEARCH_USER" 2>/dev/null || true
    
    # Remove firewall rules
    ufw delete allow "$OPENSEARCH_PORT"/tcp || true
    ufw delete allow "$DASHBOARDS_PORT"/tcp || true
    
    log_success "OpenSearch cleanup complete"
}

show_help() {
    cat <<EOF
OpenSearch Secure Setup Script v2.0.0 - Public Access with TLS

USAGE:
    sudo $0 [OPTIONS]

OPTIONS:
    (no options)           Run full installation
    --add-user <user> <pass>     Add a new user
    --change-password <user> <pass>  Change user password
    --list-users           List all configured users
    --cleanup              Uninstall OpenSearch completely
    --uninstall            Same as --cleanup
    --help                 Show this help message

ENVIRONMENT VARIABLES:
    OPENSEARCH_ADMIN_PASSWORD      Admin password (default: ChangeMe@2025!)
    OPENSEARCH_DEV1_PASSWORD       Developer user password
    OPENSEARCH_ALLOWED_IPS         Comma-separated IP whitelist
    OPENSEARCH_HEAP_SIZE          JVM heap size (default: auto)
    OPENSEARCH_DASHBOARDS_TLS     Enable Dashboards TLS (default: true)

EXAMPLES:
    # Basic installation with defaults
    sudo bash $0

    # Installation with custom passwords
    sudo OPENSEARCH_ADMIN_PASSWORD='MySecure@Pass123' \\
         OPENSEARCH_DEV1_PASSWORD='Dev1@Pass456' \\
         bash $0

    # Add a new user after installation
    sudo bash $0 --add-user john 'JohnPass@789'

    # Change password
    sudo bash $0 --change-password john 'NewPass@123'

    # List all users
    sudo bash $0 --list-users

    # Restrict access to specific IPs
    sudo OPENSEARCH_ALLOWED_IPS='203.0.113.0/24,198.51.100.50' bash $0

FEATURES:
    ✓ Public HTTPS access with TLS encryption
    ✓ Multiple user accounts with role-based access
    ✓ Self-signed certificates (production: use Let's Encrypt)
    ✓ Optional Dashboards HTTPS
    ✓ Firewall configuration with optional IP restrictions
    ✓ Easy user management (add/change password)
    ✓ Systemd service integration
    ✓ Automatic health checks

SECURITY NOTES:
    • Change ALL default passwords after installation
    • Use strong passwords (min 8 characters)
    • Consider IP restrictions for production
    • Monitor access logs regularly
    • Self-signed certs will show browser warnings

EOF
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "  OpenSearch Secure Setup Script v2.0.0"
    log_info "  Public Access with TLS Encryption"
    log_info "═══════════════════════════════════════════════════════════════"
    echo ""
    
    # Handle command line options
    case "${1:-}" in
        --cleanup|--uninstall)
            check_root
            cleanup_opensearch
            exit 0
            ;;
        --add-user)
            add_user "${2:-}" "${3:-}"
            exit 0
            ;;
        --change-password)
            change_password "${2:-}" "${3:-}"
            exit 0
            ;;
        --list-users)
            list_users
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        --*)
            log_error "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
    
    # Pre-flight checks
    check_root
    validate_configuration
    detect_system_resources
    
    echo ""
    log_info "Starting installation..."
    echo ""
    
    # Installation steps
    install_prerequisites
    install_java
    create_system_user
    create_directories
    download_opensearch
    download_dashboards
    generate_certificates
    configure_opensearch
    configure_dashboards
    set_permissions
    configure_system_limits
    create_systemd_services
    configure_security_users
    configure_firewall
    start_services
    
    # Final health check
    sleep 5
    health_check
    
    log_success "Setup completed successfully!"
}

# Execute main function
main "$@"