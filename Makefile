.PHONY: help build up down restart logs ps composer-install composer-update composer-require composer-remove shell shell-db clean db-reset db-connect

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
COMPOSER_DIR = ./

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
	docker compose down
	@echo "${GREEN}Контейнеры остановлены!${NC}"

restart: ## Перезапустить проект
	@echo "${YELLOW}Перезапуск проекта...${NC}"
	docker compose restart
	@echo "${GREEN}Проект перезапущен!${NC}"

logs: ## Показать логи всех контейнеров
	docker compose logs -f

logs-web: ## Показать логи веб-сервера
	docker compose logs -f webserver

logs-db: ## Показать логи базы данных
	docker compose logs -f db

logs-app: ## Показать логи php
	docker compose logs -f app

ps: ## Показать статус контейнеров
	docker compose ps

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

mysql: ## Подключиться к MySQL
	docker compose exec db mysql -uroot -p

db-connect: ## Подключиться к MySQL с пользователем docker
	@echo "${GREEN}Подключение к MySQL (user: docker, password: docker)...${NC}"
	docker compose exec db mysql -udocker -pdocker docker

db-reset: ## Пересоздать volume базы данных (удалит все данные!)
	@echo "${YELLOW}ВНИМАНИЕ: Это удалит все данные базы данных!${NC}"
	@read -p "Продолжить? [y/N]: " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "${YELLOW}Остановка контейнеров...${NC}"
	docker compose down
	@echo "${YELLOW}Удаление volume базы данных...${NC}"
	docker volume rm ${COMPOSE_PROJECT_NAME}-db || true
	@echo "${GREEN}Запуск контейнеров с новым volume...${NC}"
	docker compose up -d
	@echo "${GREEN}База данных пересоздана!${NC}"

clean: ## Остановить и удалить все контейнеры, сети и volumes
	@echo "${YELLOW}Удаление всех контейнеров, сетей и volumes...${NC}"
	docker compose down -v
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
