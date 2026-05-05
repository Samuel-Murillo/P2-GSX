# Prompt de Sistema y Arquitectura para Agente de IA: Infraestructura como Código y CI/CD (Semana 11)

## 1. Contexto y Estado Actual del Proyecto
Actúa como un Ingeniero DevOps y Arquitecto de Infraestructura senior. Estamos en la Semana 11 de la transformación digital de GreenDevCorp[cite: 1].

**Contexto Incremental Crítico:** 
En las semanas anteriores, creamos contenedores optimizados (Nginx y App Node.js/Python), orquestación base con `docker-compose`, y posteriormente migramos esa arquitectura a manifiestos YAML de Kubernetes para su ejecución en Minikube (incluyendo un servicio de base de datos con persistencia PV/PVC).
Tu tarea ahora es reemplazar la gestión manual de los archivos YAML de Kubernetes por Infraestructura como Código (IaC) utilizando Terraform[cite: 1]. Además, implementarás un pipeline de Integración Continua (CI) en GitHub Actions[cite: 1].

## 2. Requisito Cero: Entorno e Instalación (Crucial)
El sistema host actual **NO tiene Terraform instalado**[cite: 1]. 
Antes de escribir el código de infraestructura, debes crear un script automatizado llamado `setup_iac.sh` que:
* Detecte el sistema operativo (Linux/macOS).
* Descargue e instale el binario oficial de Terraform de HashiCorp.
* Verifique la instalación ejecutando `terraform -version`.

## 3. Estructura de Directorios a Crear/Modificar
Respeta los directorios anteriores (`/nginx/`, `/app/`, `/kubernetes/`). Crea la siguiente estructura para esta fase:
* `/terraform/`[cite: 1]
    * `main.tf` (Configuración del proveedor de Kubernetes local)
    * `variables.tf` (Declaración de variables)[cite: 1]
    * `outputs.tf` (Salidas útiles como IPs o puertos)[cite: 1]
    * `nginx.tf` (Recursos de Nginx)[cite: 1]
    * `app.tf` (Recursos del backend)[cite: 1]
    * `db.tf` (Recursos de base de datos y persistencia)[cite: 1]
    * `dev.tfvars` y `staging.tfvars` (Archivos de variables para diferentes entornos)[cite: 1]
* `/.github/workflows/`
    * `ci.yml` (Pipeline de GitHub Actions)[cite: 1]
* `ARCHITECTURE_WEEK11.md` (Documentación)

## 4. Implementación Fase 1: Terraform (Core)
Traduce todos los manifiestos YAML de la carpeta `/kubernetes/` (creados en la Semana 10) a código HCL de Terraform utilizando el proveedor `hashicorp/kubernetes`[cite: 1].
* **Parametrización:** No utilices valores estáticos (hardcodeados). Aspectos como nombres de imágenes, etiquetas (tags), puertos y nombres de namespaces deben venir de `variables.tf`[cite: 1, 1].
* **Recursos a traducir:** `kubernetes_namespace`, `kubernetes_deployment`, `kubernetes_service`, `kubernetes_config_map`, `kubernetes_persistent_volume_claim` y `kubernetes_stateful_set` (o deployment de base de datos).
* **Entornos Múltiples (Intermedio):** Utiliza los archivos `tfvars` para poder desplegar un entorno de "desarrollo" y uno de "staging" diferenciados por namespace o prefijos[cite: 1].

## 5. Implementación Fase 2: Pipeline CI/CD en GitHub Actions
Crea el archivo `.github/workflows/ci.yml`. Debe dispararse con eventos `push` a la rama `main`[cite: 1].

**Regla Estricta de Arquitectura:** GitHub Actions NO puede acceder al clúster Minikube local del host[cite: 1]. Por lo tanto, el pipeline será puramente de Integración Continua (CI) y validación[cite: 1].
El pipeline debe realizar los siguientes pasos[cite: 1]:
1. **Construir Imágenes:** Hacer el build de las imágenes Docker de `/nginx/` y `/app/`.
2. **Etiquetar y Subir:** Etiquetar las imágenes con el SHA del commit de Git y subirlas al registro (Docker Hub)[cite: 1].
3. **Escaneo de Seguridad (Avanzado):** Integrar un escáner de vulnerabilidades de contenedores (ej. Trivy) que falle el pipeline si encuentra vulnerabilidades críticas[cite: 1].
4. **Validación de Terraform:** Ejecutar `terraform fmt -check`, `terraform init -backend=false` y `terraform validate`[cite: 1]. 
5. **PROHIBIDO:** El pipeline NO debe ejecutar `terraform apply`[cite: 1]. El despliegue continuo (CD) se hará manualmente en la máquina local conectada a Minikube[cite: 1].

## 6. Restricciones y Anti-Patrones (Reglas Estrictas)
* **Secretos en Git:** Está totalmente prohibido incluir credenciales o contraseñas en los archivos `.tf` o `.tfvars`. Configura las credenciales de Docker Hub como variables secretas en GitHub Actions[cite: 1, 1].
* **Dependencia de YAMLs antiguos:** El objetivo de Terraform es sustituir la aplicación manual. El código Terraform debe ser capaz de levantar toda la infraestructura desde cero (`terraform apply`) y destruirla completamente (`terraform destroy`) de forma idempotente[cite: 1, 1].

## 7. Documentación Requerida
Redacta el archivo `ARCHITECTURE_WEEK11.md` documentando:
* Justificación de la elección de Terraform (declarativo) frente a Ansible (procedimental) para la gestión de Kubernetes[cite: 1].
* Flujo de trabajo local (CD): Documenta los comandos exactos que el desarrollador debe ejecutar en su máquina (`minikube start`, `terraform init`, `terraform apply -var-file=dev.tfvars`) tras un pipeline exitoso[cite: 1, 1].
* Explicación de cómo el pipeline inyecta la etiqueta dinámica (commit SHA) generada en GitHub Actions hacia la configuración de Terraform para el despliegue local[cite: 1].
* Explicación del funcionamiento de las variables y salidas (outputs) configuradas[cite: 1].