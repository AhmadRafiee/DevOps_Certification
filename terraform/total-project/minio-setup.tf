resource "kubernetes_namespace" "minio_namespace" {
  metadata {
    name = "minio"
  }
  depends_on = [ cloudflare_dns_record.cname_record_panel ]
}

resource "helm_release" "minio" {
  name       = "minio"
  namespace  = kubernetes_namespace.minio_namespace.metadata[0].name
  repository = "https://charts.min.io/"
  chart      = "minio"
  version    = "5.4.0"
  values     = [
    templatefile("values/minio-values.yaml", {
      minio_api_domain     = var.minio_api_domain
      minio_console_domain = var.minio_console_domain
    })
  ]
  depends_on = [kubernetes_namespace.minio_namespace]

  set {
    name  = "rootUser"
    value = var.minio_root_username
  }

  set {
    name  = "rootPassword"
    value = var.minio_root_password
  }

}