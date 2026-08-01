# Образ с DockerHub. Версия задаётся в .env (MYSQL_VERSION).
# Битрикс требует минимум MySQL 8.0, рекомендованная версия — 8.4 и выше.
ARG MYSQL_VERSION=8.4
FROM mysql:${MYSQL_VERSION}

COPY conf/my.cnf /etc/mysql/conf.d/my.cnf
# открываем порт
EXPOSE 3306
