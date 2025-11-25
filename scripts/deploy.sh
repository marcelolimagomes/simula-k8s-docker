#!/bin/bash

# =============================================================================
# Kubernetes + Rancher Deployment Script
# =============================================================================
# Este script faz o deploy do cluster Kubernetes com Rancher
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
    echo -e "${RED}[ERROR]${NC} Arquivo .env não encontrado! Execute primeiro: ./scripts/setup.sh"
    exit 1
fi

# Funções de logging
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
echo -e "${BLUE}                    Iniciando Deploy do Ambiente K8s + Rancher${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Verificar se o Docker está rodando
if ! docker info >/dev/null 2>&1; then
    log_error "Docker não está rodando!"
    exit 1
fi

# Parar containers existentes se estiverem rodando
log_info "Parando containers existentes (se houver)..."
docker compose down --remove-orphans 2>/dev/null || true

# Limpar containers órfãos
log_info "Limpando containers órfãos..."
docker container prune -f

# Iniciar apenas o Rancher primeiro
log_info "Iniciando Rancher Server..."
docker compose up -d rancher-server

# Aguardar Rancher ficar disponível
log_info "Aguardando Rancher Server ficar disponível..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -k -s https://localhost/ping >/dev/null 2>&1; then
        log_info "Rancher Server está disponível!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    log_error "Rancher Server não ficou disponível após 5 minutos!"
    exit 1
fi

echo ""

# Aguardar mais um pouco para estabilização
log_info "Aguardando estabilização do Rancher (30 segundos)..."
sleep 30

# Iniciar o cluster Kubernetes
log_info "Iniciando cluster Kubernetes (Master + Workers)..."
docker compose up -d k8s-master k8s-worker-1 k8s-worker-2 k8s-worker-3 k8s-worker-4

# Aguardar cluster ficar disponível
log_info "Aguardando cluster Kubernetes ficar disponível..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker exec k8s-master kubectl get nodes >/dev/null 2>&1; then
        log_info "Cluster Kubernetes está disponível!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    log_error "Cluster Kubernetes não ficou disponível após 5 minutos!"
    exit 1
fi

echo ""

# Aguardar todos os nodes ficarem prontos
log_info "Aguardando todos os nodes ficarem Ready..."
max_attempts=120
attempt=0

while [ $attempt -lt $max_attempts ]; do
    ready_nodes=$(docker exec k8s-master kubectl get nodes --no-headers 2>/dev/null | grep " Ready " | wc -l || echo "0")
    if [ "$ready_nodes" -eq "5" ]; then  # Master + 4 workers
        log_info "Todos os nodes estão Ready!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    log_warn "Nem todos os nodes ficaram Ready após 10 minutos, mas continuando..."
fi

echo ""

# Copiar kubeconfig
log_info "Configurando acesso kubectl local..."
if [ -f "$ROOT_DATA_DIR/k8s-config/kubeconfig.yaml" ]; then
    mkdir -p ~/.kube
    cp "$ROOT_DATA_DIR/k8s-config/kubeconfig.yaml" ~/.kube/config
    chmod 600 ~/.kube/config
    
    # Ajustar servidor para localhost
    sed -i 's/server: https:\/\/127\.0\.0\.1:6443/server: https:\/\/localhost:6443/' ~/.kube/config
    
    log_info "kubeconfig configurado em ~/.kube/config"
else
    log_warn "kubeconfig não encontrado, será criado manualmente..."
    docker exec k8s-master cat /etc/rancher/k3s/k3s.yaml | sed 's/127.0.0.1/localhost/' > ~/.kube/config
    chmod 600 ~/.kube/config
fi

# Verificar status do cluster
log_info "Status do cluster:"
echo ""
kubectl get nodes -o wide

# Mostrar informações dos pods do sistema
log_info "Pods do sistema:"
echo ""
kubectl get pods -A

# Configurar Rancher para gerenciar o cluster local
log_info "Aguardando Rancher terminar a inicialização..."
sleep 30

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                           Deploy Concluído com Sucesso!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Informações de Acesso:${NC}"
echo -e "• Rancher UI: ${BLUE}https://localhost${NC}"
echo -e "• Usuário: ${BLUE}admin${NC}"
echo -e "• Senha: ${BLUE}$CATTLE_BOOTSTRAP_PASSWORD${NC}"
echo -e "• Kubernetes API: ${BLUE}https://localhost:6443${NC}"
echo ""
echo -e "${YELLOW}Comandos úteis:${NC}"
echo -e "• Verificar nodes: ${BLUE}kubectl get nodes${NC}"
echo -e "• Verificar pods: ${BLUE}kubectl get pods -A${NC}"
echo -e "• Logs dos containers: ${BLUE}docker compose logs -f [service]${NC}"
echo -e "• Parar ambiente: ${BLUE}./scripts/stop.sh${NC}"
echo -e "• Destruir ambiente: ${BLUE}./scripts/destroy.sh${NC}"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
