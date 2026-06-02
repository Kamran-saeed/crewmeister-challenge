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

variable "autoscaling" {
  description = "HPA configuration for the app"
  type = object({
    enabled      = bool
    min_replicas = number
    max_replicas = number
    target_cpu   = number
  })
}

variable "ingress" {
  description = "Ingress configuration for the app"
  type = object({
    enabled    = bool
    class_name = string
    host       = string
  })
}

variable "external_secrets" {
  description = "External Secrets Operator configuration — pulls credentials from AWS Secrets Manager"
  type = object({
    enabled      = bool
    eso_role_arn = string # IAM role ARN attached to the ESO service account — get it with: kubectl get sa external-secrets -n external-secrets -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
    secret_name  = string
  })
}

variable "wait" {
  description = "Wait for all pods to be ready before marking the release as successful"
  type        = bool
}

variable "timeout" {
  description = "Timeout in seconds for Helm operations"
  type        = number
}
