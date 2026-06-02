variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "service_monitor_enabled" {
  description = "Enable ServiceMonitor for Prometheus scraping — requires kube-prometheus-stack deployed first"
  type        = bool
  default     = false
}

variable "eso_role_arn" {
  description = "IAM role ARN attached to the External Secrets Operator service account. Get it with: kubectl get sa external-secrets -n external-secrets -o jsonpath='{.metadata.annotations.eks\\.amazonaws\\.com/role-arn}'"
  type        = string
}
