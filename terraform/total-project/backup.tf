resource "kubernetes_manifest" "ingress_backup" {
  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "Backup"
    metadata = {
      name      = "ingress-backup"
      namespace = "velero"
    }
    spec = {
      includedNamespaces = ["*"]
      includedResources  = ["ingress.networking.k8s.io"]
      ttl                = "720h"
      snapshotVolumes    = false
    }
  }

  depends_on = [helm_release.velero]
}

resource "kubernetes_manifest" "ingress_backup_schedule" {
  manifest = {
    apiVersion = "velero.io/v1"
    kind       = "Schedule"
    metadata = {
      name      = "ingress-daily-backup"
      namespace = "velero"
    }
    spec = {
      schedule = "0 2 * * *"
      template = {
        includedNamespaces = ["*"]
        includedResources  = ["ingress.networking.k8s.io"]
        ttl                = "720h"
        snapshotVolumes    = false
      }
    }
  }

  depends_on = [helm_release.velero]
}
