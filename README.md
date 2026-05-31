# Crewmeister DevOps Challenge

A Spring Boot REST API with MySQL, containerized with Docker and deployable via Helm and Terraform. This repository contains both the application source and all infrastructure code.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Local Setup](#local-setup)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Terraform](#terraform)
- [CI/CD Pipeline](#cicd-pipeline)
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

## Architecture

Architecture diagrams are provided per deployment environment. Each section below contains its own diagram relevant to that setup.

---

## Project Structure

```
.
├── src/                    # Spring Boot application source code
├── Dockerfile              # Multi-stage build — compile with JDK, run with JRE
├── docker-compose.yml      # Local stack — app, MySQL, Prometheus, Grafana
├── .env.example            # Environment variable template
├── pom.xml                 # Maven build and dependency config
├── .github/workflows/      # GitHub Actions CI pipeline
├── configs/
│   └── monitoring/         # Prometheus and Grafana config for Docker Compose
├── kubernetes/
│   └── helm/
│       ├── crewmeister/    # Helm chart — app + MySQL deployments, ServiceMonitor
│       └── environments/   # Environment-specific values (local, production)
└── infrastructure/
    └── terraform/
        ├── crewmeister-app/    # Terraform — deploys crewmeister Helm release
        │   ├── base/           # Reusable module (helm_release + templatefile)
        │   ├── local/          # Minikube environment root — calls base/
        │   └── production/     # Production environment root — calls base/, S3 backend
        └── monitoring/         # Terraform — deploys kube-prometheus-stack
            ├── base/           # Reusable module (helm_release + templatefile)
            ├── local/          # Minikube environment root — calls base/
            └── production/     # Production environment root — calls base/, S3 backend
```

---

## Prerequisites

### Local Development
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

Maven and Java do not need to be installed locally — the build happens inside Docker.

### Kubernetes Deployment
- `kubectl`
- `helm`
- `terraform >= 1.9.0` — versions below 1.9.0 have an expired GPG key issue with provider installation
- `minikube` — for local Kubernetes cluster

---

## Local Setup

### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Docker Network                            │
│                                                                   │
│  ┌──────────────────┐       ┌──────────────────┐                 │
│  │   Spring Boot    │──────►│      MySQL        │                 │
│  │   :8080          │       │      :3306        │                 │
│  └────────┬─────────┘       └──────────────────┘                 │
│           │ /actuator/prometheus                                  │
│           ▼                                                       │
│  ┌──────────────────┐       ┌──────────────────┐                 │
│  │   Prometheus     │──────►│     Grafana       │                 │
│  │   :9090          │       │     :3000         │                 │
│  └──────────────────┘       └──────────────────┘                 │
│                                                                   │
└──────────────────────────┬───────────────────────────────────────┘
                           │
          ┌────────────────┼──────────────────┐
          ▼                ▼                  ▼
   localhost:8080    localhost:9090     localhost:3000
   (API requests)   (Prometheus UI)   (Grafana dashboards)
```

All services run inside the same Docker network and communicate using service names as hostnames. On startup, Flyway automatically runs the database migration, creating the `user` table and seeding an initial record. Prometheus starts only after the app is healthy, and Grafana's datasource and dashboard are provisioned automatically — no manual setup needed.

**1. Clone the repository**
```bash
git clone https://github.com/Kamran-saeed/crewmeister-challenge.git
cd crewmeister-challenge
```

**2. Configure environment variables**

All variables are defined in `.env`. Never commit this file — it is listed in `.gitignore`. Use `.env.example` as the template.

| Variable | Description | Example |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | MySQL root password | `dev` |
| `MYSQL_DATABASE` | Database name | `challenge` |
| `MYSQL_USERNAME` | MySQL username | `root` |
| `GRAFANA_ADMIN_USER` | Grafana admin username | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `admin` |

```bash
cp .env.example .env
```
Edit `.env` with your preferred values.

**3. Start the stack**
```bash
docker compose up --build
```

The first run takes a few minutes — Maven downloads all dependencies inside the build container. Subsequent builds are faster due to layer caching.

**4. Test the API**

```bash
# Fetch a user by ID
curl "http://localhost:8080/user?id=1"
# Greetings from Crewmeister, Alice!

# Create a new user
curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Muhammad"}'
# Greetings from Crewmeister, Muhammad!

# Health check
curl http://localhost:8080/actuator/health
# {"status":"UP"}

# Prometheus metrics
curl http://localhost:8080/actuator/prometheus
```

**Stopping the stack**
```bash
docker compose down
```

To also remove the database volume (wipes all data):
```bash
docker compose down -v
```

---

## Kubernetes Deployment

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                            │
│                                                                      │
│   ┌─────────────────┐    ┌─────────────────┐                        │
│   │   ConfigMap     │    │     Secret      │                        │
│   │  JDBC URL       │    │  mysql-password │                        │
│   │  DB name        │    │                 │                        │
│   │  username       │    └────────┬────────┘                        │
│   └────────┬────────┘             │                                 │
│            │                      │                                 │
│            ▼                      ▼                                 │
│   ┌─────────────────────────────────────┐                           │
│   │         app-deployment              │                           │
│   │  ┌────────────────────────────┐     │                           │
│   │  │  init container (busybox)  │     │                           │
│   │  │  waits for MySQL ready     │     │                           │
│   │  └────────────────────────────┘     │                           │
│   │  ┌────────────────────────────┐     │                           │
│   │  │  Spring Boot :8080         │     │                           │
│   │  │  liveness  → /actuator     │     │                           │
│   │  │  readiness → /actuator     │     │                           │
│   │  └────────────────────────────┘     │                           │
│   └──────────────┬──────────────────────┘                           │
│                  │                                                   │
│                  ▼                                                   │
│   ┌──────────────────────┐      ┌──────────────────────────────┐    │
│   │   app-service        │      │     mysql-deployment         │    │
│   │   ClusterIP :8080    │      │  ┌────────────────────────┐  │    │
│   └──────────────────────┘      │  │  MySQL :3306           │  │    │
│                                 │  │  liveness → mysqladmin  │  │    │
│                                 │  │  readiness → mysqladmin │  │    │
│                                 │  └───────────┬────────────┘  │    │
│                                 └──────────────┼───────────────┘    │
│                                                │                    │
│   ┌──────────────────────┐      ┌──────────────▼───────────────┐    │
│   │   mysql-service      │      │     mysql-pvc                │    │
│   │   ClusterIP :3306    │      │     1Gi persistent storage   │    │
│   └──────────────────────┘      └──────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

Sensitive values (MySQL password) are stored in a Kubernetes Secret. Non-sensitive config (JDBC URL, username, database name) are stored in a ConfigMap. The app deployment reads both at startup.

The app pod includes an init container that blocks Spring Boot from starting until MySQL is confirmed reachable — eliminating crash-restart loops on startup.

MySQL data is stored on a PersistentVolumeClaim so it survives pod restarts.

### Values and Overrides

All configurable values live in `values.yaml`. Environment-specific overrides go in separate files — only the values that differ from defaults need to be specified.

| File | Purpose |
|---|---|
| `kubernetes/helm/crewmeister/values.yaml` | Defaults — base configuration |
| `kubernetes/helm/environments/local/values.yaml` | Minikube — local image, `Never` pull policy, real password |
| `kubernetes/helm/environments/local/values.yaml.example` | Template for local setup |
| `kubernetes/helm/environments/production/values.yaml.example` | Template for production setup |

### Local Kubernetes Deployment (minikube)

**1. Start minikube**
```bash
minikube start
```

**2. Build the app image and load it into minikube**

Since minikube runs its own isolated Docker environment, the locally built image must be explicitly loaded in:
```bash
docker compose build
minikube image load crewmeister-challenge-app:latest
```

**3. Configure and deploy the monitoring stack**

The monitoring stack must be deployed first — it installs the `ServiceMonitor` CRD that the app chart depends on.

```bash
cp kubernetes/helm/environments/local/monitoring-values.yaml.example kubernetes/helm/environments/local/monitoring-values.yaml
```

Edit `kubernetes/helm/environments/local/monitoring-values.yaml` and set your Grafana admin password. This file is in `.gitignore` and will never be committed.

Then add the Helm repo and deploy:
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --version 86.1.0 \
  -f ./kubernetes/helm/environments/local/monitoring-values.yaml \
  --namespace monitoring --create-namespace
```

Wait for all monitoring pods to be ready (this takes 2–3 minutes on first run):
```bash
kubectl get pods -n monitoring
```

**4. Configure and deploy the app**

```bash
cp kubernetes/helm/environments/local/values.yaml.example kubernetes/helm/environments/local/values.yaml
```

Edit `kubernetes/helm/environments/local/values.yaml` and set your MySQL password. This file is in `.gitignore` and will never be committed.

The app chart includes an optional `ServiceMonitor` resource — a Kubernetes CRD that tells the Prometheus operator to scrape the app's `/actuator/prometheus` endpoint. It is disabled by default. For monitoring, enable it, set the following in your `values.yaml`:

```yaml
serviceMonitor:
  enabled: true
```

Then deploy:
```bash
helm install crewmeister ./kubernetes/helm/crewmeister -f ./kubernetes/helm/environments/local/values.yaml
```

**5. Verify pods are running**
```bash
kubectl get pods
kubectl get pods -n monitoring
```

App pods should reach `1/1 Running`. The app pod will show `Init:0/1` briefly while the init container waits for MySQL, then transition to `Running`.

**6. Test the API**

Since services are `ClusterIP` (internal only), use port-forward to reach the app from your machine:
```bash
kubectl port-forward service/crewmeister-app-service 8080:8080
```

Then in a separate terminal:
```bash
curl "http://localhost:8080/user?id=1"
# Greetings from Crewmeister, Alice!

curl -X POST http://localhost:8080/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Muhammad"}'
# Greetings from Crewmeister, Muhammad!

curl http://localhost:8080/actuator/health
# {"status":"UP"}

# Prometheus metrics
curl http://localhost:8080/actuator/prometheus
```

**7. Access monitoring**

```bash
# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Prometheus (in a separate terminal)
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Open `http://localhost:3000` and log in with your Grafana admin credentials. To verify Prometheus is scraping the app, open `http://localhost:9090/targets` — the `crewmeister-app` target should show `State: UP`.

**Upgrading the app release**
```bash
helm upgrade crewmeister ./kubernetes/helm/crewmeister -f ./kubernetes/helm/environments/local/values.yaml
```

**Removing the releases**
```bash
helm uninstall crewmeister
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```

---

## Terraform

Terraform manages Helm releases as infrastructure as code using the Helm and Kubernetes providers. Each component (`crewmeister-app`, `monitoring`) follows a `base` / environment pattern — `base/` contains all resource definitions, `local/` and `production/` are environment root modules that call `base/`, set their own kubeconfig context in `providers.tf`, and define their own backend. Each component has its own state file, so you can deploy, update, or destroy monitoring without touching the application.

The Helm chart is referenced by local path since it lives in the same repository. In a production setup the chart would be published to a registry and versioned independently.

### Structure

**`base/`** — reusable module, shared across environments. Contains the `helm_release` resource and `templatefile()` rendering. No provider or backend configuration.

| File | Purpose |
|---|---|
| `main.tf` | `helm_release` resource with `templatefile()` |
| `variables.tf` | Input variable declarations |
| `outputs.tf` | Outputs — release name, namespace, status |
| `templates/values.yaml.tpl` | Helm values template rendered from Terraform variables |

**`local/` and `production/`** — environment root modules. Each calls `../base` and wires in environment-specific values directly in `main.tf`. Only sensitive values (passwords) go in `terraform.tfvars`.

| File | Purpose |
|---|---|
| `main.tf` | Calls `../base` with environment-specific values hardcoded |
| `variables.tf` | Sensitive variable declarations only |
| `providers.tf` | Provider config with environment-specific kubeconfig context |
| `versions.tf` | Terraform and provider version constraints |
| `backend.tf` | `local` backend for minikube, `s3` backend for production |
| `terraform.tfvars` | Sensitive values (passwords) — gitignored |
| `terraform.tfvars.example` | Template for sensitive values |
| `.terraform.lock.hcl` | Pins exact provider versions for reproducible installs |

### Deployment

Each environment directory is a self-contained Terraform root — just `cd` into it and run `terraform apply`.

Monitoring must be deployed first — it installs the `ServiceMonitor` CRD that the app chart references.

**1. Deploy monitoring stack**
```bash
cp infrastructure/terraform/monitoring/local/terraform.tfvars.example infrastructure/terraform/monitoring/local/terraform.tfvars
```
Edit `terraform.tfvars` and set your Grafana admin password.

```bash
cd infrastructure/terraform/monitoring/local
terraform init
terraform apply
```

Terraform deploys kube-prometheus-stack into the `monitoring` namespace and waits for all components to be ready (this takes 2–3 minutes on first run).

**2. Deploy the application**
```bash
cp infrastructure/terraform/crewmeister-app/local/terraform.tfvars.example infrastructure/terraform/crewmeister-app/local/terraform.tfvars
```
Edit `terraform.tfvars` and set your MySQL password. To enable Prometheus scraping, set `service_monitor_enabled = true` in `infrastructure/terraform/crewmeister-app/local/main.tf` — requires the monitoring stack to be deployed first.

```bash
cd infrastructure/terraform/crewmeister-app/local
terraform init
terraform apply
```

**3. Verify pods are running**
```bash
kubectl get pods
kubectl get pods -n monitoring
```

Then test the API using the same port-forward steps in the [Kubernetes Deployment](#kubernetes-deployment) section.

**Destroying the deployments**
```bash
cd infrastructure/terraform/crewmeister-app/local && terraform destroy
cd infrastructure/terraform/monitoring/local && terraform destroy
```

---

## CI/CD Pipeline

The pipeline runs on GitHub Actions and is defined in `.github/workflows/ci.yml`. It triggers on every push to `main`.

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
│  (multi-stage — no JDK needed locally)  │
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

**`build-and-push`** — runs only if `test` passes. Builds the Docker image using the multi-stage Dockerfile (Maven build happens inside the container — no JDK required on the runner) and pushes to GHCR with two tags.

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

### Deployment

The pipeline stops at image push. Deploying to a cluster is a manual step:

```bash
# via Helm:
helm upgrade crewmeister ./kubernetes/helm/crewmeister -f ./kubernetes/helm/environments/local/values.yaml

# via Terraform — update app_tag in local/main.tf, then:
cd infrastructure/terraform/crewmeister-app/local && terraform apply
```

In a production setup the deploy step would be automated as a third job, gated on the `build-and-push` job and targeting a cloud cluster via kubeconfig stored as a GitHub Actions secret.

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

#### Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                             │
│                                                                       │
│  ┌─────────── default namespace ──────────────────────────────────┐  │
│  │                                                                 │  │
│  │   ┌──────────────────┐       ┌─────────────────────────────┐   │  │
│  │   │  Spring Boot app │       │       ServiceMonitor        │   │  │
│  │   │  :8080           │       │  tells Prometheus to scrape │   │  │
│  │   │  /actuator/      │       │  app:8080/actuator/         │   │  │
│  │   │  prometheus      │       │  prometheus every 15s       │   │  │
│  │   └──────────────────┘       └──────────────┬──────────────┘   │  │
│  └────────────────────────────────────────────┼─────────────────┘  │
│                                                │                    │
│  ┌─────────── monitoring namespace ────────────┼─────────────────┐  │
│  │                                             │                  │  │
│  │   ┌─────────────────────┐                   │                  │  │
│  │   │  Prometheus         │◄──────────────────┘                  │  │
│  │   │  (watches all       │                                      │  │
│  │   │   ServiceMonitors)  │                                      │  │
│  │   └──────────┬──────────┘                                      │  │
│  │              │ datasource                                       │  │
│  │              ▼                                                  │  │
│  │   ┌─────────────────────┐   ┌──────────────────────────────┐   │  │
│  │   │  Grafana            │   │  kube-state-metrics          │   │  │
│  │   │  pre-built          │   │  node-exporter               │   │  │
│  │   │  dashboards         │   │  alertmanager (disabled)     │   │  │
│  │   └─────────────────────┘   └──────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

The app Helm chart includes an optional `ServiceMonitor` resource — a Kubernetes CRD that tells the Prometheus operator which pods to scrape and how. It is disabled by default — enable it once the monitoring stack is deployed.

kube-prometheus-stack is deployed as a separate Terraform module (`infrastructure/terraform/monitoring/`) and includes: Prometheus operator, Prometheus, Grafana, kube-state-metrics, and node-exporter.

#### Accessing (after port-forward)

```bash
# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

| Service | URL | Credentials |
|---|---|---|
| Grafana | `http://localhost:3000` | admin / (password from `terraform.tfvars`) |
| Prometheus | `http://localhost:9090` | — |
| App metrics | `http://localhost:8080/actuator/prometheus` | — |

To verify Prometheus is scraping the app, open `http://localhost:9090/targets` — the `crewmeister-app` target should show `State: UP`.

To explore app metrics in Grafana, open **Explore**, select the Prometheus datasource, and query:

```
# HTTP request rate
rate(http_server_requests_seconds_count[1m])

# JVM heap usage
jvm_memory_used_bytes{area="heap"}

# Active DB connections
hikaricp_connections_active
```
