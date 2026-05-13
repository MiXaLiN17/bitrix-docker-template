# Bitrix Docker Template Automation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Превратить текущую Docker-инфраструктуру в git-шаблон, разворачиваемый одной командой `./create.sh`.

**Architecture:** `create.sh` запускается из склонированной папки проекта, автоопределяет имя проекта и свободный HTTP-порт, генерирует `.env` подстановкой в `.env.example`, создаёт директории логов, собирает и запускает контейнеры, затем самоудаляется.

**Tech Stack:** Bash, Docker Compose, Makefile, sed, ss (iproute2)

---

## File Map

| Действие | Файл | Что меняется |
|---|---|---|
| Modify | `Makefile` | Удалить `.PHONY` записи, переменную `CONSOLE_DIE` и цели `migrate`, `swagger` |
| Modify | `docker-compose.yml` | Закомментировать секцию `ports` у сервиса `db` |
| Delete | `init.sh` | Удалить файл — логика переезжает в `create.sh` |
| Create | `create.sh` | Скрипт инициализации нового проекта |

---

### Task 1: Убрать project-specific цели из Makefile

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Убрать `migrate` и `swagger` из строки `.PHONY`**

Открой `Makefile`. Строка 1 сейчас:
```makefile
.PHONY: help build up down restart logs ps composer-install composer-update composer-require composer-remove shell shell-db clean db-reset db-connect
```
Она уже не содержит `migrate` и `swagger` в `.PHONY` — пропусти этот шаг если так.
Если содержит — удали эти слова из строки.

- [ ] **Step 2: Удалить переменную `CONSOLE_DIE`**

Найди и удали строку:
```makefile
CONSOLE_DIE = ./local/console
```

- [ ] **Step 3: Удалить цель `migrate`**

Найди и удали блок:
```makefile
migrate: ## Установить миграции
	@echo "${GREEN}Установка миграций в проект...${NC}"
	@docker exec -it --user ${UID}:${GID} ${PHP_CONTAINER} bash -c "cd $(CONSOLE_DIE) && php -f migrate.php migrate || { echo '❌ Migrations failed'; exit 1; }"
```

- [ ] **Step 4: Удалить цель `swagger`**

Найди и удали блок:
```makefile
swagger: ## Установить миграции
	@echo "${GREEN}Генарация swagger документации...${NC}"
	@docker exec -it --user ${UID}:${GID} ${PHP_CONTAINER} bash -c "cd $(CONSOLE_DIE) && php -f swagger.php || { echo '❌ Generate swagger fail'; exit 1; }"
```

- [ ] **Step 5: Проверить что Makefile корректен**

```bash
make help
```

Ожидаемый результат: список команд без `migrate` и `swagger`, без ошибок синтаксиса.

- [ ] **Step 6: Commit**

```bash
git add Makefile
git commit -m "chore: remove project-specific targets from template Makefile"
```

---

### Task 2: Закомментировать порты MySQL в docker-compose.yml

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Закомментировать секцию `ports` у сервиса `db`**

Найди в `docker-compose.yml` блок сервиса `db`. Текущий вид:
```yaml
  db:
    build:
      context: ./.docker/mysql
    container_name: '${COMPOSE_PROJECT_NAME}_db'
    #    restart: always
    command: mysqld --sql-mode=""
    ports:
      - ${HOST_MACHINE_MYSQL_PORT:-3306}:3306
```

Замени на:
```yaml
  db:
    build:
      context: ./.docker/mysql
    container_name: '${COMPOSE_PROJECT_NAME}_db'
    #    restart: always
    command: mysqld --sql-mode=""
    # ports:
    #   - ${HOST_MACHINE_MYSQL_PORT:-3306}:3306
```

- [ ] **Step 2: Проверить валидность docker-compose.yml**

```bash
docker compose config --quiet
```

Ожидаемый результат: команда завершается без ошибок (пустой вывод).

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "chore: comment out MySQL port mapping by default"
```

---

### Task 3: Удалить init.sh

**Files:**
- Delete: `init.sh`

- [ ] **Step 1: Убедиться что init.sh не вызывается в Makefile**

```bash
grep -n "init.sh" Makefile
```

Ожидаемый результат: пустой вывод (нет упоминаний).

- [ ] **Step 2: Удалить файл**

```bash
git rm init.sh
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: remove init.sh, logic moves to create.sh"
```

---

### Task 4: Создать create.sh

**Files:**
- Create: `create.sh`

- [ ] **Step 1: Создать файл create.sh**

```bash
cat > create.sh << 'EOF'
#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Guard: prevent re-running on an already configured project
if [ -f ".env" ]; then
    echo -e "${RED}Error: .env already exists. Remove it before running create.sh again.${NC}"
    exit 1
fi

# Detect default project name: directory name up to first dot
DEFAULT_PROJECT_NAME=$(basename "$PWD" | cut -d'.' -f1)

# Find first free port in range 81-500
find_free_port() {
    for port in $(seq 81 500); do
        if ! ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            echo "$port"
            return
        fi
    done
    echo ""
}

DEFAULT_PORT=$(find_free_port)

# Prompt: project name
read -rp "Project name [${DEFAULT_PROJECT_NAME}]: " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_PROJECT_NAME}"

# Prompt: HTTP port
if [ -n "$DEFAULT_PORT" ]; then
    read -rp "HTTP port [${DEFAULT_PORT}]: " HTTP_PORT
    HTTP_PORT="${HTTP_PORT:-$DEFAULT_PORT}"
