# Semana 12: Diseño de Red e Identidad

Este documento unifica el diseño de red (segmentación CIDR y NetworkPolicies), la investigación sobre servicios core e identidad, y la metodología de pruebas para verificar el correcto aislamiento de los recursos en Kubernetes.

---

## PARTE 1: Diseño de Arquitectura de Red y Planificación CIDR

### 1.1 Diagrama de Arquitectura de Red

```mermaid
graph LR
    Internet(["Internet"])
    Partners(["Partners Externos"])
    Oficina(["Oficina Central / VPN"])

    FW1{{"Firewall Perimetral - FW1"}}

    Internet -->|"HTTPS 443 / HTTP 80"| FW1
    Partners -->|"VPN IPsec"| FW1
    Oficina  -->|"VPN SD-WAN"| FW1

    subgraph DMZ ["DMZ - Zona Desmilitarizada 10.0.1.0/24"]
        direction TB
        Nginx_DMZ["Nginx - Reverse Proxy 10.0.1.10"]
        Bastion["Bastion Host - SSH 10.0.1.20"]
    end

    FW1 -->|"Solo 80 y 443"| Nginx_DMZ
    FW1 -.->|"Solo 22 - solo admins"| Bastion

    FW2{{"Firewall Interno - FW2"}}

    Nginx_DMZ -->|"Proxy Pass HTTP"| FW2
    Bastion -.->|"Acceso admin"| FW2

    subgraph Interna ["Red Corporativa Interna 10.0.0.0/16"]
        direction TB

        subgraph K8s ["Cluster Kubernetes"]
            direction TB

            subgraph Prod ["Produccion 10.0.10.0/24"]
                direction LR
                App_Prod["Node.js"] --> DB_Prod[("PostgreSQL")]
            end

            subgraph Staging ["Staging 10.0.20.0/24"]
                direction LR
                App_Stg["Node.js"] --> DB_Stg[("PostgreSQL")]
            end

            subgraph Dev ["Desarrollo 10.0.30.0/24"]
                direction LR
                App_Dev["Node.js"] --> DB_Dev[("PostgreSQL")]
            end
        end

        subgraph Core ["Servicios Core 10.0.100.0/24"]
            direction TB
            DNS["DNS Interno"]
            LDAP["OpenLDAP / IdP"]
            NTP["NTP Server"]
        end
    end

    FW2 -->|"App Prod"| App_Prod
    FW2 -->|"App Staging"| App_Stg
    FW2 -->|"App Dev"| App_Dev

    K8s -->|"Auth y DNS interno"| Core
    Bastion -.->|"kubectl / SSH"| K8s

    classDef external   fill:#ffcdd2,stroke:#c62828,color:#000
    classDef fw         fill:#ff8a65,stroke:#bf360c,color:#000
    classDef dmz        fill:#ffe0b2,stroke:#e65100,color:#000
    classDef prod_style fill:#c8e6c9,stroke:#1b5e20,color:#000
    classDef stg_style  fill:#fff9c4,stroke:#f57f17,color:#000
    classDef dev_style  fill:#bbdefb,stroke:#0d47a1,color:#000
    classDef core_style fill:#e1bee7,stroke:#4a148c,color:#000

    class Internet,Partners,Oficina external
    class FW1,FW2 fw
    class Nginx_DMZ,Bastion dmz
    class App_Prod,DB_Prod prod_style
    class App_Stg,DB_Stg stg_style
    class App_Dev,DB_Dev dev_style
    class DNS,LDAP,NTP core_style
```

### 1.2 Plan de Direccionamiento IP (CIDR)

Se ha adoptado el bloque `10.0.0.0/16` para toda la organización, proporcionando 65,536 direcciones IP, lo cual es altamente escalable. 

| Segmento de Red              | Subred CIDR     | IPs Disponibles | Propósito                                                       |
| :--------------------------- | :-------------- | :-------------- | :-------------------------------------------------------------- |
| **Red Corporativa (Global)** | `10.0.0.0/16`   | 65,536          | Todo el tráfico corporativo interno.                            |
| **DMZ / Servicios Expuestos** | `10.0.1.0/24`   | 254             | Nginx Reverse Proxy (cara pública) y Bastion Host (administración SSH). |
| **Producción (Prod)**        | `10.0.10.0/24`  | 254             | Nodos y pods del entorno de producción. Aislado estrictamente.  |
| **Staging (Pre-Prod)**       | `10.0.20.0/24`  | 254             | Entorno de pruebas previo a producción.                         |
| **Desarrollo (Dev)**         | `10.0.30.0/24`  | 254             | Entorno para desarrolladores y pruebas continuas.               |
| **Servicios Core (Infra)**   | `10.0.100.0/24` | 254             | DNS, NTP, LDAP/AD, herramientas de monitorización (Prometheus). |
| **VPN de Partners**          | `10.0.200.0/24` | 254             | Segmento asignado dinámicamente a conexiones VPN externas.      |

