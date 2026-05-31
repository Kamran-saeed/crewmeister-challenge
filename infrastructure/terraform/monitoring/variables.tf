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

variable "namespace" {
  description = "Kubernetes namespace to deploy monitoring into"
  type        = string
  default     = "monitoring"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "alertmanager_enabled" {
  description = "Enable Alertmanager deployment"
  type        = bool
  default     = false
}

variable "service_monitor_selector_nil_uses_helm_values" {
  description = "When false, Prometheus scrapes all ServiceMonitors in the cluster regardless of labels"
  type        = bool
  default     = false
}
