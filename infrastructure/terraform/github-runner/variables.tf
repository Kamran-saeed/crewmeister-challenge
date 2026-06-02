variable "vpc_id" {
  description = "VPC ID where the runner will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID to deploy the runner into"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name — used to look up the cluster security group"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the runner"
  type        = string
  default     = "t3.small"
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format — OIDC trust and runner registration are scoped to this repo"
  type        = string
}

variable "github_pat_secret_name" {
  description = "AWS Secrets Manager secret name containing the GitHub PAT (key: github-pat)"
  type        = string
  default     = "crewmeister/credentials"
}

variable "runner_name" {
  description = "Display name for the runner in GitHub Actions"
  type        = string
  default     = "crewmeister-eks-runner"
}

variable "oidc_role_name" {
  description = "Name of the IAM role assumed per job via GitHub Actions OIDC"
  type        = string
  default     = "crewmeister-github-actions"
}

variable "state_bucket" {
  description = "S3 bucket name used for Terraform state — granted to the OIDC role"
  type        = string
}

variable "lock_table" {
  description = "DynamoDB table name used for Terraform state locking — granted to the OIDC role"
  type        = string
}
