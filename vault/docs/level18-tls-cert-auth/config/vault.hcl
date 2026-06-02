storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address       = "0.0.0.0:8300"
  tls_cert_file = "/vault/certs/vault-server.crt"
  tls_key_file  = "/vault/certs/vault-server.key"
  tls_client_ca_file    = "/vault/certs/ca.crt"
  tls_require_and_verify_client_cert = false
}

ui            = true
disable_mlock = true
