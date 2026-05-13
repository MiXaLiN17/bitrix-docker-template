FROM nginx:1.29.3-alpine

ARG UID=1000
ARG GID=1000

RUN apk add --no-cache --virtual .user-tools shadow && \
    rm -f /etc/nginx/conf.d/default.conf && \
    groupmod -g ${GID} nginx && \
    usermod -u ${UID} -g nginx nginx && \
    mkdir -p /var/log/nginx /var/cache/nginx /var/www/src && \
    chown -R nginx:nginx /var/log/nginx /var/cache/nginx /var/www/src && \
    apk del .user-tools

# Копируем конфигурацию
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/upstream.conf /etc/nginx/conf.d/upstream.conf
COPY conf/backend.conf /etc/nginx/conf.d/backend.conf


HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget -q -O - http://127.0.0.1/health >/dev/null || exit 1

# Настраиваем рабочую директорию
WORKDIR /var/www/src

CMD ["nginx", "-g", "daemon off;"]

EXPOSE 80
