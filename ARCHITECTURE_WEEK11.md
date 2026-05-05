# Arquitectura de Infraestructura como Codigo - Semana 11

## GreenDevCorp - Infraestructura como Codigo con Terraform y CI/CD con GitHub Actions

---

## 1. Justificacion de la eleccion: Terraform frente a Ansible

### El problema a resolver

En la Semana 10 la infraestructura se gestionaba aplicando manualmente archivos YAML de Kubernetes con `kubectl apply`. Este enfoque tiene tres deficiencias criticas en un contexto profesional:

1. El estado del cluster es implicito: no existe un registro auditado de que recursos existen y con que configuracion.
2. No es idempotente de forma garantizada: aplicar el mismo YAML dos veces puede producir resultados distintos dependiendo del estado previo del cluster.
3. No soporta multiples entornos sin duplicar archivos o usar variables de shell ad-hoc.

### Por que Terraform y no Ansible

| Criterio | Terraform | Ansible |
|---|---|---|
| Paradigma | Declarativo: describes el estado deseado | Procedimental: describes los pasos a ejecutar |
| Gestion del estado | Mantiene un archivo de estado (`terraform.tfstate`) que refleja exactamente los recursos creados | No mantiene estado; cada ejecucion relanza los playbooks desde cero |
| Idempotencia | Nativa: `terraform apply` solo modifica lo que ha cambiado | Condicional: depende del correcto uso de modulos y condiciones en los playbooks |
| Ecosistema Kubernetes | Proveedor oficial `hashicorp/kubernetes` que mapea directamente todos los recursos de la API de Kubernetes | Modulo `community.kubernetes` mas complejo de mantener y con menor cobertura |
| Multiples entornos | Variables y archivos `.tfvars` permiten desplegar entornos completamente distintos con un unico codebase | Requiere inventarios separados y estructuras de variables mas complejas (`group_vars`, `host_vars`) |
| Legibilidad de cambios | `terraform plan` muestra exactamente que va a cambiar antes de aplicarlo | No existe un equivalente directo al plan previo |
| Destruccion de entornos | `terraform destroy` elimina exactamente los recursos creados por Terraform | Requiere playbooks de rollback separados |

**Conclusion:** Para gestionar recursos de Kubernetes (objetos con especificacion declarativa en la API), Terraform es la herramienta mas adecuada porque:
- El modelo mental de Kubernetes ya es declarativo; Terraform extiende esa declaratividad al proceso de aprovisionamiento.
- El archivo de estado permite detectar y corregir desviaciones (drift) entre el codigo y la realidad del cluster.
- El flujo `plan -> apply` proporciona una capa de seguridad que Ansible no puede ofrecer de forma nativa.

---

## 2. Estructura de archivos Terraform

```
terraform/
├── main.tf          # Proveedor Kubernetes, namespace, ConfigMap y Secret
├── variables.tf     # Declaracion de todas las variables (sin valores sensibles)
├── outputs.tf       # Salidas: NodePort, URLs de acceso, entorno desplegado
├── nginx.tf         # Deployment y Service de Nginx (frontend)
├── app.tf           # Deployment y Service del backend Node.js
├── db.tf            # PV, PVC, StatefulSet y Service de PostgreSQL
├── dev.tfvars       # Valores para el entorno de desarrollo
└── staging.tfvars   # Valores para el entorno de staging
```

### Separacion de responsabilidades

Cada archivo `.tf` corresponde a una capa de la arquitectura. Terraform unifica todos los archivos del directorio en un unico grafo de dependencias antes de ejecutar cualquier operacion.

---

## 3. Variables y Salidas (Outputs)

### 3.1 Tipos de variables utilizadas

Todas las variables se declaran en `variables.tf` con los siguientes atributos:

- `description`: documentacion legible por el equipo.
- `type`: garantiza que Terraform valide el tipo antes de ejecutar.
- `default`: valor seguro que evita errores en entornos de desarrollo.
- `sensitive = true`: para variables como `db_password`, Terraform omite el valor en los logs de salida y en los planes.
- `validation`: restricciones de dominio, como obligar a que `environment` sea unicamente `"dev"` o `"staging"`.

### 3.2 Jerarquia de resolucion de variables

Terraform resuelve el valor final de cada variable en el siguiente orden de precedencia (de menor a mayor):

```
Valor por defecto en variables.tf
  < Archivo .tfvars (-var-file=dev.tfvars)
    < Variable de entorno del shell (TF_VAR_nombre)
      < Flag -var en la linea de comandos
```

