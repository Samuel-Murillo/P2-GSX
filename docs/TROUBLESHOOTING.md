# Guía de Resolución de Problemas (Troubleshooting)

Esta guía recopila problemas comunes y procedimientos de diagnóstico recomendados para la infraestructura de microservicios de GreenDevCorp.

## Problema 1: El Servicio X no puede alcanzar al Servicio Y

Este es uno de los incidentes de red más comunes en arquitecturas segmentadas y orquestadas con Kubernetes, particularmente después de implementar políticas restrictivas.

**Síntomas:**
* Las peticiones desde Nginx a la Aplicación Node.js devuelven un error HTTP 502 (Bad Gateway) o 504 (Gateway Timeout).
* La Aplicación muestra errores de "Connection Refused" o "Timeout" al intentar interactuar con PostgreSQL.

**Pasos de Diagnóstico:**
1. **Comprobar la existencia y estado de los servicios (Endpoints):**
   Asegúrese de que el servicio de destino está correctamente registrado y tiene Endpoints activos. Si no hay Endpoints, el servicio no está enrutando tráfico a ningún pod.
   ```bash
   kubectl get svc -n default
   kubectl get endpoints -n default
   ```
2. **Validar Selectores y Etiquetas (Labels):**
   Verifique que los selectores definidos en el servicio en cuestión coinciden con precisión con las etiquetas de los pods que deberían respaldarlo.
   ```bash
   kubectl describe svc <nombre-del-servicio> -n default
   kubectl get pods -n default --show-labels
   ```
3. **Revisar Restricciones de NetworkPolicies:**
   Si la resolución DNS interna es correcta pero la conexión es rechazada sistemáticamente, es altamente probable que el tráfico esté siendo descartado por una política de red restrictiva.
   ```bash
   kubectl get networkpolicies -n default
   kubectl describe networkpolicy <nombre-de-la-politica> -n default
   ```
   Valide que los selectores de origen en las reglas de `ingress` de la política destino permiten el tráfico basándose en las etiquetas exactas del pod de origen.

## Problema 2: Un pod está en estado CrashLoopBackOff

El estado `CrashLoopBackOff` indica que el proceso principal dentro del contenedor está finalizando prematuramente o fallando repetidamente, provocando que Kubernetes intente reiniciarlo en un bucle continuo.

**Síntomas:**
* Al verificar el estado de los recursos, un pod altera constantemente entre `Error` y `CrashLoopBackOff`.
* El componente en cuestión nunca se marca como disponible.

**Pasos de Diagnóstico:**
1. **Inspeccionar los Eventos de Sistema (Events):**
   Revise la sección de "Events" al final de la descripción del pod para descartar problemas de falta de recursos de nodo (OOMKilled, OutOfMemory), fallos de autenticación al descargar imágenes (ImagePullBackOff), o fallos repetidos en los Liveness/Readiness probes.
   ```bash
   kubectl describe pod <nombre-del-pod> -n default
   ```
2. **Revisar los Registros (Logs) de Ejecución:**
   La causa técnica del cierre abrupto se encuentra normalmente en la salida estándar de la aplicación.
   ```bash
   kubectl logs <nombre-del-pod> -n default
   ```
   *Consejo:* Si el pod falla y se reinicia tan rápido que no puede capturar los logs actuales, inspeccione los registros de la instancia inmediatamente anterior que falló:
   ```bash
   kubectl logs <nombre-del-pod> -n default --previous
   ```
3. **Verificar Dependencias Externas (Secrets / ConfigMaps):**
   Para la aplicación Node.js o la base de datos PostgreSQL, la ausencia de variables críticas (como el `DB_HOST` o `POSTGRES_PASSWORD`) provocará una interrupción forzada en el arranque. Confirme que todos los recursos auxiliares existen y están aplicados correctamente a través de Terraform.
   ```bash
   kubectl get configmaps -n default
   kubectl get secrets -n default
   ```
