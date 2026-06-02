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

The Helm chart supports two deployment environments — local (minikube) and production (EKS). Both share the same chart. Environment-specific behaviour is controlled entirely through values.

The app pod includes an init container that blocks Spring Boot from starting until MySQL is confirmed reachable — eliminating crash-restart loops on startup.

The app runs under a dedicated `ServiceAccount` with `automountServiceAccountToken: false` — no Kubernetes API token is mounted into the container, following the principle of least privilege.

The app container declares CPU and memory requests and limits, giving it `Burstable` QoS class. This ensures the scheduler places pods correctly, prevents noisy-neighbour resource contention, and enables HPA to calculate CPU utilisation accurately.

MySQL runs as a `StatefulSet` rather than a Deployment. StatefulSet gives each pod a stable identity (`mysql-0`) and a stable DNS name via a headless service (`mysql-0.mysql-headless`). Each pod gets its own `PersistentVolumeClaim` via `volumeClaimTemplates` — the PVC is bound to the pod's identity and follows it across restarts, even in multi-AZ clusters where EBS volumes are zone-specific.

### Values and Overrides

All configurable values live in `values.yaml`. Environment-specific overrides go in separate files — only the values that differ from defaults need to be specified.

| File | Purpose |
|---|---|
| `kubernetes/helm/crewmeister/values.yaml` | Defaults — base configuration, all features disabled |
| `kubernetes/helm/environments/local/values.yaml` | Minikube overrides — gitignored, created from `.example` |
| `kubernetes/helm/environments/local/values.yaml.example` | Template for local setup |
| `kubernetes/helm/environments/production/values.yaml.example` | Template for production setup |

The table below shows which features are enabled per deployment method:

| Feature | Raw Helm (minikube) | Terraform local (minikube) | Terraform prod (EKS) |
|---|:---:|:---:|:---:|
| K8s Secret (password from values) | ✓ | ✓ | ✗ |
| External Secrets (ESO + AWS) | ✗ | ✗ | ✓ |
| HPA (autoscaling) | ✗ | ✗ | ✓ |
| Ingress (NGINX) | ✗ | ✗ | ✓ |
| ServiceMonitor (Prometheus) | optional | optional | ✓ |
| Fixed replica count | ✓ (1) | ✓ (1) | ✗ (HPA owns it) |

### Local Kubernetes Deployment (minikube)

#### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Minikube Cluster                           │
│                                                                   │
│  ┌──────────────────┐   ┌──────────────────────────────────────┐  │
│  │    ConfigMap     │   │           K8s Secret                 │  │
│  │  JDBC URL        │   │  mysql-password (from tfvars)        │  │
│  │  DB name         │   └─────────────────┬────────────────────┘  │
│  │  username        │                     │                       │
│  └────────┬─────────┘                     │                       │
│           │                               │                       │
│  ┌────────▼───────────────────────────────▼──────────────────┐   │
│  │                    app-deployment  (replicas: 1)           │   │
│  │   serviceAccount: crewmeister-app (no API token)          │   │
│  │   ┌────────────────────────────────────────────────────┐  │   │
│  │   │  init container — waits for MySQL ready            │  │   │
│  │   └────────────────────────────────────────────────────┘  │   │
│  │   ┌────────────────────────────────────────────────────┐  │   │
│  │   │  Spring Boot :8080                                 │  │   │
│  │   │  resources: 100m/256Mi req  limits: 500m/512Mi     │  │   │
│  │   │  liveness  → /actuator/health/liveness             │  │   │
│  │   │  readiness → /actuator/health/readiness            │  │   │
│  │   └────────────────────────────────────────────────────┘  │   │
│  └────────────────────────┬──────────────────────────────────┘   │
│                           │                                       │
│  ┌────────────────────────▼──────────┐  ┌──────────────────────┐ │
│  │   app-service (ClusterIP :8080)   │  │  mysql-statefulset   │ │
│  └────────────────────────┬──────────┘  │  MySQL :3306         │ │
│                           │             │  volumeClaimTemplates│ │
│                           │             │  └── mysql-storage   │ │
│                           │             └──────────┬───────────┘ │
│                           │                        │             │
│                           │             ┌──────────▼───────────┐ │
│                           │             │  mysql-headless-svc  │ │
│                           │             │  clusterIP: None     │ │
│                           │             └──────────────────────┘ │
└───────────────────────────┼───────────────────────────────────────┘
                            │ kubectl port-forward :8080
                            ▼
                      localhost:8080
