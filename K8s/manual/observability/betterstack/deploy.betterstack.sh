#!/usr/bin/env bash
set -euo pipefail

############################################
# Configuration
############################################
RELEASE_NAME="betterstack-logs"
HELM_REPO_NAME="betterstack-logs"
HELM_REPO_URL="https://betterstackhq.github.io/logs-helm-chart"

BETTERSTACK_BASE_URL="https://s1673263.eu-nbg-2.betterstackdata.com"
VALUES_FILE="values.yaml"

############################################
# Helm repo setup
############################################
echo "➡️ Ensuring Better Stack Helm repo exists"
helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL" >/dev/null || true
helm repo update >/dev/null

############################################
# values.yaml handling
############################################
if [[ -f "$VALUES_FILE" ]]; then
  echo "⚠️  $VALUES_FILE already exists."
  echo "Choose an option:"
  echo "  1) Use existing $VALUES_FILE"
  echo "  2) Create a new $VALUES_FILE (will overwrite)"
  read -rp "Enter choice [1/2]: " CHOICE

  case "$CHOICE" in
    1)
      echo "✅ Using existing $VALUES_FILE"
      ;;
    2)
      CREATE_VALUES=true
      ;;
    *)
      echo "❌ Invalid choice"
      exit 1
      ;;
  esac
else
  CREATE_VALUES=true
fi

############################################
# Create values.yaml if needed
############################################
if [[ "${CREATE_VALUES:-false}" == "true" ]]; then
  if [[ -z "${BETTERSTACK_TOKEN:-}" ]]; then
    read -s -p "Enter Better Stack ingestion token: " BETTERSTACK_TOKEN
    echo
  fi

  if [[ -z "$BETTERSTACK_TOKEN" ]]; then
    echo "❌ Better Stack token is required to create values.yaml"
    exit 1
  fi

  echo "➡️ Creating new $VALUES_FILE"

  cat > "$VALUES_FILE" <<EOF
vector:
  customConfig:
    sinks:
      better_stack_http_sink:
        type: http
        uri: "${BETTERSTACK_BASE_URL}/"
        auth:
          strategy: bearer
          token: "${BETTERSTACK_TOKEN}"

      better_stack_http_metrics_sink:
        type: http
        uri: "${BETTERSTACK_BASE_URL}/metrics"
        auth:
          strategy: bearer
          token: "${BETTERSTACK_TOKEN}"
EOF

  echo "✅ $VALUES_FILE created"
fi

############################################
# Helm install / upgrade
############################################
echo "➡️ Deploying Better Stack logs"
echo "➡️ Deploying Better Stack logs into current kube-context namespace"

helm upgrade --install "$RELEASE_NAME" \
  betterstack-logs/betterstack-logs \
  -f "$VALUES_FILE" \
  --set metrics-server.enabled=false

echo "✅ Deployment complete"
