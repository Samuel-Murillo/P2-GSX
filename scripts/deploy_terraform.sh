#!/usr/bin/env bash
# =============================================================================
# deploy_terraform.sh — Despliegue automatizado en Minikube con Terraform
# =============================================================================
# Uso:
#   bash deploy_terraform.sh
#
# Requisitos:
#   - Minikube en ejecución (minikube start)
#   - Terraform instalado (bash install_terraform.sh)
#   - Variable de entorno TF_VAR_db_password exportada
#
# Lo que hace este script:
#   1. Calcula el SHA corto del commit actual (etiqueta de imagen única)
#   2. Construye las tres imágenes Docker con esa etiqueta
#   3. Las carga en el registro interno de Minikube (sin pull de internet)
#   4. Ejecuta terraform apply con la etiqueta calculada
# =============================================================================

set -euo pipefail

# ── Colores para los mensajes ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

# ── Directorio raíz del proyecto ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"

# ── Configuración ─────────────────────────────────────────────────────────────
REGISTRY="musefa"
NGINX_IMAGE="${REGISTRY}/nginx-gsx"
APP_IMAGE="${REGISTRY}/app-gsx"
DB_IMAGE="${REGISTRY}/postgres-gsx"

NGINX_CONTEXT="${SCRIPT_DIR}/../nginx"
APP_CONTEXT="${SCRIPT_DIR}/../app"
DB_CONTEXT="${SCRIPT_DIR}/../db"

TFVARS_FILE="dev.tfvars"

# =============================================================================
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}   GreenDevCorp — Deploy automático con Terraform       ${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════════════════${RESET}"
echo ""

# ── 0. Precondiciones ─────────────────────────────────────────────────────────
info "Comprobando precondiciones..."

command -v docker      >/dev/null 2>&1 || error "Docker no está instalado."
command -v minikube    >/dev/null 2>&1 || error "Minikube no está instalado."
command -v terraform   >/dev/null 2>&1 || error "Terraform no instalado. Ejecuta: bash install_terraform.sh"

if ! minikube status | grep -q "Running"; then
  error "Minikube no está en ejecución. Ejecuta primero: minikube start"
fi

if [[ -z "${TF_VAR_db_password:-}" ]]; then
  error "La variable TF_VAR_db_password no está definida.\nEjecuta: export TF_VAR_db_password=\"tu_contrasena\""
fi

success "Precondiciones cumplidas."
echo ""

# ── 1. Calcular etiqueta de imagen ────────────────────────────────────────────
IMAGE_TAG=$(git -C "${SCRIPT_DIR}/.." rev-parse --short HEAD 2>/dev/null || echo "latest")
info "Etiqueta de imagen calculada: ${BOLD}${IMAGE_TAG}${RESET}"
echo ""

# ── 2. Construir imágenes ─────────────────────────────────────────────────────
info "Construyendo imagen Nginx → ${NGINX_IMAGE}:${IMAGE_TAG}"
docker build -t "${NGINX_IMAGE}:${IMAGE_TAG}" "${NGINX_CONTEXT}" -q
success "Nginx construida."

info "Construyendo imagen App  → ${APP_IMAGE}:${IMAGE_TAG}"
docker build -t "${APP_IMAGE}:${IMAGE_TAG}" "${APP_CONTEXT}" -q
success "App construida."

info "Construyendo imagen DB   → ${DB_IMAGE}:${IMAGE_TAG}"
docker build -t "${DB_IMAGE}:${IMAGE_TAG}" "${DB_CONTEXT}" -q
success "DB construida."
echo ""

# ── 3. Cargar imágenes en Minikube ────────────────────────────────────────────
info "Cargando imágenes en el registro interno de Minikube..."
info "  → ${NGINX_IMAGE}:${IMAGE_TAG}"
minikube image load "${NGINX_IMAGE}:${IMAGE_TAG}"
info "  → ${APP_IMAGE}:${IMAGE_TAG}"
minikube image load "${APP_IMAGE}:${IMAGE_TAG}"
info "  → ${DB_IMAGE}:${IMAGE_TAG}"
minikube image load "${DB_IMAGE}:${IMAGE_TAG}"
success "Todas las imágenes cargadas en Minikube."
echo ""

# ── 4. Terraform apply ────────────────────────────────────────────────────────
info "Inicializando Terraform..."
cd "${TERRAFORM_DIR}"
terraform init -upgrade -input=false -no-color 2>&1 | grep -E "^(Terraform|provider|─)" || true

info "Ejecutando terraform apply con image_tag=${IMAGE_TAG}..."
terraform apply \
  -var-file="${TFVARS_FILE}" \
  -var="image_tag=${IMAGE_TAG}" \
  -auto-approve \
  -input=false
echo ""

# ── 5. Verificar el despliegue ────────────────────────────────────────────────
success "Despliegue completado. Estado del clúster:"
kubectl get pods -n greendev-dev
echo ""

# ── 6. Abrir túnel y mostrar la URL de acceso ────────────────────────────────
echo -e "${BOLD}── URL de la aplicación ────────────────────────────────${RESET}"
info "Iniciando túnel de red (puede tardar unos segundos)..."

# Archivo temporal para capturar la URL del túnel
TMPFILE=$(mktemp)

# Lanzar el túnel en background y desvincular del script (disown)
# para que siga vivo después de que el script termine.
minikube service nginx-service -n greendev-dev --url > "${TMPFILE}" 2>/dev/null &
TUNNEL_PID=$!
disown "${TUNNEL_PID}"

# Esperar a que el túnel imprima la URL (máx 8s)
APP_URL=""
for i in {1..8}; do
  sleep 1
  APP_URL=$(grep -m1 "http" "${TMPFILE}" 2>/dev/null || true)
  if [[ -n "${APP_URL}" ]]; then
    break
  fi
done

rm -f "${TMPFILE}"

echo ""
if [[ -n "${APP_URL}" ]]; then
  echo -e "  ${GREEN}${BOLD}→ ${APP_URL}${RESET}"
  echo ""
  info "El túnel de red está activo en segundo plano."
  info "Mientras esté activo, la URL funcionará en el navegador."
else
  warn "No se pudo obtener la URL automáticamente."
  warn "Ejecuta en otra terminal (y déjala abierta):"
  warn "  minikube service nginx-service -n greendev-dev --url"
fi

echo ""
success "¡Todo listo! Imagen desplegada: ${BOLD}${IMAGE_TAG}${RESET}"
