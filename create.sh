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

# Find first free port in range 80-500
find_free_port() {
    for port in $(seq 80 500); do
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
    echo -e "${YELLOW}No free port found in range 80-500. Enter port manually:${NC}"
    read -rp "HTTP port: " HTTP_PORT
    while [ -z "$HTTP_PORT" ]; do
        read -rp "HTTP port: " HTTP_PORT
    done
fi

# Prompt: PHP version
PHP_VERSIONS=("8.4" "8.3" "8.2" "8.1")
DEFAULT_PHP_VERSION="8.4"
echo "PHP version:"
for i in "${!PHP_VERSIONS[@]}"; do
    if [ "${PHP_VERSIONS[$i]}" = "$DEFAULT_PHP_VERSION" ]; then
        echo "  $((i+1))) ${PHP_VERSIONS[$i]} (default)"
    else
        echo "  $((i+1))) ${PHP_VERSIONS[$i]}"
    fi
done
read -rp "Select [1]: " PHP_CHOICE
case "$PHP_CHOICE" in
    2) PHP_VERSION="8.3" ;;
    3) PHP_VERSION="8.2" ;;
    4) PHP_VERSION="8.1" ;;
    *) PHP_VERSION="8.4" ;;
esac

# Prompt: database engine. Picks the build context of the db service — configs live in
# .docker/mysql and .docker/mariadb. MySQL is the default because Bitrix recommends it;
# MariaDB is here for dumps taken from MariaDB 11.4+, which carry *_uca1400_* collations
# MySQL does not know and refuses to import ("Unknown collation").
echo "Database engine:"
echo "  1) mysql (default, recommended by Bitrix)"
echo "  2) mariadb (for dumps from MariaDB 11.4+ with uca1400 collations)"
read -rp "Select [1]: " DB_ENGINE_CHOICE
case "$DB_ENGINE_CHOICE" in
    2) DB_ENGINE="mariadb" ;;
    *) DB_ENGINE="mysql" ;;
esac

# Prompt: database version. The list depends on the engine chosen above.
# MySQL: 8.4 and 8.0 are LTS releases; 8.1-8.3 are EOL Innovation releases kept for
# parity with legacy production servers. Bitrix requires 8.0 minimum and recommends 8.4+.
# MariaDB: both offered branches are LTS — 11.4 until 2029, 10.11 until 2028.
if [ "$DB_ENGINE" = "mariadb" ]; then
    echo "MariaDB version:"
    echo "  1) 11.4 (default, LTS, supported until 2029)"
    echo "  2) 10.11 (LTS, supported until 2028)"
    read -rp "Select [1]: " DB_VERSION_CHOICE
    case "$DB_VERSION_CHOICE" in
        2) DB_VERSION="10.11" ;;
        *) DB_VERSION="11.4" ;;
    esac
else
    echo "MySQL version:"
    echo "  1) 8.4 (default, LTS, recommended by Bitrix)"
    echo "  2) 8.3 (Innovation, EOL)"
    echo "  3) 8.2 (Innovation, EOL)"
    echo "  4) 8.1 (Innovation, EOL)"
    echo "  5) 8.0 (LTS, minimum supported by Bitrix)"
    read -rp "Select [1]: " DB_VERSION_CHOICE
    case "$DB_VERSION_CHOICE" in
        2) DB_VERSION="8.3" ;;
        3) DB_VERSION="8.2" ;;
        4) DB_VERSION="8.1" ;;
        5) DB_VERSION="8.0" ;;
        *) DB_VERSION="8.4" ;;
    esac
fi

# Optional services: every "yes" adds its Docker Compose profile to COMPOSE_PROFILES
COMPOSE_PROFILES=""
add_profile() {
    if [ -z "$COMPOSE_PROFILES" ]; then
        COMPOSE_PROFILES="$1"
    else
        COMPOSE_PROFILES="${COMPOSE_PROFILES},$1"
    fi
}

# Prompt: optional Sphinx full-text search container
read -rp "Install Sphinx full-text search? [y/N]: " SPHINX_CHOICE
case "$SPHINX_CHOICE" in
    [yY]|[yY][eE][sS]) add_profile "sphinx"; SPHINX_ENABLED="yes" ;;
    *) SPHINX_ENABLED="" ;;
esac

# Prompt: optional memcached container. Needed when bitrix/.settings.php carries
# 'type' => 'memcache' / 'memcached' — typical for a config copied from production.
read -rp "Install memcached cache server? [y/N]: " MEMCACHED_CHOICE
case "$MEMCACHED_CHOICE" in
    [yY]|[yY][eE][sS]) add_profile "memcached"; MEMCACHED_ENABLED="yes" ;;
    *) MEMCACHED_ENABLED="" ;;
esac

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
set_env_var "PHP_VERSION" "$PHP_VERSION"
set_env_var "DB_ENGINE" "$DB_ENGINE"
set_env_var "DB_VERSION" "$DB_VERSION"
set_env_var "COMPOSE_PROFILES" "$COMPOSE_PROFILES"

# Create log directories and src placeholder
mkdir -p ./logs/webserver ./logs/app ./logs/mysql ./logs/sphinx ./src

# src/.gitkeep нужен только репозиторию шаблона, чтобы пустой каталог попал в git.
# У проекта src — корень сайта, и посторонний файл там ни к чему. Удаляем здесь,
# а не в блоке очистки в конце: тот выполняется только при успешной сборке.
rm -f ./src/.gitkeep

echo -e "${GREEN}Environment configured:${NC}"
echo -e "  Project   : ${PROJECT_NAME}"
echo -e "  PHP       : ${PHP_VERSION}"
echo -e "  Database  : ${DB_ENGINE} ${DB_VERSION}"
echo -e "  Sphinx    : $([ -n "$SPHINX_ENABLED" ] && echo "yes" || echo "no (enable later: make sphinx-enable)")"
echo -e "  memcached : $([ -n "$MEMCACHED_ENABLED" ] && echo "yes" || echo "no (enable later: make memcached-enable)")"
echo -e "  URL       : http://localhost:${HTTP_PORT}"

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

# Remove template git history
rm -rf .git
rm -rf .gitignore

# Self-delete: script is no longer needed after successful init
rm -- "$0"
