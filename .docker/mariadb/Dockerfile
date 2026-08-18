# Образ с DockerHub. Версия задаётся в .env (DB_VERSION).
# Ветку выбираем LTS: 11.4 поддерживается до 2029 года.
ARG DB_VERSION=11.4
FROM mariadb:${DB_VERSION}

COPY conf/my.cnf /etc/mysql/conf.d/my.cnf

# В MariaDB 11.x симлинков mysqladmin/mysql/mysqld больше нет, поэтому проверяем
# штатным скриптом из образа. --connect поднимает реальное соединение,
# --innodb_initialized ждёт, пока InnoDB закончит recovery: во время первичной
# инициализации сервер уже отвечает, но базы ещё не готовы принимать запросы.
# start-period 60s — запас на создание системных таблиц при первом запуске.
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=10 \
    CMD healthcheck.sh --connect --innodb_initialized || exit 1

# открываем порт
EXPOSE 3306
