output "ingress_namespace" {
  value = kubernetes_namespace.ingress_namespace.id
}

output "helm_ingress-nginx" {
  value = helm_release.ingress-nginx.id
}

output "cert-manager_namespace" {
  value = kubernetes_namespace.cert_manager_namespace.id
}

output "helm_cert-manager" {
  value = helm_release.cert-manager.id
}

output "argocd_namespace" {
  value = kubernetes_namespace.argocd_namespace.id
}

output "helm_argocd" {
  value = helm_release.argocd.id
}

output "minio_namespace" {
  value = kubernetes_namespace.minio_namespace.id
}

output "helm_minio" {
  value = helm_release.minio.id
}

output "velero_namespace" {
  value = kubernetes_namespace.velero_namespace.id
}

output "helm_velero" {
  value = helm_release.velero.id
}