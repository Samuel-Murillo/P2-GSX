# GreenDevCorp - Proyecto Final de Transformación Digital

Bienvenido al repositorio oficial de infraestructura de GreenDevCorp. Este proyecto representa la fase final de nuestra transformación digital hacia una arquitectura moderna, contenerizada y completamente orquestada con Kubernetes, gestionada mediante Infraestructura como Código (IaC) con Terraform.

## Visión General del Proyecto

GreenDevCorp ha modernizado su aplicación principal migrando de un entorno monolítico tradicional a una arquitectura de microservicios. Este repositorio contiene todo el código necesario para desplegar de manera reproducible y automatizada nuestra infraestructura en un entorno de desarrollo o producción basado en Kubernetes.

El sistema consta de tres capas principales:
* **Frontend/Proxy Inverso:** Servidor Nginx que maneja las peticiones entrantes y las redirige.
* **Aplicación Backend:** Aplicación Node.js encargada de la lógica de negocio.
* **Base de Datos:** PostgreSQL con persistencia de datos configurada mediante Persistent Volumes en Kubernetes.

Todo el despliegue está gestionado y aprovisionado a través de **Terraform**, garantizando la inmutabilidad y consistencia del entorno. Además, se han implementado políticas de red (NetworkPolicies) para garantizar la seguridad y segmentación estricta del tráfico entre servicios.

## Documentación del Proyecto

La documentación detallada se encuentra en el directorio `/docs/`:

### Entregables Generales
* [Arquitectura Final (`/docs/ARCHITECTURE_FINAL.md`)](./docs/ARCHITECTURE_FINAL.md): Diagramas de infraestructura, flujos de datos y especificaciones de microservicios.
* [Proceso de Integración (`/docs/INTEGRATION_PROCESS.md`)](./docs/INTEGRATION_PROCESS.md): Guía y reporte sobre el proceso de integración continua y despliegue.
* [Runbook Operativo (`/docs/RUNBOOK.md`)](./docs/RUNBOOK.md): Guía de operaciones diarias, despliegues y escalado.
* [Troubleshooting (`/docs/TROUBLESHOOTING.md`)](./docs/TROUBLESHOOTING.md): Guía para la resolución de problemas comunes.
* [Reflexión Individual - Eric (`/docs/REFLECTION_ERIC.md`)](./docs/REFLECTION_ERIC.md): Ensayo personal de Eric sobre el proceso de aprendizaje DevOps.
* [Reflexión Individual - Samuel (`/docs/REFLECTION_SAMUEL.md`)](./docs/REFLECTION_SAMUEL.md): Ensayo personal de Samuel sobre el proceso de aprendizaje DevOps.

### Bitácoras de Trabajo Semanal
* [Semana 08: Contenerización](./docs/SEMANA_08_CONTENEDORIZACION.md): Empaquetado de la aplicación con Docker y auditoría inicial de seguridad.
* [Semana 09: Orquestación Local con Docker Compose](./docs/SEMANA_09_DOCKER_COMPOSE.md): Definición del entorno multi-contenedor y validación de red local.
* [Semana 10: Despliegue en Kubernetes (Kubectl)](./docs/SEMANA_10_KUBERNETES.md): Migración y despliegue sobre Minikube.
* [Semana 11: Infraestructura como Código con Terraform](./docs/SEMANA_11_TERRAFORM.md): Automatización del aprovisionamiento del clúster de K8s.
* [Semana 12: Diseño de Red e Identidad](./docs/SEMANA_12_RED_E_IDENTIDAD.md): Segmentación de red (CNI Calico, NetworkPolicies) y servicios de identidad.

## Quick Start: Despliegue desde cero

Este proyecto está diseñado para ejecutarse localmente usando Minikube y Terraform. Siga estas instrucciones para desplegar la infraestructura completa desde cero.

### Prerrequisitos
* Git
* Minikube
* Kubectl
* Terraform

### Pasos de Despliegue

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/usuario/greendevcorp.git
   cd greendevcorp
   ```

2. **Iniciar Minikube:**
   Asegúrese de tener un clúster local funcionando.
   ```bash
   minikube start
   ```

3. **Inicializar y aplicar Terraform:**
   El proyecto utiliza Terraform para el despliegue en Kubernetes. Desplácese a la carpeta correspondiente e inicialice el proveedor.
   ```bash
   cd terraform
   terraform init
   ```
   A continuación, aplique los manifiestos para crear toda la infraestructura de red, servicios, volúmenes y despliegues.
   ```bash
   terraform apply -auto-approve
   ```

4. **Verificar el despliegue:**
   Puede comprobar que todos los pods están funcionando ejecutando:
   ```bash
   kubectl get pods -n default
   ```

5. **Acceder a la aplicación:**
   Si está utilizando Minikube, puede obtener la IP y el puerto de acceso o crear un túnel al servicio de Nginx:
   ```bash
   minikube service nginx-service
   ```

6. **Prueba de Integración Completa:**
   Para validar automáticamente que el entorno se crea, se configuran las políticas de seguridad y la comunicación fluye correctamente, puede ejecutar el script de integración desde la raíz del proyecto:
   ```bash
   cd ..
   chmod +x scripts/integration_test.sh
   ./scripts/integration_test.sh
   ```

### Limpieza del entorno

Para destruir todos los recursos creados por Terraform de manera segura y dejar el clúster limpio:
```bash
cd terraform
terraform destroy -auto-approve
```
