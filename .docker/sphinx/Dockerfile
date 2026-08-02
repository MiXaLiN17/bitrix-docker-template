# Sphinx 2.2.11 — версия из состава BitrixVM.
# 1С-Битрикс поддерживает Sphinx от 2.1.1; ветка 3.x работает только с модулем "Поиск" 25.0.0+.
# Пакет sphinxsearch в Ubuntu 24.04 собран под amd64 и arm64 (работает и на Apple Silicon).
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

# mariadb-client-core даёт клиент mysql для SphinxQL (make sphinx-cli) и healthcheck.
# Именно core, а не полный mariadb-client: тот тянет perl и весит на 120 МБ больше.
# Клиент MySQL 8.x здесь не подходит — в нём отключён mysql_native_password, которым отвечает Sphinx.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        sphinxsearch \
        mariadb-client-core \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/sphinxsearch/data /var/log/sphinxsearch /var/run/sphinxsearch

# Пакет sphinxsearch уже заводит служебного пользователя (uid 100), но каталог логов
# монтируется с хоста и принадлежит хостовому пользователю — поэтому переносим
# sphinxsearch на его UID/GID, как это сделано для nginx и php.
# В ubuntu:24.04 id 1000 заняты пользователем ubuntu, его предварительно удаляем.
RUN taken_user="$(getent passwd ${UID} | cut -d: -f1)" \
    && if [ -n "$taken_user" ] && [ "$taken_user" != "sphinxsearch" ]; then userdel -r "$taken_user" 2>/dev/null || true; fi \
    && taken_group="$(getent group ${GID} | cut -d: -f1)" \
    && if [ -n "$taken_group" ] && [ "$taken_group" != "sphinxsearch" ]; then groupdel "$taken_group" 2>/dev/null || true; fi \
    && groupmod -g ${GID} sphinxsearch \
    && usermod -u ${UID} -g ${GID} sphinxsearch \
    && chown -R sphinxsearch:sphinxsearch \
        /var/lib/sphinxsearch/data /var/log/sphinxsearch /var/run/sphinxsearch

# Копируем конфигурацию с RT-индексом под структуру данных модуля "Поиск"
COPY conf/sphinx.conf /etc/sphinxsearch/sphinx.conf

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD mysql -h 127.0.0.1 -P 9306 -e "SHOW TABLES" > /dev/null 2>&1 || exit 1

# 9312 — нативный протокол Sphinx, 9306 — SphinxQL (протокол MySQL), именно его использует Битрикс
EXPOSE 9312 9306

# Демон не требует root: порты непривилегированные, все рабочие каталоги отданы выше
USER sphinxsearch

# --nodetach: searchd остаётся на переднем плане и дублирует лог в stdout (docker compose logs)
CMD ["searchd", "--nodetach", "--config", "/etc/sphinxsearch/sphinx.conf"]
