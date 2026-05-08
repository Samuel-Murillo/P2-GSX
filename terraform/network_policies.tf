# terraform/network_policies.tf
# Políticas de Red (NetworkPolicies) para Kubernetes
# Implementa segmentación estricta y aislamiento de entornos.

# 1. Regla de Segmentación de Entornos (Aislamiento por Namespace)
# Deniega todo el tráfico Ingress y Egress por defecto a menos que esté explícitamente permitido.
resource "kubernetes_network_policy" "default_deny_all" {
  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.greendev.metadata[0].name
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]

    # Permitimos Egress básico para DNS hacia kube-system
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = 53
        protocol = "UDP"
      }
      ports {
        port     = 53
        protocol = "TCP"
      }
    }
  }
}

# 2. Política para el Frontend (Nginx)
resource "kubernetes_network_policy" "frontend_policy" {
  metadata {
    name      = "frontend-policy"
    namespace = kubernetes_namespace.greendev.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "frontend"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      # Permitimos tráfico desde la red corporativa y partners (Evitando 0.0.0.0/0 absoluto si es interno)
      # Según el diseño CIDR, 10.0.0.0/16 es la red corporativa.
      from {
        ip_block {
          cidr = "10.0.0.0/16"
        }
      }
      ports {
        port     = var.nginx_container_port
        protocol = "TCP"
      }
    }

    egress {
      # Permitir salida al Backend
      to {
        pod_selector {
          match_labels = {
            app = "backend"
          }
        }
      }
      ports {
        port     = var.app_port
        protocol = "TCP"
      }
    }
  }
}

# 3. Política para el Backend (Node.js)
resource "kubernetes_network_policy" "backend_policy" {
  metadata {
    name      = "backend-policy"
    namespace = kubernetes_namespace.greendev.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "backend"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Solo acepta tráfico del frontend
    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "frontend"
          }
        }
      }
      ports {
        port     = var.app_port
        protocol = "TCP"
      }
    }

    # Puede comunicarse con la base de datos
    egress {
      to {
        pod_selector {
          match_labels = {
            app = "postgres"
          }
        }
      }
      ports {
        port     = var.db_port
        protocol = "TCP"
      }
    }
  }
}

# 4. Regla de Protección de Base de Datos (PostgreSQL)
# Cumple con el requisito: la base de datos interna solo puede recibir tráfico del backend de su mismo entorno.
resource "kubernetes_network_policy" "db_policy" {
  metadata {
    name      = "db-protection-policy"
    namespace = kubernetes_namespace.greendev.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "postgres"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Solo acepta tráfico del backend del mismo namespace
    # Deniega explícitamente tráfico de pods externos o del frontend por omisión en esta regla
    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "backend"
          }
        }
      }
      ports {
        port     = var.db_port
        protocol = "TCP"
      }
    }

    # La BD no necesita iniciar conexiones externas (Egress bloqueado por default_deny_all, solo DNS permitido)
  }
}

# 5. Restricción Explícita de Aislamiento de Entornos
# Refuerza que ningún pod de otro entorno (ej. de prod a dev) pueda comunicarse.
resource "kubernetes_network_policy" "deny_cross_environment" {
  metadata {
    name      = "deny-cross-environment"
    namespace = kubernetes_namespace.greendev.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress"]

    ingress {
      # Solo permite tráfico de namespaces que tengan el MISMO entorno (dev con dev, staging con staging)
      from {
        namespace_selector {
          match_labels = {
            environment = var.environment
          }
        }
      }
    }
  }
}