```

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

For local deployment, HPA, Ingress, and ESO are all disabled. The app runs with a fixed replica count of 1 and the MySQL password is passed directly via values. Optionally enable `serviceMonitor.enabled: true` if you deployed the monitoring stack.

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

Terraform manages Helm releases as infrastructure as code using the Helm and Kubernetes providers. Each component (`crewmeister-app`, `monitoring`) follows a `base` / environment pattern — `base/` contains all resource definitions, `local/` and `production/` are environment root modules that call `base/`, configure their own provider, and define their own backend. Each component has its own state file, so you can deploy, update, or destroy monitoring without touching the application.

`local/` connects to minikube via kubeconfig. `production/` connects to EKS directly via AWS APIs — it uses `aws_eks_cluster` and `aws_eks_cluster_auth` data sources to fetch the cluster endpoint and auth token, so no kubeconfig file is needed on the machine running Terraform.

The Helm chart is referenced by local path since it lives in the same repository. In a production setup the chart would be published to a registry and versioned independently.

### Local Deployment (minikube)

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
Edit `terraform.tfvars` and set your MySQL password. To enable Prometheus scraping, set `service_monitor_enabled = true` in `terraform.tfvars` — requires the monitoring stack to be deployed first.

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

### Cloud Deployment (AWS EKS)

#### Architecture

```
                                     ┌───────────────────────────────────────────────────────────────────────┐
                                     │  EKS Cluster                                                          │
                                     │                                                                       │
  Browser                            │  ┌──────────────┐   ┌─────────────────────────────┐   ┌─────────────┐ │
     │ HTTPS                         │  │   ConfigMap  │   │  ESO ExternalSecret         │   │   MySQL     │ │
     ▼                               │  │  JDBC URL    │   │  SecretStore → AWS Secrets  │   │ StatefulSet │ │
  Route53                            │  │  DB name     │   │  Manager → K8s Secret       │   │  mysql-0    │ │
  *.domain.com                       │  │  username    │   │  (syncs every 1h)           │   │  10Gi EBS   │ │
     │                               │  └──────┬───────┘   └──────────────┬──────────────┘   │  headless   │ │
     ▼                               │         │                          │                  │  DNS        │ │
  NLB + ACM cert                     │         └──────────────┬───────────┘                  └──────┬──────┘ │
     │ HTTP                          │                        ▼                                     │        │
     ▼                               │         ┌─────────────────────────────┐                      │        │
  NGINX Ingress ──────────────────►  │         │  HPA  min:3 max:10 cpu:50%  │                      │        │
  (routes by Host header)            │         └──────────────┬──────────────┘                      │        │
                                     │                        │ scales                              │        │
                                     │         ┌──────────────▼──────────────┐                      │        │
                                     │         │   app-deployment (3 pods)   │                      │        │
                                     │         │   Spring Boot :8080         │◄────────────────────-┘        │
                                     │         │   ServiceAccount (no token) │  mysql-0.mysql-headless DNS   │
                                     │         │   liveness/readiness probes │                               │ 
                                     │         └──────────────┬──────────────┘                               │
                                     │                        │                                              │
                                     │         ┌──────────────▼──────────────┐                               │
                                     │         │   app-service  ClusterIP    │                               │
                                     │         └─────────────────────────────┘                               │
                                     └─────────────────────────────────────────────────────────────────────--┘
```

#### Prerequisites

See **[docs/production-prerequisites.md](docs/production-prerequisites.md)** for the full setup guide covering: AWS credentials, S3/DynamoDB backend, EKS cluster requirements (NGINX ingress, EBS CSI, metrics-server, ESO), Route53 DNS and ACM certificate for HTTPS, Secrets Manager secret creation, and `terraform.tfvars` setup.

#### Deploy

Monitoring must be deployed first — it installs the `ServiceMonitor` CRD. Terraform then attaches a scoped IAM policy to ESO's existing role, allowing it to read from `crewmeister/credentials` in Secrets Manager. ESO creates the Kubernetes Secret automatically before the app pods start.

```bash
cd infrastructure/terraform/monitoring/production
terraform init
terraform apply

cd infrastructure/terraform/crewmeister-app/production
terraform init
terraform apply
```

Both modules connect to EKS directly via AWS APIs — no kubeconfig needed.

**Verify**
```bash
kubectl get pods --context <your-cluster-context>
kubectl get pods -n monitoring --context <your-cluster-context>
```

**Access the application**

The app is reachable via the Ingress host you configured in `terraform.tfvars`:
```bash
curl https://<your-app-host>/actuator/health
curl "https://<your-app-host>/user?id=1"
```

Monitoring services are not exposed via Ingress — access them via port-forward:
```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 --context <your-cluster-context>
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 --context <your-cluster-context>
```

**Destroying the deployments**
```bash
cd infrastructure/terraform/crewmeister-app/production && terraform destroy
cd infrastructure/terraform/monitoring/production && terraform destroy
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
