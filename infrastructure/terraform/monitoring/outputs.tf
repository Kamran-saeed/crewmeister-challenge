output "release_name" {
  description = "Helm release name"
  value       = helm_release.monitoring.name
}

output "namespace" {
  description = "Kubernetes namespace the monitoring stack is deployed into"
  value       = helm_release.monitoring.namespace
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.monitoring.status
}
