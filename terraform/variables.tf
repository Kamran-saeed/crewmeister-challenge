variable "mysql_password" {
  description = "MySQL root password"
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
