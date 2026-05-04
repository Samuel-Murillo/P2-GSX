# Prompt de Sistema y Arquitectura para Agente de IA: Orquestación Multi-Contenedor (Docker Compose)

## 1. Contexto y Estado Actual del Proyecto
Actúa como un Ingeniero DevOps y Arquitecto de Infraestructura senior. Estamos en la Semana 9 de la transformación digital de GreenDevCorp. 

**Contexto Incremental Crítico:** En la iteración anterior, ya desarrollamos y optimizamos dos contenedores (un servidor web Nginx y una aplicación HTTP simple en Node.js/Python). Estos contenedores ya implementan multistage builds, imágenes base `alpine`, usuarios non-root y sistemas de archivos read-only. 
Tu tarea ahora es orquestar estos contenedores para que trabajen juntos usando Docker Compose, añadiendo un tercer servicio de persistencia de datos, sin romper la arquitectura previa.

## 2. Estructura de Archivos a Modificar/Crear
Debes respetar la existencia de las carpetas `/nginx/` y `/app/` de la fase anterior. Tu tarea se centrará en el nuevo directorio de orquestación y en los archivos de configuración en la raíz del proyecto.

* `/` (Directorio raíz)
    * `docker-compose.yml` (Puedes ubicarlo en la raíz o en `/docker-compose/docker-compose.yml` pero debe apuntar a los contextos de build correctos)
    * `.env` (Archivo de variables, no versionado)
    * `.env.example` (Plantilla de variables)
    * `.gitignore` (Actualizado)
* `/nginx/` (MANTENER INTACTO: contiene Dockerfile y nginx.conf)
* `/app/` (MANTENER INTACTO: contiene Dockerfile y src/)

## 3. Implementación Fase 1: Servicios Base (Core)
Escribe el archivo `docker-compose.yml` definiendo la siguiente arquitectura de servicios:

### 3.1 Servicio 1: Frontend (Nginx)
* **Construcción:** Utiliza el contexto del directorio `/nginx/` o la imagen generada en la fase previa.
* **Red:** Expón el puerto 80 al host.
* **Comunicación:** Debe poder resolver y comunicarse con el backend mediante el nombre del servicio interno (ej. `http://backend:3000`).

### 3.2 Servicio 2: Backend (App Simple)
* **Construcción:** Utiliza el contexto del directorio `/app/`.
* **Configuración:** Inyecta variables de entorno provenientes del archivo `.env` (ej. puerto, credenciales de DB).

### 3.3 Servicio 3: Base de Datos/Caché (Nuevo)
* Añade un tercer servicio (ej. Redis o PostgreSQL) utilizando su imagen oficial mínima (alpine).
* **Persistencia:** Configura un volumen Docker con nombre (named volume) montado en la ruta de datos correspondiente del contenedor (ej. `/data` o `/var/lib/postgresql/data`) para asegurar que la información sobreviva a los reinicios.

## 4. Implementación Fase 2: Resiliencia (Intermedio)
Mejora el `docker-compose.yml` con los siguientes controles de ciclo de vida:

* **Health Checks:** Configura la directiva `healthcheck` para el Backend y el servicio de Base de Datos. El backend debe comprobar un endpoint HTTP básico (ej. `/health`) o la disponibilidad del puerto.
* **Dependencias y Orden de Inicio:** Configura la directiva `depends_on` usando la condición `service_healthy`. El Backend debe esperar a que la Base de Datos esté lista, y Nginx debe esperar a que el Backend esté listo.
* **Políticas de Reinicio:** Establece la directiva `restart: always` (o `unless-stopped`) para garantizar que los contenedores se recuperen automáticamente ante fallos.

## 5. Implementación Fase 3: Redes y Límites (Avanzado)
Aplica los siguientes estándares de producción al despliegue:

* **Redes Personalizadas:** Define explícitamente una red puente personalizada (custom network) en lugar de usar la red por defecto. Todos los servicios deben pertenecer a esta red.
* **Gestión de Logs:** Configura el driver de logs (`json-file`) en cada servicio, estableciendo un límite estricto de tamaño (`max-size: "10m"`) y número de archivos rotados (`max-file: "3"`) para evitar que saturen el disco.
* **Límites de Recursos:** Configura límites estrictos de CPU y Memoria usando el bloque `deploy.resources` (o las directivas correspondientes para Compose V2) para prevenir que un contenedor comprometa el host.

## 6. Restricciones y Anti-Patrones (Reglas Estrictas)
El agente de IA debe cumplir obligatoriamente lo siguiente:
* Cero variables de configuración estáticas (hardcoded) en el código o en el YAML. Todo debe venir del archivo `.env`.
* Prohibido crear archivos `.env` con secretos reales y luego incluirlos en Git. Debes modificar el `.gitignore` para excluir el `.env` y generar únicamente un `.env.example` con valores falsos o en blanco.
* Los nombres de los servicios en las cadenas de conexión (connection strings) deben coincidir exactamente con los declarados en el YAML.

## 7. Documentación Requerida
Genera un archivo `ARCHITECTURE_WEEK9.md` que complemente el `README.md` de la semana pasada, incluyendo:
* Un diagrama de arquitectura en formato Mermaid (texto) o ASCII mostrando cómo los tres servicios se conectan entre sí a través de la red personalizada.
* Explicación del flujo de datos y el propósito de cada servicio.
* Documentación técnica sobre la persistencia: qué volúmenes existen, qué datos guardan y por qué son necesarios.
* Una tabla con todas las variables de entorno utilizadas, su propósito y valores por defecto esperados.