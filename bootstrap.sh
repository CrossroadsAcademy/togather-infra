#!/bin/bash
set -e  # Exit on error
set -o pipefail

# git clone -b develop https://github.com/CrossroadsAcademy/togather-user-service.git

# --- CONFIG ---
ROOT_DIR="$(pwd)/../togather-dev"

   # TODO: need to add elastic search proxy
REPOS=(
  # "https://github.com/CrossroadsAcademy/togather-infra.git"
  "https://github.com/CrossroadsAcademy/togather-user-service.git"
  "https://github.com/CrossroadsAcademy/togather-location-service.git"
  "https://github.com/CrossroadsAcademy/togather-experience-service.git"
  "https://github.com/CrossroadsAcademy/togather-websocket-service.git"
  "https://github.com/CrossroadsAcademy/togather-chat-service.git"
  "https://github.com/CrossroadsAcademy/togather-auth-service.git"
  "https://github.com/CrossroadsAcademy/togather-booking-finance-service.git"
  "https://github.com/CrossroadsAcademy/togather-feed-service.git"
  "https://github.com/CrossroadsAcademy/togather-graphql-service.git"
  "https://github.com/CrossroadsAcademy/togather-notification-service.git" 
  "https://github.com/CrossroadsAcademy/togather-partner-service.git"
)

# --- COLORS ---
GREEN="\033[0;32m"
NC="\033[0m"

# --- FUNCTIONS ---
log() { echo -e "${GREEN}[+] $1${NC}"; }

# --- MAIN LOGIC ---
log "Setting up development infrastructure..."
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"

log "Cloning repositories..."
for repo in "${REPOS[@]}"; do
  name=$(basename "$repo" .git)
  log "Cloning $name"
  if [ ! -d "$name" ]; then
    git clone -b develop "$repo"
  else
    log "$name already exists, manually pull the latest changes..."
   #  (cd "$name" && git pull)
  fi
done

log "Installing dependencies..."
# Example: Install Skaffold, Docker, etc.
if ! command -v skaffold &>/dev/null; then
  log "Installing Skaffold..."
  curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && \
  sudo install skaffold /usr/local/bin/
fi

# log "Starting orchestration..."
# cd infra
# skaffold dev
