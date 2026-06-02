module "app" {
  source = "../base"

  release_name            = "crewmeister"
  namespace               = "default"
  app_image               = "ghcr.io/kamran-saeed/crewmeister-challenge"
  app_tag                 = "latest"
  app_pull_policy         = "Always"
  mysql_storage           = "10Gi"
  service_monitor_enabled = var.service_monitor_enabled
  autoscaling = {
    enabled      = true
    min_replicas = 3
    max_replicas = 10
    target_cpu   = 50
  }

  ingress = {
    enabled    = true
    class_name = "nginx"
    host       = "crewmeister.devex.d3cloud.de"
  }

  external_secrets = {
    enabled      = true
    eso_role_arn = var.eso_role_arn
    secret_name  = "crewmeister/credentials"
  }

  mysql_password = ""

  wait    = false
  timeout = 300
}