else
    echo -e "${YELLOW}No free port found in range 81-500. Enter port manually:${NC}"
    read -rp "HTTP port: " HTTP_PORT
    while [ -z "$HTTP_PORT" ]; do
        read -rp "HTTP port: " HTTP_PORT
    done
fi

# Generate .env from .env.example
cp .env.example .env

# Helper: replace variable in .env, append if not present
set_env_var() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" .env; then
        sed -i "s|^${key}=.*|${key}=${value}|" .env
    else
        echo "${key}=${value}" >> .env
    fi
}

set_env_var "COMPOSE_PROJECT_NAME" "$PROJECT_NAME"
set_env_var "UID" "$(id -u)"
set_env_var "GID" "$(id -g)"
set_env_var "HOST_MACHINE_UNSECURE_HOST_PORT" "$HTTP_PORT"

# Create log directories and src placeholder
mkdir -p ./logs/nginx ./logs/app ./logs/mysql ./logs/frontend ./src

echo -e "${GREEN}Environment configured:${NC}"
echo -e "  Project : ${PROJECT_NAME}"
echo -e "  URL     : http://localhost:${HTTP_PORT}"

# Build Docker images
echo -e "${GREEN}Building Docker images...${NC}"
if ! make build; then
    echo -e "${RED}Build failed. Fix the error and run 'make build && make up' manually.${NC}"
    exit 1
fi

# Start containers
echo -e "${GREEN}Starting containers...${NC}"
if ! make up; then
    echo -e "${RED}Failed to start containers. Fix the error and run 'make up' manually.${NC}"
    exit 1
fi

echo -e "${GREEN}Done! Project '${PROJECT_NAME}' is running at http://localhost:${HTTP_PORT}${NC}"

# Self-delete: script is no longer needed after successful init
rm -- "$0"
EOF
```

- [ ] **Step 2: Сделать файл исполняемым**

```bash
chmod +x create.sh
```

- [ ] **Step 3: Проверить синтаксис скрипта**

```bash
bash -n create.sh
```

Ожидаемый результат: пустой вывод (нет синтаксических ошибок).

- [ ] **Step 4: Проверить автоопределение имени проекта**

Выполни в директории проекта:
```bash
basename "$PWD" | cut -d'.' -f1
```

Ожидаемый результат: имя директории до точки (например `ford-transit` если папка `ford-transit.loc`).

- [ ] **Step 5: Проверить поиск свободного порта**

```bash
for port in $(seq 81 500); do
    if ! ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        echo "First free port: $port"; break
    fi
done
```

Ожидаемый результат: строка вида `First free port: 83` (конкретный номер зависит от системы).

- [ ] **Step 6: Добавить create.sh в .gitignore исключений**

Проверь `.dockerignore` — убедись что `create.sh` не попадёт в Docker build context случайно (build contexts — поддиректории `.docker/`, поэтому `.dockerignore` в корне не влияет; шаг формальный):

```bash
grep "create.sh" .dockerignore || echo "Not in .dockerignore — OK, build contexts are subdirs"
```

- [ ] **Step 7: Commit**

```bash
git add create.sh
git commit -m "feat: add create.sh for one-command project initialization"
```

---

### Task 5: Интеграционная проверка

> Выполняется на тестовой копии, не в основном шаблоне.

**Files:** нет изменений

- [ ] **Step 1: Клонировать шаблон в тестовую директорию**

```bash
git clone . /tmp/test-project.loc
cd /tmp/test-project.loc
```

- [ ] **Step 2: Запустить create.sh**

```bash
./create.sh
```

На запросы ввода: нажать Enter (принять дефолты по обоим параметрам).

Ожидаемый результат:
```
Project name [test-project]:
HTTP port [<N>]:
Environment configured:
  Project : test-project
  URL     : http://localhost:<N>
Building Docker images...
...
Starting containers...
...
Done! Project 'test-project' is running at http://localhost:<N>
```

- [ ] **Step 3: Проверить что .env сгенерирован корректно**

```bash
grep -E "^(COMPOSE_PROJECT_NAME|UID|GID|HOST_MACHINE_UNSECURE_HOST_PORT)=" .env
```

Ожидаемый результат:
```
COMPOSE_PROJECT_NAME=test-project
UID=<текущий uid>
GID=<текущий gid>
HOST_MACHINE_UNSECURE_HOST_PORT=<выбранный порт>
```

- [ ] **Step 4: Проверить что контейнеры запущены**

```bash
docker compose ps
```

Ожидаемый результат: три контейнера (`webserver`, `app`, `db`) в состоянии `running`.

- [ ] **Step 5: Проверить что create.sh самоудалился**

```bash
ls create.sh 2>&1
```

Ожидаемый результат: `ls: cannot access 'create.sh': No such file or directory`

- [ ] **Step 6: Проверить защиту от повторного запуска**

```bash
# Восстановить create.sh из git для теста
git show HEAD:create.sh > create.sh && chmod +x create.sh
./create.sh
```

Ожидаемый результат:
```
Error: .env already exists. Remove it before running create.sh again.
```
(скрипт завершается с ненулевым кодом, .env не перезаписан)

- [ ] **Step 7: Остановить и удалить тестовые контейнеры**

```bash
make down
docker compose down -v
cd /home/mixalin17/Projects/w2you/ford-transit.loc
rm -rf /tmp/test-project.loc
```