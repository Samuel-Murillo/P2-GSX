# Proceso de Integración y Pruebas (Semana 13)

Este documento detalla la metodología, los tiempos y los retos superados durante la fase de integración final de la infraestructura de GreenDevCorp.

## 1. El Test de Integración (`scripts/integration_test.sh`)

Para garantizar la calidad y seguridad del despliegue, hemos desarrollado un script de integración "End-to-End" que automatiza todo el ciclo de vida de la infraestructura.

### Metodología del Test
El script sigue cuatro fases críticas:
1.  **Limpieza (Destroy):** Elimina cualquier rastro de infraestructuras anteriores para garantizar un test desde cero.
2.  **Preparación de Imágenes:** Carga las imágenes Docker locales directamente en el registro de Minikube.
3.  **Despliegue (Apply):** Ejecuta Terraform para levantar el Namespace, NetworkPolicies, StatefulSets y Deployments.
4.  **Validación de Salud (Healthchecks):** Verifica que Nginx, App y DB estén operativos.
5.  **Pruebas de Seguridad (Pen-Test):** Intenta realizar conexiones prohibidas entre pods para validar el firewall interno.

### Métricas de Despliegue
*   **Tiempo de limpieza total:** ~30-40 segundos.
*   **Tiempo de carga de imágenes en Minikube:** ~20 segundos por imagen.
*   **Tiempo de aprovisionamiento de Terraform:** ~45-60 segundos.
*   **Tiempo de estabilización de Pods:** ~30 segundos.
*   **Tiempo Total del Proceso:** **~3 minutos (180 segundos)**.

---

## 2. Registro de Problemas y Soluciones

Durante la integración surgieron varios desafíos técnicos que fueron resueltos para alcanzar la estabilidad actual:

| Problema detectado | Causa raíz | Solución aplicada |
| :--- | :--- | :--- |
| **Error `ImagePullBackOff`** | Minikube intentaba descargar las imágenes de Internet en lugar de usar las locales. | Se añadió el comando `minikube image load` al flujo de integración y se configuró `image_pull_policy = "IfNotPresent"`. |
| **Fallo en Healthcheck de DB** | El script de test intentaba conectar a la IP del pod, la cual es dinámica. | Se cambió la validación para que apunte al nombre DNS del `Service` de la base de datos (`db-service`). |
| **NetworkPolicies ignoradas** | El CNI por defecto de Minikube (Docker) no soporta filtrado de red. | Se documentó y automatizó el arranque de Minikube con el CNI **Calico** (`--cni=calico`). |
| **Error de Sintaxis en Pods** | Error tipográfico en el comando `kubectl run` durante los tests de intrusión. | Se corrigió el espaciado en los argumentos de labels en el script de integración. |
| **Bloqueo de red en macOS** | El driver de Docker en Mac a veces aísla el tráfico de red de forma distinta a Linux. | Se añadieron tiempos de espera (timeouts) y reintentos en los comandos `curl` de validación. |

---


