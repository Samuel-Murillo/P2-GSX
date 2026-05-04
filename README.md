# Proyecto de Contenerización - GreenDevCorp

Este repositorio contiene la arquitectura de contenerización para las aplicaciones iniciales de GreenDevCorp, cumpliendo con los estándares de diseño, optimización y seguridad solicitados.

## 1. Justificación de Imágenes Base (Semana 8)

Se optó por utilizar las variantes `alpine` de las imágenes oficiales (`nginx:1.27-alpine` y `node:22-alpine`) por las siguientes razones:
- **Reducción de tamaño**: Alpine Linux es extremadamente ligero (~5MB base), lo que reduce el tamaño de las imágenes en más de un 80% comparado con imágenes completas basadas en Ubuntu o Debian.
- **Seguridad**: Al tener una superficie menor, se reducen drásticamente las vulnerabilidades conocidas (CVEs) y las herramientas disponibles para posibles atacantes.
- **Rendimiento**: Menor tamaño implica transferencias más rápidas por red (push/pull) y tiempos de inicio de contenedores más veloces.

## 2. Dependencias (Semana 8)

### Contenedor Nginx
- **Base:** `nginx:alpine`
- **Dependencias internas:** Ninguna dependencia adicional instalada. Utiliza `nginx` y archivos estáticos.

### Contenedor de Aplicación Simple
- **Base:** `node:22-alpine`
- **Lenguaje:** Node.js (JavaScript).
- **Dependencias de producción (npm):** Ninguna (se utiliza la librería nativa `http` de Node.js).
- **Dependencias de desarrollo:** Ninguna.

## 3. Decisiones de Diseño en los Dockerfile (Semana 8)

### Nginx Dockerfile
- `FROM alpine:latest AS builder`: Utilizamos un multistage build. La primera fase (builder) usa alpine base parcheada.
- `RUN mkdir /site && echo "<h1>Welcome to GreenDevCorp Nginx</h1>" > /site/index.html`: Creamos los artefactos de la aplicación en esta primera etapa.
- `FROM nginx:1.27-alpine`: Iniciamos la fase de runtime usando la imagen mínima de nginx en una versión actualizada.
- `RUN apk update && apk upgrade --no-cache`: Ejecutado para mitigar cualquier vulnerabilidad de paquetes OS (CVE) inyectando los últimos parches sin ensuciar la caché.
- `ENV NGINX_PORT=8080`: No hardcodeamos el puerto, lo parametrizamos en una variable de entorno.
- `COPY --from=builder /site/index.html /usr/share/nginx/html/index.html`: Copiamos solo el artefacto generado en el build, asegurando que no arrastramos basura de compilación.
- `COPY nginx.conf /etc/nginx/nginx.conf`: Copiamos la configuración personalizada adaptada a non-root.
- `RUN chown -R nginx:nginx ...`: Cambiamos los permisos de las carpetas a las que nginx necesita acceder temporalmente, para no depender de root.
- `USER nginx`: Principio de menor privilegio (non-root explícito).
- `EXPOSE $NGINX_PORT`: Declaramos el puerto en el que escucha el contenedor.
- `CMD ["nginx", "-g", "daemon off;"]`: Comando para mantener el proceso en el foreground y no permitir que el contenedor se apague.

### App Dockerfile
- `FROM node:22-alpine AS builder`: Fase de compilación de la app con la versión más reciente de Node para evitar vulnerabilidades de NPM.
- `WORKDIR /build`: Establece el directorio de trabajo para compilar.
- `COPY package.json ./`: Copia definición de dependencias.
- `RUN apk update && apk upgrade --no-cache && npm install -g npm@latest`: Forzamos el parcheo de vulnerabilidades tanto a nivel de OS como del gestor de dependencias de node.
- `RUN npm install`: Instala dependencias (si las hubiera) aprovechando el caché de capas de Docker.
- `COPY src/ ./src/`: Copia el código fuente.
- `FROM node:22-alpine`: Fase de ejecución (runtime) optimizada.
- `ENV PORT=3000`: Parametrización del puerto.
- `ENV NODE_ENV=production`: Define el entorno para que Node aplique optimizaciones de rendimiento.
- `RUN apk update && apk upgrade --no-cache`: Parcheo de CVEs sobre la capa de ejecución final, asegurando que paquetes como `zlib` o `busybox` estén actualizados.
- `RUN addgroup -S appgroup && adduser -S appuser -G appgroup`: Crea usuario no-root explícito por seguridad.
- `WORKDIR /home/appuser/app`: Establece el entorno del usuario no-root.
- `COPY --from=builder /build/package.json ./` y `COPY --from=builder /build/src/ ./src/`: Copia los resultados de la compilación en la imagen final.
- `RUN chown -R appuser:appgroup /home/appuser/app`: Ajusta permisos de forma segura para la aplicación.
- `USER appuser`: Ejecuta el proceso como usuario de bajos privilegios.
- `EXPOSE $PORT`: Expone el puerto especificado en la variable de entorno.
- `CMD ["node", "src/server.js"]`: Punto de entrada de la aplicación.

