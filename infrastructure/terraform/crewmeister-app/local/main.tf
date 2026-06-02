module "app" {
  source = "../base"

  release_name            = "crewmeister"
  namespace               = "default"
  app_image               = "crewmeister-challenge-app"
  app_tag                 = "latest"
  app_pull_policy         = "Never"
  mysql_storage           = "1Gi"
  service_monitor_enabled = var.service_monitor_enabled
  ingress = {
    enabled    = false
    class_name = "nginx"
    host       = ""
  }

  autoscaling = {
    enabled      = false
    min_replicas = 1
    max_replicas = 3
    target_cpu   = 50
  }

  external_secrets = {
    enabled      = false
    eso_role_arn = ""
    secret_name  = ""
  }

  mysql_password = var.mysql_password

  wait    = true
  timeout = 300
}
