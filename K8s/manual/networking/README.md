routes naming conventions

Name of this HTTPRoute object, here backend.

Naming convention:

Use descriptive names like <service>-http or <team>-<service>-route.

Must be unique per namespace.

Avoid uppercase letters or underscores (use -).

multiple bakcned wiht weight for ab testing

backendRefs:

- name: backend-v1
  port: 3000
  weight: 90
- name: backend-v2
  port: 3000
  weight: 10
