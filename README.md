# ToGather Infrastructure

This repository contains the infrastructure configuration for the toGather project. It uses Skaffold to manage the deployment of microservices to a Kubernetes cluster.

## Services

The following microservices are managed by this infrastructure.
Each service has its own repository and Skaffold configuration and is orchestrated through the root `skaffold.yaml`.

| S.No | Service | Repository |
|------|----------|-------------|
| 1 | togather-auth-service | https://github.com/CrossroadsAcademy/togather-auth-service |
| 2 | togather-user-service | https://github.com/CrossroadsAcademy/togather-user-service |
| 3 | togather-partner-service | https://github.com/CrossroadsAcademy/togather-partner-service |
| 4 | togather-websocket-service | https://github.com/CrossroadsAcademy/togather-websocket-service |
| 5 | togather-notification-service | https://github.com/CrossroadsAcademy/togather-notification-service |
| 6 | togather-graphql-service | https://github.com/CrossroadsAcademy/togather-graphql-service |
| 7 | togather-chat-service | https://github.com/CrossroadsAcademy/togather-chat-service |
| 8 | togather-feed-service | https://github.com/CrossroadsAcademy/togather-feed-service |
| 9 | togather-experience-service | https://github.com/CrossroadsAcademy/togather-experience-service |
| 10 | togather-booking-finance-service | https://github.com/CrossroadsAcademy/togather-booking-finance-service |
| 11 | togather-ml-ranking-service | https://github.com/CrossroadsAcademy/togather-ml-ranking-service |
| 12 | togather-ml-dev-composition | https://github.com/CrossroadsAcademy/togather-togather-ml-dev-composition |
| 13 | togather-ml-retrieval-service | https://github.com/CrossroadsAcademy/togather-ml-retrieval-service |
| 14 | togather-ml-training-pipeline | https://github.com/CrossroadsAcademy/togather-ml-training-pipeline |
| 15 | togather-ml-feature-pipeline | https://github.com/CrossroadsAcademy/togather-ml-feature-pipeline |
| 16 | togather-shared-loadtest | https://github.com/CrossroadsAcademy/togather-shared-loadtest |

## Client

The client applications of toGather platform.

| S.No | Client | Repository |
|------|----------|-------------|
| 1 | togather-frontend | https://github.com/CrossroadsAcademy/togather-frontend |

## Libraries

The following repositories contain shared libraries, schemas, and utilities used across multiple microservices.

| S.No | Client | Repository |
|------|----------|-------------|
| 1 | togather-ml-shared-lib | https://github.com/CrossroadsAcademy/togather-ml-shared-lib |
| 2 | togather-shared-protos | https://github.com/CrossroadsAcademy/togather-shared-protos |
| 3 | togather-shared-events | https://github.com/CrossroadsAcademy/togather-shared-events |
| 4 | togather-shared-utils | https://github.com/CrossroadsAcademy/togather-shared-utils |

## Prerequisites

Before you begin, ensure that the following tools are installed and configured on your system:

*   **Docker:** Required to build and run containers. Make sure the Docker daemon is running.
*   **Kubernetes:** A container orchestration platform. This setup assumes you have a running Kubernetes cluster.
*   **kubectl:** The Kubernetes command-line tool. Ensure it is configured to connect to your cluster.
*   **Skaffold:** A tool that automates the build, push, and deploy workflow for Kubernetes applications.
*   **pnpm** A package manager and tooling to run scrips written in javascript.


## Getting Started

1.  **Clone the repository:**
    ```bash
    mkdir togather-dev
    cd togather-dev
    git clone -b develop https://github.com/CrossroadsAcademy/togather-infra.git
    cd togather-infra
    ```

2.  **Run the bootstrap script:**
    This script will clone all the necessary microservice repositories into a same parent folder as `togather-infra `
    ```bash
    chmod +x bootstrap.sh
    ./bootstrap.sh
    ```
3. **Setup the infisial credential for Cluster wide**
    This scrtipt will help generate a Kubernetes secret manifest for infisical
    > 🚧 Apply the generated infisical manifest file before starting the cluster
    
    ```bash
    chmod +x ./scripts/setup-infisical-secret.sh
    ./scripts/setup-infisical-secret.sh
    ```

4. **Staring the Cluster**

    ```bash
    skaffold dev
    ```

## Skaffold Configuration

The `skaffold.yaml` file in this repository is the main entry point for orchestrating the deployment of the entire toGather application. It references the Skaffold configurations of individual microservices, and also deploys the core infrastructure components from the `K8s/auto/` directory.

## Development Workflow

### Starting the Entire Infrastructure

To deploy all the microservices and infrastructure components defined in this repository, run the following command from the root of the `infra` directory:

>Note: Make sure that, you have run the `bootstrap.sh` script and the microservices source code is cloned succesfully before starting the infrastucture

```bash
skaffold dev
```

This will build, push, and deploy all the applications, and then tail the logs from the running containers.

### Starting a Specific Microservice

If you want to work on a single microservice, you can run Skaffold from within that micro-service's directory. This will only build and deploy that specific service.

```bash
cd micro-services/<microservice-repo>
skaffold dev
```
> ⚠️ Make sure the Infisical secrets is available in the cluster.
> If not run `scripts/setup-infisical-secret.sh` to set it up.


### Starting a Subset of Microservices

You can start specific microservices by using the `--module` flag followed by the configuration name of the micro-service. The configuration names can be found in the root `skaffold.yaml` file.

In the root `skaffold.yaml` path run,

```bash
skaffold dev --module togather-base-infra --module togather-auth-cfg --module togather-notification-cfg
```

Alternatively, you can use the `Makefile` to simplify these long commands. Save your specific command configurations in the `Makefile` and run them easily:

```bash
make <command_name>
```

### Tearing Down the Infrastructure

To delete all the Kubernetes resources deployed by Skaffold, run the following command from the root of the `infra` directory:

```bash
skaffold delete
```

## Best Practices

* Uses ConfigMap for environment variables (non-secrets)
* Always **open each micro-services in a new IDE**, rather than opening all the infrastructure in a single IDE, which can improve system resources and commting to wrong repo or infra repo my mistake*  
* **Resource Management:** Each microservice should have its resource requests and limits defined in its Kubernetes deployment configuration. This ensures that your applications run efficiently and don't starve other services of resources.


## Common Mistakes & Troubleshooting

*   **Root Skaffold Cleanup:** The root `skaffold.yaml` orchestrates the deployment of all submodules. If you modify it to remove a microservice, Skaffold's cleanup process will remove all previously deployed manifests for that service from the cluster. Be mindful of this when making changes to the root `skaffold.yaml`.
