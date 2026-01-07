# SimpleApp GitOps

A GitOps repository for managing Kubernetes deployments of the SimpleApp API using ArgoCD and Kustomize.

## Overview

This repository contains the infrastructure-as-code configuration for deploying and managing the SimpleApp API across multiple environments (dev, staging, prod) using GitOps principles. It leverages ArgoCD for continuous delivery and Kustomize for environment-specific configurations.

## Architecture

```
simpleapp-gitops/
├── argocd/                    # ArgoCD configuration
│   ├── project.yaml           # ArgoCD project definition
│   └── applications/          # ArgoCD Application manifests
│       ├── dev.yaml
│       ├── staging.yaml
│       └── prod.yaml
├── k8s/                       # Kubernetes manifests
│   ├── base/                  # Base configuration (shared)
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── app-secret.yaml
│   │   └── postgres/          # PostgreSQL database
│   └── overlays/              # Environment-specific overlays
│       ├── dev/
│       ├── staging/
│       └── prod/
├── scripts/                   # Utility scripts
└── Makefile                   # Automation commands
```

## Prerequisites

- Kubernetes cluster (local or remote)
- kubectl configured with cluster access
- ArgoCD CLI (optional, for manual sync operations)
- Kustomize (for local validation)

## Quick Start

### 1. Install ArgoCD

```bash
make install-argocd
```

This will install ArgoCD on your cluster and display the admin password.

### 2. Deploy All Environments

```bash
make deploy-all
```

Or deploy individual environments:

```bash
make deploy-dev
make deploy-staging
make deploy-prod
```

### 3. Access ArgoCD UI

```bash
make port-forward-argocd
```

Navigate to https://localhost:8080 and login with:
- Username: `admin`
- Password: Run `make get-argocd-password`

## Environments

| Environment | Namespace         | Replicas | Auto-Scaling | Description                    |
|-------------|-------------------|----------|--------------|--------------------------------|
| dev         | simpleapp-dev     | 1        | No           | Development and testing        |
| staging     | simpleapp-staging | 2        | No           | Pre-production validation      |
| prod        | simpleapp-prod    | 3        | Yes (3-10)   | Production with HPA            |

### Environment Differences

**Development:**
- Single replica
- Minimal resource allocation
- Automated sync with self-heal enabled

**Staging:**
- Two replicas for basic redundancy
- Moderate resource allocation
- Automated sync with self-heal enabled

**Production:**
- Three replicas minimum
- HorizontalPodAutoscaler (3-10 replicas)
- Increased memory limits (512Mi-1Gi)
- CPU/Memory-based auto-scaling (70%/80% thresholds)

## Make Targets

Run `make help` to see all available commands.

### Installation

| Command              | Description                           |
|----------------------|---------------------------------------|
| `make install-argocd` | Install ArgoCD on the cluster        |
| `make uninstall-argocd` | Uninstall ArgoCD from the cluster  |
| `make get-argocd-password` | Get ArgoCD admin password        |

### Deployment

| Command              | Description                           |
|----------------------|---------------------------------------|
| `make setup`         | Full setup: Install ArgoCD + deploy all |
| `make deploy-all`    | Deploy project and all applications   |
| `make deploy-dev`    | Deploy dev environment               |
| `make deploy-staging`| Deploy staging environment           |
| `make deploy-prod`   | Deploy prod environment              |

### Destruction

| Command              | Description                           |
|----------------------|---------------------------------------|
| `make teardown`      | Destroy all apps (keeps ArgoCD)       |
| `make destroy-all`   | Destroy everything except ArgoCD      |
| `make destroy-dev`   | Destroy dev environment only          |
| `make nuke`          | DANGER: Destroy everything            |

### Synchronization

| Command              | Description                           |
|----------------------|---------------------------------------|
| `make sync-all`      | Sync all environments                 |
| `make sync-dev`      | Sync dev environment                  |
| `make sync-staging`  | Sync staging environment              |
| `make sync-prod`     | Sync prod environment                 |

