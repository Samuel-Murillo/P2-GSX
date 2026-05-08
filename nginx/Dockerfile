# Fase 1: Build (para simular un multistage build aunque sea estático)
FROM alpine:latest AS builder
RUN mkdir /site && echo "<h1>Welcome to GreenDevCorp Nginx</h1>" > /site/index.html

# Fase 2: Runtime
FROM nginx:1.27-alpine
ENV NGINX_PORT=8080

# Parchear vulnerabilidades del sistema base (CVEs)
RUN apk update && apk upgrade --no-cache

# Copiar el archivo personalizado y la configuración
COPY --from=builder /site/index.html /usr/share/nginx/html/index.html
COPY nginx.conf /etc/nginx/nginx.conf

# Ajustar permisos para usuario non-root (nginx)
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /tmp/nginx.pid && \
    chown -R nginx:nginx /tmp/nginx.pid

# Cambiar al usuario non-root
USER nginx

EXPOSE $NGINX_PORT
CMD ["nginx", "-g", "daemon off;"]
