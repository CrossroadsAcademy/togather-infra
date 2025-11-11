#!/bin/bash
set -e

echo "=========================================="
echo "Deploying Togather Services to Envoy Gateway"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${YELLOW}Step 1: Applying HTTPRoutes${NC}"
echo "=========================================="

# Apply Auth Service Route
echo "Applying auth-service-route..."
kubectl apply -f routes/auth-service-route.yaml

# Apply User Service Route
echo "Applying user-service-route..."
kubectl apply -f routes/user-service-route.yaml

# Apply Notification Service Route
echo "Applying notification-service-route..."
kubectl apply -f routes/notification-service-route.yaml

echo -e "${GREEN}✓ All HTTPRoutes applied${NC}"
echo ""

echo -e "${YELLOW}Step 2: Applying Rate Limiting Policies${NC}"
echo "=========================================="

# Apply rate limiting for auth verification
echo "Applying auth verification rate limit (1 req/min)..."
kubectl apply -f envoy-gateway/policies/rate-limiting/auth-verification-rate-limit.yaml

echo -e "${GREEN}✓ Rate limiting policies applied${NC}"
echo ""

echo -e "${YELLOW}Step 3: Verifying Routes${NC}"
echo "=========================================="

# Wait for routes to be accepted
sleep 3

echo "Checking HTTPRoute status..."
kubectl get httproute auth-service-route -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")]}' | jq '.'
kubectl get httproute user-service-route -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")]}' | jq '.'
kubectl get httproute notification-service-route -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")]}' | jq '.'

echo ""
echo -e "${GREEN}✓ Deployment Complete!${NC}"
echo ""
echo "=========================================="
echo "Gateway Information"
echo "=========================================="

# Get Gateway address
GATEWAY_IP=$(kubectl get gateway togather-gateway -n envoy-gateway -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || echo "localhost")
GATEWAY_PORT=$(kubectl get gateway togather-gateway -n envoy-gateway -o jsonpath='{.spec.listeners[0].port}' 2>/dev/null || echo "4100")

echo "Gateway Address: ${GATEWAY_IP}:${GATEWAY_PORT}"
echo ""
echo "Available Routes:"
echo "  - Auth Service:         http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/auth"
echo "  - User Service:         http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/user"
echo "  - Notification Service: http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/notification"
echo ""
echo "Rate Limits:"
echo "  - Auth Verification:    1 request/minute"
echo "  - Other Auth Endpoints: 100 requests/minute"
echo ""
echo "=========================================="
echo "Test Commands"
echo "=========================================="
echo ""
echo "# Test Auth Service Signup"
echo "curl -X POST http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/auth/user/signup \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"firstName\":\"Test\",\"lastName\":\"User\",\"email\":\"test@example.com\",\"password\":\"Test@1234\"}'"
echo ""
echo "# Test Auth Service Verification (Rate Limited: 1/min)"
echo "curl -X POST http://${GATEWAY_IP}:${GATEWAY_PORT}/api/v1/auth/user/verify \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"email\":\"test@example.com\",\"code\":\"123456\"}'"
echo ""
echo "=========================================="
