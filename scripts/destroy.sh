#!/bin/bash

# =============================================================================
# Kubernetes + Rancher Destroy Script
# =============================================================================
# Este script remove completamente o ambiente e TODOS OS DADOS
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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                      Destruindo Ambiente K8s + Rancher${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Carregar configurações
if [ -f .env ]; then
    source .env
else
    log_warn "Arquivo .env não encontrado! Usando configurações padrão..."
    DATA_DIR="/media/marcelo/backup_ext4"
fi

echo ""
log_error "⚠️  ATENÇÃO: Esta operação irá:"
echo -e "   • Parar e remover todos os containers"
echo -e "   • Remover todas as imagens relacionadas"
echo -e "   • Remover todos os volumes de dados"
echo -e "   • Limpar completamente o ambiente"
echo ""
log_error "⚠️  TODOS OS DADOS SERÃO PERDIDOS PERMANENTEMENTE!"
echo ""

read -p "Tem certeza que deseja continuar? Digite 'DESTROY' para confirmar: " -r
if [ "$REPLY" != "DESTROY" ]; then
    log_info "Operação cancelada."
    exit 0
fi

echo ""
log_info "Iniciando destruição do ambiente..."

# Parar e remover containers
log_info "Parando e removendo containers..."
docker compose down --remove-orphans --volumes 2>/dev/null || true

# Remover containers órfãos relacionados
log_info "Removendo containers órfãos..."
docker container prune -f

# Remover imagens relacionadas
log_info "Removendo imagens Docker..."
docker rmi rancher/rancher:latest rancher/k3s:latest 2>/dev/null || true

# Remover volumes Docker
log_info "Removendo volumes Docker..."
docker volume prune -f

# Remover dados persistentes
log_info "Removendo dados persistentes..."
directories=(
    "$DATA_DIR/rancher-data"
    "$DATA_DIR/rancher-audit"
    "$DATA_DIR/k8s-master"
    "$DATA_DIR/k8s-worker-1"
    "$DATA_DIR/k8s-worker-2"
    "$DATA_DIR/k8s-worker-3"
    "$DATA_DIR/k8s-worker-4"
    "$DATA_DIR/k8s-config"
)

for dir in "${directories[@]}"; do
    if [ -d "$dir" ]; then
        sudo rm -rf "$dir"
        log_info "Removido: $dir"
    fi
done

# Remover configuração kubectl local
log_info "Removendo configuração kubectl local..."
if [ -f ~/.kube/config ]; then
    rm ~/.kube/config
    log_info "kubeconfig local removido"
fi

# Remover arquivo de ambiente
if [ -f .env ]; then
    rm .env
    log_info "Arquivo .env removido"
fi

# Limpeza final
log_info "Executando limpeza final..."
docker system prune -f

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                    Ambiente Completamente Destruído!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Para recriar o ambiente, execute:${NC}"
echo -e "1. ${BLUE}./scripts/setup.sh${NC}"
echo -e "2. ${BLUE}./scripts/deploy.sh${NC}"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
