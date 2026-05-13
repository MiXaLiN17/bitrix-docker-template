#!/bin/bash

# Импортируем переменные из .env (удаляем \r из Windows-переносов)
set -a
source <(sed 's/\r$//' ./.env)
set +a

# Создаём директории для логов на основании переменных .env
mkdir -p "${WEB_SERVER_LOG_DIR}"
mkdir -p "${APP_LOG_DIR}"
mkdir -p "${MYSQL_LOG_DIR}"
mkdir -p "${FRONTEND_LOG_DIR}"
mkdir -p "src"

echo "Все необходимые директории созданы."
