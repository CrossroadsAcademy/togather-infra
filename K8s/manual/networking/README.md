# Networking Infrastructure

Currently we have [Envoy Gateway](https://gateway.envoyproxy.io/docs/) based [Gateway API](https://kubernetes.io/docs/concepts/services-networking/gateway/) for routing external traffic to internal services.

## Structure

```bash
networking/
├── README.md                    # This file
├── install.sh                   # Install Gateway API CRDs + Envoy Gateway + dependencies
├── verify.sh                    # Verify installation
├── makefile                     # Common commands
├── networking.env               # Environment variables
│
├── envoy-gateway/              # Gateway configuration
│   ├── gateway-class.yaml      # GatewayClass definition
│   ├── gateway.yaml            # Gateway resource
│   └── values.yaml             # Helm values for Envoy Gateway
│
└── routes/                     # HTTPRoute definitions
    ├── demo-route.yaml         # Example route
    └── demo-service/           # Example service
        └── deployment.yaml     # Backend deployment
```

## Quick Start Guide

### First Time Setup

```bash
# Install everything
./install.sh

# Verify installation
./verify.sh

curl localhost:4100 # or port specified on gateway.yaml
```

### Using Makefile

```bash
make install     # Install Gateway API CRDs + Envoy Gateway
make verify      # Verify installation
make routes      # Apply all routes (apply services and deployments first, more on that down)
make clean       # Remove everything
```

## Installation Order

**IMPORTANT**: Follow this order to avoid issues:

```
1. Gateway API CRDs
   ↓
2. Envoy Gateway (Helm)
   ↓
3. GatewayClass
   ↓
4. Gateway
   ↓
5. Backend Services (Deployments/Services)
   ↓
6. HTTPRoutes
```

### Why This Order Matters

- **CRDs First**: Gateway API CRDs must exist before Envoy Gateway can start
- **Services Before Routes**: Deploy backend services **before** creating HTTPRoutes to avoid `BackendNotFound` errors
- **Wait for Reconciliation**: If routes show `BackendNotFound`, the controller will automatically reconcile once services are ready

## Adding a New Route

### Step 1: Deploy Your Backend Service

**IMPORTANT**: Always deploy your service **BEFORE** creating the HTTPRoute.

```bash
# Apply your deployment and service
kubectl apply -f {my-service}/deployment.yaml
kubectl apply -f {my-service}/service.yaml

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=60s deployment/{my-service}
```

### Step 2: Create HTTPRoute

Create `routes/my-service-route.yaml`:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: SERVICE_NAME-service # Follow naming convention
  labels:
    app: SERVICE_NAME-service
spec:
  parentRefs:
    - name: { { GATEWAY_NAME } }
      namespace: { { NAMESPACE } }

  # hostnames:
  # - "www.togather.com"

  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api/v1/myservice

      backendRefs:
        - name: my-service # Must match Service name
          port: 8080 # Must match Service port
```

### Step 3: Apply and Verify

```bash
# Apply the route
kubectl apply -f routes/my-service-route.yaml

# Verify route is accepted
kubectl describe httproute {my-service}

# Check for ResolvedRefs condition
kubectl get httproute my-service-http -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")]}'
```

## Naming Conventions

### HTTPRoute Names

Use descriptive, lowercase names with hyphens:

✅ **Good Examples:**

- `user-service-route`
- `auth-api-route`

❌ **Bad Examples:**

- `UserService` (no uppercase)
- `user_service_route` (no underscores)
- `route1` (not descriptive)
- `myroute` (not clear)

### Convention Pattern

```
<service-name>-route
<domain>-<service>-route
```

### Rules

- Must be **unique per namespace**
- Use **lowercase** letters only
- Use **hyphens** (`-`) as separators, not underscores
- Be **descriptive** - name should indicate what it routes to
- Suffix with `-route` for clarity

## Advanced Routing

### A/B Testing with Weighted Backends

Split traffic between multiple backend versions:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend-api-route
  namespace: default
spec:
  parentRefs:
    - name: { { GATEWAY_NAME } }
      namespace: { { GATEWAY_CLASS_NAME } }

  # hostnames:
  # - "www.togather.com"

  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api

      backendRefs:
        - name: backend-v1 # 90% traffic to stable version
          port: 3000
          weight: 90

        - name: backend-v2 # 10% traffic to new version
          port: 3000
          weight: 10
```

**Notes:**

- Weights are relative (90:10 = 90% vs 10%)
- Both backends must exist as Kubernetes Services
- Total weights don't need to sum to 100
- Useful for canary deployments and gradual rollouts

### Header-Based Routing

Route based on HTTP headers:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend-api-route
  namespace: default
spec:
  parentRefs:
    - name: { { GATEWAY_NAME } }
      namespace: { { GATEWAY_CLASS_NAME } }
  rules:
    - matches:
        - headers:
            - name: X-API-Version
              value: "v2"
      backendRefs:
        - name: api-v2
          port: 8080

    - matches:
        - headers:
            - name: X-API-Version
              value: "v1"
      backendRefs:
        - name: api-v1
          port: 8080
```

## Monitoring Routes

### List all routes:

```bash
kubectl get httproute -A
```

### Check route status:

```bash
kubectl describe httproute <route-name>
```

### View route details:

```bash
kubectl get httproute <route-name> -o yaml
```

### Check which routes are attached to gateway:

```bash
kubectl get httproute -A -o json | \
  jq -r '.items[] | select(.spec.parentRefs[].name=="main-gateway") | .metadata.name'
```

## Testing Your Routes

### From outside cluster:

```bash
# Get Gateway IP
GATEWAY_IP=$(kubectl get gateway main-gateway -n envoy-gateway-system -o jsonpath='{.status.addresses[0].value}')

# Test your route
curl http://$GATEWAY_IP/api/v1/myservice
```

## Additional Resources

- [Envoy Gateway Docs](https://gateway.envoyproxy.io/)
- [Gateway API Docs](https://gateway-api.sigs.k8s.io/)
- [HTTPRoute API Reference](https://gateway-api.sigs.k8s.io/reference/spec/#gateway.networking.k8s.io/v1.HTTPRoute)

## Getting Help

- Check `./verify.sh` for installation issues
- Review Envoy Gateway logs for routing problems
- Contact Team

**Last Updated**: 21/10/2025
**Maintained By**: Togather Team
