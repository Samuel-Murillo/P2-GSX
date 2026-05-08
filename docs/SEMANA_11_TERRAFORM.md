# Semana 11: Infraestructura como Código (Terraform) y CI/CD

## 1. Elección de la Herramienta de IaC: Terraform vs Ansible

Para la gestión de los recursos en Kubernetes de GreenDevCorp, hemos seleccionado **Terraform** frente a alternativas como Ansible por las siguientes razones técnicas:

*   **Enfoque Declarativo vs Procedural:** Terraform es puramente declarativo; tú describes el *estado final* deseado (ej. "quiero 3 réplicas") y él se encarga de alcanzarlo. Ansible, aunque puede gestionar K8s, tiene un ADN más procedural enfocado en la configuración paso a paso de servidores.
*   **Gestión del Estado (State File):** Terraform mantiene un archivo de estado (`tfstate`) que le permite saber qué recursos existen realmente y detectar cambios manuales (drift). Ansible no tiene un concepto nativo de estado para la infraestructura, lo que dificulta saber qué borrar si eliminamos código.
*   **Orquestación de Ciclo de Vida:** Terraform sobresale en la creación y destrucción de recursos complejos y sus dependencias. Ansible es excelente para configurar el *interior* de una máquina virtual, pero Terraform es superior para orquestar los *objetos* de la API de Kubernetes.

## 2. Pasos de Despliegue: Del Código a la Infraestructura

El flujo de despliegue sigue un camino determinista para asegurar la paridad entre lo que el desarrollador escribe y lo que se ejecuta en el clúster:

1.  **Codificación:** Se definen los recursos en archivos `.tf` modularizados (`app.tf`, `nginx.tf`, etc.).
2.  **Validación Local:** El desarrollador usa `terraform plan` para previsualizar los cambios.
3.  **Push al Repositorio:** El código se sube a GitHub, disparando el pipeline de CI.
4.  **Aplicación:** Una vez validado, se ejecuta el despliegue (localmente mediante scripts o en un entorno de staging).

## 3. Flujo de CI/CD (Integración y Despliegue Continuo)

Hemos implementado un modelo híbrido donde la integración es global y el despliegue es local para este proyecto.

### A. CI en GitHub Actions (Integración Continua)
Al hacer `push` o `merge` a las ramas `main` o `eric`, ocurre lo siguiente:
*   **Linting & Validation:** Se comprueba el formato del código Terraform (`fmt`) y la validez de su sintaxis (`validate`).
*   **Build & Push:** Se construyen las imágenes Docker y se suben a Docker Hub etiquetadas con el SHA del commit.
*   **Security Scan:** Se utiliza **Trivy** para escanear las imágenes y los archivos IaC en busca de vulnerabilidades críticas.
*   **Restricción:** El pipeline de GitHub Actions tiene **prohibido** ejecutar `terraform apply` para evitar cambios accidentales en entornos reales desde la nube.

### B. CD Local en Minikube (Despliegue Continuo)
El despliegue se realiza mediante el script `scripts/deploy_terraform.sh`, que automatiza:
1.  Sincronización de la etiqueta de imagen con el commit actual de Git.
2.  Carga de imágenes directamente en el motor de Minikube (`image load`).
3.  Ejecución de `terraform apply` inyectando las variables de entorno necesarias.

## 4. Estrategia de Etiquetado (Tagging)

Utilizamos el **Git Commit SHA (corto, 7 caracteres)** como etiqueta única para todas las imágenes.
*   **Por qué:** Garantiza la inmutabilidad. Sabemos exactamente qué versión del código está corriendo en cada contenedor.
*   **Configuración:**
    *   En CI: Se calcula en el job `build-and-push` dentro de `.github/workflows/ci.yml`.
    *   En Local: Se calcula dinámicamente en `scripts/deploy_terraform.sh`.

## 5. Manual Paso a Paso: Levantar, Probar y Borrar

### 5.1. Levantar el Entorno
Para levantar la infraestructura automatizada de Terraform en el entorno de desarrollo:

1. **Asegúrate de tener Minikube encendido con Calico**:
   ```bash
   minikube start --cni=calico
   ```
2. **Exporta tu contraseña de base de datos:**
   ```bash
   export TF_VAR_db_password="secret_example_password"
   ```
3. **Ejecuta el Script de Despliegue:**
   ```bash
   ./scripts/deploy_terraform.sh
   ```
   *(Nota: También puedes hacerlo manualmente con `terraform init` y `terraform apply -var-file=dev.tfvars` dentro de la carpeta /terraform).*

### 5.2. Probar
1. **Acceso Web:** El script te proporcionará una URL. Si falla, usa:
   ```bash
   minikube service nginx-service -n greendev-dev --url
   ```
2. **Verificación de Pods:**
   ```bash
   kubectl get pods -n greendev-dev
   ```

### 5.3. Borrar el Entorno
Para destruir los recursos y limpiar el clúster:
```bash
cd terraform
terraform destroy -var-file=dev.tfvars -auto-approve
```

## 6. Variables y Outputs

El sistema está parametrizado para ser reutilizable:

*   **Variables (`variables.tf`):**
    *   `db_password`: Sensible, inyectada vía `TF_VAR_db_password`.
    *   `image_tag`: Define qué versión de la aplicación desplegar.
    *   `namespace`: Por defecto `greendev-dev`.
*   **Outputs:**
    *   `app_service_cluster_ip`: Facilita el diagnóstico de red interna.
    *   `nginx_node_port`: Indica en qué puerto físico de Minikube podemos acceder a la web.
    *   `minikube_access_hint`: Proporciona el comando exacto para abrir el túnel de acceso.
