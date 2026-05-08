# terraform/staging.tfvars
# Variables especificas del entorno de STAGING.
#
# SEGURIDAD: Este archivo NO debe contener la variable 'db_password'.
# Inyectar la contrasena mediante:
#   export TF_VAR_db_password="tu_contrasena_staging"
# o mediante el flag -var al ejecutar terraform apply.
#
# Para staging, la etiqueta de imagen debe ser el SHA del commit
# generado por el pipeline de CI:
#   terraform apply -var-file=staging.tfvars -var="image_tag=<COMMIT_SHA>"

# ── Entorno ──────────────────────────────────────────────────
environment = "staging"
namespace   = "greendev-staging"

# ── Registro de imagenes ──────────────────────────────────────
# Sustituir por tu usuario de Docker Hub.
docker_registry = "tu-usuario-dockerhub"

# La etiqueta se sobreescribe en el momento del despliegue con el SHA del commit.
# Valor por defecto conservador para evitar despliegues accidentales con 'latest'.
image_tag = "must-be-overridden-with-commit-sha"

# ── Nombres de imagen ─────────────────────────────────────────
nginx_image_name = "nginx-gsx"
app_image_name   = "app-gsx"
db_image_name    = "postgres-gsx"

# ── Puertos ───────────────────────────────────────────────────
nginx_container_port = 8080
nginx_node_port      = 30081
app_port             = 3000
db_port              = 5432

# ── Base de datos ─────────────────────────────────────────────
db_service_name = "db"
db_user         = "greendev_user"
db_name         = "greendev_db"
db_storage_size = "2Gi"
db_host_path    = "/mnt/data/greendev-db-staging"

# ── Replicas (mayor disponibilidad en staging) ────────────────
app_replicas   = 2
nginx_replicas = 1

# ── Limites de recursos (equivalentes a produccion) ───────────
app_cpu_limit      = "1000m"
app_memory_limit   = "512Mi"
app_cpu_request    = "200m"
app_memory_request = "128Mi"

nginx_cpu_limit      = "500m"
nginx_memory_limit   = "256Mi"
nginx_cpu_request    = "100m"
nginx_memory_request = "64Mi"

db_cpu_limit      = "1000m"
db_memory_limit   = "512Mi"
db_cpu_request    = "500m"
db_memory_request = "256Mi"
