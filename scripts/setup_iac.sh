#!/usr/bin/env bash
# setup_iac.sh
# Descarga e instala Terraform en sistemas Unix (Linux / macOS).
# Uso: bash setup_iac.sh [VERSION]
# Ejemplo: bash setup_iac.sh 1.8.5

set -euo pipefail

TERRAFORM_VERSION="${1:-1.8.5}"
INSTALL_DIR="/usr/local/bin"

# ────────────────────────────────────────────────────────────
# 1. Detectar sistema operativo y arquitectura
# ────────────────────────────────────────────────────────────
detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "darwin" ;;
    *)
      echo "[ERROR] Sistema operativo no soportado: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)
      echo "[ERROR] Arquitectura no soportada: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

OS=$(detect_os)
ARCH=$(detect_arch)

echo "[INFO] Sistema detectado: ${OS} / ${ARCH}"
echo "[INFO] Version de Terraform a instalar: ${TERRAFORM_VERSION}"

# ────────────────────────────────────────────────────────────
# 2. Verificar dependencias minimas
# ────────────────────────────────────────────────────────────
for cmd in curl unzip; do
  if ! command -v "${cmd}" &>/dev/null; then
    echo "[ERROR] '${cmd}' no esta instalado. Instalalo e intenta de nuevo." >&2
    exit 1
  fi
done

# ────────────────────────────────────────────────────────────
# 3. Si Terraform ya esta instalado y coincide con la version
#    solicitada, no hace nada.
# ────────────────────────────────────────────────────────────
if command -v terraform &>/dev/null; then
  INSTALLED_VERSION=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4 || terraform version | awk '/Terraform v/{print $2}' | tr -d 'v')
  if [[ "${INSTALLED_VERSION}" == "${TERRAFORM_VERSION}" ]]; then
    echo "[INFO] Terraform ${TERRAFORM_VERSION} ya esta instalado. No se realiza ninguna accion."
    terraform version
    exit 0
  else
    echo "[INFO] Version instalada: ${INSTALLED_VERSION}. Se actualizara a ${TERRAFORM_VERSION}."
  fi
fi

# ────────────────────────────────────────────────────────────
# 4. Descargar el binario oficial de HashiCorp
# ────────────────────────────────────────────────────────────
DOWNLOAD_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip"
CHECKSUM_URL="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS"

TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "[INFO] Descargando Terraform desde: ${DOWNLOAD_URL}"
curl -fSL --progress-bar -o "${TMPDIR}/terraform.zip" "${DOWNLOAD_URL}"
curl -fSL --silent -o "${TMPDIR}/SHA256SUMS" "${CHECKSUM_URL}"

# ────────────────────────────────────────────────────────────
# 5. Verificar la integridad del archivo descargado
# ────────────────────────────────────────────────────────────
echo "[INFO] Verificando suma de comprobacion SHA-256..."
EXPECTED_HASH=$(grep "terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip" "${TMPDIR}/SHA256SUMS" | awk '{print $1}')

if [[ "${OS}" == "linux" ]]; then
  ACTUAL_HASH=$(sha256sum "${TMPDIR}/terraform.zip" | awk '{print $1}')
else
  ACTUAL_HASH=$(shasum -a 256 "${TMPDIR}/terraform.zip" | awk '{print $1}')
fi

if [[ "${EXPECTED_HASH}" != "${ACTUAL_HASH}" ]]; then
  echo "[ERROR] La verificacion SHA-256 fallo. El archivo puede estar corrupto." >&2
  echo "  Esperado: ${EXPECTED_HASH}" >&2
  echo "  Obtenido: ${ACTUAL_HASH}" >&2
  exit 1
fi

echo "[INFO] Suma de comprobacion correcta."

# ────────────────────────────────────────────────────────────
# 6. Instalar el binario
# ────────────────────────────────────────────────────────────
echo "[INFO] Descomprimiendo y copiando binario a ${INSTALL_DIR}..."
unzip -q "${TMPDIR}/terraform.zip" -d "${TMPDIR}"

if [[ -w "${INSTALL_DIR}" ]]; then
  cp "${TMPDIR}/terraform" "${INSTALL_DIR}/terraform"
  chmod +x "${INSTALL_DIR}/terraform"
else
  echo "[INFO] Se requieren permisos de superusuario para instalar en ${INSTALL_DIR}."
  sudo cp "${TMPDIR}/terraform" "${INSTALL_DIR}/terraform"
  sudo chmod +x "${INSTALL_DIR}/terraform"
fi

# ────────────────────────────────────────────────────────────
# 7. Verificar la instalacion
# ────────────────────────────────────────────────────────────
echo "[INFO] Verificando la instalacion..."
if ! command -v terraform &>/dev/null; then
  echo "[ERROR] El binario de Terraform no se encontro en el PATH." >&2
  echo "  Asegurate de que ${INSTALL_DIR} esta incluido en tu variable PATH." >&2
  exit 1
fi

echo ""
echo "================================================"
echo "  Terraform instalado correctamente."
echo "================================================"
terraform version
