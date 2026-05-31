variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

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

variable "environment" {
  description = "Deployment environment — determines which values file to use"
  type        = string
  default     = "local"
}

variable "namespace" {
  description = "Kubernetes namespace to deploy monitoring into"
  type        = string
  default     = "monitoring"
}
