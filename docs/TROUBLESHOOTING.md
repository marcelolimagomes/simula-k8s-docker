# 🔧 Guia de Troubleshooting e FAQ

## 🚨 Problemas Comuns e Soluções

### 1. Containers não iniciam

#### Sintomas
```bash
docker compose ps
# Mostra containers com status "Exit" ou "Restarting"
```

#### Diagnóstico
```bash
# Verificar logs
docker compose logs rancher-server
docker compose logs k8s-master

# Verificar recursos do sistema
free -h
df -h /media/marcelo/backup_ext4
```

#### Soluções
```bash
# Verificar espaço em disco
sudo rm -rf /var/lib/docker/tmp/*
docker system prune -f

# Verificar memória
# Fechar aplicações desnecessárias
# Aumentar swap se necessário
sudo swapon --show
```

### 1.1. Erro: "port is already allocated"

#### Sintomas
```bash
docker compose up -d
# Error response from daemon: failed to set up container networking: 
# driver failed programming external connectivity on endpoint k8s-master
# Bind for 0.0.0.0:80 failed: port is already allocated
```

#### Diagnóstico
```bash
# Verificar qual processo está usando a porta
sudo netstat -tulpn | grep :80
sudo lsof -i :80

# Verificar se o Rancher já está rodando
docker ps | grep rancher
```

#### Soluções
```bash
# Parar todos os containers e reiniciar
docker compose down
docker compose up -d

# Ou verificar conflitos com outros serviços
sudo systemctl stop nginx apache2  # Se estiverem instalados
```

### 2. Rancher não fica disponível

#### Sintomas
```bash
curl -k https://localhost/ping
# curl: (7) Failed to connect to localhost port 443
```

#### Diagnóstico
```bash
# Verificar se container está rodando
docker compose ps rancher-server

# Verificar logs
docker compose logs -f rancher-server

# Verificar porta
sudo netstat -tulpn | grep :443
```

#### Soluções
```bash
# Aguardar mais tempo (pode levar até 10 minutos na primeira vez)
sleep 300

# Verificar conflitos de porta
sudo systemctl stop nginx apache2
docker compose restart rancher-server

# Verificar certificados
docker exec rancher-server ls -la /var/lib/rancher/
```

### 3. Workers não se conectam ao Master

#### Sintomas
```bash
kubectl get nodes
# Mostra apenas o master ou workers com status "NotReady"
```

#### Diagnóstico
```bash
# Verificar logs do master
docker compose logs k8s-master | grep -i error

# Verificar logs dos workers
docker compose logs k8s-worker-1 | grep -i "unable to connect"

# Testar conectividade
docker exec k8s-worker-1 ping k8s-master
```

#### Soluções
```bash
# Verificar token
grep K3S_TOKEN docker-compose.yml

# Reiniciar workers
docker compose restart k8s-worker-1 k8s-worker-2 k8s-worker-3 k8s-worker-4

# Recriar cluster se necessário
./scripts/destroy.sh
./scripts/deploy.sh
```

### 3.1. Pods Traefik/Helm em CrashLoopBackOff

#### Sintomas
```bash
kubectl get pods -A
# helm-install-traefik-v8txr    0/1  CrashLoopBackOff  3  2m37s
```

#### Diagnóstico
```bash
# Verificar logs do pod Traefik
kubectl logs helm-install-traefik-v8txr -n kube-system

# Verificar se CRDs foram instaladas
kubectl get crd | grep traefik
```

#### Soluções
```bash
# Aguardar - geralmente se resolve automaticamente
# O K3s tenta reinstalar após algumas tentativas
sleep 60 && kubectl get pods -A

# Se persistir, reiniciar o cluster
docker compose restart k8s-master
```

**Nota**: Este problema é comum no K3s e geralmente se resolve automaticamente após 2-3 tentativas do Helm.

### 4. kubectl não funciona

#### Sintomas
```bash
kubectl get nodes
# The connection to the server localhost:6443 was refused
```

#### Diagnóstico
```bash
# Verificar se o kubeconfig existe
ls -la ~/.kube/config

# Verificar conteúdo
cat ~/.kube/config | grep server

# Verificar se API está disponível
curl -k https://localhost:6443/version
```

#### Soluções
```bash
# Recriar kubeconfig
cp /media/marcelo/backup_ext4/k8s-config/kubeconfig.yaml ~/.kube/config
chmod 600 ~/.kube/config

# Ajustar servidor
sed -i 's/127.0.0.1/localhost/' ~/.kube/config

# Testar novamente
kubectl get nodes
```

### 5. Performance ruim do cluster

#### Sintomas
- Pods demoram para iniciar
- API Server responde lentamente
- High CPU/Memory usage

#### Diagnóstico
```bash
# Verificar recursos
top
htop
docker stats

# Verificar métricas do cluster
kubectl top nodes
kubectl top pods -A
```

#### Soluções
```bash
# Limitar recursos dos containers
# Editar docker-compose.yml
services:
  k8s-worker-1:
    cpus: '1.0'          # Limitar CPU
    mem_limit: 1.5g      # Reduzir RAM se necessário

# Desabilitar componentes desnecessários do K3s
environment:
  - K3S_DISABLE=traefik,servicelb,metrics-server
```

## 🔍 Comandos de Diagnóstico

