#!/bin/bash

# =============================================================================
# Bastion Host Setup Script
# =============================================================================
# Este script configura o bastion host para acesso seguro ao cluster
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
echo -e "${BLUE}                Configuração do Bastion Host${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Carregar configurações
if [ -f .env ]; then
    source .env
else
    ROOT_DATA_DIR="./data/backup_ext4"
fi

# Criar diretório para SSH keys do bastion
BASTION_SSH_DIR="${ROOT_DATA_DIR}/bastion-ssh"
if [ ! -d "$BASTION_SSH_DIR" ]; then
    mkdir -p "$BASTION_SSH_DIR"
    log_info "Diretório SSH do bastion criado: $BASTION_SSH_DIR"
fi

# Gerar chave SSH para o bastion (opcional)
if [ ! -f "$BASTION_SSH_DIR/id_rsa" ]; then
    log_info "Gerando chave SSH para o bastion..."
    ssh-keygen -t rsa -b 4096 -f "$BASTION_SSH_DIR/id_rsa" -N "" -C "bastion@k8s-cluster"
    log_info "Chave SSH gerada em: $BASTION_SSH_DIR/id_rsa"
fi

# Configurar authorized_keys
if [ ! -f "$BASTION_SSH_DIR/authorized_keys" ]; then
    cp "$BASTION_SSH_DIR/id_rsa.pub" "$BASTION_SSH_DIR/authorized_keys"
    log_info "authorized_keys configurado"
fi

# Definir permissões
chmod 700 "$BASTION_SSH_DIR"
chmod 600 "$BASTION_SSH_DIR"/*
chmod 644 "$BASTION_SSH_DIR/id_rsa.pub"

log_info "Bastion host configurado com sucesso!"
echo ""
echo -e "${YELLOW}Para iniciar o bastion:${NC}"
echo -e "  docker compose up -d bastion"
echo ""
echo -e "${YELLOW}Para conectar:${NC}"
echo -e "  ssh bastion@localhost -p 2222"
echo -e "  Senha: P@ssw0rd123!"
echo ""
echo -e "${YELLOW}Dentro do bastion, use:${NC}"
echo -e "  kubectl get nodes    # Ver nodes"
echo -e "  kubectl get pods -A  # Ver pods"
echo -e "  kga                  # Alias para kubectl get all"
echo ""
echo -e "${GREEN}==============================================================================${NC}"