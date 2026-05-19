# Semana 9: Arquitectura de Orquestación (Docker Compose)

Este apartado detalla la arquitectura de los servicios y la orquestación implementada en la Semana 9 utilizando Docker Compose para establecer la red y comunicación multicontenedor.

## 1. Diagrama de Arquitectura

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
                                             | Montaje persistente
                                             | /var/lib/postgresql/data
                                             v
+-------------------------------------------------------------+
|                  Almacenamiento Persistente                 |
|                   [( Volumen: db_data )]                    |
+-------------------------------------------------------------+
```

## 2. Decisiones y Flujo de Datos

*   **Frontend Proxy (Nginx):** Recibe las peticiones por el puerto 80 del host y las enruta al servicio `app` (el backend). Cuenta con healthchecks para no arrancar hasta que la aplicación esté operativa.
*   **Backend (App Simple):** Utiliza la red interna de Docker (`greendev_net`) para contactar con la base de datos sin exponerla a nivel de host.
*   **Base de Datos (PostgreSQL):** Acceso restringido a la red interna. El backend depende de que esta BD devuelva el estado `pg_isready` antes de arrancar.

### Persistencia de Datos
Se utiliza un volumen administrado por Docker (Named Volume) llamado `db_data` en lugar de un *bind mount*.
*   **Justificación:** Un *named volume* asegura un rendimiento óptimo de I/O de disco para bases de datos y evita conflictos de permisos (UID/GID) entre el host local y el contenedor.

## 3. Variables de Entorno y Seguridad
Toda configuración sensible se extrajo a un archivo `.env` para evitar versionarla en Git. El archivo `.env.example` sirve de plantilla. Las contraseñas (como `DB_PASSWORD`) se inyectan en tiempo de ejecución.

## 4. Manual Paso a Paso: Levantar, Probar y Borrar

### 4.1. Preparación y Levantar el Entorno
Antes de levantar la orquestación, configura el entorno:
1. Copia la plantilla:
   ```bash
   cp .env.example .env
   ```
2. Modifica `.env` si lo necesitas y levanta los servicios:
   ```bash
   docker compose up -d --build
   ```
   *(La opción `--build` compila Nginx y App antes de arrancar).*

### 4.2. Probar el Entorno
Verifica que los *healthchecks* y recursos funcionen:

1. **Estado:**
   ```bash
   docker compose ps
   ```
   *(Backend y Base de datos deben estar `healthy`).*

2. **Límites de Recursos:**
   ```bash
   docker stats --no-stream
   ```

3. **Prueba de Red y Conectividad:**
   ```bash
   curl http://localhost:80
   ```
   Para la base de datos (comprueba la conexión interna):
   ```bash
   docker compose exec db psql -U greendev_user -d greendev_db -c "SELECT NOW();"
   ```

4. **Prueba de Conectividad entre Contenedores (Pings):**
   Para demostrar que los contenedores se reconocen correctamente entre sí mediante el DNS interno de Docker (en la red `greendev_net`), ejecuta el siguiente script que realizará comprobaciones cruzadas (`ping`) entre Nginx, App y DB:
   ```bash
   ./scripts/test_compose_connectivity.sh
   ```

### 4.3. Borrar el Entorno
Cuando termines las pruebas, baja los contenedores y elimina la red creada:
```bash
docker compose down
```
*(Si deseas destruir también los volúmenes y perder la base de datos, añade la bandera `-v`: `docker compose down -v`)*
