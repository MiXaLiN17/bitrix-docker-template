# Design: Bitrix Docker Template Automation

**Date:** 2026-05-13
**Status:** Approved

## Overview

Автоматизация разворачивания Docker-инфраструктуры для Bitrix-проектов одной командой. Шаблон хранится в git-репозитории. Новый проект создаётся через клонирование шаблона и запуск `create.sh`.

## Рабочий процесс

```bash
git clone git@github.com:you/bitrix-docker-template.git ford-transit.loc
cd ford-transit.loc
./create.sh
```

## Стек

- Nginx 1.29.3-alpine
- PHP 8.3-FPM-alpine (с Composer, Xdebug, imagick)
- MySQL 8.4

## Структура репозитория шаблона

```
bitrix-docker-template/
├── .docker/
│   ├── nginx/
│   │   ├── Dockerfile
│   │   └── conf/
│   ├── php/
│   │   ├── Dockerfile
│   │   └── conf/
│   └── mysql/
│       ├── Dockerfile
│       └── conf/
├── src/                  # пустая папка (placeholder для Bitrix)
├── docs/
├── .dockerignore
├── .editorconfig
├── .env.example
├── docker-compose.yml
├── Makefile
└── create.sh
```

**Удалено из шаблона:**
- `init.sh` — логика переехала в `create.sh`

## `create.sh` — логика

### Шаг 1: Автоопределение дефолтов

- **Имя проекта:** `$(basename "$PWD" | cut -d'.' -f1)`
  - Пример: запуск из `ford-transit.loc/` → дефолт `ford-transit`
- **HTTP-порт:** перебор диапазона 81–500, первый свободный через `ss -tlnp`

### Шаг 2: Интерактивный ввод (два вопроса)

```
Project name [ford-transit]:
HTTP port [83]:
```

Enter без ввода принимает дефолт.

### Шаг 3: Генерация `.env`

На основе `.env.example` с подстановкой:

| Переменная | Значение |
|---|---|
| `COMPOSE_PROJECT_NAME` | имя проекта |
| `UID` | `$(id -u)` |
| `GID` | `$(id -g)` |
| `HOST_MACHINE_UNSECURE_HOST_PORT` | выбранный HTTP-порт |
| `MYSQL_DATABASE` | статично из `.env.example` |
| `MYSQL_USER` | статично из `.env.example` |
| `MYSQL_PASSWORD` | статично из `.env.example` |
| `MYSQL_ROOT_PASSWORD` | статично из `.env.example` |
| `WEB_SERVER_LOG_DIR` | `./logs/nginx` |
| `APP_LOG_DIR` | `./logs/app` |
| `MYSQL_LOG_DIR` | `./logs/mysql` |
| `FRONTEND_LOG_DIR` | `./logs/frontend` |

### Шаг 4: Создание директорий логов

```bash
mkdir -p ./logs/nginx ./logs/app ./logs/mysql ./logs/frontend ./src
```

### Шаг 5: Сборка и запуск

```bash
make build && make up
```

### Шаг 6: Самоудаление

```bash
rm -- "$0"
```

`create.sh` нужен только при инициализации, после удаляет себя.

## Изменения в `docker-compose.yml`

Секция `ports` у сервиса `db` закомментирована по умолчанию:

```yaml
db:
  # ports:
  #   - ${HOST_MACHINE_MYSQL_PORT:-3306}:3306
```

MySQL доступен только внутри Docker-сети. Раскомментировать вручную при необходимости прямого подключения с хоста.

## Изменения в `Makefile`

- Убрать переменную `CONSOLE_DIE` и цели `migrate`, `swagger` — специфичны для конкретного проекта, не для шаблона
- `restore` и `setup` (скачивание Bitrix-скриптов) — **оставить**, они шаблонные

> Makefile шаблона содержит инфраструктурные команды (build, up, down, restart, logs, shell, db-connect, clean, rebuild) и Bitrix-команды (restore, setup).

## Обработка ошибок в `create.sh`

- Если `.env` уже существует — прервать выполнение с сообщением об ошибке (защита от повторного запуска)
- Если свободный порт в диапазоне 81–500 не найден — запросить порт вручную без дефолта
- Если `make build` или `make up` завершился с ошибкой — скрипт не удаляет себя, выводит инструкцию

## Что не входит в scope

- Автоматическая установка/восстановление Bitrix (требует веб-мастера)
- Загрузка дампа БД
- Настройка SSL/HTTPS