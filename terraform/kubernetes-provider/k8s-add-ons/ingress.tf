resource "kubernetes_namespace" "ingress_namespace" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "ingress-nginx" {
  name       = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_namespace.metadata[0].name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.0"
  values     = [file("values/ingress-nginx-values.yaml")]
}