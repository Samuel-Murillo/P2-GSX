# terraform/nginx.tf
# Recursos de Kubernetes para el proxy inverso Nginx (frontend).
# Traduccion fiel del manifiesto kubernetes/04-nginx.yaml.

locals {
  nginx_image = "${var.docker_registry}/${var.nginx_image_name}:${var.image_tag}"
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "frontend"
      managed_by = "terraform"
    }
  }

  spec {
    replicas = var.nginx_replicas

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = local.nginx_image

          # En Minikube usamos imagenes cargadas con 'minikube image load',
          # por eso la politica es IfNotPresent en dev e Always en staging.
          image_pull_policy = var.environment == "staging" ? "Always" : "IfNotPresent"

          port {
            container_port = var.nginx_container_port
            protocol       = "TCP"
          }

          resources {
            limits = {
              cpu    = var.nginx_cpu_limit
              memory = var.nginx_memory_limit
            }
            requests = {
              cpu    = var.nginx_cpu_request
              memory = var.nginx_memory_request
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.nginx_container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.nginx_container_port
            }
            initial_delay_seconds = 2
            period_seconds        = 10
          }
        }
      }
    }
  }

  # Evita que Terraform destruya y recree el Deployment en cada apply
  # cuando solo cambia la imagen (rolling update nativo de Kubernetes).
  lifecycle {
    create_before_destroy = true
  }
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "frontend"
      managed_by = "terraform"
    }
  }

  spec {
    type = "NodePort"

    selector = {
      app = "frontend"
    }

    port {
      port        = 80
      target_port = var.nginx_container_port
      node_port   = var.nginx_node_port
      protocol    = "TCP"
    }
  }
}
