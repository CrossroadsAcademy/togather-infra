include networking.env
export $(shell sed 's/=.*//' networking.env) # exports all the variables

.PHONY: help install-crds install-gateway install verify clean

# Colors
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[0;33m
BLUE=\033[0;34m
MAGENTA=\033[0;35m
CYAN=\033[0;36m
BOLD=\033[1m
RESET=\033[0m

help:
	@echo  "$(BOLD)$(CYAN)╔════════════════════════════════════════╗$(RESET)"
	@echo  "$(BOLD)$(CYAN)║   Togather Networking Infrastructure   ║$(RESET)"
	@echo  "$(BOLD)$(CYAN)╚════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo  "$(GREEN)Available commands:$(RESET)"
	@echo ""
	@echo  "  $(BOLD)make install-crds$(RESET)     - Install Gateway API CRDs"
	@echo  "  $(BOLD)make install-gateway$(RESET)  - Install Envoy Gateway (installs CRDs first)"
	@echo  "  $(BOLD)make install$(RESET)          - Full installation (CRDs + Gateway + Resources)"
	@echo  "  $(BOLD)make apply-gateway$(RESET)    - Apply Gateway resources"
	@echo  "  $(BOLD)make apply-routes$(RESET)     - Apply all routes"
	@echo  "  $(BOLD)make verify$(RESET)           - Verify installation"
	@echo  "  $(BOLD)make clean$(RESET)            - Remove everything"
	@echo  "  $(BOLD)make clean-all$(RESET)        - Remove everything including CRDs"


install-crds:
	@echo "$(MAGENTA)Installing Gateway API CRDs $(GATEWAY_API_VERSION)...$(RESET)"
	@if kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null; then \
		echo "$(YELLOW)Gateway API CRDs already installed$(RESET)"; \
		CURRENT_VERSION=$$(kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}' 2>/dev/null || echo "unknown"); \
		echo "$(GREEN)Current version: $$CURRENT_VERSION$(RESET)"; \
	else \
		kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml; \
		echo "$(GREEN)Gateway API CRDs installed$(RESET)"; \
	fi

install-gateway: install-crds
	@echo "$(MAGENTA)Installing Envoy Gateway $(ENVOY_VERSION)...$(RESET)"
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@helm install eg oci://docker.io/envoyproxy/gateway-helm \
     --version $(ENVOY_GATEWAY_VERSION) -n $(NAMESPACE) \
     --values $(FILE_NAME) || true # helm throw error installing same thing twice 

	@echo "$(YELLOW)Waiting for Envoy Gateway to be ready...$(RESET)"
	@kubectl wait --timeout=5m -n $(NAMESPACE) deployment/envoy-gateway --for=condition=Available

	@echo "$(GREEN)Envoy Gateway installed successfully$(RESET)"

	@kubectl get pods -n $(NAMESPACE)

apply-gateway:

	@echo "$(MAGENTA)Applying Gateway resources...$(RESET)"
	@kubectl apply -f ./envoy-gateway/gateway-class.yaml
	@kubectl apply -f ./envoy-gateway/gateway.yaml
	@sleep 5
	@kubectl wait --timeout=2m \
		-n $(NAMESPACE) \
		gateway/${GATEWAY_NAME} \
		--for=condition=Programmed || echo "Gateway may still be starting"
	@echo "$(GREEN)Gateway resources applied$(RESET)"

apply-routes:
	@echo "$(MAGENTA)Applying routes...(RESET)"
	@kubectl apply -f ./routes/
	@echo "$(GREEN)Routes applied(RESET)"


install: install-gateway apply-gateway apply-routes
	@echo ""
	@echo "$(GREEN)Full installation complete!"$(RESET)
	@echo ""
	@echo "$(BLUE)Next steps:$(RESET)"
	@echo "  make verify           - Verify installation"
	@echo "  kubectl get gateway main-gateway -n $(NAMESPACE) - Get Gateway IP"

verify:
	@echo "$(MAGENTA) Running verify script$(RESET)"
	@-./verify.sh 2>/dev/null || true

clean:
	@echo "$(MAGENTA)Removing all resources (keeping CRDs)...$(RESET)"
	@kubectl delete -f ./routes/ --ignore-not-found
	@kubectl delete -f ./envoy-gateway/gateway.yaml --ignore-not-found
	@kubectl delete -f ./envoy-gateway/gateway-class.yaml --ignore-not-found
	@helm uninstall eg -n $(NAMESPACE) || true
	@echo "$(CYAN)Terminating Namespace: $(NAMESPACE)$(RESET)"
	@echo "$(RED)may take some time....$(RESET)"
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found
	@echo "$(GREEN)Cleanup complete (CRDs preserved)$(RESET)"

clean-all: clean
	@echo "$(MAGENTA)Removing Gateway API CRDs...$(RESET)"
	@kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$(GATEWAY_API_VERSION)/standard-install.yaml --ignore-not-found
	@echo "$(GREEN) Complete cleanup (including CRDs)$(RESET)"