Esto permite, por ejemplo, que la contrasena de la base de datos se inyecte mediante una variable de entorno sin que aparezca en ningun archivo trackeado por Git:

```bash
export TF_VAR_db_password="mi_contrasena_local"
terraform apply -var-file=dev.tfvars
```

### 3.3 Outputs configurados

| Output | Descripcion |
|---|---|
| `namespace` | Nombre del namespace creado en Kubernetes |
| `nginx_node_port` | Puerto NodePort del Service de Nginx |
| `minikube_access_hint` | Comando exacto para obtener la URL de acceso |
| `app_service_cluster_ip` | DNS interno del backend dentro del cluster |
| `db_service_cluster_ip` | DNS interno de PostgreSQL dentro del cluster |
| `image_tag_deployed` | Etiqueta de imagen aplicada en este despliegue |
| `environment` | Nombre del entorno activo |

Para consultar los outputs tras un despliegue:

```bash
terraform output
terraform output -raw minikube_access_hint
```

---

## 4. Flujo de trabajo local (Continuous Delivery manual)

El despliegue continuo (CD) es una operacion manual y deliberada que el desarrollador ejecuta en su maquina local una vez que el pipeline de CI ha finalizado con exito.

### 4.1 Prerrequisitos

```bash
# Verificar que Terraform esta instalado
terraform -version

# Instalar Terraform si no esta disponible
bash setup_iac.sh

# Verificar que Minikube esta en ejecucion
minikube status
```

### 4.2 Flujo completo para el entorno de desarrollo

```bash
# 1. Iniciar el cluster de Minikube (si no esta corriendo)
minikube start

# 2. Cargar las imagenes en el registry interno de Minikube
#    (evita necesitar un registro remoto en desarrollo)
minikube image load tu-usuario-dockerhub/nginx-gsx:latest
minikube image load tu-usuario-dockerhub/app-gsx:latest
minikube image load tu-usuario-dockerhub/postgres-gsx:latest

# 3. Posicionarse en el directorio de Terraform
cd terraform/

# 4. Inicializar el directorio de trabajo (descarga el proveedor hashicorp/kubernetes)
#    Solo necesario la primera vez o cuando cambian los proveedores.
terraform init

# 5. Inyectar la contrasena de la base de datos de forma segura
export TF_VAR_db_password="mi_contrasena_local"

# 6. Revisar el plan de cambios antes de aplicar (nunca saltar este paso)
terraform plan -var-file=dev.tfvars

# 7. Aplicar la infraestructura
terraform apply -var-file=dev.tfvars

# 8. Verificar los recursos creados
kubectl get all -n greendev-dev

# 9. Obtener la URL de acceso a la aplicacion
$(terraform output -raw minikube_access_hint)
```

### 4.3 Flujo completo para el entorno de staging

```bash
# El SHA del commit a desplegar se obtiene del pipeline de CI exitoso.
COMMIT_SHA="a1b2c3d"

export TF_VAR_db_password="mi_contrasena_staging"

cd terraform/
terraform init

terraform plan \
  -var-file=staging.tfvars \
  -var="image_tag=${COMMIT_SHA}"

terraform apply \
  -var-file=staging.tfvars \
  -var="image_tag=${COMMIT_SHA}"
```

### 4.4 Destruccion del entorno

```bash
# Destruir todos los recursos de un entorno de forma limpia
terraform destroy -var-file=dev.tfvars
```

---

## 5. Estrategia de etiquetado de imagenes y el pipeline de CI

### 5.1 Como el pipeline genera la etiqueta dinamica

El pipeline de GitHub Actions calcula la etiqueta de imagen a partir del SHA del commit en el job `build-and-push`:

```yaml
- name: Calcular etiqueta de imagen (commit SHA)
  id: meta
  run: |
    SHORT_SHA=$(echo "${{ github.sha }}" | cut -c1-7)
    echo "image_tag=${SHORT_SHA}" >> "$GITHUB_OUTPUT"
```

Este valor se almacena en los outputs del job y se propaga a los jobs dependientes (`security-scan`) para escanear exactamente la imagen que fue construida en ese pipeline, no una version anterior.

### 5.2 Por que el SHA del commit y no 'latest'

El uso del SHA del commit como etiqueta garantiza:

- **Trazabilidad**: cada imagen publicada en Docker Hub puede relacionarse exactamente con el codigo fuente que la genero.
- **Inmutabilidad**: una imagen con etiqueta SHA nunca es sobreescrita por una publicacion posterior.
- **Reproducibilidad**: un despliegue en staging con `image_tag=a1b2c3d` siempre ejecutara exactamente el mismo codigo, sin importar cuantas veces se repita.

