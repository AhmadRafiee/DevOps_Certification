output "namespace" {
  value = kubernetes_namespace.my_namespace.id
}

output "deployment" {
  value = kubernetes_deployment.my_deployment.id
}
