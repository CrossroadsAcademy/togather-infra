include networking.env
export $(shell sed 's/=.*//' networking.env) # exports all the variables

.PHONY: help install-crds install-gateway install verify clean


help:
	@echo "╔════════════════════════════════════════╗"
	@echo "║   Togather Networking Infrastructure   ║"
	@echo "╚════════════════════════════════════════╝"
	@echo ""
	@echo "Available commands:"
	@echo "  make install-crds     - Install Gateway API CRDs"
	@echo "  make install-gateway  - Install Envoy Gateway (installs CRDs first)"
	@echo "  make install          - Full installation (CRDs + Gateway + Resources)"
	@echo "  make apply-gateway    - Apply Gateway resources"
	@echo "  make apply-routes     - Apply all routes"
	@echo "  make verify           - Verify installation"
	@echo "  make clean            - Remove everything"
	@echo "  make clean-all        - Remove everything including CRDs"

install-crds:
	@echo "Installing Gateway API CRDs $(GATEWAY_API_VERSION)..."
	@if kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null; then \
		echo "Gateway API CRDs already installed"; \
		CURRENT_VERSION=$$(kubectl get crd gateways.gateway.networking.k8s.io -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}' 2>/dev/null || echo "unknown"); \
		echo "  Current version: $$CURRENT_VERSION"; \
	else \
		kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml; \
		echo "Gateway API CRDs installed"; \
	fi

install-gateway: install-crds
	@echo "Installing Envoy Gateway $(ENVOY_VERSION)..."
	@kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
	@helm install eg oci://docker.io/envoyproxy/gateway-helm \
     --version ${ENVOY_GATEWAY_VERSION} -n ${NAMESPACE} \
     --values ${FILE_NAME} || true # helm throw error installing same thing twice 

	@echo "Waiting for Envoy Gateway to be ready..."
	@kubectl wait --timeout=5m -n ${NAMESPACE} deployment/envoy-gateway --for=condition=Available

	@echo "Envoy Gateway installed successfully"

	@kubectl get pods -n $(NAMESPACE)

apply-gateway:

	@echo "Applying Gateway resources..."
	@kubectl apply -f ./networking/envoy-gateway/gateway-class.yaml
	@kubectl apply -f ./networking/envoy-gateway/gateway.yaml
	@sleep 5
	@kubectl wait --timeout=2m \
		-n $(NAMESPACE) \
		gateway/${GATEWAY_NAME} \
		--for=condition=Programmed || echo "Gateway may still be starting"
	@echo "Gateway resources applied"

apply-routes:
	@echo "Applying routes..."
	@kubectl apply -f networking/routes/
	@echo "Routes applied"


install: install-gateway apply-gateway apply-routes
	@echo ""
	@echo "✓ Full installation complete!"
	@echo ""
	@echo "Next steps:"
	@echo "  make verify           - Verify installation"
	@echo "  kubectl get gateway main-gateway -n $(NAMESPACE) - Get Gateway IP"

verify:
	@-./verify.sh 2>/dev/null || true

clean:
# 	@echo "Removing all resources (keeping CRDs)..."
# 	@kubectl delete -f networking/routes/ --ignore-not-found
# 	@kubectl delete -f networking/envoy-gateway/gateway.yaml --ignore-not-found
# 	@kubectl delete -f networking/envoy-gateway/gateway-class.yaml --ignore-not-found
# 	@helm uninstall eg -n $(NAMESPACE) || true
# 	@kubectl delete namespace $(NAMESPACE) --ignore-not-found
# 	@echo "✓ Cleanup complete (CRDs preserved)"

clean-all: clean
# 	@echo "Removing Gateway API CRDs..."
# 	@kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$(GATEWAY_API_VERSION)/standard-install.yaml --ignore-not-found
# 	@echo "✓ Complete cleanup (including CRDs)"