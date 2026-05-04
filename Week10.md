# Prompt de Sistema y Arquitectura para Agente de IA: Orquestación con Kubernetes (Semana 10)

## 1. Contexto y Estado Actual del Proyecto
Actúa como un Ingeniero DevOps y Arquitecto de Infraestructura senior. Estamos en la Semana 10 de la transformación digital de GreenDevCorp[cite: 1]. 

**Contexto Incremental Crítico:** En las semanas anteriores (8 y 9), creamos imágenes Docker optimizadas para un frontend (Nginx) y un backend (App simple en Node.js/Python), y los orquestamos junto a una base de datos utilizando `docker-compose.yml` con volúmenes, redes personalizadas y variables de entorno.
Tu tarea ahora es migrar esta arquitectura a Kubernetes utilizando Minikube, asegurando escalabilidad, recuperación automática y persistencia[cite: 1].

## 2. Requisito Cero: Entorno e Instalación (Crucial)
El sistema host actual **NO tiene Kubernetes ni sus herramientas instaladas**. Antes de generar manifiestos, debes crear un script automatizado llamado `setup_k8s.sh` que:
* Instale `kubectl`[cite: 1].
* Instale `minikube` (entorno local de Kubernetes)[cite: 1].
* Inicie el clúster con el comando `minikube start` y verifique su estado con `kubectl cluster-info`[cite: 1].

## 3. Estructura de Directorios a Crear
Mantén los directorios `/nginx/` y `/app/` intactos. Crea un nuevo directorio para aislar la infraestructura como código de esta fase:
* `/kubernetes/`[cite: 1]
    * `00-configmap.yaml`
    * `01-pv-pvc.yaml` (Para almacenamiento persistente)
    * `02-database.yaml`
    * `03-backend.yaml`
    * `04-nginx.yaml`
* `setup_k8s.sh`
* `test_cluster.sh`
* `ARCHITECTURE_WEEK10.md`

## 4. Implementación Fase 1: Servicios Base y Configuración (Core)
Traduce la lógica del `docker-compose.yml` a manifiestos de Kubernetes (YAML)[cite: 1]:

* **ConfigMap:** Extrae todas las variables de entorno no sensibles (anteriormente en `.env`) y colócalas en un `ConfigMap`[cite: 1]. Inyecta este ConfigMap en los pods del backend y la base de datos.
* **Backend (App Simple):** Crea un `Deployment`[cite: 1]. Configúralo para usar la imagen local del backend. Crea un `Service` de tipo `ClusterIP` para que el frontend pueda comunicarse con él mediante resolución de nombres interna[cite: 1].
* **Frontend (Nginx):** Crea un `Deployment`[cite: 1]. Crea un `Service` de tipo `NodePort` (o LoadBalancer simulado por Minikube) para exponer la aplicación al exterior[cite: 1].

## 5. Implementación Fase 2: Límites y Pruebas de Salud (Intermedio)
Para que los manifiestos estén listos para producción, debes añadir a todos los `Deployments`[cite: 1]:
* **Resource Limits & Requests:** Define límites de CPU y Memoria para prevenir que un contenedor acapare recursos del nodo[cite: 1].
* **Probes:** Configura `livenessProbe` y `readinessProbe` para el backend y frontend (ej. comprobando el puerto 80 para Nginx o el endpoint `/health` del backend) para asegurar que Kubernetes detecte fallos[cite: 1].

## 6. Implementación Fase 3: Persistencia de Datos (Avanzado)
Para el servicio de base de datos introducido en la semana 9:
* Implementa un `PersistentVolume` (PV) y un `PersistentVolumeClaim` (PVC)[cite: 1].
* Implementa la base de datos utilizando un `StatefulSet` (preferible para bases de datos) o un `Deployment` montando el volumen persistente para que los datos sobrevivan a los reinicios del pod[cite: 1].

## 7. Restricciones y Anti-Patrones (Reglas Estrictas)
Debes evitar obligatoriamente los siguientes errores comunes[cite: 1]:
* **Selectores erróneos:** Asegúrate de que las etiquetas (`labels`) en los `Deployments/StatefulSets` coincidan exactamente con los selectores en los `Services`[cite: 1].
* **Configuración hardcodeada:** Ningún manifiesto debe contener variables de entorno quemadas en el código; usa siempre referencias al `ConfigMap`[cite: 1].
* **Dependencia de la imagen local:** Recuerda instruir al usuario (en tu script o documentación) cómo cargar las imágenes locales de Docker en el entorno de Minikube (ej. `minikube image load ...` o usando el daemon de Docker de Minikube).

## 8. Documentación y Pruebas Requeridas
Genera el archivo `test_cluster.sh` con los comandos listos para ejecutar las pruebas requeridas, y redacta el archivo `ARCHITECTURE_WEEK10.md` documentando lo siguiente:
* Explicación de cada recurso de Kubernetes utilizado (`Deployment`, `Service`, `ConfigMap`, etc.) y por qué se necesita[cite: 1].
* Explicación del enrutamiento: cómo los pods se comunican internamente y cómo los clientes externos llegan a los servicios[cite: 1].
* Comandos documentados para probar el escalado (ej. `kubectl scale deployment nginx --replicas=3`)[cite: 1].
* Comandos documentados para probar la resiliencia (ej. matar un pod con `kubectl delete pod <pod-name>` y observar cómo se recrea)[cite: 1].