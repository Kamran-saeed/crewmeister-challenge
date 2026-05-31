variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "mysql_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "service_monitor_enabled" {
  description = "Enable ServiceMonitor for Prometheus scraping — requires kube-prometheus-stack deployed first"
  type        = bool
  default     = false
}
