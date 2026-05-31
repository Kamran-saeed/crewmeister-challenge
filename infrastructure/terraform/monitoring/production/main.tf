module "monitoring" {
  source = "../base"

  namespace                                     = "monitoring"
  chart_version                                 = "86.1.0"
  alertmanager_enabled                          = true
  service_monitor_selector_nil_uses_helm_values = false

  grafana_admin_password = var.grafana_admin_password
}
