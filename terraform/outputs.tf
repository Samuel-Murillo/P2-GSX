# terraform/outputs.tf
# Salidas utiles tras ejecutar terraform apply.

output "namespace" {
  description = "Nombre del namespace de Kubernetes creado para este entorno."
  value       = kubernetes_namespace.greendev.metadata[0].name
}

output "nginx_node_port" {
  description = "Puerto NodePort expuesto por el Service de Nginx. Acceder via http://<MINIKUBE_IP>:<PORT>."
  value       = var.nginx_node_port
}

output "minikube_access_hint" {
  description = "Comando para obtener la URL de acceso a la aplicacion a traves de Minikube."
  value       = "minikube service nginx-service -n ${kubernetes_namespace.greendev.metadata[0].name} --url"
}

output "app_service_cluster_ip" {
  description = "Nombre DNS interno del Service del backend dentro del cluster."
  value       = "app.${kubernetes_namespace.greendev.metadata[0].name}.svc.cluster.local:${var.app_port}"
}

output "db_service_cluster_ip" {
  description = "Nombre DNS interno del Service de la base de datos dentro del cluster."
  value       = "${var.db_service_name}.${kubernetes_namespace.greendev.metadata[0].name}.svc.cluster.local:${var.db_port}"
}

output "image_tag_deployed" {
  description = "Etiqueta de imagen que fue aplicada en este despliegue."
  value       = var.image_tag
}

output "environment" {
  description = "Nombre del entorno desplegado."
  value       = var.environment
}
