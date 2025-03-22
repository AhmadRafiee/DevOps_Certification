resource "kubernetes_namespace" "cert_manager_namespace" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace.cert_manager_namespace.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.17.1"
  values     = [file("values/cert-manager-values.yaml")]
  depends_on = [helm_release.ingress-nginx]
}

resource "kubernetes_manifest" "cluster_Issuer" {
  manifest = yamldecode(file("manifests/clusterIssuer.yaml"))
  depends_on = [helm_release.cert-manager]
}