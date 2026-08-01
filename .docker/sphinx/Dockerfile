# Sphinx 2.2.11 — версия из состава BitrixVM.
# 1С-Битрикс поддерживает Sphinx от 2.1.1; ветка 3.x работает только с модулем "Поиск" 25.0.0+.
# Пакет sphinxsearch в Ubuntu 24.04 собран под amd64 и arm64 (работает и на Apple Silicon).
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# mariadb-client-core даёт клиент mysql для SphinxQL (make sphinx-cli) и healthcheck.
# Именно core, а не полный mariadb-client: тот тянет perl и весит на 120 МБ больше.
# Клиент MySQL 8.x здесь не подходит — в нём отключён mysql_native_password, которым отвечает Sphinx.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        sphinxsearch \
        mariadb-client-core \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/lib/sphinxsearch/data /var/log/sphinxsearch /var/run/sphinxsearch

# Копируем конфигурацию с RT-индексом под структуру данных модуля "Поиск"
COPY conf/sphinx.conf /etc/sphinxsearch/sphinx.conf

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD mysql -h 127.0.0.1 -P 9306 -e "SHOW TABLES" > /dev/null 2>&1 || exit 1

# 9312 — нативный протокол Sphinx, 9306 — SphinxQL (протокол MySQL), именно его использует Битрикс
EXPOSE 9312 9306

# --nodetach: searchd остаётся на переднем плане и дублирует лог в stdout (docker compose logs)
CMD ["searchd", "--nodetach", "--config", "/etc/sphinxsearch/sphinx.conf"]