### 1.3 Fronteras de Seguridad (Security Boundaries)

Esta segmentación responde al principio de **defensa en profundidad** y **mínimo privilegio**:
* **Internet a DMZ (FW1):** Permitido **SÓLO** puertos 80 y 443 hacia el Nginx Reverse Proxy. El Bastion Host solo acepta conexiones SSH (puerto 22) desde IPs de administración. El resto del tráfico está bloqueado.
* **DMZ a Red Interna (FW2):** El Nginx de la DMZ puede hacer `proxy_pass` hacia los backends (Node.js) en la red interna. El Bastion puede acceder al clúster Kubernetes para administración. Ningún otro tráfico proveniente de la DMZ puede entrar a la red interna.
* **Intra-Entorno (Backend a DB):** El Backend (Node.js) solo puede comunicarse con su PostgreSQL en el puerto 5432. Todo el resto de tráfico entrante a la DB se **deniega implícitamente**.
* **Inter-Entorno (Prod ↔ Dev):** Todo el tráfico cruzado entre namespaces de distintos entornos está **estrictamente bloqueado** usando `kubernetes_network_policy`.

Esto previene la configuración errónea accidental: si un desarrollador configura la base de datos de producción en el archivo `dev.tfvars`, la conexión fallará por red, evitando corrupción de datos.

### 1.4 Diseño Avanzado: Conectividad VPN y Exposición a Partners

* **Conexión VPN Site-to-Site:** Para conectar oficinas físicas, se implementa un túnel IPsec en el Firewall Perimetral. El tráfico interno viaja cifrado por Internet.
* **VPN Client-to-Site (Teletrabajo/Partners):** Los usuarios se conectan mediante OpenVPN o WireGuard y reciben una IP del rango reservado `10.0.200.0/24`. 
* **Exposición Segura:** Para exponer servicios a Partners, el tráfico ingresa por VPN. Una regla de firewall específica solo permite tráfico del rango `10.0.200.0/24` hacia un servicio específico en la DMZ.

### 1.5 Análisis de Seguridad y Mitigación de Riesgos

La infraestructura de GreenDevCorp está diseñada para mitigar los ataques más comunes mediante capas superpuestas:

| Riesgo Identificado | Estrategia de Mitigación | Implementación en la Práctica |
| :--- | :--- | :--- |
| **Movimiento Lateral** | Aislamiento de red (Microsegmentación). | `NetworkPolicies` con política de *Default Deny*. Si un Pod es comprometido, el atacante no puede "saltar" a otros pods. |
| **Acceso no autorizado a DB** | Restricción estricta de tráfico entrante. | Solo los pods con la etiqueta `app=backend` pueden conectar al puerto 5432 de la DB. |
| **Error Humano / Despiste** | Prevención de configuraciones erróneas. | Uso de **Terraform (IaC)**. Las políticas se definen en código, eliminando el riesgo de olvidar configurar un firewall manualmente. |
| **Ataque Externo Masivo** | Reducción de la superficie de ataque. | Solo el Ingress Controller tiene exposición pública. El Backend y la DB son totalmente invisibles desde Internet. |

#### ¿Cómo prevenimos configuraciones erróneas accidentales?
El sistema utiliza un enfoque de **Seguridad por Defecto (Secure by Default)**:
1.  **Validación en CI:** Antes de aplicar cualquier cambio, el pipeline de GitHub Actions valida que el código Terraform sea correcto.
2.  **Inmutabilidad de Red:** Las `NetworkPolicies` se aplican a nivel de Namespace. Si un desarrollador despliega por error un pod mal configurado en el entorno de producción, ese pod nacerá "mudo" por defecto, ya que no cumplirá con las etiquetas requeridas por las políticas de red activas.
3.  **Aislamiento de Entornos:** La segmentación CIDR y las políticas entre Namespaces aseguran que, incluso con una contraseña de producción válida, un pod en el entorno de Desarrollo jamás podrá establecer una conexión TCP con la base de datos de Producción.


