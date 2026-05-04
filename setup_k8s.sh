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

echo "=== Cargando imágenes locales en Minikube ==="
echo "Nota: Esto puede tardar unos segundos..."
minikube image load nginx-gsx:latest
minikube image load app-gsx:latest
minikube image load postgres-gsx:latest

echo "=== ¡Entorno listo! ==="
