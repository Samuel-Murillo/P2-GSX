# terraform/app.tf
# Recursos de Kubernetes para el backend Node.js.
# Traduccion fiel del manifiesto kubernetes/03-backend.yaml.

locals {
  app_image = "${var.docker_registry}/${var.app_image_name}:${var.image_tag}"
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "app"
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "backend"
      managed_by = "terraform"
    }
  }

  spec {
    replicas = var.app_replicas

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = local.app_image

          image_pull_policy = var.environment == "staging" ? "Always" : "IfNotPresent"

          port {
            container_port = var.app_port
            protocol       = "TCP"
          }

          # Variables de entorno desde el ConfigMap
          env_from {
            config_map_ref {
              name = kubernetes_config_map.greendev.metadata[0].name
            }
          }

          # Variables de entorno sensibles desde el Secret
          env_from {
            secret_ref {
              name = kubernetes_secret.greendev.metadata[0].name
            }
          }

          resources {
            limits = {
              cpu    = var.app_cpu_limit
              memory = var.app_memory_limit
            }
            requests = {
              cpu    = var.app_cpu_request
              memory = var.app_memory_request
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.app_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.app_port
            }
            initial_delay_seconds = 2
            period_seconds        = 10
          }
        }
      }
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "app"
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "backend"
      managed_by = "terraform"
    }
  }

  spec {
    # ClusterIP: el servicio es interno, solo accesible desde dentro del cluster.
    type = "ClusterIP"

    selector = {
      app = "backend"
    }

    port {
      port        = var.app_port
      target_port = var.app_port
      protocol    = "TCP"
    }
  }
}