## 4. Manual de Compilación y Ejecución (Semana 8)

### Construcción (Build)
Desde la raíz del proyecto, ejecuta:
```bash
# Para construir nginx
cd nginx && docker build -t nginx-gsx .
cd ..

# Para construir la aplicación
cd app && docker build -t app-gsx .
cd ..
```

### Ejecución Local de Forma Segura
Para asegurar la ejecución segura (read-only filesystem y drop capabilities limitadas):

**Para Nginx:**
```bash
docker run -d -p 8080:8080 \
  --name nginx-container \
  --read-only \
  --tmpfs /tmp \
  --cap-drop=ALL \
  nginx-gsx
```
*Puedes verificarlo con `curl localhost:8080`*

**Para Aplicación Node:**
```bash
docker run -d -p 3000:3000 \
  --name app-container \
  --read-only \
  --cap-drop=ALL \
  app-gsx
```
*Puedes verificarlo con `curl localhost:3000`*

## 5. Análisis Comparativo de Tamaños (Semana 8)

Al aplicar optimizaciones `multistage builds` e imágenes base `alpine`:
- **Nginx (Antes: `nginx:latest`):** ~187 MB.
- **Nginx (Después: `nginx:alpine` + multistage):** ~42 MB. *(Reducción del ~77%)*
- **App Node (Antes: `node:latest` basada en Debian):** ~1.1 GB.
- **App Node (Después: `node:18-alpine` + multistage):** ~175 MB. *(Reducción del ~84%)*

Estas optimizaciones garantizan descargas rápidas y menor uso de disco.

## 6. Consideraciones de Seguridad Implementadas (Semana 8)

1. **Usuario Non-Root (Principio de menor privilegio):** Ningún contenedor se ejecuta como `root`. Se ha configurado el usuario `nginx` nativo y creado `appuser`.
2. **Sistema de archivos de Solo Lectura (Read-only filesystem):** Los contenedores están diseñados para correr con `--read-only`, utilizando `--tmpfs` (RAM) estrictamente en Nginx para los directorios temporales que requieran escritura (`/tmp`).
3. **Capacidades Mínimas del Kernel:** Diseñados para funcionar levantando servicios no privilegiados (puertos > 1024, ej. 8080, 3000). Permite arrancar los contenedores con la bandera `--cap-drop=ALL`.
4. **Resolución de Vulnerabilidades y Gestión de CVEs:** Se incluyó el paso `RUN apk upgrade --no-cache` en todos los contenedores para eliminar fallos pre-existentes en los paquetes base. Se ha forzado el uso de versiones mayores (Node 22, Nginx 1.27) y **se ha eliminado por completo `npm`** de la imagen de producción de la App para reducir la superficie de ataque y eliminar decenas de vulnerabilidades asociadas a sus dependencias internas.
5. **Archivos `.dockerignore`:** Se incluyeron para prevenir fugas de secretos locales, basura o directorios `.git` hacia el contexto del build.
6. **Configuración Dinámica:** Sin variables hardcodeadas, se utilizaron sentencias de configuración `ENV`.

### Escaneo de Vulnerabilidades
Se requiere y documenta escanear las imágenes construidas y descargadas utilizando:
```bash
docker scout cves nginx-gsx
docker scout cves app-gsx
docker scout cves postgres-gsx
```

