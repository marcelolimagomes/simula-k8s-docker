#!/bin/bash

# =============================================================================
# Kubernetes + Rancher Backup Script
# =============================================================================
# Este script faz backup de todos os dados importantes do ambiente
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
    ROOT_DATA_DIR="./data/backup_ext4"
fi

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Configurações de backup
BACKUP_BASE_DIR="$ROOT_DATA_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_BASE_DIR/k8s_rancher_backup_$TIMESTAMP"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}                    Backup do Ambiente K8s + Rancher${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Criar diretório de backup
log_info "Criando diretório de backup: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup da configuração do projeto
log_info "Fazendo backup das configurações do projeto..."
cp docker-compose.yml "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/" 2>/dev/null || log_warn "Arquivo .env não encontrado"
cp -r scripts "$BACKUP_DIR/"

# Backup do kubeconfig
if [ -f ~/.kube/config ]; then
    log_info "Fazendo backup do kubeconfig..."
    cp ~/.kube/config "$BACKUP_DIR/kubeconfig.yaml"
fi

# Backup dos dados Kubernetes
log_info "Fazendo backup dos dados Kubernetes..."
if [ -d "$ROOT_DATA_DIR/k8s-master" ]; then
    tar -czf "$BACKUP_DIR/k8s-master-data.tar.gz" -C "$ROOT_DATA_DIR" k8s-master/
fi

for worker in {1..4}; do
    if [ -d "$ROOT_DATA_DIR/k8s-worker-$worker" ]; then
        tar -czf "$BACKUP_DIR/k8s-worker-$worker-data.tar.gz" -C "$ROOT_DATA_DIR" "k8s-worker-$worker/"
    fi
done

# Backup dos dados Rancher
log_info "Fazendo backup dos dados Rancher..."
if [ -d "$ROOT_DATA_DIR/rancher-data" ]; then
    tar -czf "$BACKUP_DIR/rancher-data.tar.gz" -C "$ROOT_DATA_DIR" rancher-data/
fi

# Backup dos recursos Kubernetes (se o cluster estiver rodando)
if docker compose ps | grep -q "k8s-master.*Up"; then
    log_info "Fazendo backup dos recursos Kubernetes..."
    
    mkdir -p "$BACKUP_DIR/k8s-resources"
    
    # Backup de namespaces
    kubectl get namespaces -o yaml > "$BACKUP_DIR/k8s-resources/namespaces.yaml" 2>/dev/null || true
    
    # Backup de todos os recursos em todos os namespaces
    kubectl get all --all-namespaces -o yaml > "$BACKUP_DIR/k8s-resources/all-resources.yaml" 2>/dev/null || true
    
    # Backup de configmaps e secrets
    kubectl get configmaps --all-namespaces -o yaml > "$BACKUP_DIR/k8s-resources/configmaps.yaml" 2>/dev/null || true
    kubectl get secrets --all-namespaces -o yaml > "$BACKUP_DIR/k8s-resources/secrets.yaml" 2>/dev/null || true
    
    # Backup de PVs e PVCs
    kubectl get pv -o yaml > "$BACKUP_DIR/k8s-resources/persistent-volumes.yaml" 2>/dev/null || true
    kubectl get pvc --all-namespaces -o yaml > "$BACKUP_DIR/k8s-resources/persistent-volume-claims.yaml" 2>/dev/null || true
fi

# Criar arquivo de metadados do backup
log_info "Criando arquivo de metadados..."
cat > "$BACKUP_DIR/backup-metadata.txt" << EOF
# Backup Metadata
Backup criado em: $(date)
Versão do Docker: $(docker --version)
Versão do Docker Compose: $(docker compose version)
Versão do kubectl: $(kubectl version --client --short 2>/dev/null || echo "kubectl não disponível")
Sistema operacional: $(uname -a)
Usuário: $(whoami)
Diretório de dados: $ROOT_DATA_DIR

# Conteúdo do backup:
$(find "$BACKUP_DIR" -type f | sort)
EOF

# Calcular tamanho do backup
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)

# Criar backup comprimido (opcional)
read -p "Deseja criar um arquivo comprimido do backup? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Criando backup comprimido..."
    cd "$BACKUP_BASE_DIR"
    tar -czf "k8s_rancher_backup_$TIMESTAMP.tar.gz" "k8s_rancher_backup_$TIMESTAMP/"
    COMPRESSED_SIZE=$(du -sh "k8s_rancher_backup_$TIMESTAMP.tar.gz" | cut -f1)
    log_info "Backup comprimido criado: k8s_rancher_backup_$TIMESTAMP.tar.gz ($COMPRESSED_SIZE)"
fi

# Limpeza de backups antigos
log_info "Verificando backups antigos..."
BACKUP_COUNT=$(find "$BACKUP_BASE_DIR" -name "k8s_rancher_backup_*" -type d | wc -l)

if [ "$BACKUP_COUNT" -gt 5 ]; then
    log_warn "Encontrados $BACKUP_COUNT backups. Removendo os mais antigos..."
    find "$BACKUP_BASE_DIR" -name "k8s_rancher_backup_*" -type d | sort | head -n $((BACKUP_COUNT - 5)) | xargs rm -rf
    
    # Também remover arquivos comprimidos antigos
    find "$BACKUP_BASE_DIR" -name "k8s_rancher_backup_*.tar.gz" | sort | head -n $((BACKUP_COUNT - 5)) | xargs rm -f 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                           Backup Concluído!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Informações do Backup:${NC}"
echo -e "• Localização: ${BLUE}$BACKUP_DIR${NC}"
echo -e "• Tamanho: ${BLUE}$BACKUP_SIZE${NC}"
echo -e "• Data/Hora: ${BLUE}$(date)${NC}"
echo ""
echo -e "${YELLOW}Para restaurar o backup, execute:${NC} ${BLUE}./scripts/restore.sh $TIMESTAMP${NC}"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
