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

# Prompt: optional Sphinx full-text search container
read -rp "Install Sphinx full-text search? [y/N]: " SPHINX_CHOICE
case "$SPHINX_CHOICE" in
    [yY]|[yY][eE][sS]) COMPOSE_PROFILES="sphinx" ;;
    *) COMPOSE_PROFILES="" ;;
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
set_env_var "COMPOSE_PROFILES" "$COMPOSE_PROFILES"

# Create log directories and src placeholder
mkdir -p ./logs/webserver ./logs/app ./logs/mysql ./logs/sphinx ./logs/frontend ./src

echo -e "${GREEN}Environment configured:${NC}"
echo -e "  Project : ${PROJECT_NAME}"
echo -e "  PHP     : ${PHP_VERSION}"
echo -e "  Sphinx  : $([ -n "$COMPOSE_PROFILES" ] && echo "yes" || echo "no (enable later: make sphinx-enable)")"
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

# Remove template git history
rm -rf .git
rm -rf .gitignore

# Self-delete: script is no longer needed after successful init
rm -- "$0"