### Sistema Geral
```bash
# Status dos containers
docker compose ps -a

# Recursos do sistema
free -h && df -h && uptime

# Rede
sudo netstat -tulpn | grep -E ':(80|443|6443)'

# Processes relacionados
ps aux | grep -E "(rancher|k3s|docker)"
```

### Docker
```bash
# Informações do Docker
docker info

# Espaço usado pelo Docker
docker system df

# Logs de containers específicos
docker compose logs -f --tail=100 rancher-server
docker compose logs -f --tail=100 k8s-master

# Executar comandos dentro dos containers
docker exec -it k8s-master /bin/sh
docker exec -it rancher-server /bin/bash
```

### Kubernetes
```bash
# Status do cluster
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A -o wide

# Eventos do sistema
kubectl get events -A --sort-by='.lastTimestamp'

# Logs de pods
kubectl logs -n kube-system -l k8s-app=kube-apiserver

# Recursos do cluster
kubectl describe nodes
kubectl top nodes
```

## 📋 FAQ (Perguntas Frequentes)

### Q: Posso executar em uma máquina com menos de 10GB de RAM?
**R**: É possível, mas você pode ter problemas de performance. Considere:
- Reduzir a RAM dos workers para 1GB cada
- Desabilitar componentes não essenciais
- Usar apenas 2 workers em vez de 4

### Q: Como adicionar mais workers?
**R**: Edite o `docker-compose.yml` adicionando novos serviços worker seguindo o padrão dos existentes.

### Q: Posso usar um storage diferente de `/media/marcelo/backup_ext4`?
**R**: Sim, edite a variável `DATA_DIR` no script `setup.sh` antes de executá-lo.

### Q: Como acessar o cluster de outras máquinas na rede?
**R**: Modifique o `docker-compose.yml` para expor as portas no IP da máquina em vez de localhost:
```yaml
ports:
  - "0.0.0.0:443:443"  # Em vez de "443:443"
```

### Q: Posso usar este ambiente em produção?
**R**: **NÃO**. Este ambiente é apenas para desenvolvimento e testes. Para produção, use instalações dedicadas do Kubernetes e Rancher.

### Q: Como fazer upgrade das versões?
**R**: 
1. Faça backup: `./scripts/backup.sh`
2. Edite as tags das imagens no `docker-compose.yml`
3. Execute: `docker compose pull && docker compose up -d`

### Q: Aparecem warnings sobre "version is obsolete" no Docker Compose
**R**: Este é um warning benigno. O Docker Compose v2 não requer mais a linha `version:` no arquivo YAML. O arquivo foi atualizado para remover esse warning.

### Q: O ambiente persiste após reinicializar a máquina?
**R**: Sim, os dados são persistidos em volumes. Mas você precisa reiniciar manualmente:
```bash
cd /home/marcelo/des/simula-k8s-docker
docker compose up -d
```

### Q: Como monitorar recursos em tempo real?
**R**: Use ferramentas como:
```bash
# Recursos do sistema
htop
iotop

# Containers Docker
docker stats

# Kubernetes
watch kubectl top nodes
```

## 🛠️ Scripts de Debug

### Script de Health Check
```bash
#!/bin/bash
# health-check.sh

echo "=== Health Check ==="

# Docker
echo "Docker Status:"
systemctl is-active docker
docker info | grep -E "(Containers|Images|Server Version)"

# Containers
echo -e "\nContainers:"
docker compose ps

# Kubernetes
echo -e "\nKubernetes Nodes:"
kubectl get nodes 2>/dev/null || echo "Kubectl not available"

# Network
echo -e "\nNetwork:"
curl -k -s -o /dev/null -w "Rancher: %{http_code}\n" https://localhost/ping
curl -k -s -o /dev/null -w "K8s API: %{http_code}\n" https://localhost:6443/version

# Resources
echo -e "\nResources:"
free -h | head -2
df -h /media/marcelo/backup_ext4 | tail -1

echo "=== End Health Check ==="
```

### Script de Limpeza Completa
```bash
#!/bin/bash
# clean-all.sh

echo "⚠️  ATENÇÃO: Este script irá limpar TUDO relacionado ao Docker!"
read -p "Continuar? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Parar todos os containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    
    # Remover todos os containers
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remover todas as imagens
    docker rmi $(docker images -q) -f 2>/dev/null || true
    
    # Limpar tudo
    docker system prune -a -f
    docker volume prune -f
    docker network prune -f
    
    echo "✅ Limpeza completa realizada!"
fi
```

## 📞 Quando Pedir Ajuda

Antes de pedir ajuda, colete as seguintes informações:

1. **Informações do sistema**:
```bash
uname -a
docker --version
docker compose version
free -h
df -h
```

2. **Status dos containers**:
```bash
docker compose ps -a
docker compose logs --tail=50
```

3. **Status do Kubernetes**:
```bash
kubectl get nodes
kubectl get pods -A
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

4. **Logs de erro específicos**:
```bash
# Incluir logs com timestamps e contexto
docker compose logs --timestamps --tail=100 [service-name]
```

---

💡 **Dica**: A maioria dos problemas pode ser resolvida reiniciando os containers com `docker compose restart` ou recriando o ambiente com `./scripts/destroy.sh && ./scripts/deploy.sh`
