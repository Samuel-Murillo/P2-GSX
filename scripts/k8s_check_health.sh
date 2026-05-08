#!/bin/bash
set -e

echo "=== Verificando estado del clúster ==="
kubectl get all

echo ""
echo "=== Prueba de Escalado (Resiliencia) ==="
echo "Escalando el Deployment de Nginx a 3 réplicas..."
kubectl scale deployment nginx --replicas=3
echo "Esperando 5 segundos para que se levanten los pods..."
sleep 5
kubectl get pods -l app=frontend

echo ""
echo "=== Prueba de Resiliencia (Auto-recuperación) ==="
echo "Vamos a eliminar un pod del backend para observar cómo Kubernetes lo recrea automáticamente..."
POD_NAME=$(kubectl get pods -l app=backend -o jsonpath="{.items[0].metadata.name}")
echo "Eliminando pod: $POD_NAME"
kubectl delete pod $POD_NAME
echo "Pod eliminado. Comprobando la creación instantánea de un nuevo pod..."
sleep 3
kubectl get pods -l app=backend

echo ""
echo "=== Prueba de Conectividad ==="
echo "Exponiendo el servicio Nginx a través de Minikube (abrirá el navegador automáticamente o mostrará la URL)..."
minikube service nginx-service --url
