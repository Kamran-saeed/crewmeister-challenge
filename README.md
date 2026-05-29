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
├── src/                        # Application source code
├── Dockerfile                  # Multi-stage build — JDK for building, JRE for running
├── docker-compose.yml          # Local development stack — app + MySQL
├── .env.example                # Environment variable template
├── helm/                       # Helm chart for Kubernetes deployment (coming soon)
├── terraform/                  # Terraform configuration (coming soon)
└── pom.xml                     # Maven dependencies and build configuration
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

> Diagram coming soon — will cover pods, services, ingress, secrets and how Helm and Terraform fit together.

> Coming soon — Helm chart and Terraform configuration.

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
