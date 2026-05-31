resource "helm_release" "crewmeister" {
  name      = var.release_name
  chart     = "${path.module}/../../../../kubernetes/helm/crewmeister"
  namespace = var.namespace

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      app_image               = var.app_image
      app_tag                 = var.app_tag
      app_pull_policy         = var.app_pull_policy
      mysql_password          = var.mysql_password
      mysql_storage           = var.mysql_storage
      service_monitor_enabled = var.service_monitor_enabled
    })
  ]

  timeout       = var.timeout
  wait          = var.wait
  wait_for_jobs = var.wait
}
