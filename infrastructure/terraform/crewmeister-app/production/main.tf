module "app" {
  source = "../base"

  release_name            = "crewmeister"
  namespace               = "default"
  app_image               = "ghcr.io/kamran-saeed/crewmeister-challenge"
  app_tag                 = "latest"
  app_pull_policy         = "Always"
  mysql_storage           = "10Gi"
  service_monitor_enabled = false

  mysql_password = var.mysql_password
}
