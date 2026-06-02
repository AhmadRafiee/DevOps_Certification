storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

seal "transit" {
  address         = "http://172.19.0.2:8200"
  token           = "your-root-token-here"
  key_name        = "ha-unseal-key"
  mount_path      = "transit/"
  disable_renewal = "false"
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}

api_addr      = "http://vault-autounseal:8200"
ui            = true
disable_mlock = true
