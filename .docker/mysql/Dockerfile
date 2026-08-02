# Образ с DockerHub. Версия задаётся в .env (MYSQL_VERSION).
# Битрикс требует минимум MySQL 8.0, рекомендованная версия — 8.4 и выше.
ARG MYSQL_VERSION=8.4
FROM mysql:${MYSQL_VERSION}

COPY conf/my.cnf /etc/mysql/conf.d/my.cnf

# Проверяем именно по TCP (-h 127.0.0.1): во время первичной инициализации
# entrypoint поднимает временный сервер с --skip-networking, и контейнер
# останется unhealthy, пока база реально не будет готова принимать соединения.
# start-period 60s — запас на создание системных таблиц при первом запуске.
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=10 \
    CMD mysqladmin ping -h 127.0.0.1 -uroot -p"$MYSQL_ROOT_PASSWORD" --silent || exit 1

# открываем порт
EXPOSE 3306
