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
  values = [
    templatefile("values/velero-values.yaml", {
      aws_access_key_id     = var.minio_velero_username
      aws_secret_access_key = var.minio_velero_password
      s3_url                = var.minio_api_domain
      bucket_name           = var.bucket_name
    })
  ]
  depends_on = [helm_release.minio,minio_iam_user_policy_attachment.backup]
}