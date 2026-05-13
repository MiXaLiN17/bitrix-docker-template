# clearbitrix.loc

Docker-шаблон для локальной разработки PHP-проектов на базе 1С-Битрикс.

**Стек:** Nginx 1.29 · PHP-FPM 8.1–8.4 · MySQL 8.4

---

## Требования

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose v2
- `make`
- `wget` (нужен для команд `make setup` / `make restore`)

---

## Быстрый старт

```bash
git clone <repo-url> clearbitrix.loc
cd clearbitrix.loc
./create.sh
```

Скрипт интерактивно запросит:

| Параметр | По умолчанию |
|---|---|
| Имя проекта | имя директории до первой точки |
| HTTP-порт | первый свободный в диапазоне 81–500 |
| Версия PHP | 8.4 |

После ответов `create.sh` автоматически создаст `.env`, соберёт Docker-образы и запустит контейнеры. Затем удалит себя — повторный запуск не требуется.

Проект будет доступен по адресу `http://localhost:<порт>`.

---

## Управление проектом

```bash
make help   # показать все доступные команды
```

### Запуск и остановка

| Команда | Описание |
|---|---|
| `make build` | Собрать Docker-образы |
| `make up` | Запустить контейнеры |
| `make down` | Остановить контейнеры |
| `make restart` | Перезапустить контейнеры |
| `make rebuild` | Пересобрать и перезапустить |
| `make clean` | Удалить контейнеры, сети и volumes |

### Логи

| Команда | Описание |
|---|---|
| `make logs` | Логи всех контейнеров |
| `make logs-web` | Логи Nginx |
| `make logs-app` | Логи PHP-FPM |
| `make logs-db` | Логи MySQL |
| `make ps` | Статус контейнеров |

### Shell

| Команда | Описание |
|---|---|
| `make shell` | Shell в контейнер Nginx |
| `make shell-app` | Shell в контейнер PHP |
| `make shell-db` | Shell в контейнер MySQL |

### Composer

```bash
make composer-install
make composer-update
make composer-require PACKAGE=vendor/package
make composer-remove  PACKAGE=vendor/package
```

### База данных

| Команда | Описание |
|---|---|
| `make mysql` | Подключиться к MySQL (root) |
| `make db-connect` | Подключиться к MySQL (пользователь из .env) |
| `make db-reset` | Пересоздать volume БД (все данные будут удалены!) |

---

## Переменные окружения

Файл `.env` создаётся из `.env.example` скриптом `create.sh`. Основные переменные:

| Переменная | Описание |
|---|---|
| `COMPOSE_PROJECT_NAME` | Префикс имён контейнеров |
| `PHP_VERSION` | Версия PHP (8.1 / 8.2 / 8.3 / 8.4) |
| `HOST_MACHINE_UNSECURE_HOST_PORT` | Внешний HTTP-порт |
| `MYSQL_DATABASE` | Имя базы данных |
| `MYSQL_USER` | Пользователь MySQL |
| `MYSQL_PASSWORD` | Пароль пользователя MySQL |
| `MYSQL_ROOT_PASSWORD` | Пароль root MySQL |
| `APP_LOG_DIR` | Путь к логам PHP на хосте |
| `WEB_SERVER_LOG_DIR` | Путь к логам Nginx на хосте |
| `MYSQL_LOG_DIR` | Путь к логам MySQL на хосте |

---

## Установка и восстановление Битрикс

### Новая установка

```bash
make setup
```

Скачивает `bitrixsetup.php` в `./src/`. Открыть в браузере: `http://localhost:<порт>/bitrixsetup.php`.

### Восстановление из резервной копии

```bash
make restore
```

Скачивает `restore.php` в `./src/`. Открыть в браузере: `http://localhost:<порт>/restore.php`.
