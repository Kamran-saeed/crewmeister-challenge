app:
  image: ${app_image}
  tag: ${app_tag}
  pullPolicy: ${app_pull_policy}

mysql:
  password: ${mysql_password}
  storage: ${mysql_storage}

serviceMonitor:
  enabled: ${service_monitor_enabled}
