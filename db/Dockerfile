FROM postgres:15-alpine

# Parchear vulnerabilidades del sistema base (CVEs)
RUN apk update && apk upgrade --no-cache

# El binario 'gosu' incluido en postgres:15-alpine está compilado con una versión vulnerable de Go (stdlib).
# Lo reemplazamos por 'su-exec' (binario en C) que es el estándar de Alpine y no arrastra estas vulnerabilidades.
RUN apk add --no-cache su-exec && \
    rm -f /usr/local/bin/gosu && \
    ln -s /sbin/su-exec /usr/local/bin/gosu
