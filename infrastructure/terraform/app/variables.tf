variable "kubeconfig_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Kubeconfig context to use for deployment"
  type        = string
  default     = "minikube"
}

variable "release_name" {
  description = "Helm release name"
  type        = string
  default     = "crewmeister"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "default"
}

variable "app_image" {
  description = "Docker image name for the application"
  type        = string
  default     = "crewmeister-challenge-app"
}

variable "app_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "app_pull_policy" {
  description = "Image pull policy — Never for local minikube, Always for remote registry"
  type        = string
  default     = "Never"
}

variable "mysql_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

variable "mysql_storage" {
  description = "Storage size for MySQL PersistentVolumeClaim"
  type        = string
  default     = "1Gi"
}

variable "service_monitor_enabled" {
  description = "Enable ServiceMonitor for Prometheus scraping — requires kube-prometheus-stack to be deployed first"
  type        = bool
  default     = false
}
