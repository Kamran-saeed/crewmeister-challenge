prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: ${service_monitor_selector_nil_uses_helm_values}

alertmanager:
  enabled: ${alertmanager_enabled}

grafana:
  adminPassword: ${grafana_admin_password}
