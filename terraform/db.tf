# terraform/db.tf
# Recursos de Kubernetes para la base de datos PostgreSQL.
# Traduccion fiel de kubernetes/01-pv-pvc.yaml y kubernetes/02-database.yaml.

locals {
  db_image = "${var.docker_registry}/${var.db_image_name}:${var.image_tag}"
}

# ────────────────────────────────────────────────────────────
# Volumen persistente (PV) - provisionado de forma estatica en Minikube
# ────────────────────────────────────────────────────────────
resource "kubernetes_persistent_volume" "db" {
  metadata {
    name = "${var.namespace}-db-pv"

    labels = {
      type       = "local"
      managed_by = "terraform"
    }
  }

  spec {
    capacity = {
      storage = var.db_storage_size
    }

    access_modes                     = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Retain"

    persistent_volume_source {
      host_path {
        path = var.db_host_path
      }
    }

    # Asegura que el PV solo puede ser reclamado por el PVC de este namespace
    claim_ref {
      namespace = kubernetes_namespace.greendev.metadata[0].name
      name      = "${var.namespace}-db-pvc"
    }
  }
}

# ────────────────────────────────────────────────────────────
# Reclamacion de volumen persistente (PVC)
# ────────────────────────────────────────────────────────────
resource "kubernetes_persistent_volume_claim" "db" {
  metadata {
    name      = "${var.namespace}-db-pvc"
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "postgres"
      managed_by = "terraform"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = var.db_storage_size
      }
    }

    # Vincula explicitamente este PVC al PV creado arriba
    volume_name = kubernetes_persistent_volume.db.metadata[0].name
  }

  # El PVC no debe destruirse antes de que el StatefulSet lo libere
  depends_on = [kubernetes_persistent_volume.db]
}

# ────────────────────────────────────────────────────────────
# StatefulSet de PostgreSQL
# ────────────────────────────────────────────────────────────
resource "kubernetes_stateful_set" "db" {
  metadata {
    name      = "db"
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "postgres"
      managed_by = "terraform"
    }
  }

  spec {
    service_name = var.db_service_name
    replicas     = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = local.db_image

          image_pull_policy = var.environment == "staging" ? "Always" : "IfNotPresent"

          port {
            container_port = var.db_port
            protocol       = "TCP"
          }

          # Usuario de la base de datos (desde ConfigMap)
          env {
            name = "POSTGRES_USER"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.greendev.metadata[0].name
                key  = "DB_USER"
              }
            }
          }

          # Nombre de la base de datos (desde ConfigMap)
          env {
            name = "POSTGRES_DB"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.greendev.metadata[0].name
                key  = "DB_NAME"
              }
            }
          }

          # Contrasena (desde Secret - NUNCA en texto plano)
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.greendev.metadata[0].name
                key  = "DB_PASSWORD"
              }
            }
          }

          resources {
            limits = {
              cpu    = var.db_cpu_limit
              memory = var.db_memory_limit
            }
            requests = {
              cpu    = var.db_cpu_request
              memory = var.db_memory_request
            }
          }

          volume_mount {
            name       = "db-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "db-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.db.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_persistent_volume_claim.db]
}

# ────────────────────────────────────────────────────────────
# Service headless de la base de datos (requerido por StatefulSet)
# ────────────────────────────────────────────────────────────
resource "kubernetes_service" "db" {
  metadata {
    name      = var.db_service_name
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "postgres"
      managed_by = "terraform"
    }
  }

  spec {
    # ClusterIP para acceso interno desde el backend
    type = "ClusterIP"

    selector = {
      app = "postgres"
    }

    port {
      port        = var.db_port
      target_port = var.db_port
      protocol    = "TCP"
    }
  }
}
