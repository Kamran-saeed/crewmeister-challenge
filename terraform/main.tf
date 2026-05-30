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

resource "helm_release" "crewmeister" {
  name      = var.release_name
  chart     = "${path.module}/../helm/crewmeister"
  namespace = var.namespace

  values = [
    file("${path.module}/../helm/environments/${var.environment}/values.yaml")
  ]

  set = [
    {
      name  = "mysql.password"
      value = var.mysql_password
    }
  ]

  timeout = 300

  wait          = true
  wait_for_jobs = true
}
