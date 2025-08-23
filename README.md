# 🚀 Simulador Kubernetes + Rancher DevOps

Ambiente completo de desenvolvimento local para simular um cluster Kubernetes com 4 workers gerenciado pelo Rancher, utilizando Docker Compose e Infrastructure as Code.

## 📋 Visão Geral

Este projeto fornece um ambiente DevOps completo que simula:
- **Cluster Kubernetes** com 1 master + 4 workers
- **Rancher Server** para gerenciamento do cluster
- **Infrastructure as Code** com scripts automatizados
- **Persistência de dados** em volumes externos
- **Backup e restore** automatizados

## 🏗️ Arquitetura

```
┌─────────────────┐    ┌─────────────────┐
│  Rancher Server │    │   K8s Master    │
│   (Port 443)    │    │   (Port 6443)   │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────┬───────────────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───▼───┐   ┌───▼───┐   ┌───▼───┐   ┌───────┐
│Worker1│   │Worker2│   │Worker3│   │Worker4│
│ 2GB   │   │ 2GB   │   │ 2GB   │   │ 2GB   │
│ 50GB  │   │ 50GB  │   │ 50GB  │   │ 50GB  │
└───────┘   └───────┘   └───────┘   └───────┘
```

## 🛠️ Pré-requisitos

### Sistema
- Linux (Ubuntu/Debian recomendado)
- Docker 20.10+
- Docker Compose v2+
- 10GB+ de RAM disponível
- 250GB+ de espaço em disco
- `curl` e `wget` instalados

### Versões Testadas
- **K3s**: v1.30.14+k3s2
- **Rancher**: latest (v2.11+)
- **containerd**: 1.7.27-k3s1

### Verificação Rápida
```bash
docker --version
docker compose version
free -h
df -h /media/marcelo/dados
```

## 🚀 Início Rápido

### 1. Setup Inicial
```bash
./scripts/setup.sh
```
Este script irá:
- ✅ Verificar dependências
- ✅ Criar estrutura de diretórios
- ✅ Configurar limites do sistema
- ✅ Baixar imagens Docker
- ✅ Criar arquivo de configuração

### 2. Deploy do Ambiente
```bash
./scripts/deploy.sh
```
Este script irá:
- 🚀 Iniciar Rancher Server
- 🚀 Criar cluster Kubernetes
- 🚀 Conectar 4 workers
- 🚀 Configurar kubectl local
- 🚀 Exibir informações de acesso

**⏱️ Tempo estimado**: 5-10 minutos (dependendo da conexão e hardware)

### 3. Verificar Status
```bash
./scripts/status.sh
```

## 🔧 Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `setup.sh` | Configuração inicial do ambiente |
| `deploy.sh` | Deploy completo do cluster |
| `stop.sh` | Para o ambiente (mantém dados) |
| `destroy.sh` | Remove completamente o ambiente |
| `status.sh` | Mostra status detalhado |
| `backup.sh` | Faz backup completo |
| `restore.sh` | Restaura backup |

## 📊 Monitoramento e Acesso

### URLs de Acesso
- **Rancher UI**: https://localhost
- **Kubernetes API**: https://localhost:6443

### Credenciais Padrão
- **Usuário**: admin
- **Senha**: admin123456

### Comandos Úteis
```bash
# Verificar nodes
kubectl get nodes -o wide

# Verificar pods
kubectl get pods -A

# Logs dos containers
docker compose logs -f rancher-server
docker compose logs -f k8s-master

# Acessar container
docker exec -it k8s-master /bin/sh

# Status dos containers
docker compose ps
```

## 💾 Gerenciamento de Dados

### Estrutura de Dados
```
/media/marcelo/dados/
├── rancher-data/         # Dados do Rancher
├── rancher-audit/        # Logs de auditoria
├── k8s-master/          # Dados do master
├── k8s-worker-1/        # Dados do worker 1
├── k8s-worker-2/        # Dados do worker 2
├── k8s-worker-3/        # Dados do worker 3
├── k8s-worker-4/        # Dados do worker 4
├── k8s-config/          # Configurações Kubernetes
└── backups/             # Backups automáticos
```

