# toGather Infrastructure

This repository contains the infrastructure configuration for the toGather project. It uses Skaffold to manage the deployment of microservices to a Kubernetes cluster.

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
    This scrtipt will help generate a Kuberbeties secret manifest for infisical
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

>Note: Make sure that, you have run the `bootstrap.sh` script and the mirosrcies source code is cloned succesfully before starting the infrastucture

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
