variable "release_name" {
  description = "Helm release name"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
}

variable "app_image" {
  description = "Docker image name for the application"
  type        = string
}

variable "app_tag" {
  description = "Docker image tag"
  type        = string
}

variable "app_pull_policy" {
  description = "Image pull policy — Never for local minikube, Always for remote registry"
  type        = string
}

variable "mysql_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "mysql_storage" {
  description = "Storage size for MySQL PersistentVolumeClaim"
  type        = string
}

variable "service_monitor_enabled" {
  description = "Enable ServiceMonitor for Prometheus scraping — requires kube-prometheus-stack deployed first"
  type        = bool
}
