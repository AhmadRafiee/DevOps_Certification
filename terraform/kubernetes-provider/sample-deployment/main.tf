resource "kubernetes_namespace" "my_namespace" {
  metadata {
    name = var.namespace_name
  }
}

resource "kubernetes_deployment" "my_deployment" {
  metadata {
    name      = var.deployment_name
    namespace = kubernetes_namespace.my_namespace.metadata[0].name
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.deployment_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.deployment_name
        }
      }

      spec {
        container {
          name  = var.deployment_name
          image = var.image

        }
      }
    }
  }
}