### Monitoring

| Command              | Description                           |
|----------------------|---------------------------------------|
| `make status`        | Show status of all resources          |
| `make status-argocd` | Show ArgoCD status                    |
| `make logs-dev`      | Show dev API logs                     |
| `make logs-staging`  | Show staging API logs                 |
| `make logs-prod`     | Show prod API logs                    |

### Port Forwarding

| Command                   | Description                        |
|---------------------------|------------------------------------|
| `make port-forward-argocd`| ArgoCD UI at https://localhost:8080|
| `make port-forward-dev`   | Dev API at http://localhost:8081   |
| `make port-forward-staging`| Staging API at http://localhost:8082|
| `make port-forward-prod`  | Prod API at http://localhost:8083  |

### Validation

| Command              | Description                           |
|----------------------|---------------------------------------|
| `make validate`      | Validate all Kustomize overlays       |
| `make validate-dev`  | Validate dev overlay                  |
| `make validate-staging` | Validate staging overlay           |
| `make validate-prod` | Validate prod overlay                 |

## Promotion Workflow

To promote a deployment from one environment to another:

```bash
./scripts/promote.sh dev staging
./scripts/promote.sh staging prod
```

This script:
1. Extracts the current image tag from the source environment
2. Updates the target environment's Kustomization with the new image tag
3. Commits and pushes the changes
4. ArgoCD automatically syncs the changes

## Components

### Application Stack

- **SimpleApp API**: Spring Boot application running on port 8081
- **PostgreSQL**: Database backend with persistent storage

### Kubernetes Resources

**Base resources (all environments):**
- Deployment with health probes (liveness/readiness)
- Service (ClusterIP)
- ConfigMap for application configuration
- Secret for sensitive data
- PostgreSQL deployment with PVC

**Production additions:**
- HorizontalPodAutoscaler

### Security Features

- Non-root container execution
- Read-only root filesystem
- Dropped Linux capabilities
- Security contexts enforced

## Configuration

### Application Configuration

Environment variables are managed via ConfigMap:

| Variable               | Description                    |
|------------------------|--------------------------------|
| APP_VERSION            | Application version            |
| APP_ENVIRONMENT        | Environment name               |
| SPRING_PROFILES_ACTIVE | Spring profile                 |
| DB_HOST                | PostgreSQL host                |
| DB_PORT                | PostgreSQL port                |
| DB_NAME                | Database name                  |

### Image Management

Images are managed in each overlay's `kustomization.yaml`:

```yaml
images:
- name: simpleapp-api
  newName: ghcr.io/atychkivskyy/simpleapp-api
  newTag: <commit-sha>
```

## ArgoCD Sync Policy

All environments are configured with:
- **Automated sync**: Changes are automatically applied
- **Self-heal**: Manual changes are reverted to match Git state
- **Prune**: Orphaned resources are removed
- **Retry**: Failed syncs are retried (5 attempts with exponential backoff)

## Troubleshooting

### Check cluster status

```bash
./scripts/check-cluster.sh
```

### View application status

```bash
make status
```

### View logs

```bash
make logs-dev
make logs-staging
make logs-prod
```

### Validate manifests locally

```bash
make validate
```

### Force sync an environment

```bash
argocd app sync simpleapp-api-dev --force
```

## Repository Structure Details

### ArgoCD Project

The `argocd/project.yaml` defines a project named `simpleapp` that:
- Restricts deployments to specific namespaces
- Limits allowed resource types
- Scopes access to the designated Git repository

### Kustomize Overlays

Each environment overlay customizes:
- Namespace
- Replica count
- Image tag
- Environment-specific labels
- Resource limits (prod)
- Additional resources (HPA for prod)

[//]: # (## License)

[//]: # ()
[//]: # (This project is proprietary. All rights reserved.)
