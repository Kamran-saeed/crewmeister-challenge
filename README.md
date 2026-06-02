# Crewmeister DevOps Challenge

A Spring Boot REST API with MySQL, containerized with Docker and deployable via Helm and Terraform. This repository contains both the application source and all infrastructure code.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Local Deployment](#local-deployment)
- [Production Deployment](#production-deployment)
- [CI/CD Pipeline](#cicd-pipeline)
  - [CI — Build and Push](#ci--build-and-push)
  - [CD — Terraform Deploy](#cd--terraform-deploy)
- [Monitoring](#monitoring)

---

## Overview

Spring Boot REST API that manages users, backed by MySQL. The application uses Flyway for database migrations and Spring Actuator for health and metrics endpoints.

**Tech stack:**
- Java 17, Spring Boot 3.3.5, MySQL 8.0
- Docker, Docker Compose
- Helm, Terraform, Kubernetes
- GitHub Actions
- Prometheus, Grafana

---

## Project Structure

```
.
├── src/                    # Spring Boot application source code
├── Dockerfile              # Multi-stage build — compile with JDK, run with JRE
├── docker-compose.yml      # Local stack — app, MySQL, Prometheus, Grafana
├── .env.example            # Environment variable template
├── pom.xml                 # Maven build and dependency config
├── .github/workflows/
│   ├── ci.yml              # CI — test + build + push to GHCR on every push to main
│   └── terraform-deploy.yml # CD — workflow_dispatch plan/apply dropdown for EKS deployment
├── configs/
│   └── monitoring/         # Prometheus and Grafana config for Docker Compose
├── kubernetes/
│   └── helm/
│       ├── crewmeister/    # Helm chart — app + MySQL deployments, ServiceMonitor
│       └── environments/   # Environment-specific values (local, production)
├── docs/
│   ├── prerequisites.md         # Required tools and AWS resources (S3, DynamoDB) — read first
│   ├── local-docker.md          # Docker Compose setup and commands
│   ├── local-kubernetes.md      # Raw Helm and Terraform local deployment steps
│   └── production-deployment.md # EKS-specific prerequisites, deploy steps, verify, monitoring access
└── infrastructure/
    └── terraform/
        ├── crewmeister-app/    # Terraform — deploys crewmeister Helm release
        │   ├── base/           # Reusable module (helm_release + templatefile)
        │   ├── local/          # Minikube environment root — calls base/
        │   └── production/     # Production environment root — calls base/, S3 backend
        ├── monitoring/         # Terraform — deploys kube-prometheus-stack
        │   ├── base/           # Reusable module (helm_release + templatefile)
        │   ├── local/          # Minikube environment root — calls base/
        │   └── production/     # Production environment root — calls base/, S3 backend
        └── github-runner/      # Terraform — self-hosted runner EC2 + GitHub OIDC IAM role + EKS access entry
```

---

## Prerequisites

See **[docs/prerequisites.md](docs/prerequisites.md)** for required tools (Docker, kubectl, helm, terraform, minikube) and required AWS resources (credentials, S3 state bucket, DynamoDB lock table).

---

## Local Deployment

Two options — Docker Compose for a quick local dev stack, or minikube for a full Kubernetes environment.

### Docker Compose

Runs Spring Boot, MySQL, Prometheus, and Grafana in a single Docker network. Grafana and the Prometheus datasource are provisioned automatically on first start.

Full setup guide: **[docs/local-docker.md](docs/local-docker.md)**

### Kubernetes (minikube)

Deploys the full Helm chart to a local minikube cluster — app, MySQL StatefulSet, and kube-prometheus-stack for monitoring. Two methods are available: raw Helm commands or Terraform.

Full guide (both methods): **[docs/local-kubernetes.md](docs/local-kubernetes.md)**

---

## Production Deployment

Deploys to AWS EKS using Terraform. The Helm chart is the same as local — production-specific features are enabled via values:

| Feature | Local | Production (EKS) |
|---|:---:|:---:|
| K8s Secret (password from values) | ✓ | ✗ |
| External Secrets (ESO + AWS Secrets Manager) | ✗ | ✓ |
| HPA (min 3 / max 10 pods, cpu 50%) | ✗ | ✓ |
| Ingress (NGINX, HTTPS via ACM) | ✗ | ✓ |
| ServiceMonitor (Prometheus scraping) | optional | ✓ |

Terraform connects to EKS directly via AWS APIs — no kubeconfig needed. Each component (`crewmeister-app`, `monitoring`) has its own state file so they can be deployed and destroyed independently.

Full guide (prerequisites + deploy): **[docs/production-deployment.md](docs/production-deployment.md)**

---

## CI/CD Pipeline

Two GitHub Actions workflows handle CI and CD separately.

---

## CI — Build and Push

Defined in `.github/workflows/ci.yml`. Triggers on every push to `main`.

### Architecture

```
push to main
     │
     ▼
┌─────────────────────────────────────────┐
│               test job                  │
│                                         │
│  checkout code                          │
│       │                                 │
│       ▼                                 │
│  MySQL 8.0 service container            │
│  (health checked before tests run)      │
│       │                                 │
│       ▼                                 │
│  JDK 17 setup                           │
│       │                                 │
│       ▼                                 │
│  mvn test                               │
└─────────────────┬───────────────────────┘
                  │ only if green
                  ▼
┌─────────────────────────────────────────┐
│           build-and-push job            │
│                                         │
│  checkout code                          │
│       │                                 │
│       ▼                                 │
│  Docker Buildx setup                    │
│       │                                 │
│       ▼                                 │
│  login to GHCR (GITHUB_TOKEN)           │
│       │                                 │
│       ▼                                 │
│  docker build + push                    │
│  (multi-stage)                          │
└─────────────────┬───────────────────────┘
                  │
                  ▼
         ghcr.io/kamran-saeed/
         crewmeister-challenge
         :latest
         :sha-<commit-sha>
```

### Jobs

**`test`** — spins up a MySQL 8.0 service container, installs JDK 17, and runs `mvn test`. The Spring Boot context load test connects to the real MySQL, runs Flyway migrations, and verifies the application boots successfully.

**`build-and-push`** — runs only if `test` passes. Builds the Docker image using the multi-stage Dockerfile (Maven build happens inside the container — no JDK required on the runner) and pushes to GHCR with two tags. Maven dependencies are cached between runs via `setup-java`; Docker layers are cached via GHCR (`buildcache` tag, mode=max) — subsequent builds are significantly faster.

### Image

The built image is published to GitHub Container Registry:

```
ghcr.io/kamran-saeed/crewmeister-challenge:latest        # latest main build
ghcr.io/kamran-saeed/crewmeister-challenge:sha-<commit>  # exact commit reference
```

Pull the image:
```bash
docker pull ghcr.io/kamran-saeed/crewmeister-challenge:latest
```

The SHA tag provides traceability — you can identify exactly which commit produced any given image.

---

## CD — Terraform Deploy

Defined in `.github/workflows/terraform-deploy.yml`. Triggered manually via `workflow_dispatch` — never runs automatically.

### How it works

The workflow uses a `plan`/`apply` input dropdown. Running it with `plan` always runs `terraform init` and `terraform plan` — no changes are made. Running it with `apply` runs `terraform apply -auto-approve` in addition.

The intended flow is: run with **plan** → review the plan output in the workflow logs → run again with **apply** only if the plan looks correct.

Two jobs run sequentially — `deploy-monitoring` first, then `deploy-app` (via `needs:`). Each job authenticates to AWS independently using GitHub OIDC, so no long-lived AWS credentials are stored anywhere.

### Architecture

```
GitHub Actions UI
  (workflow_dispatch)
        │
        │  input: plan | apply
        ▼
┌───────────────────────────────────────────────────────────────┐
│  GitHub Actions — self-hosted runner [self-hosted, linux, eks] │
│  EC2 t3.small — private subnet, same VPC as EKS               │
│                                                                │
│  ┌───────────────────────────────────────────┐                 │
│  │  Assume OIDC role via short-lived token   │                 │
│  │  (no AWS keys stored in GitHub Secrets)   │                 │
│  └───────────────────┬───────────────────────┘                 │
│                      │                                         │
│                      ▼                                         │
│  ┌───────────────────────────────────────────┐                 │
│  │  Job 1: deploy-monitoring                 │                 │
│  │  terraform init + plan  (always)          │                 │
│  │  terraform apply        (if: apply)       │                 │
│  └───────────────────┬───────────────────────┘                 │
│                      │ needs:                                  │
│                      ▼                                         │
│  ┌───────────────────────────────────────────┐                 │
│  │  Job 2: deploy-app                        │                 │
│  │  terraform init + plan  (always)          │                 │
│  │  terraform apply        (if: apply)       │                 │
│  └───────────────────────────────────────────┘                 │
│                      │                                         │
│                      ▼                                         │
│         EKS private API endpoint                               │
│         (resolvable only from within the VPC)                  │
└───────────────────────────────────────────────────────────────┘
```

### Self-hosted runner

The workflow runs on a self-hosted EC2 runner inside the same VPC as the EKS cluster. This is required because the EKS API endpoint is private — not reachable from GitHub-hosted runners. The runner is a one-time setup — once provisioned it stays running and picks up jobs automatically.

**Step 1 — Store the GitHub PAT in Secrets Manager**

The runner reads a GitHub PAT on startup to register itself with the repository. Add it to the existing `crewmeister/credentials` secret without overwriting the MySQL password:

```bash
aws secretsmanager put-secret-value \
  --secret-id crewmeister/credentials \
  --region eu-central-1 \
  --secret-string "$(aws secretsmanager get-secret-value \
    --secret-id crewmeister/credentials \
    --region eu-central-1 \
    --query SecretString \
    --output text | jq '. + {"github-pat": "your_github_pat"}')"
```

The PAT requires **Administration: Read and Write** permission on the repository.

**Step 2 — Provision the runner**

```bash
cd infrastructure/terraform/github-runner
cp terraform.tfvars.example terraform.tfvars  # fill in cluster name, VPC/subnet IDs, repo name
terraform init
terraform apply
```

This creates the EC2 instance, security group, IAM role, OIDC provider, and EKS access entry. On first boot the instance reads the PAT from Secrets Manager and registers itself as a runner automatically.

**Step 3 — Set GitHub Secrets**

Use the Terraform outputs to configure the repository secrets:

| Secret | Where to get the value |
|---|---|
| `AWS_ROLE_ARN` | `oidc_role_arn` output from `terraform apply` in step 2 above |
| `ESO_ROLE_ARN` | Run `kubectl get sa external-secrets -n external-secrets -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'` on the cluster |
| `GRAFANA_ADMIN_PASSWORD` | Your chosen Grafana admin password — injected into `terraform.tfvars` at runtime, never stored in the repo or state |

### Usage

**1. Run plan first**

Go to **Actions → Terraform Deploy (Production) → Run workflow**, select `plan`, and click **Run workflow**. Wait for both jobs to complete, then review the `Terraform Plan` step output in each job.

**2. Run apply**

If the plan output looks correct, trigger the workflow again with `apply`. Terraform will deploy both stacks.

---

## Monitoring

The application exposes Prometheus metrics at `/actuator/prometheus` via the Micrometer library. Two monitoring setups are provided: one for Docker Compose (local dev) and one for Kubernetes.

---

### Docker Compose Monitoring

#### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Docker Network                         │
│                                                              │
│   ┌──────────────┐   scrape every   ┌──────────────────┐    │
│   │  Spring Boot │◄─────15s─────────│   Prometheus     │    │
│   │  :8080       │  /actuator/      │   :9090          │    │
│   │              │   prometheus     │                  │    │
│   └──────────────┘                  └────────┬─────────┘    │
│                                              │ datasource   │
│                                              ▼              │
│                                    ┌──────────────────┐     │
│                                    │     Grafana       │     │
│                                    │     :3000         │     │
│                                    │  dashboard auto-  │     │
│                                    │  provisioned      │     │
│                                    └──────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

Prometheus and Grafana start automatically alongside the app when you run `docker compose up`. No manual configuration is needed — the Prometheus datasource and Spring Boot dashboard are provisioned automatically on first start.

#### Accessing

| Service | URL | Credentials |
|---|---|---|
| Grafana | `http://localhost:3000` | admin / admin (set via `.env`) |
| Prometheus | `http://localhost:9090` | — |
| App metrics | `http://localhost:8080/actuator/prometheus` | — |

The pre-loaded dashboard is **Spring Boot 2.1 System Monitor** — it shows JVM memory, CPU, GC activity, HTTP request rates, and HikariCP connection pool metrics.

---

### Kubernetes Monitoring (kube-prometheus-stack)

The app Helm chart includes an optional `ServiceMonitor` resource — a Kubernetes CRD that tells the Prometheus operator which pods to scrape and how. It is disabled by default and enabled automatically in production via Terraform.

kube-prometheus-stack is deployed as a separate Terraform module (`infrastructure/terraform/monitoring/`) and includes: Prometheus operator, Prometheus, Grafana, kube-state-metrics, and node-exporter.

Access via port-forward (see the relevant deployment guide for exact commands):

| Service | URL | Credentials |
|---|---|---|
| Grafana | `http://localhost:3000` | admin / (password from `terraform.tfvars` or `GRAFANA_ADMIN_PASSWORD` secret) |
| Prometheus | `http://localhost:9090` | — |

Useful PromQL queries to explore app metrics:

```
rate(http_server_requests_seconds_count[1m])   # HTTP request rate
jvm_memory_used_bytes{area="heap"}             # JVM heap usage
hikaricp_connections_active                    # Active DB connections
```
