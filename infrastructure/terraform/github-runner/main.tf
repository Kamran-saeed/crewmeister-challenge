data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Runner security group ─────────────────────────────────────────────────────
resource "aws_security_group" "runner" {
  name        = "github-runner"
  description = "GitHub Actions self-hosted runner"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "runner_to_eks" {
  security_group_id            = data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
  referenced_security_group_id = aws_security_group.runner.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "GitHub Actions runner to EKS API server"
}

# ── EC2 instance profile (PAT secret read only) ───────────────────────────────
data "aws_iam_policy_document" "runner_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runner" {
  name               = "github-runner"
  assume_role_policy = data.aws_iam_policy_document.runner_assume.json
}

data "aws_iam_policy_document" "runner_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:eu-central-1:${data.aws_caller_identity.current.account_id}:secret:${var.github_pat_secret_name}-*"]
  }
}

resource "aws_iam_policy" "runner" {
  name   = "github-runner-policy"
  policy = data.aws_iam_policy_document.runner_permissions.json
}

resource "aws_iam_role_policy_attachment" "runner" {
  role       = aws_iam_role.runner.name
  policy_arn = aws_iam_policy.runner.arn
}

resource "aws_iam_role_policy_attachment" "runner_ssm" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "runner" {
  name = "github-runner"
  role = aws_iam_role.runner.name
}

# ── EC2 instance ──────────────────────────────────────────────────────────────
resource "aws_instance" "runner" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.runner.id]
  iam_instance_profile   = aws_iam_instance_profile.runner.name

  user_data = templatefile("${path.module}/templates/user-data.sh.tpl", {
    terraform_version      = "1.9.7"
    kubectl_version        = "1.33.0"
    helm_version           = "3.17.3"
    github_repo            = var.github_repo
    github_pat_secret_name = var.github_pat_secret_name
    runner_name            = var.runner_name
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "github-actions-runner"
  }
}
