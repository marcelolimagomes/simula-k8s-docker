#!/bin/bash

# =============================================================================
# Kubernetes + Rancher Status Script
# =============================================================================
# Este script mostra o status completo do ambiente
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
echo -e "${BLUE}                      Status do Ambiente K8s + Rancher${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Status dos containers Docker
echo ""
log_info "Status dos Containers Docker:"
echo ""
docker compose ps

echo ""
echo -e "${BLUE}------------------------------------------------------------------------------${NC}"

# Status do cluster Kubernetes (se disponível)
if docker compose ps | grep -q "k8s-master.*Up"; then
    echo ""
    log_info "Status dos Nodes Kubernetes:"
    echo ""
    kubectl get nodes -o wide 2>/dev/null || docker exec k8s-master kubectl get nodes -o wide 2>/dev/null || log_error "Cluster Kubernetes não está disponível"

    echo ""
    log_info "Pods do Sistema Kubernetes:"
    echo ""
    kubectl get pods -A 2>/dev/null || docker exec k8s-master kubectl get pods -A 2>/dev/null || log_error "Não foi possível listar pods"

    echo ""
    log_info "Recursos do Cluster:"
    echo ""
    kubectl top nodes 2>/dev/null || log_warn "Metrics server não disponível"
    
    echo ""
    log_info "Namespaces:"
    echo ""
    kubectl get namespaces 2>/dev/null || docker exec k8s-master kubectl get namespaces 2>/dev/null || log_error "Não foi possível listar namespaces"
else
    echo ""
    log_warn "Cluster Kubernetes não está rodando"
fi

echo ""
echo -e "${BLUE}------------------------------------------------------------------------------${NC}"

# Status do Rancher
if docker compose ps | grep -q "rancher-server.*Up"; then
    echo ""
    log_info "Status do Rancher:"
    echo "• URL: https://localhost"
    echo "• Status: $(curl -k -s -o /dev/null -w "%{http_code}" https://localhost/ping 2>/dev/null || echo "Não disponível")"
    
    if curl -k -s https://localhost/ping >/dev/null 2>&1; then
        echo -e "• Rancher: ${GREEN}Disponível${NC}"
    else
        echo -e "• Rancher: ${RED}Não disponível${NC}"
    fi
else
    echo ""
    log_warn "Rancher Server não está rodando"
fi

echo ""
echo -e "${BLUE}------------------------------------------------------------------------------${NC}"

# Uso de recursos
echo ""
log_info "Uso de Recursos do Sistema:"
echo ""
echo "CPU:"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"% usado"}'

echo ""
echo "Memória:"
free -h | awk 'NR==2{printf "%.1f/%.1fGB (%.2f%%)\n", $3/1024/1024/1024,$2/1024/1024/1024,$3*100/$2 }'

echo ""
echo "Disco ($DATA_DIR):"
if [ -d "${DATA_DIR:-/media/marcelo/dados}" ]; then
    df -h "${DATA_DIR:-/media/marcelo/dados}" | awk 'NR==2 {print $3"/"$2" ("$5" usado)"}'
else
    log_warn "Diretório de dados não encontrado"
fi

echo ""
echo -e "${BLUE}------------------------------------------------------------------------------${NC}"

# Logs recentes (últimas 10 linhas de cada serviço)
echo ""
log_info "Logs Recentes dos Serviços:"
echo ""

services=("rancher-server" "k8s-master" "k8s-worker-1" "k8s-worker-2" "k8s-worker-3" "k8s-worker-4")

for service in "${services[@]}"; do
    if docker compose ps | grep -q "$service.*Up"; then
        echo -e "${YELLOW}--- $service ---${NC}"
        docker compose logs --tail=5 "$service" 2>/dev/null || echo "Logs não disponíveis"
        echo ""
    fi
done

echo ""
echo -e "${BLUE}==============================================================================${NC}"

# URLs úteis e comandos
echo ""
log_info "URLs de Acesso:"
echo "• Rancher: https://localhost"
echo "• Kubernetes API: https://localhost:6443"

echo ""
log_info "Comandos Úteis:"
echo "• Ver logs: docker compose logs -f [service]"
echo "• Acessar container: docker exec -it [container] /bin/sh"
echo "• Parar ambiente: ./scripts/stop.sh"
echo "• Reiniciar ambiente: ./scripts/deploy.sh"

echo ""
echo -e "${BLUE}==============================================================================${NC}"
