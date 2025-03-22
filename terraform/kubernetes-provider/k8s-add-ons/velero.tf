resource "kubernetes_namespace" "velero_namespace" {
  metadata {
    name = "velero"
  }
}

resource "helm_release" "velero" {
  name       = "velero"
  namespace  = kubernetes_namespace.velero_namespace.metadata[0].name
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = "8.3.0"
  values     = [file("values/velero-values.yaml")]
  depends_on = [helm_release.minio]
}