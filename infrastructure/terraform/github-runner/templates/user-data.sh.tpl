#!/bin/bash
set -euo pipefail

# ── Wait for network ─────────────────────────────────────────────────────────
# NAT gateway may not be ready immediately at boot
until curl -sf https://www.google.com > /dev/null 2>&1; do
  echo "Waiting for network..."
  sleep 5
done

# ── System setup ─────────────────────────────────────────────────────────────
apt-get update -y
apt-get install -y curl unzip jq git

# ── AWS CLI v2 ────────────────────────────────────────────────────────────────
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

# ── Terraform ${terraform_version} ───────────────────────────────────────────
curl -fsSL "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip" -o /tmp/terraform.zip
unzip -qo /tmp/terraform.zip -d /tmp/terraform-bin
mv /tmp/terraform-bin/terraform /usr/local/bin/terraform

# ── kubectl v${kubectl_version} ──────────────────────────────────────────────
curl -fsSL "https://dl.k8s.io/release/v${kubectl_version}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

# ── Helm v${helm_version} ────────────────────────────────────────────────────
curl -fsSL "https://get.helm.sh/helm-v${helm_version}-linux-amd64.tar.gz" | tar -xz -C /tmp
mv /tmp/linux-amd64/helm /usr/local/bin/helm

# ── GitHub Actions runner user ────────────────────────────────────────────────
useradd -m -s /bin/bash runner
mkdir -p /home/runner/actions-runner
cd /home/runner/actions-runner

# ── Download and extract runner ───────────────────────────────────────────────
RUNNER_VERSION=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/v//')
curl -fsSL "https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz" | tar -xz

# chown after extract so all files are owned by runner
chown -R runner:runner /home/runner/actions-runner

# ── Fetch GitHub PAT from Secrets Manager ────────────────────────────────────
GITHUB_PAT=$(aws secretsmanager get-secret-value \
  --secret-id "${github_pat_secret_name}" \
  --region eu-central-1 \
  --query 'SecretString' \
  --output text | jq -r '."github-pat"')

# ── Get runner registration token ────────────────────────────────────────────
REG_TOKEN=$(curl -fsSL \
  -X POST \
  -H "Authorization: Bearer $${GITHUB_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${github_repo}/actions/runners/registration-token" \
  | jq -r '.token')

# ── Configure runner (-H sets HOME correctly for the runner user) ─────────────
sudo -Hu runner ./config.sh \
  --url "https://github.com/${github_repo}" \
  --token "$${REG_TOKEN}" \
  --name "${runner_name}" \
  --labels "self-hosted,linux,eks" \
  --unattended \
  --replace

# ── Install and start as systemd service ─────────────────────────────────────
./svc.sh install runner
./svc.sh start
