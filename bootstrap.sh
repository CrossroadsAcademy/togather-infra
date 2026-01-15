#!/bin/bash
set -e  # Exit on error
set -o pipefail

# --- CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/../"

# --- BRANCH SELECTION ---
# Usage: ./bootstrap.sh [branch]
# branch: develop (default), staging, or main
BRANCH="${1:-develop}"

# Validate branch
if [[ ! "$BRANCH" =~ ^(develop|staging|main)$ ]]; then
  echo "Error: Invalid branch '$BRANCH'. Valid options: develop, staging, main"
  exit 1
fi

   # TODO: need to add elastic search proxy
REPOS=(
  # "https://github.com/CrossroadsAcademy/togather-infra.git"
  "https://github.com/CrossroadsAcademy/togather-user-service.git"
  # "https://github.com/CrossroadsAcademy/togather-location-service.git"
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
YELLOW="\033[1;33m"
NC="\033[0m"

# --- FUNCTIONS ---
log() { echo -e "${GREEN}[+] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }

# --- MAIN LOGIC ---
log "Setting up infrastructure with branch: $BRANCH"
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"

log "Cloning repositories..."
for repo in "${REPOS[@]}"; do
  name=$(basename "$repo" .git)
  log "Cloning $name"
  if [ ! -d "$name" ]; then
  git clone --no-single-branch "$repo"
  (
    cd "$name"
    if git show-ref --verify --quiet refs/remotes/origin/$BRANCH; then
      git checkout $BRANCH
    else
      warn "No '$BRANCH' branch found for $name, staying on default branch"
    fi
  )
else
  log "$name already exists, pulling latest changes from '$BRANCH' or default branch..."
  (
    cd "$name"
    # Fetch all branches/tags/etc.
    git fetch
    
    # Try to checkout and pull target branch, otherwise pull the current branch
    if git show-ref --verify --quiet refs/remotes/origin/$BRANCH; then
      git checkout $BRANCH
      git pull
    else
      warn "No '$BRANCH' branch found for $name, pulling current branch"
      git pull # Pulls the current checked-out branch (e.g., main/master)
    fi
  )
fi
done


log "Installing infra npm dependencies..."

# --- Check for pnpm installation ---
if ! command -v pnpm &>/dev/null; then
  log "pnpm is not installed. Please install pnpm to continue."
  exit 1
fi

# --- Install dependencies ---
cd "$ROOT_DIR/togather-infra"
pnpm i

log "Bootstrap complete! All repos on '$BRANCH' branch."

