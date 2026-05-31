terraform {
  required_version = ">= 1.9.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.1"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes = {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "86.1.0"
  namespace        = var.namespace
  create_namespace = true

  values = [
    file("${path.module}/../../helm/environments/${var.environment}/monitoring-values.yaml")
  ]

  set = [
    {
      name  = "grafana.adminPassword"
      value = var.grafana_admin_password
    }
  ]

  timeout = 600

  wait          = true
  wait_for_jobs = true
}
