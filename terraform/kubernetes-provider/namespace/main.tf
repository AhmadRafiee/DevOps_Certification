resource "kubernetes_namespace" "my_namespace" {
  metadata {
    name = var.namespace_name
  }
}