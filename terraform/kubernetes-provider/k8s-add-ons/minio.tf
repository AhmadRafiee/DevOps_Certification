resource "kubernetes_namespace" "minio_namespace" {
  metadata {
    name = "minio"
  }
}

resource "helm_release" "minio" {
  name       = "minio"
  namespace  = kubernetes_namespace.minio_namespace.metadata[0].name
  repository = "https://charts.min.io/"
  chart      = "minio"
  version    = "5.4.0"
  values     = [file("values/minio-values.yaml")]
  depends_on = [helm_release.cert-manager]
}