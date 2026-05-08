#!/bin/bash
# scripts/k8s_check_security.sh
# Script automatizado para verificar las NetworkPolicies en Kubernetes.
# Requiere: kubectl configurado y apuntando al clúster Minikube.

NAMESPACE="greendev-dev"

echo "=========================================================="
echo "🚀 Iniciando pruebas de Network Policies en $NAMESPACE"
echo "=========================================================="

echo "[*] Verificando que los pods estén listos en el namespace $NAMESPACE..."
kubectl wait --for=condition=ready pod -l app=backend -n $NAMESPACE --timeout=60s
kubectl wait --for=condition=ready pod -l app=frontend -n $NAMESPACE --timeout=60s
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=60s

FRONTEND_POD=$(kubectl get pod -l app=frontend -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}")
BACKEND_POD=$(kubectl get pod -l app=backend -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}")

# ---------------------------------------------------------
# Prueba 1: Frontend -> Backend (Permitido)
# ---------------------------------------------------------
echo -e "\n[Prueba 1] Frontend conectando al Backend (Debe funcionar)"
kubectl exec -n $NAMESPACE $FRONTEND_POD -- wget -qO- --timeout=5 http://app:3000/health > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ ÉXITO: Frontend se comunicó con el Backend correctamente."
else
  echo "❌ FALLO: Frontend NO pudo comunicarse con el Backend."
fi

# ---------------------------------------------------------
# Prueba 2: Backend -> Database (Permitido)
# ---------------------------------------------------------
echo -e "\n[Prueba 2] Backend conectando a PostgreSQL (Debe funcionar)"
# Usamos Node.js dentro del pod backend para probar la conexión TCP hacia la base de datos
NODE_TEST_SCRIPT="const net = require('net'); const client = new net.Socket(); client.setTimeout(2000); client.connect(5432, 'db', () => { console.log('OK'); client.destroy(); }); client.on('error', () => { process.exit(1); }); client.on('timeout', () => { process.exit(1); });"
kubectl exec -n $NAMESPACE $BACKEND_POD -- node -e "$NODE_TEST_SCRIPT" > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "✅ ÉXITO: Backend alcanzó el puerto 5432 de la base de datos."
else
  echo "❌ FALLO: Backend NO pudo alcanzar la base de datos."
fi

# ---------------------------------------------------------
# Prueba 3: Intruso en el mismo namespace -> Database (Bloqueado)
# ---------------------------------------------------------
echo -e "\n[Prueba 3] Pod intruso en el mismo namespace intentando acceder a la DB (Debe fallar por Timeout)"
kubectl run intruder --image=busybox -n $NAMESPACE --restart=Never --labels="app=intruder" -- sleep 3600 > /dev/null 2>&1
kubectl wait --for=condition=ready pod/intruder -n $NAMESPACE --timeout=60s > /dev/null 2>&1

# netcat (nc) con timeout de 3 segundos
kubectl exec -n $NAMESPACE intruder -- nc -w 3 db 5432 > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "✅ ÉXITO (Esperado): La política db-protection BLOQUEÓ al intruso."
else
  echo "❌ FALLO CRÍTICO: El intruso PUDO conectarse a la DB. (Asegúrate de estar usando un CNI en minikube)."
fi

# Limpieza del intruso
kubectl delete pod intruder -n $NAMESPACE --ignore-not-found=true > /dev/null 2>&1

# ---------------------------------------------------------
# Prueba 4: Aislamiento de Entornos (Prod -> Dev) (Bloqueado)
# ---------------------------------------------------------
echo -e "\n[Prueba 4] Pod desde entorno de producción intentando acceder a Dev (Debe fallar)"
kubectl create namespace greendev-prod --dry-run=client -o yaml | kubectl apply -f - > /dev/null 2>&1
kubectl label namespace greendev-prod environment=prod --overwrite > /dev/null 2>&1
kubectl run intruder-prod --image=busybox -n greendev-prod --restart=Never -- sleep 3600 > /dev/null 2>&1
kubectl wait --for=condition=ready pod/intruder-prod -n greendev-prod --timeout=60s > /dev/null 2>&1

# Intenta alcanzar la app en Dev desde Prod
kubectl exec -n greendev-prod intruder-prod -- wget -qO- --timeout=3 http://app.$NAMESPACE.svc.cluster.local:3000 > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "✅ ÉXITO (Esperado): La política de aislamiento BLOQUEÓ el tráfico cross-namespace."
else
  echo "❌ FALLO CRÍTICO: El intruso de Producción PUDO conectarse a Dev. (Asegúrate de estar usando un CNI)."
fi

# Limpieza del namespace temporal de prueba
kubectl delete namespace greendev-prod --ignore-not-found=true > /dev/null 2>&1

echo -e "\n=========================================================="
echo "🎉 Pruebas finalizadas."
echo "=========================================================="