### Backup e Restore
```bash
# Criar backup
./scripts/backup.sh

# Listar backups
ls -la /media/marcelo/dados/backups/

# Restaurar backup
./scripts/restore.sh 20240823_143022
```

## ⚙️ Configurações Avançadas

### Personalizar Recursos
Edite o `docker-compose.yml` para ajustar:
- Memória RAM por worker (padrão: 2GB)
- Limites de CPU
- Configurações de rede
- Volumes de dados

### Variáveis de Ambiente
Arquivo `.env` gerado automaticamente:
```env
DATA_DIR=/media/marcelo/dados
PROJECT_DIR=/home/marcelo/des/simula-k8s-docker
RANCHER_PASSWORD=admin123456
K3S_TOKEN=k8s-cluster-secret
CLUSTER_CIDR=10.42.0.0/16
SERVICE_CIDR=10.43.0.0/16
```

## 🔍 Troubleshooting

### Problemas Comuns

#### 1. Containers não iniciam
```bash
# Verificar logs
docker compose logs

# Verificar recursos
free -h
df -h
```

#### 2. Rancher não fica disponível
```bash
# Aguardar mais tempo (pode levar até 5 minutos)
curl -k https://localhost/ping

# Verificar logs do Rancher
docker compose logs -f rancher-server
```

#### 2.1. Erro "port is already allocated"
```bash
# Parar todos os containers e reiniciar
docker compose down
docker compose up -d
```

#### 3. Workers não se conectam
```bash
# Verificar conectividade
docker exec k8s-worker-1 ping k8s-master

# Verificar token
docker compose logs k8s-master | grep token
```

#### 4. Kubectl não funciona
```bash
# Reconfigurar kubeconfig
cp /media/marcelo/dados/k8s-config/kubeconfig.yaml ~/.kube/config
chmod 600 ~/.kube/config
```

#### 5. Pods Traefik em CrashLoopBackOff
```bash
# Aguardar - geralmente se resolve automaticamente
sleep 60 && kubectl get pods -A
```

**💡 Dica**: Para troubleshooting completo, consulte `docs/TROUBLESHOOTING.md`

### Limpeza Completa
```bash
# Parar tudo
./scripts/destroy.sh

# Limpar Docker
docker system prune -a -f

# Remover dados (CUIDADO!)
sudo rm -rf /media/marcelo/dados
```

## 📈 Recursos do Sistema

### Requisitos Mínimos
- **CPU**: 4 cores
- **RAM**: 10GB
- **Disco**: 250GB
- **Rede**: Porta 80, 443, 6443 disponíveis

### Uso Esperado
- **RAM**: ~8GB em uso
- **Disco**: ~200GB (com dados de teste)
- **CPU**: 10-30% em idle

## 🔐 Segurança

### Configurações de Segurança
- Containers executam com usuário não-root quando possível
- Volumes limitados ao necessário
- Rede isolada entre containers
- Logs de auditoria habilitados no Rancher

### Notas de Segurança
⚠️ **Este ambiente é para desenvolvimento local apenas!**
- Senhas padrão são simples
- Certificados são auto-assinados
- Não usar em produção

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Push para a branch
5. Abra um Pull Request

## 📄 Licença

Este projeto está licenciado sob a licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.

## 📞 Suporte

- **Issues**: Use o GitHub Issues para reportar problemas
- **Documentação**: Consulte a pasta `docs/` para mais detalhes
- **Logs**: Sempre inclua logs ao reportar problemas

---

**Desenvolvido com ❤️ para a comunidade DevOps**

> 🎯 **Objetivo**: Fornecer um ambiente completo e reproduzível para aprendizado e desenvolvimento com Kubernetes e Rancher