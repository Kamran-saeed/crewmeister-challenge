# Local Kubernetes Deployment

Deploys the app and monitoring stack to a local minikube cluster. Two methods are covered: raw Helm commands and Terraform.

## Helm Chart Design

Key decisions that apply across both local and production:

- **Init container** — blocks Spring Boot from starting until MySQL is reachable, eliminating crash-restart loops
- **ServiceAccount** with `automountServiceAccountToken: false` — no Kubernetes API token mounted into the container
- **MySQL as StatefulSet** — stable pod identity (`mysql-0`), stable headless DNS (`mysql-0.mysql-headless`), PVC bound per pod via `volumeClaimTemplates`
- **Resource requests and limits** on the app container — enables HPA to calculate CPU utilisation accurately

Environment-specific features are controlled entirely through values — both environments use the same chart:

| Feature | Local (minikube) | Production (EKS) |
|---|:---:|:---:|
| K8s Secret (password from values) | ✓ | ✗ |
| External Secrets (ESO + AWS) | ✗ | ✓ |
| HPA (autoscaling) | ✗ | ✓ |
| Ingress (NGINX) | ✗ | ✓ |
| ServiceMonitor (Prometheus) | optional | ✓ |
| Fixed replica count | ✓ (1) | ✗ (HPA owns it) |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Minikube Cluster                           │
│                                                                   │
│  ┌──────────────────┐   ┌──────────────────────────────────────┐  │
│  │    ConfigMap     │   │           K8s Secret                 │  │
│  │  JDBC URL        │   │  mysql-password (from values)        │  │
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

---

## Prerequisites

- `kubectl`
- `helm`
- `terraform >= 1.9.0`
- `minikube`

---

## Method 1 — Raw Helm

### Start minikube

```bash
minikube start
```

### Build and load the app image

Since minikube runs its own isolated Docker environment, the locally built image must be explicitly loaded in:

```bash
docker compose build
minikube image load crewmeister-challenge-app:latest
```

### Deploy the monitoring stack

The monitoring stack must be deployed first — it installs the `ServiceMonitor` CRD that the app chart depends on.

```bash
cp kubernetes/helm/environments/local/monitoring-values.yaml.example \
   kubernetes/helm/environments/local/monitoring-values.yaml
```

Edit `monitoring-values.yaml` and set your Grafana admin password. This file is in `.gitignore` and will never be committed.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --version 86.1.0 \
  -f ./kubernetes/helm/environments/local/monitoring-values.yaml \
  --namespace monitoring --create-namespace
```

Wait for all monitoring pods to be ready (2–3 minutes on first run):
```bash
kubectl get pods -n monitoring
```

### Deploy the app

```bash
cp kubernetes/helm/environments/local/values.yaml.example \
   kubernetes/helm/environments/local/values.yaml
```

Edit `values.yaml` and set your MySQL password. HPA, Ingress, and ESO are all disabled for local. Optionally set `serviceMonitor.enabled: true` if you deployed the monitoring stack.

```bash
helm install crewmeister ./kubernetes/helm/crewmeister \
  -f ./kubernetes/helm/environments/local/values.yaml
```

### Upgrade

```bash
helm upgrade crewmeister ./kubernetes/helm/crewmeister \
  -f ./kubernetes/helm/environments/local/values.yaml
```

### Verify

```bash
kubectl get pods
kubectl get pods -n monitoring
```

App pods should reach `1/1 Running`. The app pod will show `Init:0/1` briefly while the init container waits for MySQL, then transition to `Running`.

### Test the API

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

### Access Monitoring

```bash
# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Open `http://localhost:3000` and log in with your Grafana admin credentials. To verify Prometheus is scraping the app, open `http://localhost:9090/targets` — the `crewmeister-app` target should show `State: UP`.

### Remove

```bash
helm uninstall crewmeister
helm uninstall monitoring -n monitoring
kubectl delete namespace monitoring
```

---

## Method 2 — Terraform

Terraform manages the same Helm releases as infrastructure as code. The module structure mirrors the Helm method — monitoring first, then app.

### Start minikube

```bash
minikube start
```

### Deploy the monitoring stack

```bash
cp infrastructure/terraform/monitoring/local/terraform.tfvars.example \
   infrastructure/terraform/monitoring/local/terraform.tfvars
```

Edit `terraform.tfvars` and set your Grafana admin password.

```bash
cd infrastructure/terraform/monitoring/local
terraform init
terraform apply
```

### Deploy the app

```bash
cp infrastructure/terraform/crewmeister-app/local/terraform.tfvars.example \
   infrastructure/terraform/crewmeister-app/local/terraform.tfvars
```

Edit `terraform.tfvars` and set your MySQL password. To enable Prometheus scraping, set `service_monitor_enabled = true` — requires the monitoring stack to be deployed first.

```bash
cd infrastructure/terraform/crewmeister-app/local
terraform init
terraform apply
```

### Upgrade

Re-running apply picks up any changes in the chart or values:

```bash
cd infrastructure/terraform/crewmeister-app/local && terraform apply
```

### Verify

```bash
kubectl get pods
kubectl get pods -n monitoring
```

App pods should reach `1/1 Running`. The app pod will show `Init:0/1` briefly while the init container waits for MySQL, then transition to `Running`.

### Test the API

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

### Access Monitoring

```bash
# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Open `http://localhost:3000` and log in with your Grafana admin credentials. To verify Prometheus is scraping the app, open `http://localhost:9090/targets` — the `crewmeister-app` target should show `State: UP`.

### Destroy

```bash
cd infrastructure/terraform/crewmeister-app/local && terraform destroy
cd infrastructure/terraform/monitoring/local && terraform destroy
```
