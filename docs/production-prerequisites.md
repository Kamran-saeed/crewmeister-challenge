# Production Deployment Prerequisites

Complete these steps once before running `terraform apply` for the production environment.

---

## 1. AWS credentials

Ensure AWS credentials are configured with permissions for: `eks:DescribeCluster`, `s3:*` on the state bucket, `dynamodb:GetItem/PutItem/DeleteItem` on the lock table, `iam:CreatePolicy/AttachRolePolicy` for the ESO policy attachment, and `secretsmanager:CreateSecret`.

```bash
aws configure   # or export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
```

---

## 2. S3 bucket for Terraform state

```bash
aws s3api create-bucket \
  --bucket <your-state-bucket> \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-public-access-block \
  --bucket <your-state-bucket> \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

---

## 3. DynamoDB table for state locking

```bash
aws dynamodb create-table \
  --table-name <your-lock-table> \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

---

## 4. Update backend configuration

Set the real bucket and table names in both `backend.tf` files:
- `infrastructure/terraform/crewmeister-app/production/backend.tf`
- `infrastructure/terraform/monitoring/production/backend.tf`

---

## 5. EKS cluster requirements

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

---

## 6. External Secrets Operator (ESO)

ESO must be installed and its service account must have an IRSA role with `secretsmanager:GetSecretValue` permissions.

Get the IRSA role ARN from the ESO service account — you will need it in step 8:
```bash
kubectl get sa external-secrets -n external-secrets \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
```

Terraform will attach a scoped IAM policy (allowing access to `crewmeister/credentials` only) to this role — no new role is created.

---

## 7. Create the secret in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name crewmeister/credentials \
  --region eu-central-1 \
  --secret-string '{"mysql-root-password": "your_strong_password"}'
```

The `mysql-root-password` key is what ESO reads and syncs into a Kubernetes Secret. The password never appears in Terraform state or Helm values.

---

## 8. Create `terraform.tfvars` files

```bash
cp infrastructure/terraform/monitoring/production/terraform.tfvars.example \
   infrastructure/terraform/monitoring/production/terraform.tfvars

cp infrastructure/terraform/crewmeister-app/production/terraform.tfvars.example \
   infrastructure/terraform/crewmeister-app/production/terraform.tfvars
```

Edit `crewmeister-app/production/terraform.tfvars` and set your EKS cluster name and the ESO role ARN from step 6:

```hcl
cluster_name = "your-eks-cluster-name"
eso_role_arn = "arn:aws:iam::YOUR_ACCOUNT_ID:role/your-eso-role-name"
```

Edit `monitoring/production/terraform.tfvars` and set your Grafana admin password:

```hcl
grafana_admin_password = "your_grafana_password"
```
