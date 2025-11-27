#!/bin/bash

# =============================================================================
# Kubernetes Cluster Import Script
# =============================================================================
# Este script importa o cluster K3s externo para o Rancher Server
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

# Carregar configurações
if [ -f .env ]; then
    source .env
else
    log_error "Arquivo .env não encontrado!"
    exit 1
fi

CLUSTER_NAME="${1:-k3s-local}"
RANCHER_URL="https://rancher-server"
RANCHER_INTERNAL_URL="https://rancher-server"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}           Importando Cluster K3s para o Rancher Server${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# Verificar se o Rancher está rodando
if ! docker compose ps | grep -q "rancher-server.*Up"; then
    log_error "Rancher Server não está rodando!"
    exit 1
fi

# Verificar se o cluster K3s está rodando
if ! docker compose ps | grep -q "k8s-master.*Up"; then
    log_error "Cluster K3s não está rodando!"
    exit 1
fi

# Aguardar Rancher estar completamente disponível
log_info "Verificando disponibilidade do Rancher..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -k -s https://localhost/ping >/dev/null 2>&1; then
        break
    fi
    attempt=$((attempt + 1))
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    log_error "Rancher não está disponível!"
    exit 1
fi

log_info "Rancher está disponível!"

# Obter token de autenticação do Rancher
log_info "Obtendo token de autenticação do Rancher..."

# Criar token de API via kubectl no Rancher
TOKEN_NAME="import-token-$(date +%s)"

# Verificar se já existe um cluster com este nome
EXISTING_CLUSTER=$(docker exec rancher-server kubectl get clusters.management.cattle.io -o jsonpath='{.items[*].spec.displayName}' 2>/dev/null | tr ' ' '\n' | grep -x "$CLUSTER_NAME" || true)

if [ -n "$EXISTING_CLUSTER" ]; then
    log_warn "Cluster '$CLUSTER_NAME' já existe no Rancher!"
    
    # Verificar se é o cluster local interno
    if [ "$CLUSTER_NAME" == "local" ]; then
        log_info "O cluster 'local' é o cluster interno do Rancher."
        log_info "Para importar o cluster K3s externo, use um nome diferente:"
        echo -e "  ${BLUE}./scripts/import-cluster.sh k3s-external${NC}"
        exit 0
    fi
    
    read -p "Deseja reimportar o cluster? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operação cancelada."
        exit 0
    fi
    
    # Deletar cluster existente
    log_info "Removendo cluster existente..."
    CLUSTER_ID=$(docker exec rancher-server kubectl get clusters.management.cattle.io -o jsonpath='{.items[?(@.spec.displayName=="'"$CLUSTER_NAME"'")].metadata.name}' 2>/dev/null)
    if [ -n "$CLUSTER_ID" ]; then
        docker exec rancher-server kubectl delete clusters.management.cattle.io "$CLUSTER_ID" 2>/dev/null || true
        sleep 10
    fi
fi

# Criar o cluster no Rancher via API usando kubectl
log_info "Criando registro do cluster '$CLUSTER_NAME' no Rancher..."

cat << EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: management.cattle.io/v3
kind: Cluster
metadata:
  name: c-${CLUSTER_NAME}
  annotations:
    field.cattle.io/description: "Cluster K3s local importado automaticamente"
spec:
  displayName: ${CLUSTER_NAME}
  description: "Cluster K3s com 1 master + 4 workers"
  dockerRootDir: /var/lib/docker
  enableNetworkPolicy: false
  windowsPreferedCluster: false
EOF

# Aguardar o cluster ser criado
log_info "Aguardando cluster ser registrado..."
sleep 10

# Obter o ID do cluster
CLUSTER_ID=$(docker exec rancher-server kubectl get clusters.management.cattle.io -o jsonpath='{.items[?(@.spec.displayName=="'"$CLUSTER_NAME"'")].metadata.name}' 2>/dev/null)

if [ -z "$CLUSTER_ID" ]; then
    log_error "Falha ao criar cluster no Rancher!"
    exit 1
fi

log_info "Cluster ID: $CLUSTER_ID"

# Aguardar token de registro ser gerado
log_info "Aguardando token de registro ser gerado..."
max_attempts=30
attempt=0
MANIFEST_URL=""

while [ $attempt -lt $max_attempts ]; do
    # Obter o ClusterRegistrationToken
    MANIFEST_URL=$(docker exec rancher-server kubectl get clusterregistrationtokens.management.cattle.io -n "$CLUSTER_ID" -o jsonpath='{.items[0].status.manifestUrl}' 2>/dev/null || true)
    
    if [ -n "$MANIFEST_URL" ]; then
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 5
done
echo ""

if [ -z "$MANIFEST_URL" ]; then
    log_error "Não foi possível obter URL do manifesto de importação!"
    log_info "Tente importar manualmente via Rancher UI"
    exit 1
fi

log_info "URL do manifesto: $MANIFEST_URL"

# Baixar o manifesto de importação
log_info "Baixando manifesto de importação..."

# Ajustar URL para usar hostname interno
INTERNAL_MANIFEST_URL=$(echo "$MANIFEST_URL" | sed 's|https://[^/]*|https://rancher-server|')

# Baixar e aplicar o manifesto no cluster K3s externo
log_info "Aplicando manifesto de importação no cluster K3s..."

# Primeiro, baixar o manifesto via Rancher (que tem curl)
docker exec rancher-server sh -c "curl -k -sfL '$INTERNAL_MANIFEST_URL'" > /tmp/import-manifest.yaml 2>/dev/null

if [ ! -s /tmp/import-manifest.yaml ]; then
    log_warn "Falha ao baixar via URL interna, tentando URL externa..."
    docker exec rancher-server sh -c "curl -k -sfL '$MANIFEST_URL'" > /tmp/import-manifest.yaml 2>/dev/null
fi

if [ ! -s /tmp/import-manifest.yaml ]; then
    log_error "Não foi possível baixar o manifesto de importação!"
    exit 1
fi

# Copiar manifesto para k8s-master
docker cp /tmp/import-manifest.yaml k8s-master:/tmp/import-manifest.yaml

# Aplicar no cluster K3s
docker exec k8s-master kubectl apply -f /tmp/import-manifest.yaml

log_info "Manifesto aplicado com sucesso!"

# Aguardar cluster ficar ativo
log_info "Aguardando cluster ficar ativo no Rancher..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    STATE=$(docker exec rancher-server kubectl get clusters.management.cattle.io "$CLUSTER_ID" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    
    if [ "$STATE" == "True" ]; then
        log_info "Cluster está ativo!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 10
done
echo ""

if [ $attempt -eq $max_attempts ]; then
    log_warn "Cluster ainda não está completamente ativo, mas a importação foi iniciada."
    log_info "Verifique o status no Rancher UI: https://localhost"
fi

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}                    Importação do Cluster Concluída!${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "${YELLOW}Informações:${NC}"
echo -e "• Nome do Cluster: ${BLUE}$CLUSTER_NAME${NC}"
echo -e "• Cluster ID: ${BLUE}$CLUSTER_ID${NC}"
echo -e "• Rancher UI: ${BLUE}https://localhost${NC}"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo -e "1. Acesse o Rancher UI: ${BLUE}https://localhost${NC}"
echo -e "2. Navegue até 'Cluster Management'"
echo -e "3. O cluster '${CLUSTER_NAME}' deve aparecer na lista"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
