#!/bin/bash

# =============================================================================
# Kubernetes + Rancher Infrastructure Setup Script
# =============================================================================
# Este script prepara o ambiente local para executar um cluster Kubernetes
# com 4 workers gerenciado pelo Rancher
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
DATA_DIR="/media/marcelo/backup_ext4"
PROJECT_DIR="/home/marcelo/des/simula-k8s-docker"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}        Kubernetes + Rancher Local Development Environment Setup${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Função para logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se o usuário é root
if [ "$EUID" -eq 0 ]; then
    log_error "Este script não deve ser executado como root!"
    exit 1
fi

# Verificar dependências
log_info "Verificando dependências..."

# Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker não está instalado!"
    echo "Instale o Docker: https://docs.docker.com/engine/install/"
    exit 1
fi

# Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose v2 não está instalado!"
    echo "Instale o Docker Compose v2: https://docs.docker.com/compose/install/"
    exit 1
fi

# Kubectl
if ! command -v kubectl &> /dev/null; then
    log_warn "kubectl não está instalado. Instalando..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

log_info "Todas as dependências estão instaladas!"

# Criar estrutura de diretórios
log_info "Criando estrutura de diretórios de dados..."

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
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_info "Diretório criado: $dir"
    else
        log_info "Diretório já existe: $dir"
    fi
done

# Definir permissões
log_info "Configurando permissões dos diretórios..."
sudo chown -R $USER:$USER $DATA_DIR
chmod -R 755 $DATA_DIR

# Verificar espaço em disco
log_info "Verificando espaço disponível em disco..."
available_space=$(df -BG "$DATA_DIR" | awk 'NR==2 {print $4}' | sed 's/G//')
required_space=250 # 250GB requeridos (50GB x 4 workers + overhead)

if [ "$available_space" -lt "$required_space" ]; then
    log_warn "Espaço em disco pode ser insuficiente!"
    log_warn "Disponível: ${available_space}GB, Recomendado: ${required_space}GB"
    read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Verificar memória RAM
log_info "Verificando memória RAM disponível..."
total_ram=$(free -g | awk 'NR==2{print $2}')
required_ram=10 # 2GB x 4 workers + 2GB para master e rancher

if [ "$total_ram" -lt "$required_ram" ]; then
    log_warn "Memória RAM pode ser insuficiente!"
    log_warn "Total: ${total_ram}GB, Recomendado: ${required_ram}GB"
    read -p "Deseja continuar mesmo assim? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Configurar limites do sistema
log_info "Configurando limites do sistema para Kubernetes..."

# Aumentar limites de arquivos abertos
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Configurar parâmetros do kernel
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.conf

# Aplicar configurações
sudo sysctl -p

# Baixar imagens Docker necessárias
log_info "Pré-baixando imagens Docker (isso pode levar alguns minutos)..."
docker pull rancher/rancher:latest
docker pull rancher/k3s:latest

# Criar arquivo de ambiente
log_info "Criando arquivo de configuração de ambiente..."
cat > "$PROJECT_DIR/.env" << EOF
# Configurações do ambiente Kubernetes + Rancher
DATA_DIR=$DATA_DIR
PROJECT_DIR=$PROJECT_DIR
RANCHER_PASSWORD=admin123456
K3S_TOKEN=k8s-cluster-secret

# Configurações de rede
CLUSTER_CIDR=10.42.0.0/16
SERVICE_CIDR=10.43.0.0/16

# URLs de acesso
RANCHER_URL=https://localhost
KUBERNETES_API=https://localhost:6443
EOF

log_info "Setup inicial concluído com sucesso!"
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}Próximos passos:${NC}"
echo -e "1. Execute: ${YELLOW}./scripts/deploy.sh${NC} para iniciar o ambiente"
echo -e "2. Acesse o Rancher em: ${YELLOW}https://localhost${NC}"
echo -e "3. Use a senha: ${YELLOW}admin123456${NC}"
echo -e "${GREEN}==============================================================================${NC}"
