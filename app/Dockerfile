# Fase 1: Construcción
FROM node:22-alpine AS builder

WORKDIR /build
COPY package.json ./
# Instalamos dependencias, aunque no haya en este caso (preparado para el futuro)
RUN apk update && apk upgrade --no-cache
RUN npm install
COPY src/ ./src/

# Fase 2: Runtime
FROM node:22-alpine

ENV PORT=3000
ENV NODE_ENV=production

# Parchear vulnerabilidades del sistema base en runtime
RUN apk update && apk upgrade --no-cache

# Eliminar NPM del contenedor de producción para mitigar CVEs asociados
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Crear grupo y usuario no-root por seguridad
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /home/appuser/app

# Copiar artefactos de la fase de builder
COPY --from=builder /build/package.json ./
COPY --from=builder /build/src/ ./src/
COPY --from=builder /build/node_modules/ ./node_modules/

# Cambiar ownership al usuario no-root
RUN chown -R appuser:appgroup /home/appuser/app

USER appuser

EXPOSE $PORT

CMD ["node", "src/server.js"]
