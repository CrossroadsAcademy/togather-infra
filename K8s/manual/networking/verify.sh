#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'


source ./networking.env


echo "═══════════════════════════════════════"
echo "  Verifying Networking Infrastructure"
echo "═══════════════════════════════════════"
echo ""

# verify crds
echo "Gateway API CRDs"

if kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null; then
    VERSION=$(kubectl get crd gateways.gateway.networking.k8s.io \
        -o jsonpath='{.metadata.labels.gateway\.networking\.k8s\.io/bundle-version}' 2>/dev/null || echo "unknown")
    echo -e "   ${GREEN}✓${NC} Installed (version: ${VERSION})"
else
    echo -e "   ${RED}Not found${NC} "
    exit 1
fi

# envoy gateway
echo ""
echo "Envoy Gateway Deployment"
if kubectl get deployment envoy-gateway -n ${NAMESPACE} &> /dev/null; then
DATA_PLANE=$(kubectl get deploy -n $NAMESPACE \
  -l gateway.envoyproxy.io/owning-gateway-name=${GATEWAY_NAME} \
  -o jsonpath='{.items[0].metadata.name}')

echo "Data-plane deployment: $DATA_PLANE"

# check status
READY=$(kubectl get deploy $DATA_PLANE -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl get deploy $DATA_PLANE -n $NAMESPACE -o jsonpath='{.spec.replicas}')

    if [ "$READY" = "$DESIRED" ]; then
        echo -e "   ${GREEN}Ready${NC}  ($READY/$DESIRED)"
    else
        echo -e "   ${YELLOW}Starting${NC}  ($READY/$DESIRED)"
    fi
else
    echo -e "   ${RED}Not found${NC}"
    exit 1
fi


# gateway class
echo ""
echo "3. GatewayClass"
if kubectl get gatewayclass ${GATEWAY_CLASS_NAME} &> /dev/null; then
    STATUS=$(kubectl get gatewayclass ${GATEWAY_CLASS_NAME} -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}')
    if [ "$STATUS" = "True" ]; then
        echo -e "${GREEN}Accepted${NC}"
    else
        echo -e "   ${YELLOW}Status${NC}: $STATUS"
    fi
else
    echo -e "   ${RED}Not found${NC}"
fi



# Check Gateway
echo ""
echo "Gateway Resource"
if kubectl get gateway ${GATEWAY_NAME} -n ${NAMESPACE} &> /dev/null; then
    STATUS=$(kubectl get gateway ${GATEWAY_NAME} -n ${NAMESPACE} \
        -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')
    if [ "$STATUS" = "True" ]; then
        echo -e "   ${GREEN}Programmed${NC}"
    else
        echo -e "   ${YELLOW}Status${NC}: $STATUS"
    fi
    
    ADDRESS=$(kubectl get gateway  ${GATEWAY_NAME} -n ${NAMESPACE} \
        -o jsonpath='{.status.addresses[0].value}' 2>/dev/null)
    if [ -n "$ADDRESS" ]; then
        echo -e "   ${GREEN}Address${NC}: $ADDRESS"
    else
        echo -e "   ${YELLOW}Address not yet assigned${NC}"
    fi
else
    echo -e "   ${RED}Not found${NC}"
fi



# checking routes
echo ""
echo "HTTPRoutes"
ROUTE_COUNT=$(kubectl get httproute -A --no-headers 2>/dev/null | wc -l)
if [ "$ROUTE_COUNT" -gt 0 ]; then
    echo -e "   ${GREEN}Found${NC} $ROUTE_COUNT route(s)"
    kubectl get httproute -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNAMES:.spec.hostnames
else
    echo -e "   ${YELLOW}No routes configured yet${NC}"
fi


echo ""
echo "═══════════════════════════════════════"
echo -e "  ${GREEN}Verification Complete${NC}"
echo "═══════════════════════════════════════"