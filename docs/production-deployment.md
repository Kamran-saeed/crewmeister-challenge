# Production Deployment — AWS EKS

Deploys the app and monitoring stack to EKS using Terraform.

---

## Architecture

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
                                     │         │   Spring Boot :8080         │◄─────────────────────┘        │
                                     │         │   ServiceAccount (no token) │  mysql-0.mysql-headless DNS   │
                                     │         │   liveness/readiness probes │                               │
                                     │         └──────────────┬──────────────┘                               │
                                     │                        │                                              │
                                     │         ┌──────────────▼──────────────┐                               │
                                     │         │   app-service  ClusterIP    │                               │
                                     │         └─────────────────────────────┘                               │
                                     └─────────────────────────────────────────────────────────────────────--┘
```

---

## Prerequisites

Before continuing, ensure you have completed **[docs/prerequisites.md](prerequisites.md)** — required tools, AWS credentials, S3 state bucket, and DynamoDB lock table must all be in place first.

The following are specific to the production EKS environment.

### 1. EKS cluster requirements

The following must be running on the target EKS cluster before deploying:

| Component | Why needed |
|-----------|-----------|
| **NGINX ingress controller** | Ingress resource routes external traffic to the app |
| **EBS CSI driver** | MySQL StatefulSet creates an EBS-backed PVC |
| **metrics-server** | HPA needs it to read CPU metrics |
| **External Secrets Operator** | Syncs the MySQL password from AWS Secrets Manager into a Kubernetes Secret |

**DNS and TLS (required for HTTPS access)**

| Resource | Details |
|----------|---------|
| **Route53 hosted zone** | A DNS record (or wildcard) pointing to the load balancer in front of the NGINX ingress controller. Set `ingress.host` in `terraform.tfvars` to a hostname in this zone. |
| **ACM certificate** | A TLS certificate covering the ingress hostname (or a wildcard like `*.your-domain.com`). Must be attached to the load balancer — TLS termination happens at the load balancer, not inside the cluster. |

If your cluster uses an NLB, attach the ACM certificate to the NLB listener on port 443. Traffic from the NLB to NGINX ingress travels over HTTP (port 80 internally) — no cert-manager or in-cluster TLS is currently implemented.

### 2. External Secrets Operator (ESO)

ESO must be installed and its service account must have an IRSA role with `secretsmanager:GetSecretValue` permissions.

Get the IRSA role ARN from the ESO service account — you will need it in step 8:
```bash
kubectl get sa external-secrets -n external-secrets \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

Terraform will attach a scoped IAM policy (allowing access to `crewmeister/credentials` only) to this role — no new role is created.

### 3. Create the secret in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name crewmeister/credentials \
  --region eu-central-1 \
  --secret-string '{"mysql-root-password": "your_strong_password"}'
```

The `mysql-root-password` key is what ESO reads and syncs into a Kubernetes Secret. The password never appears in Terraform state or Helm values.

### 4. Create `terraform.tfvars` files

```bash
cp infrastructure/terraform/monitoring/production/terraform.tfvars.example \
   infrastructure/terraform/monitoring/production/terraform.tfvars

cp infrastructure/terraform/crewmeister-app/production/terraform.tfvars.example \
   infrastructure/terraform/crewmeister-app/production/terraform.tfvars
```

Edit `crewmeister-app/production/terraform.tfvars` and set your EKS cluster name and the ESO role ARN from step 2:

```hcl
cluster_name = "your-eks-cluster-name"
eso_role_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/your-eso-role-name"
```

Edit `monitoring/production/terraform.tfvars` and set your Grafana admin password:

```hcl
grafana_admin_password = "your_grafana_password"
```

---

## Deploy

Monitoring must be deployed first — it installs the `ServiceMonitor` CRD.

Both modules connect to EKS directly via AWS APIs (`aws_eks_cluster` + `aws_eks_cluster_auth` data sources) — no kubeconfig needed.

```bash
cd infrastructure/terraform/monitoring/production
terraform init
terraform apply

cd infrastructure/terraform/crewmeister-app/production
terraform init
terraform apply
```

---

## Verify

```bash
kubectl get pods --context <your-cluster-context>
kubectl get pods -n monitoring --context <your-cluster-context>
```

App pods should reach `3/3 Running` (HPA minimum). The app pod will show `Init:0/1` briefly while the init container waits for MySQL.

### Test the API

```bash
curl https://<your-app-host>/actuator/health
# {"status":"UP"}

curl "https://<your-app-host>/user?id=1"
# Greetings from Crewmeister, Alice!

curl -X POST https://<your-app-host>/user \
  -H "Content-Type: application/json" \
  -d '{"name": "Muhammad"}'
# Greetings from Crewmeister, Muhammad!

curl https://<your-app-host>/actuator/prometheus
```

---

## Access Monitoring

Monitoring services are not exposed via Ingress — access them via port-forward:

```bash
# Grafana
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80 --context <your-cluster-context>

# Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 --context <your-cluster-context>
```

| Service | URL | Credentials |
|---|---|---|
| Grafana | `http://localhost:3000` | admin / (password from `GRAFANA_ADMIN_PASSWORD` secret) |
| Prometheus | `http://localhost:9090` | — |

---

## Destroy

```bash
cd infrastructure/terraform/crewmeister-app/production && terraform destroy
cd infrastructure/terraform/monitoring/production && terraform destroy
```
