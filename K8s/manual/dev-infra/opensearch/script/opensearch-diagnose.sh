#!/bin/bash

################################################################################
# OpenSearch Diagnostic Script
# Identifies and fixes common startup issues
################################################################################

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo "════════════════════════════════════════════════════════════"
echo "  OpenSearch Diagnostic Tool"
echo "════════════════════════════════════════════════════════════"
echo ""

# 1. Check system resources
log_info "Checking system resources..."
free -h
echo ""
df -h /var/lib/opensearch 2>/dev/null || df -h /
echo ""

total_mem=$(free -m | awk '/^Mem:/{print $2}')
available_mem=$(free -m | awk '/^Mem:/{print $7}')

if [[ $total_mem -lt 2048 ]]; then
    log_error "Total RAM: ${total_mem}MB - OpenSearch needs at least 2GB for stable operation"
    log_warning "Current available: ${available_mem}MB"
else
    log_success "RAM: ${total_mem}MB total, ${available_mem}MB available"
fi

# 2. Check if ports are in use
log_info "Checking if OpenSearch ports 9200 and 9300 are available..."
if netstat -tuln 2>/dev/null | grep -q ":9200 "; then
    log_warning "Port 9200 is already in use:"
    netstat -tuln | grep ":9200 "
    lsof -i :9200 2>/dev/null || true
else
    log_success "Port 9200 is available"
fi

if netstat -tuln 2>/dev/null | grep -q ":9300 "; then
    log_warning "Port 9300 is already in use:"
    netstat -tuln | grep ":9300 "
    lsof -i :9300 2>/dev/null || true
else
    log_success "Port 9300 is available"
fi

log_info "Checking if Dashboard port 5601 is available..."
if netstat -tuln 2>/dev/null | grep -q ":5601 "; then
    log_warning "Port 5601 is already in use:"
    netstat -tuln | grep ":5601 "
    lsof -i :5601 2>/dev/null || true
else
    log_success "Port 5601 is available"
fi

# 3. Check OpenSearch process
log_info "Checking OpenSearch processes..."
if pgrep -f "org.opensearch.bootstrap.OpenSearch" > /dev/null; then
    log_warning "OpenSearch processes found:"
    ps aux | grep -v grep | grep "org.opensearch.bootstrap.OpenSearch"
else
    log_info "No OpenSearch processes running"
fi

# 3b. Check Dashboard process
log_info "Checking OpenSearch Dashboard processes..."
if pgrep -f "opensearch-dashboards" > /dev/null; then
    log_success "Dashboard processes found:"
    ps aux | grep -v grep | grep "opensearch-dashboards"
else
    log_info "No Dashboard processes running"
fi

# 4. Check for lock files
log_info "Checking for lock files..."
if [[ -f /var/lib/opensearch/nodes/0/node.lock ]]; then
    log_warning "Lock file exists: /var/lib/opensearch/nodes/0/node.lock"
    ls -lah /var/lib/opensearch/nodes/0/node.lock
else
    log_success "No lock files found"
fi

# 5. Check OpenSearch logs
log_info "Recent OpenSearch logs (last 30 lines)..."
echo "─────────────────────────────────────────────────────────────"
if [[ -f /var/log/opensearch/opensearch-cluster.log ]]; then
    tail -30 /var/log/opensearch/opensearch-cluster.log
else
    log_warning "Log file not found at /var/log/opensearch/opensearch-cluster.log"
fi
echo "─────────────────────────────────────────────────────────────"

# 6. Check systemd journal
log_info "OpenSearch systemd journal (last 20 lines)..."
echo "─────────────────────────────────────────────────────────────"
journalctl -u opensearch -n 20 --no-pager
echo "─────────────────────────────────────────────────────────────"

# 6b. Check Dashboard systemd journal
log_info "Dashboard systemd journal (last 20 lines)..."
echo "─────────────────────────────────────────────────────────────"
journalctl -u opensearch-dashboards -n 20 --no-pager 2>/dev/null || log_warning "Dashboard service not found in systemd"
echo "─────────────────────────────────────────────────────────────"

# 7. Check configuration files
log_info "Checking OpenSearch configuration..."
if [[ -f /opt/opensearch/config/opensearch.yml ]]; then
    log_success "Config file exists"
    echo "Network settings:"
    grep -E "^network.host|^http.port|^transport.port" /opt/opensearch/config/opensearch.yml || log_warning "Network settings not found"
else
    log_error "Config file not found: /opt/opensearch/config/opensearch.yml"
fi

# 8. Check JVM settings
log_info "Checking JVM heap settings..."
if [[ -f /opt/opensearch/config/jvm.options ]]; then
    echo "Heap settings:"
    grep -E "^-Xms|-Xmx" /opt/opensearch/config/jvm.options
else
    log_error "JVM options file not found"
fi

# 9. Check certificates
log_info "Checking certificates..."
if [[ -d /opt/opensearch/config/certs ]]; then
    log_success "Certificate directory exists"
    ls -lah /opt/opensearch/config/certs/
else
    log_error "Certificate directory not found"
fi

# 10. Check vm.max_map_count
log_info "Checking vm.max_map_count..."
current_map_count=$(sysctl vm.max_map_count | awk '{print $3}')
if [[ $current_map_count -ge 262144 ]]; then
    log_success "vm.max_map_count = $current_map_count (OK)"
else
    log_error "vm.max_map_count = $current_map_count (should be at least 262144)"
