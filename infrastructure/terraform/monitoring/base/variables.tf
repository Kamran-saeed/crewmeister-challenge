variable "namespace" {
  description = "Kubernetes namespace to deploy monitoring into"
  type        = string
}

variable "chart_version" {
  description = "kube-prometheus-stack Helm chart version"
  type        = string
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "alertmanager_enabled" {
  description = "Enable Alertmanager deployment"
  type        = bool
}

variable "service_monitor_selector_nil_uses_helm_values" {
  description = "When false, Prometheus scrapes all ServiceMonitors in the cluster regardless of labels"
  type        = bool
}

variable "wait" {
  description = "Wait for all pods to be ready before marking the release as successful"
  type        = bool
}

variable "timeout" {
  description = "Timeout in seconds for Helm operations"
  type        = number
}
