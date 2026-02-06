#!/bin/bash
#===============================================================================
#  Togather Application - One-Click Deployment Script
#===============================================================================
#  This script sets up a fresh Ubuntu/Debian VM with all required dependencies
#  and starts the entire Togather application stack.
#
#  Usage:
#    git clone https://github.com/CrossroadsAcademy/togather-infra.git
#    cd togather-infra
#    chmod +x scripts/start.sh
#    ./scripts/start.sh
#
#===============================================================================

set -e
set -o pipefail

# --- CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/.."
ROOT_DIR="$INFRA_DIR/.."
BRANCH="main"

# --- COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- LOGGING FUNCTIONS ---
log()     { echo -e "${GREEN}[✓]${NC} $1"; }
info()    { echo -e "${BLUE}[ℹ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
fail()    { echo -e "${RED}[✗]${NC} $1"; exit 1; }
section() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}"; echo -e "${BOLD}${CYAN}  $1${NC}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════════════════════════${NC}\n"; }

# --- HELPER FUNCTIONS ---
command_exists() {
    command -v "$1" &>/dev/null
}

install_if_missing() {
    local cmd="$1"
    local name="${2:-$1}"
    local install_func="$3"
    
    if command_exists "$cmd"; then
        log "$name is already installed"
        return 0
    fi
    
    warn "$name is not installed. Installing..."
    $install_func
    
    if command_exists "$cmd"; then
        log "$name installed successfully"
    else
        fail "Failed to install $name"
    fi
}

# --- INSTALLATION FUNCTIONS ---

install_docker() {
    info "Installing Docker..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add current user to docker group
    sudo usermod -aG docker "$USER"
    
    # Start Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Apply docker group to current session
    if ! groups | grep -q docker; then
        info "Applying Docker group permissions to current session..."
        # Re-exec the script with docker group if we just added it
        exec sg docker "$0"
    fi
}

install_k3s() {
    info "Installing K3s (lightweight Kubernetes)..."
    
    # Install K3s without traefik (we use Envoy Gateway), writable kubeconfig
    curl -sfL https://get.k3s.io | sh -s - --disable traefik --write-kubeconfig-mode 644
    
    # Wait for K3s to be ready
    sleep 10
    
    # Set KUBECONFIG environment variable
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    
    # Add KUBECONFIG to bashrc for future sessions
    if ! grep -q "KUBECONFIG" ~/.bashrc; then
        echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
    fi
    
    # Add kubectl aliases
    if ! grep -q "alias k=" ~/.bashrc; then
        echo "# Kubectl aliases" >> ~/.bashrc
        echo "alias k='kubectl'" >> ~/.bashrc
        echo "alias kgp='kubectl get pods'" >> ~/.bashrc
        echo "alias kgs='kubectl get svc'" >> ~/.bashrc
        echo "alias kga='kubectl get all'" >> ~/.bashrc
    fi
    
    # Wait for node to be ready
    info "Waiting for K3s node to be ready..."
    kubectl wait --for=condition=ready node --all --timeout=120s
    
    log "K3s installed and running"
}

install_kubectl() {
    info "Installing kubectl..."
    
    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
}

install_helm() {
    info "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_skaffold() {
    info "Installing Skaffold..."
    
    # Download Skaffold
    curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
    
    # Install Skaffold
    sudo install -o root -g root -m 0755 skaffold /usr/local/bin/skaffold
    rm skaffold
}

install_nodejs() {
    info "Installing Node.js LTS..."
    
    # Install Node.js using NodeSource
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
}

install_pnpm() {
    info "Installing pnpm..."
    sudo npm install -g pnpm
}

install_jq() {
    info "Installing jq..."
    sudo apt-get install -y jq
}

install_make() {
    info "Installing make..."
    sudo apt-get install -y make
}

install_k9s() {
    info "Installing k9s..."
    
    # Download latest k9s release
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -sL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | sudo tar xz -C /usr/local/bin k9s
    
    log "k9s installed successfully"
}

install_gh() {
    info "Installing GitHub CLI..."
    
    sudo apt-get install -y gh
    
    log "GitHub CLI installed. Run 'gh auth login' to authenticate."
}

install_cloudflared() {
    info "Installing cloudflared..."
    
    # Download and install cloudflared
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb
    sudo dpkg -i /tmp/cloudflared.deb
    rm /tmp/cloudflared.deb
    
    log "cloudflared installed. Run 'cloudflared tunnel login' to authenticate."
}

install_git() {
    info "Installing git..."
    sudo apt-get install -y git
}

# --- MAIN SCRIPT ---

