.PHONY: basic-auth user-auth

basic-auth:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-notification-cfg


user-auth:
	skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-user-cfg  --module togather-notification-cfg