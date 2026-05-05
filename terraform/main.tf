# terraform/main.tf
# Punto de entrada principal: configuracion del proveedor de Kubernetes
# dirigido al cluster Minikube local.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

# El proveedor se configura apuntando al kubeconfig generado por Minikube.
# No se incrusta ninguna credencial en el codigo.
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

# Namespace que aislara todos los recursos del entorno activo.
resource "kubernetes_namespace" "greendev" {
  metadata {
    name = var.namespace

    labels = {
      environment = var.environment
      project     = "greendev"
      managed_by  = "terraform"
    }
  }
}

# ConfigMap compartido por los pods de backend y base de datos.
resource "kubernetes_config_map" "greendev" {
  metadata {
    name      = "greendev-config"
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "greendev"
      managed_by = "terraform"
    }
  }

  data = {
    APP_PORT = tostring(var.app_port)
    DB_HOST  = var.db_service_name
    DB_PORT  = tostring(var.db_port)
    DB_USER  = var.db_user
    DB_NAME  = var.db_name
  }
}

# Secret de base de datos.
# El valor de DB_PASSWORD se inyecta a traves de la variable de entorno
# TF_VAR_db_password y NUNCA se almacena en un .tfvars trackeado por Git.
resource "kubernetes_secret" "greendev" {
  metadata {
    name      = "greendev-secret"
    namespace = kubernetes_namespace.greendev.metadata[0].name

    labels = {
      app        = "greendev"
      managed_by = "terraform"
    }
  }

  type = "Opaque"

  data = {
    DB_PASSWORD = var.db_password
  }
}
