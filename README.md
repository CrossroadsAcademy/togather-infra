# toGather Infrastructure

This repository contains the infrastructure configuration for the toGather project. It uses Skaffold to manage the deployment of microservices to a Kubernetes cluster.

## Prerequisites

Before you begin, ensure that the following tools are installed and configured on your system:

*   **Docker:** Required to build and run containers. Make sure the Docker daemon is running.
*   **Kubernetes:** A container orchestration platform. This setup assumes you have a running Kubernetes cluster.
*   **kubectl:** The Kubernetes command-line tool. Ensure it is configured to connect to your cluster.
*   **Skaffold:** A tool that automates the build, push, and deploy workflow for Kubernetes applications.

## Getting Started

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/CrossroadsAcademy/togather-infra.git
    cd togather-infra
    ```

2.  **Run the bootstrap script:**
    This script will clone all the necessary microservice repositories into a `togather-dev` directory and install Skaffold if it's not already present(works only for linux).
    ```bash
    ./bootstrap.sh
    ```

## Skaffold Configuration

The `skaffold.yaml` file in this repository is the main entry point for orchestrating the deployment of the entire toGather application. It references the Skaffold configurations of individual microservices, and also deploys the core infrastructure components from the `K8s/auto/` directory.

## Development Workflow

### Starting the Entire Infrastructure

To deploy all the microservices and infrastructure components defined in this repository, run the following command from the root of the `infra` directory:

```bash
skaffold dev
```

This will build, push, and deploy all the applications, and then tail the logs from the running containers.

### Starting a Specific Microservice

If you want to work on a single microservice, you can run Skaffold from within that microservice's directory. This will only build and deploy that specific service.

```bash
cd togather-dev/<microservice-repo>
skaffold dev
```

### Tearing Down the Infrastructure

To delete all the Kubernetes resources deployed by Skaffold, run the following command from the root of the `infra` directory:

```bash
skaffold delete
```

## Common Mistakes & Troubleshooting

*   **Root Skaffold Cleanup:** The root `skaffold.yaml` orchestrates the deployment of all submodules. If you modify it to remove a microservice, Skaffold's cleanup process will remove all previously deployed manifests for that service from the cluster. Be mindful of this when making changes to the root `skaffold.yaml`.

* Uses ConfigMap for environment variables (non-secrets)