La etiqueta `latest` tambien se publica para conveniencia del entorno de desarrollo, pero nunca debe usarse en staging.

### 5.3 Como se inyecta la etiqueta al despliegue local

El pipeline NO despliega en Minikube (el cluster local no es accesible desde los runners de GitHub). Sin embargo, el SHA del commit del ultimo pipeline exitoso esta siempre disponible en la interfaz de GitHub Actions o con:

```bash
# Obtener el SHA del ultimo commit en main
git log --oneline -1 main
```

El desarrollador lo usa al ejecutar terraform apply:

```bash
terraform apply \
  -var-file=staging.tfvars \
  -var="image_tag=$(git rev-parse --short HEAD)"
```

Este comando hace que la variable `var.image_tag` en Terraform adopte el valor del SHA, que a su vez se interpola en la etiqueta de imagen de cada Deployment y StatefulSet:

```hcl
# En nginx.tf
locals {
  nginx_image = "${var.docker_registry}/${var.nginx_image_name}:${var.image_tag}"
}
```

De esta forma, Kubernetes actualiza el Deployment detectando que la imagen referenciada ha cambiado y ejecuta un rolling update automatico.

---

## 6. Gestión de secretos: anti-patrones y buenas practicas

### Lo que esta prohibido

- Incluir valores de contrasenas directamente en archivos `.tf` o `.tfvars`.
- Subir a Git cualquier archivo `.tfvars` que contenga valores de `db_password`.
- Usar la etiqueta `latest` en staging o produccion.

### Lo que se hace en este proyecto

| Secreto | Mecanismo de inyeccion |
|---|---|
| `db_password` (Terraform) | Variable de entorno `TF_VAR_db_password` o flag `-var` en la ejecucion local |
| `DOCKERHUB_USERNAME` (CI) | Secret de repositorio en GitHub Actions (`secrets.DOCKERHUB_USERNAME`) |
| `DOCKERHUB_TOKEN` (CI) | Secret de repositorio en GitHub Actions (`secrets.DOCKERHUB_TOKEN`) |

### Configurar los secrets en GitHub

1. Acceder a: `Settings > Secrets and variables > Actions` en el repositorio de GitHub.
2. Crear los siguientes secrets:
   - `DOCKERHUB_USERNAME`: tu nombre de usuario de Docker Hub.
   - `DOCKERHUB_TOKEN`: un Access Token de Docker Hub (no la contrasena de la cuenta).

---

## 7. Diagrama de arquitectura

```
                             GitHub Actions CI Pipeline
                        ┌──────────────────────────────────┐
                        │                                  │
   git push -> main     │  Job 1: build-and-push           │
         │              │    - docker build nginx/          │
         └─────────────>│    - docker build app/            │
                        │    - docker push :<COMMIT_SHA>   │
                        │                                  │
                        │  Job 2: security-scan (Trivy)    │
                        │    - scan nginx-gsx:<SHA>        │
                        │    - scan app-gsx:<SHA>          │
                        │    - scan terraform/ (IaC)       │
                        │                                  │
                        │  Job 3: terraform-validate       │
                        │    - fmt -check                  │
                        │    - init -backend=false         │
                        │    - validate                    │
                        │                                  │
                        └───────────┬──────────────────────┘
                                    │ Pipeline OK
                                    v
                         Desarrollador (accion manual)
                        ┌──────────────────────────────────┐
                        │                                  │
                        │  terraform apply                 │
                        │    -var-file=staging.tfvars      │
                        │    -var="image_tag=<COMMIT_SHA>" │
                        │                                  │
                        └───────────┬──────────────────────┘
                                    │
                                    v
                        Minikube Cluster (local)
                    Namespace: greendev-dev / greendev-staging
                    ┌──────────────────────────────────────────┐
                    │                                          │
                    │  [NodePort:30080]                        │
                    │       |                                  │
                    │  Deployment: nginx (frontend)            │
                    │       |                                  │
                    │  Service: app (ClusterIP:3000)           │
                    │       |                                  │
                    │  Deployment: app (backend Node.js)       │
                    │       |                                  │
                    │  Service: db (ClusterIP:5432)            │
                    │       |                                  │
                    │  StatefulSet: db (PostgreSQL)            │
                    │       |                                  │
                    │  PVC -> PV (hostPath /mnt/data/...)      │
                    │                                          │
                    └──────────────────────────────────────────┘
```
