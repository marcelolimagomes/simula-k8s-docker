#!/bin/bash

# =============================================================================
# Kubernetes + Rancher Restore Script
# =============================================================================
# Este script restaura um backup do ambiente
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Carregar configurações
if [ -f .env ]; then
    source .env
else
    DATA_DIR="/media/marcelo/dados"
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar parâmetros
if [ $# -eq 0 ]; then
    echo -e "${BLUE}==============================================================================${NC}"
    echo -e "${BLUE}                  Restaurar Backup do Ambiente K8s + Rancher${NC}"
    echo -e "${BLUE}==============================================================================${NC}"
    echo ""
    log_error "Uso: $0 <timestamp_do_backup>"
    echo ""
    echo "Backups disponíveis:"
    if [ -d "$DATA_DIR/backups" ]; then
        find "$DATA_DIR/backups" -name "k8s_rancher_backup_*" -type d | sort -r | head -10
    else
        echo "Nenhum backup encontrado"
    fi
    exit 1
fi

BACKUP_TIMESTAMP="$1"
BACKUP_DIR="$DATA_DIR/backups/k8s_rancher_backup_$BACKUP_TIMESTAMP"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                  Restaurar Backup do Ambiente K8s + Rancher${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Verificar se o backup existe
if [ ! -d "$BACKUP_DIR" ]; then
    log_error "Backup não encontrado: $BACKUP_DIR"
    
    # Verificar se existe arquivo comprimido
    COMPRESSED_BACKUP="$DATA_DIR/backups/k8s_rancher_backup_$BACKUP_TIMESTAMP.tar.gz"
    if [ -f "$COMPRESSED_BACKUP" ]; then
        log_info "Encontrado backup comprimido. Extraindo..."
        cd "$DATA_DIR/backups"
        tar -xzf "k8s_rancher_backup_$BACKUP_TIMESTAMP.tar.gz"
        
        if [ ! -d "$BACKUP_DIR" ]; then
            log_error "Falha ao extrair backup comprimido"
            exit 1
        fi
    else
        exit 1
    fi
fi

echo ""
log_warn "⚠️  Esta operação irá:"
echo -e "   • Parar o ambiente atual"
echo -e "   • Substituir todos os dados pelos dados do backup"
echo -e "   • Reiniciar o ambiente"
echo ""
log_warn "⚠️  TODOS OS DADOS ATUAIS SERÃO SUBSTITUÍDOS!"
echo ""

read -p "Deseja continuar? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Restauração cancelada."
    exit 0
fi

# Parar ambiente atual
log_info "Parando ambiente atual..."
docker compose down 2>/dev/null || true

# Fazer backup dos dados atuais (por segurança)
log_info "Fazendo backup dos dados atuais por segurança..."
SAFETY_BACKUP_DIR="$DATA_DIR/backups/safety_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$SAFETY_BACKUP_DIR"

for dir in rancher-data k8s-master k8s-worker-{1..4} k8s-config; do
    if [ -d "$DATA_DIR/$dir" ]; then
        mv "$DATA_DIR/$dir" "$SAFETY_BACKUP_DIR/"
        log_info "Movido $dir para backup de segurança"
    fi
done

# Restaurar configurações do projeto
log_info "Restaurando configurações do projeto..."
if [ -f "$BACKUP_DIR/docker-compose.yml" ]; then
    cp "$BACKUP_DIR/docker-compose.yml" .
fi

if [ -f "$BACKUP_DIR/.env" ]; then
    cp "$BACKUP_DIR/.env" .
    source .env
fi

if [ -d "$BACKUP_DIR/scripts" ]; then
    cp -r "$BACKUP_DIR/scripts/" .
    chmod +x scripts/*.sh
fi

# Restaurar kubeconfig
if [ -f "$BACKUP_DIR/kubeconfig.yaml" ]; then
    log_info "Restaurando kubeconfig..."
    mkdir -p ~/.kube
    cp "$BACKUP_DIR/kubeconfig.yaml" ~/.kube/config
    chmod 600 ~/.kube/config
fi

# Restaurar dados Kubernetes
log_info "Restaurando dados Kubernetes..."

if [ -f "$BACKUP_DIR/k8s-master-data.tar.gz" ]; then
    tar -xzf "$BACKUP_DIR/k8s-master-data.tar.gz" -C "$DATA_DIR/"
    log_info "Dados do master restaurados"
fi

for worker in {1..4}; do
    if [ -f "$BACKUP_DIR/k8s-worker-$worker-data.tar.gz" ]; then
        tar -xzf "$BACKUP_DIR/k8s-worker-$worker-data.tar.gz" -C "$DATA_DIR/"
        log_info "Dados do worker-$worker restaurados"
    fi
done

# Restaurar dados Rancher
if [ -f "$BACKUP_DIR/rancher-data.tar.gz" ]; then
    log_info "Restaurando dados Rancher..."
    tar -xzf "$BACKUP_DIR/rancher-data.tar.gz" -C "$DATA_DIR/"
    log_info "Dados do Rancher restaurados"
fi

# Configurar permissões
log_info "Configurando permissões..."
sudo chown -R $USER:$USER "$DATA_DIR"
chmod -R 755 "$DATA_DIR"

# Reiniciar ambiente
log_info "Reiniciando ambiente..."
docker compose up -d

# Aguardar serviços ficarem disponíveis
log_info "Aguardando serviços ficarem disponíveis (isso pode levar alguns minutos)..."
sleep 60

# Restaurar recursos Kubernetes (se disponível no backup)
if [ -d "$BACKUP_DIR/k8s-resources" ]; then
    log_info "Aguardando cluster Kubernetes ficar disponível para restaurar recursos..."
    
    max_attempts=60
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if kubectl get nodes >/dev/null 2>&1; then
            log_info "Cluster disponível! Restaurando recursos..."
            
            # Restaurar recursos (com cuidado para evitar conflitos)
            if [ -f "$BACKUP_DIR/k8s-resources/namespaces.yaml" ]; then
                kubectl apply -f "$BACKUP_DIR/k8s-resources/namespaces.yaml" 2>/dev/null || log_warn "Alguns namespaces podem já existir"
            fi
            
            # Aguardar namespaces serem criados
            sleep 10
            
            if [ -f "$BACKUP_DIR/k8s-resources/configmaps.yaml" ]; then
                kubectl apply -f "$BACKUP_DIR/k8s-resources/configmaps.yaml" 2>/dev/null || log_warn "Alguns configmaps podem já existir"
            fi
            
            if [ -f "$BACKUP_DIR/k8s-resources/secrets.yaml" ]; then
                kubectl apply -f "$BACKUP_DIR/k8s-resources/secrets.yaml" 2>/dev/null || log_warn "Alguns secrets podem já existir"
            fi
            
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_warn "Cluster não ficou disponível para restaurar recursos Kubernetes"
    fi
fi

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                      Restauração Concluída!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Informações:${NC}"
echo -e "• Backup restaurado: ${BLUE}$BACKUP_TIMESTAMP${NC}"
echo -e "• Backup de segurança criado em: ${BLUE}$SAFETY_BACKUP_DIR${NC}"
echo -e "• Rancher UI: ${BLUE}https://localhost${NC}"
echo -e "• Kubernetes API: ${BLUE}https://localhost:6443${NC}"
echo ""
echo -e "${YELLOW}Verificar status:${NC} ${BLUE}./scripts/status.sh${NC}"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
