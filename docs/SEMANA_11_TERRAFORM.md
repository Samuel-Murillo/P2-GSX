# Semana 11: Infraestructura como Código (Terraform)

## 1. Justificación de Terraform frente a Scripts Manuales
En la Semana 10, la infraestructura se gestionaba manualmente con `kubectl apply`. Ese método tiene varias limitaciones críticas para equipos grandes:
- Falta de un estado auditable (state file).
- Idempotencia débil frente a cambios complejos.
- Dificultad para parametrizar de forma robusta múltiples entornos (ej. Staging vs Producción).

Terraform ofrece un enfoque declarativo puro, planificación de cambios en seco (`terraform plan`) y soporte multi-entorno nativo utilizando ficheros de variables (`.tfvars`).

## 2. Estructura del Proyecto
El código Terraform se almacena en la carpeta `/terraform`:
- `main.tf`: Provider de Kubernetes y recursos transversales (Namespace, ConfigMap, Secret).
- `variables.tf`: Declaración tipada de todas las variables. Ningún valor sensible se hardcodea por defecto.
- `app.tf`, `nginx.tf`, `db.tf`: Separación modular de recursos por aplicación.
- `dev.tfvars`, `staging.tfvars`: Entornos.

## 3. Gestión de Secretos
- **Contraseña de PostgreSQL (`db_password`)**: Declarada como `sensitive = true` en `variables.tf`. Nunca se sube a Git. Se pasa externamente mediante variables de entorno del sistema (`export TF_VAR_db_password`).

## 4. Manual Paso a Paso: Levantar, Probar y Borrar

### 4.1. Levantar el Entorno

Para levantar la infraestructura automatizada de Terraform en el entorno de desarrollo, el método más sencillo y recomendado es usar el script orquestador:

1. **Asegúrate de tener Minikube encendido y con un CNI compatible**:
   ```bash
   minikube start --cni=calico
   ```
2. **Exporta tu contraseña:**
   ```bash
   export TF_VAR_db_password="secret_example_password"
   ```
3. **Ejecuta el Script de Despliegue:**
   ```bash
   ./scripts/deploy_dev.sh
   ```
   *¿Qué hace el script?* Construye las imágenes Docker, las inyecta en el demonio interno de Minikube (para no depender de internet) y ejecuta automáticamente `terraform init` y `terraform apply` sin intervención manual. Finalmente, abre un túnel con la URL de la aplicación.

*(Nota: Si quieres aplicar Terraform manualmente, debes entrar a la carpeta `/terraform`, hacer `terraform init` y lanzar `terraform apply -var-file=dev.tfvars`).*

### 4.2. Probar
1. **Acceso Web:** El script anterior te dará una URL (ej. `http://127.0.0.1:54322`). Abre esa URL en tu navegador.
2. **Si el túnel falla**, puedes forzar la apertura del puerto del clúster ejecutando:
   ```bash
   minikube service nginx-service -n greendev-dev
   ```

### 4.3. Borrar el Entorno
Cuando hayas finalizado y desees destruir los recursos aprovisionados:

1. Entra a la carpeta de terraform:
   ```bash
   cd terraform
   ```
2. Destruye los recursos:
   ```bash
   terraform destroy -var-file=dev.tfvars -auto-approve
   ```
3. Apaga o elimina el clúster si ya no lo necesitas:
   ```bash
   minikube stop
   # o minikube delete
   ```
