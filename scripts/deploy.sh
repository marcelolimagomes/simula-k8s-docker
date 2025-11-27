#!/bin/bash

# =============================================================================
# Kubernetes + Rancher Deployment Script
# =============================================================================
# Este script faz o deploy do cluster Kubernetes integrado com Rancher
# Os workers K3s se conectam diretamente ao cluster interno do Rancher
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
echo -e "${BLUE}              Iniciando Deploy do Ambiente K8s + Rancher Integrado${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Verificar se o Docker está rodando
if ! docker info >/dev/null 2>&1; then
    log_error "Docker não está rodando!"
    exit 1
fi

# Criar diretórios necessários
log_info "Criando diretórios de dados..."
mkdir -p "$ROOT_DATA_DIR/rancher-data"
mkdir -p "$ROOT_DATA_DIR/rancher-audit"
mkdir -p "$ROOT_DATA_DIR/k8s-config"
mkdir -p "$ROOT_DATA_DIR/k8s-token"
mkdir -p "$ROOT_DATA_DIR/k8s-worker-1"
mkdir -p "$ROOT_DATA_DIR/k8s-worker-2"
mkdir -p "$ROOT_DATA_DIR/k8s-worker-3"
mkdir -p "$ROOT_DATA_DIR/k8s-worker-4"
mkdir -p "$ROOT_DATA_DIR/bastion-ssh"

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
log_info "Aguardando Rancher Server ficar disponível (pode levar alguns minutos)..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -k -s https://localhost/ping >/dev/null 2>&1; then
        log_info "Rancher Server está respondendo!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    log_error "Rancher Server não ficou disponível após 5 minutos!"
    docker compose logs rancher-server
    exit 1
fi

echo ""

# Aguardar o K3s interno do Rancher ficar pronto
log_info "Aguardando cluster K3s interno do Rancher ficar pronto..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    # Verificar se o K3s interno está rodando
    if docker exec rancher-server kubectl get nodes >/dev/null 2>&1; then
        log_info "Cluster K3s interno do Rancher está disponível!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    log_warn "Timeout aguardando K3s interno, mas continuando..."
fi

echo ""

# Extrair token do K3s interno do Rancher para os workers
log_info "Extraindo token de autenticação do K3s..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    TOKEN=$(docker exec rancher-server cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || echo "")
    
    if [ -n "$TOKEN" ]; then
        echo "$TOKEN" > "$ROOT_DATA_DIR/k8s-token/node-token"
        chmod 600 "$ROOT_DATA_DIR/k8s-token/node-token"
        log_info "Token extraído e salvo com sucesso!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 3
done

if [ $attempt -eq $max_attempts ]; then
    log_error "Não foi possível extrair o token do K3s!"
    log_error "Verifique se o Rancher está funcionando corretamente."
    docker compose logs rancher-server
    exit 1
fi

echo ""

# Iniciar os worker nodes
log_info "Iniciando Worker Nodes (k8s-worker-1 a k8s-worker-4)..."
docker compose up -d k8s-worker-1 k8s-worker-2 k8s-worker-3 k8s-worker-4

# Aguardar workers se registrarem
log_info "Aguardando workers se registrarem no cluster..."
sleep 30

# Verificar status dos nodes
log_info "Verificando status dos nodes..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    ready_nodes=$(docker exec rancher-server kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
    total_nodes=$(docker exec rancher-server kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
    
    echo -ne "\rNodes Ready: $ready_nodes / $total_nodes esperado: 5 (1 master + 4 workers)"
    
    # Esperamos pelo menos 5 nodes (1 server interno do rancher + 4 workers)
    if [ "$ready_nodes" -ge "5" ]; then
        echo ""
        log_info "Todos os nodes estão Ready!"
        break
    fi
    
    attempt=$((attempt + 1))
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    echo ""
    log_warn "Nem todos os nodes ficaram Ready após 5 minutos."
    log_info "Nodes atuais:"
    docker exec rancher-server kubectl get nodes -o wide 2>/dev/null || true
fi

# Copiar kubeconfig
log_info "Configurando acesso kubectl local..."
docker exec rancher-server cat /etc/rancher/k3s/k3s.yaml 2>/dev/null | \
    sed 's/127.0.0.1/localhost/' > "$ROOT_DATA_DIR/k8s-config/kubeconfig.yaml"
chmod 600 "$ROOT_DATA_DIR/k8s-config/kubeconfig.yaml"

# Copiar para ~/.kube/config se não existir
if [ ! -f ~/.kube/config ] || [ -s "$ROOT_DATA_DIR/k8s-config/kubeconfig.yaml" ]; then
    mkdir -p ~/.kube
    cp "$ROOT_DATA_DIR/k8s-config/kubeconfig.yaml" ~/.kube/config
    chmod 600 ~/.kube/config
    log_info "kubeconfig configurado em ~/.kube/config"
fi

# Iniciar bastion
log_info "Iniciando Bastion Host..."
docker compose up -d bastion

# Verificar status final
echo ""
log_info "Status do cluster:"
echo ""
docker exec rancher-server kubectl get nodes -o wide 2>/dev/null || kubectl get nodes -o wide

# Mostrar informações dos pods do sistema
echo ""
log_info "Pods do sistema Kubernetes:"
echo ""
docker exec rancher-server kubectl get pods -A 2>/dev/null || kubectl get pods -A

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                           Deploy Concluído com Sucesso!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Informações de Acesso:${NC}"
echo -e "• Rancher UI: ${BLUE}https://localhost${NC}"
echo -e "• Usuário: ${BLUE}admin${NC}"
echo -e "• Senha inicial: ${BLUE}$CATTLE_BOOTSTRAP_PASSWORD${NC}"
echo -e "• Kubernetes API: ${BLUE}https://localhost:6443${NC}"
echo ""
echo -e "${YELLOW}Cluster Kubernetes:${NC}"
echo -e "• Nome no Rancher: ${BLUE}local${NC}"
echo -e "• Tipo: ${BLUE}K3s integrado (1 server + 4 workers)${NC}"
echo -e "• Os workers já estão registrados no cluster 'local' do Rancher"
echo ""
echo -e "${YELLOW}Acesso via Bastion:${NC}"
echo -e "• SSH: ${BLUE}ssh root@localhost -p 2222${NC}"
echo -e "• Senha: ${BLUE}P@ssw0rd123!${NC}"
echo ""
echo -e "${YELLOW}Comandos úteis:${NC}"
echo -e "• Verificar nodes: ${BLUE}kubectl get nodes${NC}"
echo -e "• Verificar pods: ${BLUE}kubectl get pods -A${NC}"
echo -e "• Logs dos containers: ${BLUE}docker compose logs -f [service]${NC}"
echo -e "• Status ambiente: ${BLUE}./scripts/status.sh${NC}"
echo -e "• Parar ambiente: ${BLUE}./scripts/stop.sh${NC}"
echo -e "• Destruir ambiente: ${BLUE}./scripts/destroy.sh${NC}"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