fi

# 11. Check file descriptors
log_info "Checking file descriptor limits..."
if [[ -f /etc/security/limits.conf ]]; then
    grep -E "opensearch.*nofile" /etc/security/limits.conf || log_warning "No file descriptor limits set for opensearch user"
else
    log_warning "limits.conf not found"
fi

# 12. Check Dashboard configuration
log_info "Checking Dashboard configuration..."
if [[ -f /opt/opensearch-dashboards/config/opensearch_dashboards.yml ]]; then
    log_success "Dashboard config file exists"
    echo "Server settings:"
    grep -E "^server.host|^server.port|^opensearch.hosts" /opt/opensearch-dashboards/config/opensearch_dashboards.yml || log_warning "Server settings not found"
else
    log_error "Dashboard config file not found: /opt/opensearch-dashboards/config/opensearch_dashboards.yml"
fi

# 13. Check Dashboard logs
log_info "Recent Dashboard logs (last 30 lines)..."
echo "─────────────────────────────────────────────────────────────"
if [[ -f /var/log/opensearch-dashboards/opensearch_dashboards.log ]]; then
    tail -30 /var/log/opensearch-dashboards/opensearch_dashboards.log
elif [[ -f /opt/opensearch-dashboards/logs/opensearch_dashboards.log ]]; then
    tail -30 /opt/opensearch-dashboards/logs/opensearch_dashboards.log
else
    log_warning "Dashboard log file not found"
fi
echo "─────────────────────────────────────────────────────────────"

# 14. Check Dashboard service status
log_info "Checking Dashboard service status..."
if systemctl is-active --quiet opensearch-dashboards 2>/dev/null; then
    log_success "Dashboard service is active"
    systemctl status opensearch-dashboards --no-pager -l | head -15
else
    log_warning "Dashboard service is not active"
    systemctl status opensearch-dashboards --no-pager -l 2>/dev/null | head -15 || log_error "Dashboard service not found"
fi

# 15. Test Dashboard connectivity
log_info "Testing Dashboard connectivity..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:5601 2>/dev/null | grep -q "200\|302"; then
    log_success "Dashboard is responding on port 5601"
else
    log_warning "Dashboard is not responding on port 5601"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Diagnostic Summary"
echo "════════════════════════════════════════════════════════════"
echo ""

# Provide recommendations
log_info "RECOMMENDATIONS:"
echo ""

if [[ $total_mem -lt 2048 ]]; then
    echo "❌ CRITICAL: Not enough RAM. OpenSearch needs at least 2GB."
    echo "   Solution: Upgrade to a system with at least 2GB RAM"
    echo ""
fi

if [[ $available_mem -lt 800 ]]; then
    echo "⚠️  WARNING: Low available memory (${available_mem}MB)"
    echo "   Solution: Stop other services or upgrade RAM"
    echo ""
fi

if netstat -tuln 2>/dev/null | grep -q ":9200 "; then
    echo "❌ Port 9200 is in use"
    echo "   Solution: sudo systemctl stop opensearch"
    echo "   Or: sudo pkill -9 -f opensearch"
    echo ""
fi

if netstat -tuln 2>/dev/null | grep -q ":5601 "; then
    if ! pgrep -f "opensearch-dashboards" > /dev/null; then
        echo "⚠️  Port 5601 is in use but Dashboard is not running"
        echo "   Solution: sudo pkill -9 -f 'node.*5601'"
        echo ""
    fi
fi

if ! systemctl is-active --quiet opensearch-dashboards 2>/dev/null; then
    echo "⚠️  Dashboard service is not running"
    echo "   Solution: sudo systemctl start opensearch-dashboards"
    echo ""
fi

if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:5601 2>/dev/null | grep -q "200\|302"; then
    if systemctl is-active --quiet opensearch-dashboards 2>/dev/null; then
        echo "⚠️  Dashboard service is running but not responding"
        echo "   Solution: Check Dashboard logs and restart"
        echo "   sudo systemctl restart opensearch-dashboards"
        echo ""
    fi
fi

if [[ -f /var/lib/opensearch/nodes/0/node.lock ]]; then
    echo "⚠️  Lock file exists"
    echo "   Solution: sudo rm -f /var/lib/opensearch/nodes/0/node.lock"
    echo ""
fi

if [[ $current_map_count -lt 262144 ]]; then
    echo "❌ vm.max_map_count too low"
    echo "   Solution: sudo sysctl -w vm.max_map_count=262144"
    echo ""
fi

echo "════════════════════════════════════════════════════════════"
echo "  Quick Fix Commands"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "# Stop OpenSearch and clean up"
echo "sudo systemctl stop opensearch"
echo "sudo pkill -9 -f opensearch"
echo "sudo rm -f /var/lib/opensearch/nodes/*/node.lock"
echo ""
echo "# Fix system settings"
echo "sudo sysctl -w vm.max_map_count=262144"
echo "sudo swapoff -a"
echo ""
echo "# Restart OpenSearch"
echo "sudo systemctl start opensearch"
echo ""
echo "# Restart Dashboard"
echo "sudo systemctl start opensearch-dashboards"
echo ""
echo "# Watch logs in real-time"
echo "sudo journalctl -u opensearch -f"
echo "sudo journalctl -u opensearch-dashboards -f"
echo ""
echo "# Test connectivity"
echo "curl -k -u admin:admin https://localhost:9200"
echo "curl http://localhost:5601"
echo ""