### Gestión de Riesgos y Falsos Positivos (Vulnerabilidades Residuales)
Tras la auditoría de seguridad de la imagen `postgres-gsx`, es posible que herramientas como Docker Scout sigan reportando vulnerabilidades. En un entorno de producción DevOps, estas se documentan y asumen bajo las siguientes justificaciones:

1. **Paquetes sin parche oficial (`busybox`, `openldap`):** Docker Scout indica que el "Fixed version" es "not fixed". Esto significa que los mantenedores de Alpine Linux aún no han liberado un parche. Al usar `RUN apk upgrade`, garantizamos tener la última versión existente. No se puede actualizar a algo que no existe.
2. **Vulnerabilidades de historial (`stdlib / gosu`):** El equipo de PostgreSQL oficial incluye el binario `gosu` (compilado en Go) en su imagen base. Aunque en nuestro `db/Dockerfile` **borramos explícitamente este archivo** y lo reemplazamos por la alternativa segura `su-exec` en C, los escáneres analizan todas las capas históricas de la imagen y seguirán detectando el archivo original de la capa base. Al no existir en la capa final ejecutable, se considera un **Falso Positivo** mitigado.

Se asume mantener la imagen base `alpine` (en lugar de migrar a `debian`) para no comprometer los drásticos beneficios de rendimiento y ahorro de tamaño demostrados en la sección 5.

## 7. Arquitectura de Orquestación (Semana 9)

Este apartado detalla la arquitectura de los servicios y la orquestación implementada en la Semana 9 para GreenDevCorp.

### 7.1. Diagrama de Arquitectura

El siguiente diagrama muestra la relación entre los contenedores, los volúmenes, la red interna y las solicitudes entrantes.

```text
+-------------------------------------------------------------+
|                     Host / Entorno Externo                  |
|                       [ Usuario Final ]                     |
+------------------------------+------------------------------+
                               |
                               | Petición HTTP (Puerto 80)
                               v
+-------------------------------------------------------------+
|                 Entorno Docker (Red: greendev_net)          |
|                                                             |
|   +-------------------+          +-------------------+      |
|   | Frontend Proxy    |          | Backend App       |      |
|   | (Nginx)           +--------->| (Node.js/Python)  |      |
|   +-------------------+  Proxy   +---------+---------+      |
|                          Pass              |                |
|                                            | Conexión TCP   |
|                                            | (Puerto 5432)  |
|                                            v                |
|                                  +-------------------+      |
|                                  | Base de Datos     |      |
|                                  | (PostgreSQL)      |      |
|                                  +---------+---------+      |
+--------------------------------------------|----------------+
                                             |
                                             | Montaje persistente
                                             | /var/lib/postgresql/data
                                             v
+-------------------------------------------------------------+
|                  Almacenamiento Persistente                 |
|                   [( Volumen: db_data )]                    |
+-------------------------------------------------------------+
```

### 7.2. Flujo de Datos y Propósito de cada Servicio

*   **Frontend Proxy (Nginx):** Funciona como proxy inverso y servidor de exposición hacia el mundo exterior. Su objetivo es recibir las peticiones por el puerto 80 del host y enrutarlas internamente al servicio `app` (el backend). Con las reglas de healthchecks establecidas, no arrancará ni enviará tráfico si la aplicación no está completamente lista.
*   **Backend (App Simple):** Contiene la lógica de negocio del servicio. Utiliza los recursos de la red interna de Docker (`greendev_net`) para contactar con la base de datos sin exponer el tráfico de conexión a nivel de host. Recibe las variables de entorno de configuración al vuelo.
*   **Base de Datos (PostgreSQL):** Almacena y provee los datos transaccionales del proyecto utilizando un contenedor mínimo basado en Alpine. Su acceso está restringido únicamente a la red interna y requiere estar completamente operativo (`pg_isready`) antes de que se levante la aplicación Backend.

### 7.3. Persistencia de Datos

Para que el estado de la aplicación no se pierda al actualizar o reiniciar los contenedores de la base de datos, se utiliza un volumen administrado por Docker (Named Volume).

