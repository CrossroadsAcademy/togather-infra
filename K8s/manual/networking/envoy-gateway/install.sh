#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' 



ENVOY_GATEWAY_VERSION="v1.5.3"
NAMESPACE="envoy-gateway"
FILE_NAME="values.yaml"

# verify if kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi


if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

# install helm
# https://helm.sh/docs/intro/install/
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}⚠ Helm not found. Installing Helm...${NC}"
   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo -e "${GREEN}✓ Helm is ready${NC}\n"


# install envoy
echo "Installing Envoy Gateway ${ENVOY_GATEWAY_VERSION}..."

### Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# https://gateway.envoyproxy.io/docs/install/install-helm/

helm install eg oci://docker.io/envoyproxy/gateway-helm \
 --version ${ENVOY_GATEWAY_VERSION} -n ${NAMESPACE} \
  --values ${FILE_NAME} || true # helm throw error installing same thing twice 

kubectl wait --timeout=5m -n ${NAMESPACE} deployment/envoy-gateway --for=condition=Available


echo -e "${GREEN}✓ Envoy Gateway is ready${NC}\n"



# Apply Gateway resources

