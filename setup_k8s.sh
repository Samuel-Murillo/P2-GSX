#!/bin/bash
set -e

echo "=== Instalando dependencias de Kubernetes (Minikube & kubectl) ==="

if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew &> /dev/null; then
        echo "Homebrew no está instalado. Por favor, instala Homebrew primero."
        exit 1
    fi
    if ! command -v minikube &> /dev/null; then
        echo "Instalando Minikube y kubectl vía Homebrew..."
        brew install minikube kubernetes-cli
    else
        echo "Minikube ya está instalado."
    fi
else
    echo "Instalando para Linux vía curl..."
    if ! command -v kubectl &> /dev/null; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    fi
    if ! command -v minikube &> /dev/null; then
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
    fi
fi

echo "=== Iniciando Minikube ==="
minikube start

echo "=== Verificando el cluster ==="
kubectl cluster-info

echo "=== Construyendo imágenes directamente en el daemon Docker de Minikube ==="
echo "Nota: Esto garantiza que Kubernetes use siempre la versión más reciente del código."
# Apuntar el cliente Docker al daemon interno de Minikube
eval $(minikube docker-env)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Construyendo imagen: app-gsx..."
docker build --no-cache -t app-gsx:latest "$SCRIPT_DIR/app/"

echo "Construyendo imagen: nginx-gsx..."
docker build --no-cache -t nginx-gsx:latest "$SCRIPT_DIR/nginx/"

echo "Construyendo imagen: postgres-gsx..."
if [ -d "$SCRIPT_DIR/db" ] && [ -f "$SCRIPT_DIR/db/Dockerfile" ]; then
    docker build --no-cache -t postgres-gsx:latest "$SCRIPT_DIR/db/"
else
    echo "  (No se encontró Dockerfile en /db, usando imagen base de postgres)"
fi

echo ""
echo "=== Desplegando manifiestos de Kubernetes ==="
kubectl apply -f "$SCRIPT_DIR/kubernetes/"

echo ""
echo "=== Esperando a que los pods estén listos ==="
kubectl rollout status deployment/app deployment/nginx --timeout=120s

echo ""
echo "=== ¡Entorno listo! ==="
echo "Para acceder a la aplicación, ejecuta: minikube service nginx-service --url"
