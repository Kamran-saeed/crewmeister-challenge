# Prerequisites

Complete this guide once before any Terraform deployment — local or production.

---

## Required Tools

| Tool | Version | Notes |
|------|---------|-------|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | any | Required for local Docker Compose and building the app image |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | any | Required for Kubernetes deployments |
| [helm](https://helm.sh/docs/intro/install/) | any | Required for raw Helm deployments |
| [terraform](https://developer.hashicorp.com/terraform/install) | >= 1.9.0 | Versions below 1.9.0 have an expired GPG key issue with provider installation |
| [minikube](https://minikube.sigs.k8s.io/docs/start/) | any | Required for local Kubernetes deployments only |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | any | Required for AWS resource setup |

---

## Required AWS Resources

These resources must exist before running `terraform init` in any environment.

### 1. AWS credentials

Ensure AWS credentials are configured with permissions for: `eks`, `s3`, `dynamodb`, `iam`, and `secretsmanager`.

```bash
aws configure
# or export AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
```

### 2. S3 bucket for Terraform state

```bash
aws s3api create-bucket \
  --bucket <your-state-bucket> \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-public-access-block \
  --bucket <your-state-bucket> \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 3. DynamoDB table for state locking

```bash
aws dynamodb create-table \
  --table-name <your-lock-table> \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

### 4. Update backend configuration

Set the real bucket and table names in all `backend.tf` files before running `terraform init`:

- `infrastructure/terraform/crewmeister-app/local/backend.tf`
- `infrastructure/terraform/crewmeister-app/production/backend.tf`
- `infrastructure/terraform/monitoring/local/backend.tf`
- `infrastructure/terraform/monitoring/production/backend.tf`
