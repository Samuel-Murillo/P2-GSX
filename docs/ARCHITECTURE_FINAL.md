# Arquitectura Final de GreenDevCorp

## 1. Diagrama de Arquitectura Global (Contenedores, Redes y Flujos)

El siguiente diagrama detalla la arquitectura técnica implementada en Kubernetes y gestionada mediante **Terraform (IaC)**. Incluye la segmentación de red por puertos y la capa de seguridad impuesta por las **NetworkPolicies**.

```mermaid
graph TD
    %% Entidades Externas
    Client([Usuario/Cliente Externo])

    %% Infraestructura Terraform
    subgraph "Infraestructura GreenDevCorp (Terraform)"
        %% Cluster Kubernetes
        subgraph "Kubernetes Cluster (Minikube)"
            
            %% Namespace dinámico
            subgraph "Namespace: greendev-dev"
                
                %% Capa de Red Segura (Network Policies)
                subgraph "Capa de Seguridad: NetworkPolicies (Default Deny)"
                
                    %% Nginx Ingress/Proxy
                    subgraph "Capa de Presentación"
                        NginxService[Nginx Service<br/>NodePort: 30080]
                        NginxPods[Nginx Pods<br/>Deployment: 1 réplica]
                    end

                    %% App Backend
                    subgraph "Capa de Aplicación"
                        AppService[App Service<br/>ClusterIP: 3000]
                        AppPods[Node.js App Pods<br/>Deployment: 2 réplicas]
                        AppConfig[ConfigMap: greendev-config]
                        AppSecrets[Secret: greendev-secret]
                    end

                    %% Base de Datos
                    subgraph "Capa de Datos"
                        DBService[DB Service<br/>ClusterIP: 5432]
                        DBPods[PostgreSQL Pod<br/>StatefulSet: 1 réplica]
                        DBStorage[(Persistent Volume Claim)]
                    end
                end
            end
        end
    end

    %% Conexiones y Flujos de Datos con Puertos
    Client -- "HTTP (Port 30080)" --> NginxService
    NginxService -- "Balanceo Round Robin" --> NginxPods
    NginxPods -- "HTTP Proxy Pass (Port 3000)" --> AppService
    AppService -- "Service Discovery DNS" --> AppPods
    AppPods -- "TCP Connection (Port 5432)" --> DBService
    DBService -- "Headless Routing" --> DBPods
    DBPods -- "Montaje RWO" --> DBStorage
    
    %% Inyección de Configuración
    AppConfig -. "Env Vars" .-> AppPods
    AppSecrets -. "Encrypted Vars" .-> AppPods
    AppSecrets -. "Encrypted Vars" .-> DBPods

    %% Estilos
    classDef service fill:#d4edda,stroke:#28a745,stroke-width:2px;
    classDef pod fill:#cce5ff,stroke:#007bff,stroke-width:2px;
    classDef external fill:#f8d7da,stroke:#dc3545,stroke-width:2px;
    classDef storage fill:#fff3cd,stroke:#ffc107,stroke-width:2px;
    classDef policy fill:#ffffff,stroke:#6c757d,stroke-dasharray: 5 5;

    class NginxService,AppService,DBService service;
    class NginxPods,AppPods,DBPods pod;
    class DBStorage storage;
    class Client external;
```

## 2. Detalle de Flujos de Datos y Red

El recorrido de una petición desde el exterior hasta la persistencia de datos está estrictamente controlado por políticas de red:

1. **Recepción Externa (Port 30080):** El tráfico llega al puerto físico de Minikube. El `Nginx Service` de tipo NodePort redirige la petición hacia el pod de Nginx.
2. **Capa de Seguridad 1 (Ingress Policy):** La NetworkPolicy del frontend solo permite tráfico entrante desde la red permitida hacia el puerto 80/443 del contenedor.
3. **Capa Proxy a App (Port 3000):** Nginx actúa como proxy inverso. El tráfico viaja internamente mediante el `App Service` (ClusterIP). La NetworkPolicy del backend **deniega** cualquier conexión que no provenga específicamente de un pod etiquetado como `app=frontend`.
4. **Capa App a DB (Port 5432):** La aplicación Node.js procesa la lógica y consulta la base de datos. La conexión utiliza el nombre DNS interno `db-service`. 
5. **Capa de Seguridad 2 (DB Protection):** La NetworkPolicy de la base de datos es la más restrictiva: **solo acepta tráfico entrante desde el Backend**. Intentar conectar desde el frontend o desde un pod de "debugging" resultará en un rechazo inmediato por red.
6. **Persistencia:** El pod de PostgreSQL (gestionado como un **StatefulSet** para garantizar identidad estable) escribe en el volumen montado a través del PVC.

## 3. Documentación de Microservicios

Todo el ecosistema está orquestado exclusivamente mediante **Terraform**, que aplica los manifiestos correspondientes utilizando el provider de Kubernetes.

### 3.1 Nginx (Proxy Inverso)
* **Función:** Balanceador de carga y terminador de tráfico externo.
* **Recurso K8s:** Deployment (1 réplica) + Service (NodePort).
* **Seguridad:** Aislado mediante `frontend-policy`.

### 3.2 Node.js Application (Backend)
* **Función:** Ejecución de la lógica de negocio y procesamiento de API.
* **Recurso K8s:** Deployment (2 réplicas) + Service (ClusterIP).
* **Configuración:** Consume variables del ConfigMap `greendev-config` y secretos de `greendev-secret`.

### 3.3 PostgreSQL (Capa de Datos)
* **Función:** Almacenamiento persistente relacional.
* **Recurso K8s:** **StatefulSet** (1 réplica) + Service (ClusterIP/Headless).
* **Persistencia:** Utiliza un `PersistentVolumeClaim` vinculado a un volumen local en Minikube para asegurar que los datos sobreviven a reinicios.