*   **Volumen:** `db_data`
*   **Ruta dentro del Contenedor DB:** `/var/lib/postgresql/data`
*   **Ruta en el Host:** Gestionada de forma transparente por Docker.
*   **Justificación:** A diferencia de un *bind mount*, un *named volume* asegura un rendimiento óptimo de I/O de disco para el motor de bases de datos y es mantenido por el demonio de Docker, evitando así conflictos de permisos (UID/GID) entre el host local y el usuario non-root del contenedor.

### 7.4. Variables de Entorno y Configuración

Toda configuración sensible o dependiente del entorno está inyectada en el archivo `.env` (el cual no se encuentra versionado en Git por motivos de seguridad, guiándose a través del `.env.example`).

| Variable de Entorno | Servicio Destino | Propósito | Valor por Defecto |
| :--- | :--- | :--- | :--- |
| `NGINX_PORT_HOST` | Nginx | Puerto del host al que escucha el balanceador/proxy. | `80` |
| `NGINX_PORT_CONTAINER` | Nginx | Puerto donde atiende el proceso Nginx. | `80` |
| `NGINX_CPU_LIMIT` | Nginx | Límite máximo de CPU permitido para el proxy. | `0.5` |
| `NGINX_MEM_LIMIT` | Nginx | Límite máximo de Memoria RAM para el proxy. | `256M` |
| `APP_PORT` | App | Puerto interno en el que el servidor web de la app atiende. | `3000` |
| `APP_CPU_LIMIT` | App | Límite máximo de CPU para el backend. | `1.0` |
| `APP_MEM_LIMIT` | App | Límite máximo de Memoria RAM para el backend. | `512M` |
| `DB_VERSION` | Base de Datos | Versión de la imagen oficial de PostgreSQL a utilizar. | `15` |
| `DB_HOST` | App | Nombre DNS/alias para conectarse al contenedor BD. | `db` |
| `DB_PORT` | App | Puerto de conexión a la BD. | `5432` |
| `DB_USER` | App / DB | Usuario de conexión y administración de PostgreSQL. | `greendev_user` |
| `DB_PASSWORD` | App / DB | Contraseña secreta del usuario de PostgreSQL. | `secret_example_password` |
| `DB_NAME` | App / DB | Nombre de la base de datos a instanciar al arrancar. | `greendev_db` |
| `DB_CPU_LIMIT` | Base de Datos | Límite de procesamiento para el motor de la base de datos. | `1.0` |
| `DB_MEM_LIMIT` | Base de Datos | Límite de Memoria RAM de la base de datos. | `512M` |

## 8. Despliegue y Verificación (Semana 9)

### 8.1. Preparación del Entorno
Antes de levantar la orquestación, es necesario configurar las variables de entorno.
1. Copia la plantilla `.env.example` para crear tu propio archivo `.env`:
   ```bash
   cp .env.example .env
   ```
2. Modifica el archivo `.env` según tus necesidades. **Importante:** Este archivo ya está siendo ignorado por `.gitignore` y no se subirá al repositorio.

### 8.2. Levantar los Servicios
Utiliza Docker Compose para levantar todos los contenedores en segundo plano (detached mode).
```bash
docker compose up -d --build
```
> **Nota:** La opción `--build` asegurará que las imágenes de Nginx y App se construyan usando sus Dockerfile respectivos antes de arrancar.

### 8.3. Comprobaciones de Estado y Resiliencia
Una vez que el comando finalice, puedes verificar que los *healthchecks* y las políticas de reinicio están funcionando:

1. **Estado de los Contenedores:**
   Ejecuta el siguiente comando y verifica que la columna de estado muestre `(healthy)` tanto para el backend (`app`) como para la base de datos (`db`). Nginx debe mostrar `Up`.
   ```bash
   docker compose ps
   ```

2. **Verificar Límites de Recursos y Consumo:**
   Asegúrate de que los contenedores están respetando los límites de CPU y Memoria establecidos en el `docker-compose.yml`:
   ```bash
   docker stats --no-stream
   ```

3. **Revisar Gestión de Logs:**
   Para confirmar que los logs están activos y listos para rotar, revisa su salida:
   ```bash
   docker compose logs -f
   ```

4. **Verificar Persistencia (Volúmenes):**
   Confirma que se ha creado el volumen nombrado y revisa sus detalles:
   ```bash
   docker volume ls | grep db_data
   docker volume inspect $(docker volume ls -q | grep db_data)
   ```

