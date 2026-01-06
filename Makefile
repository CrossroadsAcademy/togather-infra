.PHONY: basic-auth user-auth

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
	@echo "  $(BOLD)make basic-auth$(RESET)      		   - Start basic auth services(Notification, Auth, Base)"
	@echo "  $(BOLD)make user-auth$(RESET)      		      - Start user auth services(User, Notification, Auth, Base)"
	@echo "  $(BOLD)make graphql-experience$(RESET)       - Start graphql experience services(User, Notification, Auth, Base)"
	@echo "  $(BOLD)make user-onboarding$(RESET)          - Start full user onboarding services(User, Notification, Auth, Experience, Graphql, Base)"
	@echo "  $(BOLD)make chat-system$(RESET)              - Start auth chat websocket services(Auth, User, Chat, Websocket, Base)"
	@echo "  $(BOLD)make create-experience$(RESET)        - Start create experience services(Experience, Graphql, Auth, Base)"
	@echo "  $(BOLD)make partner-onboarding$(RESET)       - Start full partner onboarding services(Partner, Notification, Auth, Experience, Graphql, Base)"
	@echo "  $(BOLD)make feed-service$(RESET)             - Start feed service services(Feed, Graphql, Auth, Base)"
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