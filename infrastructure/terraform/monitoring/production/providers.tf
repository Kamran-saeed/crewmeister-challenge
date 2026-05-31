provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "your-prod-cluster-context"
}

provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "your-prod-cluster-context"
  }
}