### 8.4. Pruebas de Red y Conectividad
Abre tu navegador web o utiliza `curl` para verificar la conectividad:

- **Frontend (Nginx Proxy):**
  Si usas el puerto por defecto, verifica que responde y enruta al backend:
  ```bash
  curl http://localhost:80
  ```

- **Conexión Interna a la Base de Datos:**
  Verifica que PostgreSQL está listo ejecutando un comando en su contenedor:
  ```bash
  docker compose exec db psql -U greendev_user -d greendev_db -c "\dt"
  ```
  *(Debería mostrar que no se encontraron relaciones, pero confirmará que la red funciona).*

### 8.5. Apagar el Entorno
Cuando termines las pruebas, baja los contenedores de forma segura y elimina la red creada:
```bash
docker compose down
```

## 9. Arquitectura en Kubernetes (Semana 10)

Este apartado describe la migración de la infraestructura de GreenDevCorp hacia Kubernetes, transformando los servicios de Docker Compose en recursos nativos de K8s.

### 9.1. Diagrama de Arquitectura (Kubernetes)

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

### 9.2. Recursos Utilizados y Justificación

*   **ConfigMap & Secret:**
    Extraen la configuración estática (`00-configmap.yaml`). `DB_PASSWORD` se aloja en un recurso `Secret` para mayor seguridad, mientras que el resto va en el `ConfigMap`. Ambos se inyectan como variables de entorno a los pods.

*   **StatefulSet (Base de Datos):**
    Utilizamos un `StatefulSet` en lugar de un `Deployment` para PostgreSQL porque las bases de datos requieren identificadores de red estables e integridad estricta en el orden de montaje de los volúmenes (`PersistentVolumeClaim`).

*   **Deployments (App y Nginx):**
    Los servicios *stateless* (sin estado) como el proxy y el backend se manejan mediante `Deployments`. El backend arranca con 2 réplicas para garantizar alta disponibilidad.

*   **Services (ClusterIP y NodePort):**
    *   `ClusterIP`: Proporciona una IP y nombre DNS interno permanente para la base de datos (`db`) y el backend (`app`). Así Nginx puede enrutar al backend, y el backend a la base de datos, sin importar cuántos pods mueran o se recreen.
    *   `NodePort`: Abre un puerto en el host (Minikube) mapeado al puerto 80 del frontend, permitiendo que el usuario final acceda a la aplicación web.

### 9.3. Límites y Pruebas de Salud (Probes)

Cada Deployment/StatefulSet tiene configurado:
*   **Resource Limits & Requests:** Previenen que un contenedor monopolice la CPU o la memoria del clúster (Node). Los "requests" garantizan un mínimo para que Kubernetes sepa dónde agendar el pod.
*   **Liveness & Readiness Probes:**
    *   `livenessProbe`: Comprueba si el contenedor se ha bloqueado. Si falla, el clúster mata el pod y crea uno nuevo.
    *   `readinessProbe`: Comprueba si el contenedor está listo para recibir tráfico de red. Si falla, el Service deja de enviarle peticiones hasta que se recupere.

### 9.4. Pruebas de Escalado y Resiliencia

El script `test_cluster.sh` incluye comandos automatizados para demostrar el poder de K8s:

1.  **Escalado:**
    ```bash
    kubectl scale deployment nginx --replicas=3
    ```
    Este comando le dice a Kubernetes que aumente dinámicamente los pods del proxy inverso de 1 a 3 para manejar más tráfico.

2.  **Auto-Recuperación (Self-healing):**
    ```bash
    kubectl delete pod <pod-name>
    ```
    Simula una caída crítica de un contenedor. Al ejecutarse, Kubernetes detecta que el estado deseado (2 réplicas) no coincide con el actual (1 réplica) e inmediatamente levanta un nuevo pod para reemplazar al caído.

3.  **Apagar o eliminar el entorno (Equivalente a `docker compose down`):**
    Si deseas eliminar todos los recursos creados en el clúster sin apagar Minikube:
    ```bash
    kubectl delete -f kubernetes/
    ```
    Si deseas apagar por completo el clúster local de Minikube:
    ```bash
    minikube stop
    ```

