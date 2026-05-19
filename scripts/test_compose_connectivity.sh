#!/bin/bash

# Asegurar que se detiene el script en caso de error
set -e

echo "=== Iniciando pruebas de conectividad de Docker Compose ==="
echo "Este script verifica que los contenedores puedan comunicarse entre sí"
echo "mediante resolución DNS interna en la red 'greendev_net'."
echo ""

# Función para realizar el ping y verificar
test_ping() {
    local from=$1
    local to=$2
    
    echo -n "Probando conectividad desde '$from' hacia '$to'... "
    # ping -c 1 manda un solo paquete. Se redirige la salida para no ensuciar la consola.
    if docker compose exec "$from" ping -c 1 "$to" > /dev/null 2>&1; then
        echo "✅ OK"
    else
        echo "❌ FALLÓ"
        exit 1
    fi
}

echo "1. Verificando conectividad desde Nginx (Frontend Proxy)..."
test_ping nginx app
test_ping nginx db

echo ""
echo "2. Verificando conectividad desde App (Backend)..."
test_ping app nginx
test_ping app db

echo ""
echo "3. Verificando conectividad desde Base de Datos (DB)..."
test_ping db nginx
test_ping db app

echo ""
echo "=== ✅ Todas las pruebas de conectividad pasaron correctamente! ==="
echo "Esto demuestra que los contenedores están en la misma red y se reconocen por su nombre de servicio."
