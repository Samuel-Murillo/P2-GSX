# terraform/variables.tf
# Declaracion centralizada de todas las variables del modulo.
# Ningun valor por defecto contiene credenciales sensibles.

# ────────────────────────────────────────────────────────────
# Proveedor / Cluster
# ────────────────────────────────────────────────────────────

variable "kubeconfig_path" {
  description = "Ruta al archivo kubeconfig de Minikube."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Contexto de kubectl que apunta al cluster Minikube."
  type        = string
  default     = "minikube"
}

# ────────────────────────────────────────────────────────────
# Entorno
# ────────────────────────────────────────────────────────────

variable "environment" {
  description = "Nombre del entorno activo (dev | staging)."
  type        = string

  validation {
    condition     = contains(["dev", "staging"], var.environment)
    error_message = "El valor de 'environment' debe ser 'dev' o 'staging'."
  }
}

variable "namespace" {
  description = "Namespace de Kubernetes en el que se desplegaran los recursos."
  type        = string
}

# ────────────────────────────────────────────────────────────
# Imagenes Docker
# ────────────────────────────────────────────────────────────

variable "docker_registry" {
  description = "Registro de contenedores (Docker Hub username o FQDN del registro privado)."
  type        = string
}

variable "image_tag" {
  description = "Etiqueta (tag) de las imagenes Docker. En CI se inyecta el SHA del commit."
  type        = string
  default     = "latest"
}

variable "nginx_image_name" {
  description = "Nombre de la imagen del proxy Nginx dentro del registro."
  type        = string
  default     = "nginx-gsx"
}

variable "app_image_name" {
  description = "Nombre de la imagen del backend Node.js dentro del registro."
  type        = string
  default     = "app-gsx"
}

variable "db_image_name" {
  description = "Nombre de la imagen personalizada de PostgreSQL dentro del registro."
  type        = string
  default     = "postgres-gsx"
}

# ────────────────────────────────────────────────────────────
# Puertos
# ────────────────────────────────────────────────────────────

variable "nginx_container_port" {
  description = "Puerto en el que escucha el contenedor Nginx."
  type        = number
  default     = 8080
}

variable "nginx_node_port" {
  description = "NodePort expuesto por el Service de Nginx (rango 30000-32767)."
  type        = number
  default     = 30080
}

variable "app_port" {
  description = "Puerto en el que escucha la aplicacion Node.js."
  type        = number
  default     = 3000
}

variable "db_port" {
  description = "Puerto de escucha de PostgreSQL."
  type        = number
  default     = 5432
}

# ────────────────────────────────────────────────────────────
# Base de datos
# ────────────────────────────────────────────────────────────

variable "db_service_name" {
  description = "Nombre DNS interno del Service de la base de datos dentro del namespace."
  type        = string
  default     = "db"
}

variable "db_user" {
  description = "Usuario de PostgreSQL."
  type        = string
  default     = "greendev_user"
}

variable "db_name" {
  description = "Nombre de la base de datos PostgreSQL."
  type        = string
  default     = "greendev_db"
}

variable "db_password" {
  description = "Contrasena de PostgreSQL. Inyectar via variable de entorno TF_VAR_db_password o -var."
  type        = string
  sensitive   = true
}

variable "db_storage_size" {
  description = "Capacidad del volumen persistente de la base de datos."
  type        = string
  default     = "1Gi"
}

variable "db_host_path" {
  description = "Ruta del host (nodo Minikube) donde se almacenan los datos de PostgreSQL."
  type        = string
  default     = "/mnt/data/greendev-db"
}

# ────────────────────────────────────────────────────────────
# Replicas y recursos
# ────────────────────────────────────────────────────────────

variable "app_replicas" {
  description = "Numero de replicas del Deployment del backend."
  type        = number
  default     = 2
}

variable "nginx_replicas" {
  description = "Numero de replicas del Deployment de Nginx."
  type        = number
  default     = 1
}

# Limites de recursos para el backend
variable "app_cpu_limit" {
  type    = string
  default = "1000m"
}

variable "app_memory_limit" {
  type    = string
  default = "512Mi"
}

variable "app_cpu_request" {
  type    = string
  default = "200m"
}

variable "app_memory_request" {
  type    = string
  default = "128Mi"
}

# Limites de recursos para Nginx
variable "nginx_cpu_limit" {
  type    = string
  default = "500m"
}

variable "nginx_memory_limit" {
  type    = string
  default = "256Mi"
}

variable "nginx_cpu_request" {
  type    = string
  default = "100m"
}

variable "nginx_memory_request" {
  type    = string
  default = "64Mi"
}

# Limites de recursos para la base de datos
variable "db_cpu_limit" {
  type    = string
  default = "1000m"
}

variable "db_memory_limit" {
  type    = string
  default = "512Mi"
}

variable "db_cpu_request" {
  type    = string
  default = "500m"
}

variable "db_memory_request" {
  type    = string
  default = "256Mi"
}
