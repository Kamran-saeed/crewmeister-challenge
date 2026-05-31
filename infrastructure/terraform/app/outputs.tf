output "release_name" {
  description = "Helm release name"
  value       = helm_release.crewmeister.name
}

output "namespace" {
  description = "Kubernetes namespace the app is deployed into"
  value       = helm_release.crewmeister.namespace
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.crewmeister.status
}
