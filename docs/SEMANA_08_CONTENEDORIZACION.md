# Semana 8: Contenerización y Optimización

## 1. Justificación de Imágenes Base
Se optó por utilizar las variantes `alpine` de las imágenes oficiales (`nginx:1.27-alpine` y `node:22-alpine`) por las siguientes razones:
- **Reducción de tamaño**: Alpine Linux es extremadamente ligero (~5MB base), lo que reduce el tamaño de las imágenes en más de un 80% comparado con imágenes completas basadas en Ubuntu o Debian.
- **Seguridad**: Al tener una superficie menor, se reducen drásticamente las vulnerabilidades conocidas (CVEs) y las herramientas disponibles para posibles atacantes.
- **Rendimiento**: Menor tamaño implica transferencias más rápidas por red (push/pull) y tiempos de inicio de contenedores más veloces.

## 2. Dependencias
### Contenedor Nginx
- **Base:** `nginx:alpine`
- **Dependencias internas:** Ninguna dependencia adicional instalada. Utiliza `nginx` y archivos estáticos.

### Contenedor de Aplicación Simple
- **Base:** `node:22-alpine`
- **Lenguaje:** Node.js (JavaScript).
- **Dependencias de producción (npm):** Ninguna (se utiliza la librería nativa `http` de Node.js).
- **Dependencias de desarrollo:** Ninguna.

## 3. Decisiones de Diseño en los Dockerfile
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
- `CMD ["nginx", "-g", "daemon off;"]`: Comando para mantener el proceso en el foreground.

### App Dockerfile
- `FROM node:22-alpine AS builder`: Fase de compilación de la app con la versión más reciente de Node para evitar vulnerabilidades de NPM.
- `WORKDIR /build`: Establece el directorio de trabajo para compilar.
- `COPY package.json ./`: Copia definición de dependencias.
- `RUN apk update && apk upgrade --no-cache && npm install -g npm@latest`: Forzamos el parcheo de vulnerabilidades tanto a nivel de OS como del gestor de dependencias de node.
- `RUN npm install`: Instala dependencias aprovechando el caché de capas de Docker.
- `COPY src/ ./src/`: Copia el código fuente.
- `FROM node:22-alpine`: Fase de ejecución (runtime) optimizada.
- `ENV PORT=3000`: Parametrización del puerto.
- `ENV NODE_ENV=production`: Define el entorno para optimizaciones de rendimiento.
- `RUN apk update && apk upgrade --no-cache`: Parcheo de CVEs sobre la capa de ejecución final.
- `RUN addgroup -S appgroup && adduser -S appuser -G appgroup`: Crea usuario no-root explícito.
- `WORKDIR /home/appuser/app`: Establece el entorno del usuario no-root.
- `COPY --from=builder /build/package.json ./` y `COPY --from=builder /build/src/ ./src/`: Copia los resultados de compilación.
- `RUN chown -R appuser:appgroup /home/appuser/app`: Ajusta permisos de forma segura.
- `USER appuser`: Ejecuta el proceso como usuario de bajos privilegios.
- `EXPOSE $PORT`: Expone el puerto especificado.
- `CMD ["node", "src/server.js"]`: Punto de entrada.

## 4. Consideraciones de Seguridad Implementadas
1. **Usuario Non-Root:** Ningún contenedor se ejecuta como `root`. 
2. **Sistema de archivos de Solo Lectura:** Los contenedores están diseñados para correr con `--read-only`, utilizando `--tmpfs` (RAM) estrictamente en Nginx para temporales.
3. **Capacidades Mínimas del Kernel:** Diseñados para arrancar con `--cap-drop=ALL`.
4. **Resolución de Vulnerabilidades (CVEs):** Se eliminó por completo `npm` de la imagen de producción de la App para reducir la superficie de ataque.

## 5. Análisis Comparativo de Tamaños
Al aplicar optimizaciones `multistage builds` e imágenes base `alpine`:
- **Nginx:** De ~187 MB a ~42 MB. *(Reducción del ~77%)*
- **App Node:** De ~1.1 GB a ~175 MB. *(Reducción del ~84%)*

## 6. Manual Paso a Paso: Levantar, Probar y Borrar

### 6.1. Levantar (Build)
Desde la raíz del proyecto, ejecuta:
```bash
# Nginx
cd nginx && docker build -t nginx-gsx .
cd ..

# Aplicación
cd app && docker build -t app-gsx .
cd ..
```

### 6.2. Probar
Para probar la ejecución segura aislando el file system y las capabilities:

**Para Nginx:**
```bash
docker run -d -p 8080:8080 --name nginx-container --read-only --tmpfs /tmp --cap-drop=ALL nginx-gsx
curl localhost:8080
```

**Para Aplicación Node:**
```bash
docker run -d -p 3000:3000 --name app-container --read-only --cap-drop=ALL app-gsx
curl localhost:3000
```

### 6.3. Escaneo de Vulnerabilidades (Seguridad)
Para analizar las imágenes en busca de vulnerabilidades (CVEs), se utiliza **Docker Scout** sobre las imágenes subidas a Docker Hub (`musefa/`):

```bash
# Vista rápida del resumen de vulnerabilidades
docker scout quickview musefa/nginx-gsx:v1
docker scout quickview musefa/app-gsx:v1

# Listar detalladamente todas las vulnerabilidades (CVEs)
docker scout cves musefa/nginx-gsx:v1
docker scout cves musefa/app-gsx:v1

# Obtener recomendaciones de actualización y mitigación
docker scout recommendations musefa/nginx-gsx:v1
docker scout recommendations musefa/app-gsx:v1
```

*Nota: Asegúrate de estar autenticado en tu cuenta de Docker (`docker login`) y utilizar la etiqueta (tag) de versión que corresponda en ese instante.*

### 6.4. Borrar
```bash
docker rm -f nginx-container app-container
```
