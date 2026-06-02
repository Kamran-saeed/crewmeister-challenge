output "runner_instance_id" {
  description = "EC2 instance ID of the GitHub Actions runner"
  value       = aws_instance.runner.id
}

output "runner_private_ip" {
  description = "Private IP of the runner instance"
  value       = aws_instance.runner.private_ip
}

output "oidc_role_arn" {
  description = "IAM role ARN to set as AWS_ROLE_ARN in GitHub Secrets"
  value       = aws_iam_role.oidc.arn
}
