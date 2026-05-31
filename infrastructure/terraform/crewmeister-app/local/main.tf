module "app" {
  source = "../base"

  release_name            = "crewmeister"
  namespace               = "default"
  app_image               = "crewmeister-challenge-app"
  app_tag                 = "latest"
  app_pull_policy         = "Never"
  mysql_storage           = "1Gi"
  service_monitor_enabled = var.service_monitor_enabled

  mysql_password = var.mysql_password

  wait    = true
  timeout = 300
}
