#!/bin/bash

# =============================================================================
# Kubernetes + Rancher Stop Script
# =============================================================================
# Este script para o ambiente sem destruir os dados
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                        Parando Ambiente K8s + Rancher${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Verificar se há containers rodando
running_containers=$(docker compose ps -q 2>/dev/null | wc -l)

if [ "$running_containers" -eq 0 ]; then
    log_info "Nenhum container está rodando."
    exit 0
fi

log_info "Parando todos os containers..."
docker compose stop

log_info "Containers parados com sucesso!"
echo ""
echo -e "${YELLOW}Para reiniciar o ambiente, execute:${NC} ${BLUE}./scripts/deploy.sh${NC}"
echo -e "${YELLOW}Para destruir completamente o ambiente, execute:${NC} ${BLUE}./scripts/destroy.sh${NC}"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
