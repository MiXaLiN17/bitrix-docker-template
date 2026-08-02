.PHONY: help build up down restart logs ps composer-install composer-update composer-require composer-remove shell shell-db clean db-reset db-connect sphinx-enable sphinx-disable sphinx-cli sphinx-status sphinx-truncate

# Подключение .env файла
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Цвета для вывода
GREEN  := \033[0;32m
YELLOW := \033[0;33m
NC     := \033[0m # No Color

# Переменные
COMPOSE_PROJECT_NAME ?= clear
WEBSERVER_CONTAINER = ${COMPOSE_PROJECT_NAME}_webserver
PHP_CONTAINER = ${COMPOSE_PROJECT_NAME}_app
DB_CONTAINER = ${COMPOSE_PROJECT_NAME}_db
SPHINX_CONTAINER = ${COMPOSE_PROJECT_NAME}_sphinx
COMPOSER_DIR = ./

# Профили всех опциональных сервисов. Команды остановки, логов и статуса должны видеть
# весь стек: docker compose down не трогает контейнеры сервисов с неактивным профилем
ALL_PROFILES = sphinx
COMPOSE_ALL = COMPOSE_PROFILES=$(ALL_PROFILES) docker compose

# Идентификатор индекса из .docker/sphinx/conf/sphinx.conf
SPHINX_INDEX = bitrix
# Профиль задаём явно, чтобы команды работали независимо от COMPOSE_PROFILES в .env
SPHINX_COMPOSE = COMPOSE_PROFILES=sphinx docker compose
SPHINX_SQL = $(SPHINX_COMPOSE) exec sphinx mysql -h 127.0.0.1 -P 9306
SPHINX_GUARD = if [ -z "$$(docker ps -q -f name=^/${SPHINX_CONTAINER}$$)" ]; then \
		echo "${YELLOW}Контейнер ${SPHINX_CONTAINER} не запущен. Включить Sphinx: make sphinx-enable${NC}"; \
		exit 1; \
	fi

help: ## Показать справку по командам
	@echo "${GREEN}Доступные команды:${NC}"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s ${YELLOW}%-20s${NC} %s\n", "Makefile", $$1, $$2}' $(MAKEFILE_LIST) | sort

build: ## Собрать проект (build Docker образы)
	@echo "${GREEN}Сборка Docker образов...${NC}"
	docker compose build

up: ## Запустить проект
	@echo "${GREEN}Запуск проекта...${NC}"
	docker compose up -d
	@echo "${GREEN}Проект запущен!${NC}"

down: ## Выключить Docker контейнеры
	@echo "${YELLOW}Остановка Docker контейнеров...${NC}"
	$(COMPOSE_ALL) down
	@echo "${GREEN}Контейнеры остановлены!${NC}"

restart: ## Перезапустить проект
	@echo "${YELLOW}Перезапуск проекта...${NC}"
	$(COMPOSE_ALL) restart
	@echo "${GREEN}Проект перезапущен!${NC}"

logs: ## Показать логи всех контейнеров
	$(COMPOSE_ALL) logs -f

logs-web: ## Показать логи веб-сервера
	docker compose logs -f webserver

logs-db: ## Показать логи базы данных
	docker compose logs -f db

logs-app: ## Показать логи php
	docker compose logs -f app

logs-sphinx: ## Показать логи Sphinx
	$(SPHINX_COMPOSE) logs -f sphinx

ps: ## Показать статус контейнеров
	$(COMPOSE_ALL) ps

composer-install: ## Установить зависимости Composer
	@echo "${GREEN}Установка зависимостей Composer в $(COMPOSER_DIR)...${NC}"
	@docker exec -it ${PHP_CONTAINER} bash -c "cd $(COMPOSER_DIR) && composer install"


composer-update: ## Обновить зависимости Composer
	@echo "${GREEN}Обновление зависимостей Composer в $(COMPOSER_DIR)...${NC}"
	@docker exec -it ${PHP_CONTAINER} bash -c "cd $(COMPOSER_DIR) && composer update"

composer-require: ## Добавить зависимость через Composer (использование: make composer-require PACKAGE=vendor/package)
	@if [ -z "$(PACKAGE)" ]; then \
		echo "${YELLOW}Использование: make composer-require PACKAGE=vendor/package${NC}"; \
		exit 1; \
	fi
	@echo "${GREEN}Добавление пакета $(PACKAGE) в $(COMPOSER_DIR)...${NC}"
	@docker exec -it ${PHP_CONTAINER} bash -c "cd $(COMPOSER_DIR) && composer require $(PACKAGE)"

composer-remove: ## Удалить зависимость через Composer (использование: make composer-remove PACKAGE=vendor/package)
	@if [ -z "$(PACKAGE)" ]; then \
		echo "${YELLOW}Использование: make composer-remove PACKAGE=vendor/package${NC}"; \
		exit 1; \
	fi
	@echo "${YELLOW}Удаление пакета $(PACKAGE) из $(COMPOSER_DIR)...${NC}"
	@docker exec -it ${PHP_CONTAINER} bash -c "cd $(COMPOSER_DIR) && composer remove $(PACKAGE)"

shell: ## Открыть shell в контейнере веб-сервера
	@echo "${GREEN}Подключение к контейнеру веб-сервера...${NC}"
	docker compose exec webserver bash

shell-db: ## Открыть shell в контейнере базы данных
	@echo "${GREEN}Подключение к контейнеру базы данных...${NC}"
	docker compose exec db bash

shell-app: ## Открыть shell в контейнере php
	@echo "${GREEN}Подключение к контейнеру php...${NC}"
	docker compose exec app bash

shell-sphinx: ## Открыть shell в контейнере Sphinx
	@$(SPHINX_GUARD)
	@echo "${GREEN}Подключение к контейнеру Sphinx...${NC}"
	$(SPHINX_COMPOSE) exec sphinx bash

mysql: ## Подключиться к MySQL
	docker compose exec db mysql -uroot -p

db-connect: ## Подключиться к MySQL с пользователем docker
	@echo "${GREEN}Подключение к MySQL (user: docker, password: docker)...${NC}"
	docker compose exec db mysql -udocker -pdocker docker

db-reset: ## Пересоздать volume базы данных (удалит все данные!)
	@echo "${YELLOW}ВНИМАНИЕ: Это удалит все данные базы данных!${NC}"
	@read -p "Продолжить? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "${YELLOW}Остановка контейнеров...${NC}"
	$(COMPOSE_ALL) down
	@echo "${YELLOW}Удаление volume базы данных...${NC}"
	docker volume rm ${COMPOSE_PROJECT_NAME}-db || true
	@echo "${GREEN}Запуск контейнеров с новым volume...${NC}"
	docker compose up -d
	@echo "${GREEN}База данных пересоздана!${NC}"

sphinx-enable: ## Включить сервис Sphinx (профиль в .env) и запустить его
	@if [ ! -f .env ]; then echo "${YELLOW}Нет файла .env${NC}"; exit 1; fi
	@if grep -q "^COMPOSE_PROFILES=" .env; then \
		sed -i "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=sphinx|" .env; \
	else \
		echo "COMPOSE_PROFILES=sphinx" >> .env; \
	fi
	@mkdir -p ./logs/sphinx
	@echo "${GREEN}Профиль sphinx включён, собираем и запускаем контейнер...${NC}"
	$(SPHINX_COMPOSE) up -d --build sphinx
	@echo "${GREEN}Sphinx запущен. Настройки для админки Битрикса: sphinx:9306, индекс '${SPHINX_INDEX}'${NC}"

sphinx-disable: ## Отключить сервис Sphinx и удалить его контейнер
	@if [ ! -f .env ]; then echo "${YELLOW}Нет файла .env${NC}"; exit 1; fi
	@echo "${YELLOW}Остановка и удаление контейнера Sphinx (индекс в volume сохранится)...${NC}"
	-@$(SPHINX_COMPOSE) rm -sf sphinx
	@if grep -q "^COMPOSE_PROFILES=" .env; then \
		sed -i "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=|" .env; \
	fi
	@echo "${GREEN}Профиль sphinx отключён${NC}"

sphinx-cli: ## Открыть консоль SphinxQL
	@$(SPHINX_GUARD)
	@echo "${GREEN}Подключение к SphinxQL (${SPHINX_CONTAINER}:9306)...${NC}"
	$(SPHINX_SQL)

sphinx-status: ## Показать индексы и статистику Sphinx
	@$(SPHINX_GUARD)
	@$(SPHINX_SQL) -e "SHOW TABLES; SELECT COUNT(*) AS documents FROM ${SPHINX_INDEX}; SHOW STATUS;"

sphinx-truncate: ## Очистить индекс Sphinx (после нужна переиндексация в админке Битрикса)
	@$(SPHINX_GUARD)
	@echo "${YELLOW}ВНИМАНИЕ: индекс '${SPHINX_INDEX}' будет очищен!${NC}"
	@read -p "Продолжить? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	@$(SPHINX_SQL) -e "TRUNCATE RTINDEX ${SPHINX_INDEX};"
	@echo "${GREEN}Индекс очищен. Выполните переиндексацию: Настройки > Поиск > Переиндексация${NC}"

clean: ## Остановить и удалить все контейнеры, сети и volumes
	@echo "${YELLOW}Удаление всех контейнеров, сетей и volumes...${NC}"
	$(COMPOSE_ALL) down -v
	@echo "${GREEN}Очистка завершена!${NC}"

rebuild: down build up ## Пересобрать и перезапустить проект
	@echo "${GREEN}Проект пересобран и запущен!${NC}"

restore: ## Скачать restore.php
	@echo "${YELLOW}Скачиваем restore.php с сайта bitrix...${NC}"
	wget -q -O ./src/restore.php https://www.1c-bitrix.ru/download/files/scripts/restore.php
	@echo "${GREEN}Файл скачан!${NC}"

setup: ## Скачать bitrixsetup.php
	@echo "${YELLOW}Скачиваем bitrixsetup.php с сайта bitrix...${NC}"
	wget -q -O ./src/bitrixsetup.php https://www.1c-bitrix.ru/download/files/scripts/bitrixsetup.php
	@echo "${GREEN}Файл скачан!${NC}"
