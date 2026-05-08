# terraform/dev.tfvars
# Variables especificas del entorno de DESARROLLO (Minikube local).
#
# SEGURIDAD: Este archivo NO debe contener la variable 'db_password'.
# Inyectar la contrasena mediante:
#   export TF_VAR_db_password="tu_contrasena_local"
# o mediante el flag -var al ejecutar terraform apply.
#
# Este archivo SÍ puede ser trackeado por Git porque no contiene secretos.

# ── Entorno ──────────────────────────────────────────────────
environment = "dev"
namespace   = "greendev-dev"

# ── Registro de imagenes ──────────────────────────────────────
# Usuario de Docker Hub detectado en semanas anteriores.
docker_registry = "musefa"

# En desarrollo se usa 'latest' para mayor comodidad con minikube image load.
image_tag = "latest"

# ── Nombres de imagen ─────────────────────────────────────────
nginx_image_name = "nginx-gsx"
app_image_name   = "app-gsx"
db_image_name    = "postgres-gsx"

# ── Puertos ───────────────────────────────────────────────────
nginx_container_port = 8080
nginx_node_port      = 30080
app_port             = 3000
db_port              = 5432

# ── Base de datos ─────────────────────────────────────────────
db_service_name = "db"
db_user         = "greendev_user"
db_name         = "greendev_db"
db_storage_size = "1Gi"
db_host_path    = "/mnt/data/greendev-db-dev"

# ── Replicas (reducidas en dev para ahorrar recursos) ─────────
app_replicas   = 1
nginx_replicas = 1

# ── Limites de recursos (relajados en dev) ────────────────────
app_cpu_limit      = "500m"
app_memory_limit   = "256Mi"
app_cpu_request    = "100m"
app_memory_request = "64Mi"

nginx_cpu_limit      = "250m"
nginx_memory_limit   = "128Mi"
nginx_cpu_request    = "50m"
nginx_memory_request = "32Mi"

db_cpu_limit      = "500m"
db_memory_limit   = "256Mi"
db_cpu_request    = "250m"
db_memory_request = "128Mi"
