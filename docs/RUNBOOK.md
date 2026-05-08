# Runbook de Operaciones (GreenDevCorp)

Este manual de operaciones detalla los procedimientos comunes para la administración de la infraestructura de GreenDevCorp. Todas las operaciones principales de despliegue y modificación de infraestructura se gestionan a través de Terraform.

## 1. Desplegar una nueva versión de una imagen

Dado que la infraestructura se gestiona de forma declarativa con Terraform, el despliegue de una nueva versión de la aplicación (o Nginx) debe realizarse modificando los archivos de configuración de Terraform para garantizar la consistencia.

**Procedimiento:**

1. Actualizar la variable o la definición de la imagen en los archivos de Terraform (por ejemplo, en `terraform/main.tf` o en un archivo `variables.tf`).
   Cambiar la referencia de la imagen, por ejemplo, de `usuario/app:v1.0.0` a `usuario/app:v1.1.0`.
2. Navegar al directorio de Terraform:
   ```bash
   cd terraform
   ```
3. Planificar y revisar los cambios:
   ```bash
   terraform plan
   ```
4. Aplicar los cambios. Terraform se comunicará con la API de Kubernetes para actualizar la configuración del Deployment, lo que disparará un proceso de actualización progresiva (Rolling Update) de los pods:
   ```bash
   terraform apply -auto-approve
   ```

## 2. Escalar un servicio manualmente

El escalado de réplicas de cualquier microservicio también debe registrarse en la configuración de Terraform para mantener el estado sincronizado y evitar derivas (drifts) en la infraestructura.

**Procedimiento Oficial (Vía Terraform):**
1. Abrir el archivo de Terraform correspondiente al despliegue deseado.
2. Modificar el parámetro `replicas` dentro del bloque de especificación del `kubernetes_deployment`:
   ```hcl
   spec {
     replicas = 3 # Incrementado al número deseado
     ...
   }
   ```
3. Aplicar los cambios:
   ```bash
   cd terraform
   terraform apply -auto-approve
   ```

**Procedimiento de Emergencia (Vía kubectl):**
Si existe una necesidad crítica de rendimiento, se puede escalar de forma manual e inmediata usando `kubectl`, pero se debe recordar actualizar el archivo de Terraform inmediatamente después.
```bash
kubectl scale deployment app-deployment --replicas=3 -n default
```

## 3. Revisar los logs de los contenedores en Kubernetes

Para el diagnóstico y monitoreo directo de las aplicaciones y servicios.

**Ver logs de un pod específico:**
1. Obtener el nombre exacto del pod:
   ```bash
   kubectl get pods -n default
   ```
2. Inspeccionar los logs del pod seleccionado:
   ```bash
   kubectl logs <nombre-del-pod> -n default
   ```

**Ver logs en tiempo real:**
Para seguir la salida de manera continua:
```bash
kubectl logs -f <nombre-del-pod> -n default
```

**Ver logs de todos los pods de un servicio:**
Si cuenta con múltiples réplicas de la aplicación, puede revisar los logs de todas ellas simultáneamente usando selectores de etiquetas (labels):
```bash
kubectl logs -l app=app-service -n default --tail=100 -f
```

**Revisar logs de un contenedor que ha fallado:**
Si un pod experimentó un reinicio debido a un fallo crítico, es posible consultar los logs de la ejecución previa:
```bash
kubectl logs <nombre-del-pod> -n default --previous
```
