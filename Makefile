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
	@echo "  $(BOLD)make basic-auth$(RESET)     - Start basic auth services(Notification, Auth, Base)"
	@echo "  $(BOLD)make user-auth$(RESET)      - Start user auth services(User, Notification, Auth, Base)"
	@echo "  $(BOLD)make graphql-experience$(RESET)      - Start graphql experience services(User, Notification, Auth, Base)"
	@echo ""

basic-auth:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-notification-cfg


user-auth:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-user-cfg  --module togather-notification-cfg

graphql-experience:
	skaffold dev --module togather-base-infra --module togather-experience-cfg --module togather-graphql-cfg --module togather-auth-cfg