resource "helm_release" "monitoring" {
  name             = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [
    templatefile("${path.module}/templates/values.yaml.tpl", {
      grafana_admin_password                        = var.grafana_admin_password
      alertmanager_enabled                          = var.alertmanager_enabled
      service_monitor_selector_nil_uses_helm_values = var.service_monitor_selector_nil_uses_helm_values
    })
  ]

  timeout       = 600
  wait          = true
  wait_for_jobs = true
}
