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
├── src/                              # Application source code
├── Dockerfile                        # Multi-stage build — JDK for building, JRE for running
├── docker-compose.yml                # Local development stack — app + MySQL
├── .env.example                      # Environment variable template
├── helm/
│   ├── crewmeister/                        # Helm chart — reusable, environment-agnostic
│   │   ├── Chart.yaml                      # Chart metadata
│   │   ├── values.yaml                     # Default values
│   │   └── templates/
│   │       ├── secret.yaml                 # MySQL password as Kubernetes Secret
│   │       ├── configmap.yaml              # Non-sensitive config — JDBC URL, username
│   │       ├── app-deployment.yaml         # Spring Boot deployment with init container
│   │       ├── app-service.yaml            # Exposes app inside the cluster
│   │       ├── mysql-deployment.yaml       # MySQL deployment with probes and PVC mount
│   │       ├── mysql-service.yaml          # Exposes MySQL inside the cluster
│   │       └── mysql-pvc.yaml              # Persistent storage for MySQL data
│   └── environments/                       # Environment-specific values
│       ├── local/
│       │   ├── values.yaml                 # Local overrides (not committed)
│       │   └── values.yaml.example         # Template for local setup
│       └── production/
│           └── values.yaml.example         # Template for production setup
├── terraform/                        # Terraform configuration (coming soon)
└── pom.xml                           # Maven dependencies and build configuration
```

---

## Prerequisites

### Local Development
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

Maven and Java do not need to be installed locally — the build happens inside Docker.

### Kubernetes Deployment
- `kubectl`
- `helm`
- `terraform`
- `minikube` — for local Kubernetes cluster

---

## Local Setup

### Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Docker Network                     │
│                                                      │
│   ┌──────────────────┐       ┌──────────────────┐   │
│   │   Spring Boot    │       │      MySQL        │   │
│   │   :8080          │──────►│      :3306        │   │
│   │                  │       │                   │   │
│   └──────────────────┘       └──────────────────┘   │
│            │                          │              │
└────────────┼──────────────────────────┼──────────────┘
             │                          │
             ▼                          ▼
      localhost:8080             localhost:3306
      (API requests)          (local DB debugging)
```

Both services run inside the same Docker network and communicate using service names as hostnames — the app connects to MySQL at `mysql:3306`, not `localhost:3306`. On startup, Flyway automatically runs the database migration, creating the `user` table and seeding an initial record.

**1. Clone the repository**
```bash
git clone <your-repo-url>
cd crewmeister-challenge
```

**2. Configure environment variables**

All variables are defined in `.env`. Never commit this file — it is listed in `.gitignore`. Use `.env.example` as the template.

| Variable | Description | Example |
|---|---|---|
| `MYSQL_ROOT_PASSWORD` | MySQL root password | `dev` |
| `MYSQL_DATABASE` | Database name | `challenge` |
| `MYSQL_USERNAME` | MySQL username | `root` |

```bash
cp .env.example .env
```
Edit `.env` with your preferred values.

**3. Start the stack**
```bash
docker compose up --build
```

The first run takes a few minutes — Maven downloads all dependencies inside the build container. Subsequent builds are faster due to layer caching.

Wait for this line before making requests:
```
app  | Started CrewmeisterChallengeApplication
```

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

| File | Used for | Committed |
|---|---|---|
| `helm/crewmeister/values.yaml` | Defaults — base configuration | Yes |
| `helm/environments/local/values.yaml` | Minikube — local image, `Never` pull policy, real password | No — in `.gitignore` |
| `helm/environments/local/values.yaml.example` | Template for local setup | Yes |
| `helm/environments/production/values.yaml.example` | Template for production setup | Yes |

### Local Kubernetes Deployment (minikube)

**1. Start minikube**
```bash
minikube start
```

**2. Configure local Helm values**
```bash
cp helm/environments/local/values.yaml.example helm/environments/local/values.yaml
```
Edit `helm/environments/local/values.yaml` and set your MySQL password. This file is in `.gitignore` and will never be committed.

**3. Build the app image and load it into minikube**

Since minikube runs its own isolated Docker environment, the locally built image must be explicitly loaded in:
```bash
docker compose build
minikube image load crewmeister-challenge-app:latest
```

**4. Deploy with Helm**
```bash
helm install crewmeister ./helm/crewmeister -f ./helm/environments/local/values.yaml
```

**5. Verify pods are running**
```bash
kubectl get pods
```

Both pods should reach `1/1 Running`. The app pod will show `Init:0/1` briefly while the init container waits for MySQL, then transition to `Running`.

Expected output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
crewmeister-app-xxx                   1/1     Running   0          60s
crewmeister-mysql-xxx                 1/1     Running   0          60s
```

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
```

**Upgrading the release**
```bash
helm upgrade crewmeister ./helm/crewmeister -f ./helm/environments/local/values.yaml
```

**Removing the release**
```bash
helm uninstall crewmeister
```

---

## CI/CD Pipeline

### Architecture

> Diagram coming soon — will cover the full pipeline flow from a GitHub push through to a running deployment on Kubernetes.

> Coming soon — GitHub Actions workflow.

---

## Monitoring

### Architecture

> Diagram coming soon — will cover Prometheus scraping the app metrics endpoint and Grafana dashboards.

> Coming soon — Prometheus and Grafana setup.