main() {
    section "Togather Application Deployment"
    
    echo -e "${BOLD}This script will:${NC}"
    echo "  1. Install all required dependencies (Docker, K3s, Helm, Skaffold, pnpm)"
    echo "  2. Clone all microservice repositories"
    echo "  3. Set up Kubernetes secrets (Infisical)"
    echo "  4. Install Envoy Gateway for networking"
    echo "  5. Start all services"
    echo "  6. Deploy HTTP routes"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..."
    
    # ==========================================================================
    # PHASE 1: Check OS & Install Prerequisites
    # ==========================================================================
    section "Phase 1: Installing Prerequisites"
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        fail "Cannot detect OS. This script supports Ubuntu/Debian only."
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" && "$ID_LIKE" != *"ubuntu"* && "$ID_LIKE" != *"debian"* ]]; then
        fail "Unsupported OS: $ID. This script supports Ubuntu/Debian only."
    fi
    
    log "Detected OS: $PRETTY_NAME"
    
    # Update package lists
    info "Updating package lists..."
    sudo apt-get update
    
    # Install essential tools
    sudo apt-get install -y curl wget ca-certificates apt-transport-https software-properties-common
    
    # Install dependencies
    install_if_missing "git"     "Git"         install_git
    install_if_missing "docker"  "Docker"      install_docker
    install_if_missing "kubectl" "kubectl"     install_kubectl
    install_if_missing "helm"    "Helm"        install_helm
    install_if_missing "skaffold" "Skaffold"   install_skaffold
    install_if_missing "node"    "Node.js"     install_nodejs
    install_if_missing "pnpm"    "pnpm"        install_pnpm
    install_if_missing "jq"      "jq"          install_jq
    install_if_missing "make"    "make"        install_make
    install_if_missing "k9s"     "k9s"         install_k9s
    install_if_missing "gh"      "GitHub CLI"  install_gh
    install_if_missing "cloudflared" "cloudflared" install_cloudflared
    
    # Install K3s if no Kubernetes cluster is available
    if ! kubectl cluster-info &>/dev/null; then
        warn "No Kubernetes cluster detected"
        install_k3s
    else
        log "Kubernetes cluster is available"
    fi
    
    # Verify cluster connection
    if ! kubectl cluster-info &>/dev/null; then
        fail "Cannot connect to Kubernetes cluster"
    fi
    log "Kubernetes cluster is ready"
    
    # ==========================================================================
    # PHASE 2: Clone/Update Repositories
    # ==========================================================================
    section "Phase 2: Setting Up Repositories"
    
    cd "$INFRA_DIR"
    
    info "Running bootstrap script to clone/update all repositories..."
    chmod +x bootstrap.sh
    ./bootstrap.sh "$BRANCH"
    
    log "All repositories are ready"
    
    # ==========================================================================
    # PHASE 3: Configure Secrets
    # ==========================================================================
    section "Phase 3: Configuring Kubernetes Secrets"
    
    info "Setting up Infisical secrets..."
    info "You will be prompted to enter your Infisical credentials."
    echo ""
    
    chmod +x scripts/setup-infisical-secret.sh
    ./scripts/setup-infisical-secret.sh
    
    log "Secrets configured"
    
    # ==========================================================================
    # PHASE 4: Install Networking Infrastructure
    # ==========================================================================
    section "Phase 4: Installing Envoy Gateway"
    
    cd "$INFRA_DIR/K8s/manual/networking"
    
    # Force install experimental Gateway API CRDs (supports rule names in HTTPRoute)
    source ./networking.env
    info "Installing/upgrading Gateway API CRDs (Experimental channel)..."
    kubectl apply --server-side --force-conflicts -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/experimental-install.yaml"
    
    chmod +x install.sh
    ./install.sh
    
    # Verify installation
    chmod +x verify.sh
    ./verify.sh || warn "Gateway verification had warnings - continuing anyway"
    
    log "Envoy Gateway installed"
    
    cd "$INFRA_DIR"
    
    # ==========================================================================
    # PHASE 5: Start All Services
    # ==========================================================================
    section "Phase 5: Starting All Services"
    
    info "Starting all microservices via Skaffold..."
    info "This may take several minutes on first run..."
    echo ""
    
    # Run Skaffold in the background and wait for deployment
    # Using 'skaffold run' for production instead of 'skaffold dev'
    make all-run
    
    log "All services started"
    
    # ==========================================================================
    # PHASE 6: Deploy HTTP Routes
    # ==========================================================================
    section "Phase 6: Deploying HTTP Routes"
    
    cd "$INFRA_DIR/K8s/manual/networking"
    
    # Wait for services to be ready before deploying routes
    info "Waiting for services to be ready..."
    sleep 30
    
    chmod +x deploy-services.sh
    ./deploy-services.sh
    
    log "HTTP routes deployed"
    
    cd "$INFRA_DIR"
    
    # ==========================================================================
    # PHASE 7: Verification & Summary
    # ==========================================================================
    section "Deployment Complete!"
    
    # Get Gateway address
    GATEWAY_IP=$(kubectl get gateway togather-gateway -n envoy-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "localhost")
    GATEWAY_PORT=$(kubectl get gateway togather-gateway -n envoy-gateway -o jsonpath='{.spec.listeners[0].port}' 2>/dev/null || echo "4100")
    
    echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║           Togather Application is Now Running!                 ║${NC}"
    echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Gateway Address:${NC} http://${GATEWAY_IP}:${GATEWAY_PORT}"
    echo ""
    echo -e "${BOLD}Available Endpoints:${NC}"
    echo "  • Auth Service:         http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/auth"
    echo "  • User Service:         http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/user"
    echo "  • Notification Service: http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/notification"
    echo ""
    echo -e "${BOLD}Useful Commands:${NC}"
    echo "  • View all pods:        kubectl get pods -A"
    echo "  • View services:        kubectl get svc -A"
    echo "  • View routes:          kubectl get httproute -A"
    echo "  • View logs:            kubectl logs -f deployment/<service-name>"
    echo "  • Stop all:             skaffold delete"
    echo ""
    echo -e "${BOLD}Test the deployment:${NC}"
    echo "  curl http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/auth/health"
    echo ""
}

# Run main function
main "$@"