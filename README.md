# Proyecto de Contenerización e Infraestructura - GreenDevCorp

Bienvenido al repositorio central de arquitectura e infraestructura de GreenDevCorp. Este proyecto detalla la evolución técnica, desde la contenerización de las aplicaciones iniciales hasta el despliegue automático en Kubernetes utilizando Infraestructura como Código (Terraform) y estrictas políticas de red.

## Documentación por Fases (Semanas)

Toda la documentación técnica, manuales paso a paso, decisiones de diseño y justificaciones han sido extraídas y organizadas cronológicamente en la carpeta `/docs`.

Por favor, consulta los siguientes documentos para entender, levantar, probar o borrar la infraestructura correspondiente a cada fase:

*   **[Semana 8: Contenerización y Optimización](docs/SEMANA_08_CONTENEDORIZACION.md)**
    *   Optimización extrema con Alpine Linux y multistage builds.
    *   Consideraciones de seguridad (non-root, read-only, mitigación de CVEs).
    *   Manual de despliegue seguro y pruebas locales de Docker puro.
*   **[Semana 9: Arquitectura de Orquestación (Docker Compose)](docs/SEMANA_09_DOCKER_COMPOSE.md)**
    *   Flujo de red interna, volúmenes persistentes y dependencias de arranque.
    *   Configuración de variables de entorno estables mediante `.env`.
    *   Manual paso a paso de orquestación con Compose.
*   **[Semana 10: Arquitectura en Kubernetes](docs/SEMANA_10_KUBERNETES.md)**
    *   Migración a Pods, Deployments, Services y StatefulSets.
    *   Pruebas empíricas de resiliencia (Auto-healing y Escalado horizontal).
*   **[Semana 11: Infraestructura como Código (Terraform)](docs/SEMANA_11_TERRAFORM.md)**
    *   Justificación del salto a código declarativo y gestión de secretos.
    *   **Manual del script automatizado de despliegue (`deploy_dev.sh`)**.
    *   Instrucciones completas para limpiar el clúster.
*   **[Semana 12: Diseño de Red, Identidad y Seguridad](docs/SEMANA_12_RED_E_IDENTIDAD.md)**
    *   Planificación CIDR, Diagramas de Arquitectura y fronteras de seguridad.
    *   Investigación sobre servicios Core (DNS, DHCP, NTP) y estrategias de identidad (SSO, LDAP).
    *   Manual de pruebas de intrusión y verificación de las NetworkPolicies (`test_network_policies.sh`).

## Estructura del Repositorio

```text
.
├── app/                  # Código fuente y Dockerfile del Backend Node.js
├── db/                   # Configuración inicial y Dockerfile de PostgreSQL
├── docs/                 # Toda la documentación técnica separada
├── kubernetes/           # Manifiestos estáticos YAML (Fase transicional a K8s)
├── nginx/                # Configuración, estáticos y Dockerfile del Frontend
├── scripts/              # Automatización (deploy_dev.sh, setups, tests)
└── terraform/            # Código HCL de Terraform
```

## Guía Rápida de Arranque (Estado Actual)

Si quieres levantar el proyecto al instante en su forma más evolucionada:

1. **Asegúrate de que Minikube esté corriendo con soporte para red (CNI):**
   ```bash
   minikube start --cni=calico
   ```
2. **Exporta la contraseña de la base de datos:**
   ```bash
   export TF_VAR_db_password="tu_super_password"
   ```
3. **Lanza el script de despliegue mágico:**
   ```bash
   ./scripts/deploy_dev.sh
   ```
4. **Para destruir todo el entorno:**
   ```bash
   cd terraform
   terraform destroy -var-file=dev.tfvars -auto-approve
   ```
