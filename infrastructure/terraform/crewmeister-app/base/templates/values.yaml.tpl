app:
  image: ${app_image}
  tag: ${app_tag}
  pullPolicy: ${app_pull_policy}

mysql:
  password: ${mysql_password}
  storage: ${mysql_storage}

autoscaling:
  enabled: ${autoscaling_enabled}
  minReplicas: ${autoscaling_min_replicas}
  maxReplicas: ${autoscaling_max_replicas}
  targetCPUUtilizationPercentage: ${autoscaling_target_cpu}

ingress:
  enabled: ${ingress_enabled}
  className: ${ingress_class_name}
  host: ${ingress_host}

externalSecrets:
  enabled: ${external_secrets_enabled}
  secretName: ${external_secrets_secret_name}

serviceMonitor:
  enabled: ${service_monitor_enabled}
