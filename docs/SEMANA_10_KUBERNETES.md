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
|   +-------------------+          +-------------------+      |
|   |   Service Nginx   |          |   Service App     |      |
|   |    (NodePort)     +--------->|   (ClusterIP)     |      |
|   +-------------------+  Proxy   +---------+---------+      |
|             |            Pass              |                |
|             v                              v                |
|   +-------------------+          +-------------------+      |
|   | Deployment Nginx  |          | Deployment App    |      |
|   |   (1 Réplica)     |          |   (2 Réplicas)    |      |
|   +-------------------+          +---------+---------+      |
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

## 3. Manual Paso a Paso: Levantar, Probar y Borrar

### 3.1. Levantar el Entorno Manualmente (Vía kubectl)
Este proceso era la forma manual empleada en la Semana 10 antes de la introducción de Terraform. Aún puedes ejecutarlo usando el script de automatización antiguo:
```bash
./scripts/setup_k8s.sh
```

**Si prefieres hacerlo comando a comando:**
1. Iniciar Minikube: `minikube start`
2. Aplicar los manifiestos YAML:
   ```bash
   kubectl apply -f kubernetes/
   ```

### 3.2. Probar la Resiliencia (Auto-Healing y Escalado)
Puedes probar las capacidades dinámicas de Kubernetes:

1. **Prueba de Escalado:**
   ```bash
   kubectl scale deployment nginx --replicas=3
   kubectl get pods -l app=frontend
   ```
2. **Prueba de Auto-Recuperación (Self-healing):**
   ```bash
   # Obtén el nombre de un pod y mátalo
   kubectl delete pod -l app=backend
   
   # Observa cómo Kubernetes levanta otro en segundos
   kubectl get pods -w
   ```
3. **Prueba de Conectividad:**
   ```bash
   minikube service nginx-service --url
   ```

### 3.3. Borrar el Entorno
Elimina todos los recursos declarados en los ficheros YAML:
```bash
kubectl delete -f kubernetes/
```
*(Y si quieres apagar el nodo: `minikube stop`)*
