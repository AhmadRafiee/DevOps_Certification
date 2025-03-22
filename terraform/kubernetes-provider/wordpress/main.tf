resource "kubernetes_namespace" "wordpress_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.wordpress_namespace.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mysql"
      }
    }

    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        container {
          name  = "mysql"
          image = "mysql:5.7"

          env {
            name  = "MYSQL_ROOT_PASSWORD"
            value = var.mysql_root_password
          }

          env {
            name  = "MYSQL_DATABASE"
            value = var.mysql_database
          }

          env {
            name  = "MYSQL_USER"
            value = var.wordpress_username
          }

          env {
            name  = "MYSQL_PASSWORD"
            value = var.wordpress_password
          }

          volume_mount {
            name      = "mysql-storage"
            mount_path = "/var/lib/mysql"
          }
        }
        volume {
          name = "mysql-storage"

          host_path {
            path = "${var.host_path}/mysql"  # This points to the HostPath
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mysql_service" {
  metadata {
    name      = "mysql-service"
    namespace = kubernetes_namespace.wordpress_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "mysql"
    }

    port {
      port        = 3306
      target_port = 3306
    }

    type = "ClusterIP"
  }
}


resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress_namespace.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:latest"

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "${kubernetes_service.mysql_service.metadata[0].name}:3306"
          }

          env {
            name  = "WORDPRESS_DB_USER"
            value = var.wordpress_username
          }

          env {
            name  = "WORDPRESS_DB_PASSWORD"
            value = var.wordpress_password
          }

          env {
            name  = "WORDPRESS_DB_NAME"
            value = var.mysql_database
          }

          volume_mount {
            name      = "wordpress-storage"
            mount_path = "/var/www/html"
          }
        }

        volume {
          name = "wordpress-storage"

          host_path {
            path = "${var.host_path}/wordpress"  # This points to the HostPath for WordPress
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "wordpress_service" {
  metadata {
    name      = "wordpress-service"
    namespace = kubernetes_namespace.wordpress_namespace.metadata[0].name
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "wordpress_ingress" {
  metadata {
    name      = "wordpress-ingress"
    namespace = kubernetes_namespace.wordpress_namespace.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt"
      "certmanager.k8s.io/acme-http01-edit-in-place" = "false"
      "kubernetes.io/tls-acme" = "true"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = [var.ingress_host]
      secret_name = "wordpress-tls"
    }

    rule {
      host = var.ingress_host
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.wordpress_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}