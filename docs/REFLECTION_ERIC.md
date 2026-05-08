# Reflexión Final de Eric: Mi experiencia en el proyecto GreenDevCorp

Después de todas estas semanas trabajando en el proyecto de GreenDevCorp, me he dado cuenta de lo mucho que ha cambiado mi forma de ver la infraestructura. Empecé simplemente metiendo cosas en contenedores y he terminado montando todo un sistema automatizado en Kubernetes con Terraform. Ha sido un camino intenso, con bastantes dolores de cabeza, pero he aprendido un montón.

## Lo más difícil: Cambiar el chip a Terraform

Si soy sincero, lo que más me costó no fue Docker ni hacer las imágenes. Lo que de verdad me hizo sudar fue pasar de aplicar los archivos YAML a mano con `kubectl apply` a dejar que Terraform se encargara de todo (IaC). 

Al principio no terminaba de pillar qué era eso del "archivo de estado" (el famoso `tfstate`) y me frustraba cuando las cosas no cuadraban. Me pegué bastante con las dependencias; por ejemplo, que si el Deployment intentaba arrancar antes de que el Secret estuviera creado, todo fallaba. Al final, después de leer mucha documentación y pegarme con mil errores, entendí que trabajar de forma declarativa te obliga a ser mucho más ordenado. Me enseñó que si lo dejas todo bien definido en el código, te ahorras un montón de líos manuales luego.

## Lo que más me ha sorprendido

Me quedé bastante flipado con las **NetworkPolicies**. Me parece increíble que, con solo un trozo de código, puedas cerrar por completo el tráfico de la red y decidir exactamente quién puede hablar con quién. Ver que un pod de desarrollo no podía tocar la base de datos de producción aunque tuviera la IP fue el momento en el que vi que la seguridad en Kubernetes va en serio.

Otra cosa que me "voló la cabeza" fue ver la auto-recuperación en directo. Matar un pod de la base de datos a propósito y ver cómo Kubernetes lo levantaba de nuevo en segundos, enganchando automáticamente el disco con todos los datos guardados (el Persistent Volume), me pareció magia. Ahí fue cuando entendí de verdad qué significa la "alta disponibilidad".

## ¿Qué haría diferente si empezara hoy?

Si tuviera que volver al primer día, me organizaría mucho mejor con las **etiquetas (labels)**. Al principio las ponía un poco a voleo para que las cosas conectaran, y cuando llegué a la parte de seguridad, tuve que rehacer medio proyecto porque las NetworkPolicies se basan precisamente en esas etiquetas. Me volví loco cambiando nombres para que todo cuadrara.

También intentaría modularizar el código de Terraform desde el principio. Al final me quedó un poco de "código espagueti" y tuve que dedicar tiempo a limpiarlo y separar lo que es la red de lo que es la aplicación.

## Mi visión de DevOps ahora

Antes de empezar, pensaba que DevOps era simplemente saber usar cuatro herramientas modernas o hacer que los scripts corrieran rápido. Ahora veo que es más una filosofía de trabajo. 

He aprendido que no se trata de "darle al botón", sino de crear sistemas que sean fiables y repetibles. Que yo pueda borrar toda la infraestructura y levantarla de nuevo en 3 minutos con un solo script me parece la mayor ventaja de todo esto. Además, me he dado cuenta de que documentar bien (con los Runbooks y el README) es tan importante como escribir el código, porque si no, el sistema es imposible de mantener.

## Lo que me queda por aprender

Me he quedado con ganas de probar todo esto en una nube de verdad, como AWS o Google Cloud, para ver las diferencias con Minikube. También me llama la atención profundizar en temas de seguridad más avanzados, como la gestión de secretos con Vault o el uso de Service Meshes como Istio para ver qué pasa dentro de los microservicios. En resumen, esto de DevOps es un mundo infinito y esto solo ha sido el principio.
