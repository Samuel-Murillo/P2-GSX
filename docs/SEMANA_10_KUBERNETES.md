# Semana 10: Arquitectura en Kubernetes

Este apartado describe la migración de la infraestructura de GreenDevCorp hacia Kubernetes, transformando los servicios de Docker Compose en recursos nativos de K8s.

## 1. Diagrama de Arquitectura (Kubernetes)

```text
+-------------------------------------------------------------+
|                     Host / Entorno Externo                  |
|                       [ Usuario Final ]                     |
+------------------------------+------------------------------+
                               |
                               | Petición HTTP (Puerto NodePort: 30080)
                               v
+-------------------------------------------------------------+
|                 Clúster Kubernetes (Minikube)               |
|                                                             |
|   +-------------------+                                     |
|   |   Service Nginx   |                                     |
|   |    (NodePort)     |                                     |
|   +---------+---------+                                     |
|             |                                               |
|             v                                               |
|   +-------------------+          +-------------------+      |
|   | Deployment Nginx  |          |   Service App     |      |
|   |   (1 Réplica)     +--------->|   (ClusterIP)     |      |
|   +-------------------+  Proxy   +---------+---------+      |
|                          Pass              |                |
|                                            v                |
|                                  +-------------------+      |
|                                  | Deployment App    |      |
|                                  |   (2 Réplicas)    |      |
|                                  +---------+---------+      |
|                                            | Conexión TCP   |
|                                            | (Puerto 5432)  |
|                                            v                |
|                                  +-------------------+      |
|                                  |   Service DB      |      |
|                                  |   (ClusterIP)     |      |
|                                  +---------+---------+      |
|                                            |                |
|                                            v                |
|                                  +-------------------+      |
|                                  | StatefulSet DB    |      |
|                                  |   (1 Réplica)     |      |
|                                  +---------+---------+      |
+--------------------------------------------|----------------+
                                             | Montaje persistente
                                             | /var/lib/postgresql/data
                                             v
+-------------------------------------------------------------+
|                  Almacenamiento Persistente                 |
|                   [( PersistentVolume )]                    |
+-------------------------------------------------------------+
```

## 2. Decisiones de Diseño y Recursos

*   **ConfigMap & Secret:**
    La configuración estática se abstrajo en `ConfigMap`. Valores sensibles como la contraseña de BD se metieron en un `Secret` codificado en base64.
*   **StatefulSet (Base de Datos):**
    Utilizamos un `StatefulSet` en lugar de un `Deployment` para PostgreSQL. 
    **Justificación:** Las bases de datos requieren identificadores de red estables y un orden estricto de arranque/montaje de volúmenes que los Deployments no garantizan.
*   **Deployments (App y Nginx):**
    El backend arranca con 2 réplicas para garantizar alta disponibilidad. Al ser *stateless*, los Deployments son el controlador ideal.
*   **Services (ClusterIP y NodePort):**
    - `ClusterIP`: Permite resolución DNS interna entre los pods sin depender de IPs inestables.
    - `NodePort`: Abre un puerto físico en el nodo (Minikube) para tráfico externo.

## 3. Scripts de Automatización y Pruebas

Para facilitar la administración, el despliegue y las pruebas en Kubernetes, se han preparado diversos scripts automatizados:

### 3.1. Script de Despliegue (`k8s_deploy.sh`)
Este script (anteriormente `k8s_setup_manually.sh`) automatiza el despliegue del entorno:
* **¿Qué hace?** Configura el cliente de Docker para apuntar al daemon interno de Minikube, compila las imágenes localmente (garantizando que K8s use la versión exacta de tu código) y aplica de golpe todos los manifiestos YAML de la carpeta `kubernetes/`.
```bash
./scripts/k8s_deploy.sh
```

### 3.2. Script de Verificación de Salud (`k8s_check_health.sh`)
Automatiza las pruebas de resiliencia y el estado del clúster.
* **¿Qué hace?** Verifica que todos los recursos estén corriendo. Luego, realiza pruebas de **escalado** (aumentando réplicas de Nginx) y de **auto-recuperación** (eliminando intencionadamente pods del backend para comprobar que Kubernetes los recrea en segundos para mantener la alta disponibilidad).
```bash
./scripts/k8s_check_health.sh
```

### 3.3. Script de Auditoría de Seguridad (`k8s_check_security.sh`)
Verifica empíricamente que el aislamiento de red (NetworkPolicies) funciona correctamente.
* **¿Qué hace?** Lanza pods "intrusos" y simula conexiones cruzadas no autorizadas (ej. intentar acceder a la base de datos sin tener los labels adecuados, o intentar saltar desde el entorno de Producción a Desarrollo). Comprueba que Kubernetes bloquea activamente este tráfico (Timeout).
```bash
./scripts/k8s_check_security.sh
```

## 4. Comandos Manuales (Paso a Paso con kubectl)

Si prefieres realizar el control total manualmente sin usar los scripts anteriores:

### 4.1. Despliegue Manual
1. **Iniciar el clúster:**
   ```bash
   minikube start
   ```
2. **Aplicar los manifiestos YAML:**
   ```bash
   kubectl apply -f kubernetes/
   ```

### 4.2. Pruebas de Resiliencia Manuales
1. **Prueba de Escalado:**
   ```bash
   kubectl scale deployment nginx --replicas=3
   kubectl get pods -l app=frontend
   ```
2. **Prueba de Auto-Recuperación (Self-healing):**
   ```bash
   kubectl delete pod -l app=backend
   kubectl get pods -w
   ```
3. **Prueba de Conectividad (URL):**
   ```bash
   minikube service nginx-service --url
   ```

### 3.4. Borrar el Entorno
Elimina todos los recursos declarados en los ficheros YAML:
```bash
kubectl delete -f kubernetes/
```
*(Y si quieres apagar el nodo: `minikube stop`)*
