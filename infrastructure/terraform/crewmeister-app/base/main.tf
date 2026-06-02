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
      service_monitor_enabled       = var.service_monitor_enabled
      autoscaling_enabled           = var.autoscaling.enabled
      autoscaling_min_replicas      = var.autoscaling.min_replicas
      autoscaling_max_replicas      = var.autoscaling.max_replicas
      autoscaling_target_cpu        = var.autoscaling.target_cpu
      ingress_enabled    = var.ingress.enabled
      ingress_class_name = var.ingress.class_name
      ingress_host       = var.ingress.host
      external_secrets_enabled     = var.external_secrets.enabled
      external_secrets_secret_name = var.external_secrets.secret_name
    })
  ]

  timeout       = var.timeout
  wait          = var.wait
  wait_for_jobs = var.wait
}