---

## PARTE 2: Investigación Tecnológica e Identidad

### 2.1 Servicios Core de Red

*   **DNS (Domain Name System):** Funciona como la "agenda de contactos" de la red. Traduce los nombres fáciles de recordar (como `www.greendevcorp.com`) en direcciones numéricas IP que las máquinas necesitan para conectarse.
*   **DHCP (Dynamic Host Configuration Protocol):** Es el "recepcionista". Cuando conectas un dispositivo a la red, el servidor DHCP le "alquila" automáticamente una dirección IP disponible y le da la configuración para navegar, ahorrando configuración manual y evitando conflictos de IP.
*   **NTP (Network Time Protocol) y Seguridad:** Es el "relojero oficial", asegurando que todos los dispositivos tengan la misma hora exacta. **Es crucial para la seguridad** porque la criptografía, certificados HTTPS y los tokens de sesión dependen de marcas de tiempo. Si hay desfase, un sistema puede sufrir ataques de "replay" o bloquear logins legítimos.

### 2.2 Gestión de Identidad: Autenticación vs Autorización
Son dos pasos diferentes pero complementarios:
*   **Autenticación (AuthN):** Responde a *"¿Quién eres?"* (ej. usuario y contraseña).
*   **Autorización (AuthZ):** Responde a *"¿Qué puedes hacer?"* (ej. tienes permiso para leer, pero no para borrar).

### 2.3 Tecnologías de Identidad
*   **LDAP:** Protocolo abierto y base de datos optimizada para leer rápidamente quién es quién en una organización.
*   **Active Directory (AD):** Producto de Microsoft que usa LDAP pero añade políticas de grupo (GPO) y gestión nativa para entornos Windows.
*   **SSO (Single Sign-On):** Permite a un usuario autenticarse una sola vez y acceder a múltiples aplicaciones sin volver a introducir contraseñas. 

**¿Por qué identidad centralizada?** Evita el "infierno de las contraseñas", donde un empleado usa cuentas distintas para el correo, VPN, CRM y servidores. Empresas pequeñas (1-10 empleados) sobreviven con gestión manual, pero para empresas en crecimiento (20+ empleados) es obligatorio por seguridad, rotación de personal (onboarding/offboarding) y auditoría.

### 2.4 Estrategia de Identidad para GreenDevCorp

Dado que GreenDevCorp tiene **más de 20 personas** y usa Kubernetes, la gestión manual es peligrosa.

**Recomendación:** Adoptar un Proveedor de Identidad (IdP) basado en la nube (ej. Entra ID, Okta o Google Cloud Identity) con **SSO nativo**.
*   **Pros:** Mantenimiento cero (sin servidores que parchear), SSO y MFA (doble factor) nativo, integración moderna (OIDC/SAML) con Kubernetes, y bloqueo instantáneo de ex-empleados con un clic.
*   **Contras:** Costo recurrente mensual por usuario (OpEx) y dependencia del proveedor (Vendor Lock-in).

---

## PARTE 3: Manual Paso a Paso (Pruebas de Políticas de Red)

Las *NetworkPolicies* de Kubernetes operan a nivel de red interrumpiendo conexiones no autorizadas (como un firewall interno). Para verificar empíricamente que el aislamiento de entornos y la protección de bases de datos de la Parte 1 funciona, disponemos de un script de pruebas.

### 3.1 Requisitos Previos Críticos

Para que Kubernetes haga cumplir estas políticas, **necesitas arrancar Minikube con un CNI avanzado (como Calico)**. Si usas el Minikube básico, las políticas se crearán pero serán ignoradas.

```bash
# Iniciar con soporte de firewall de red
minikube delete
minikube start --cni=calico
```

Luego, aplica Terraform usando el orquestador:
```bash
export TF_VAR_db_password="tupassword"
./scripts/deploy_terraform.sh
```

### 3.2 Ejecutar las Pruebas de Intrusión

El script levanta pods "intrusos" y simula conexiones cruzadas y escaneos de puertos no autorizados.

```bash
./scripts/k8s_check_security.sh
```

**Interpretación:**
* Si ves `✅ ÉXITO (Esperado): La política BLOQUEÓ al intruso`, el firewall cerró efectivamente la conexión (Timeout). La seguridad es robusta.
* Si el intruso *logra* conectarse a la base de datos, tu Minikube no arrancó correctamente con Calico.
