.PHONY: help basic-auth user-auth graphql-experience create-experience chat-system user-onboarding partner-onboarding feed-service manage-infisical-secrets booking-flow all-clean all all-run

BOLD := \033[1m
RESET := \033[0m
CYAN := \033[36m
GREEN := \033[32m

help:
	@echo  "$(BOLD)$(CYAN)╔════════════════════════════════════════╗$(RESET)"
	@echo  "$(BOLD)$(CYAN)║   Togather Skaffold Configuration      ║$(RESET)"
	@echo  "$(BOLD)$(CYAN)╚════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(GREEN)Available commands:$(RESET)"
	@echo ""
	@echo "  $(BOLD)make manage-infisical-secrets$(RESET) - Manage Infisical secrets in K8s cluster"
	@echo ""
	@echo "  $(BOLD)make basic-auth$(RESET)               - Start basic auth services (Notification, Auth, Base)"
	@echo "  $(BOLD)make user-auth$(RESET)                - Start user auth services (User, Notification, Auth, Base)"
	@echo "  $(BOLD)make graphql-experience$(RESET)       - Start graphql experience services (Experience, Graphql, Auth, Base)"
	@echo "  $(BOLD)make create-experience$(RESET)        - Start create experience services (Experience, Graphql, Auth, Base)"
	@echo "  $(BOLD)make user-onboarding$(RESET)          - Start full user onboarding services (User, Notification, Auth, Experience, Graphql, Base)"
	@echo "  $(BOLD)make chat-system$(RESET)              - Start chat websocket services (Auth, User, Chat, Websocket, Graphql, Base)"
	@echo "  $(BOLD)make partner-onboarding$(RESET)       - Start full partner onboarding services (Partner, Auth, Experience, Graphql, Base)"
	@echo "  $(BOLD)make feed-service$(RESET)             - Start feed service (Feed, Auth, User, Experience, Graphql, Partner, Base)"
	@echo "  $(BOLD)make booking-flow$(RESET)             - Start booking flow services (Feed, Auth, User, Experience, Graphql, Partner, Booking-Finance, Base)"
	@echo ""
	@echo "  $(BOLD)make all$(RESET)                      - Start all services (dev mode)"
	@echo "  $(BOLD)make all-clean$(RESET)                - Start all services (dev mode, no cache)"
	@echo "  $(BOLD)make all-run$(RESET)                  - Run all services (production mode)"
	@echo ""

basic-auth:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-notification-cfg --module togather-infra-networking

user-auth:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-user-cfg  --module togather-notification-cfg --module togather-infra-networking

graphql-experience:
	skaffold dev --module togather-base-infra --module togather-experience-cfg --module togather-graphql-cfg --module togather-auth-cfg --module togather-infra-networking

create-experience:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-experience-cfg --module togather-graphql-cfg --module togather-infra-networking

chat-system:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-user-cfg --module togather-chat-cfg --module togather-websocket-cfg --module togather-graphql-cfg --module togather-infra-networking

user-onboarding:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-user-cfg --module togather-notification-cfg --module togather-experience-cfg --module togather-graphql-cfg  --module togather-infra-networking
partner-onboarding:
	skaffold dev --module togather-base-infra --module togather-partner-cfg --module togather-auth-cfg --module togather-experience-cfg --module togather-graphql-cfg --module togather-infra-networking
feed-service:
	skaffold dev --module togather-base-infra --module togather-feed-cfg --module togather-auth-cfg --module togather-user-cfg --module togather-experience-cfg --module togather-graphql-cfg --module togather-partner-cfg --module togather-infra-networking
manage-infisical-secrets:
	./scripts/setup-infisical-secret.sh
booking-flow:
	skaffold dev --module togather-base-infra --module togather-feed-cfg --module togather-auth-cfg --module togather-user-cfg --module togather-experience-cfg --module togather-graphql-cfg --module togather-partner-cfg --module togather-booking-finance-cfg --module togather-infra-networking
all-clean:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-user-cfg --module togather-notification-cfg --module togather-experience-cfg --module togather-graphql-cfg   --module togather-chat-cfg --module togather-websocket-cfg --module togather-partner-cfg --module togather-booking-finance-cfg --module togather-feed-cfg --module togather-infra-networking --cache-artifacts=false 
all:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-user-cfg --module togather-notification-cfg --module togather-experience-cfg --module togather-graphql-cfg   --module togather-chat-cfg --module togather-websocket-cfg --module togather-partner-cfg --module togather-booking-finance-cfg --module togather-feed-cfg --module togather-infra-networking
all-run:
	skaffold run --module togather-base-infra --module togather-auth-cfg --module togather-user-cfg --module togather-notification-cfg --module togather-experience-cfg --module togather-graphql-cfg   --module togather-chat-cfg --module togather-websocket-cfg --module togather-partner-cfg --module togather-booking-finance-cfg --module togather-feed-cfg --module togather-infra-networking
