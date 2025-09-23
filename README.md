# 🚀 Simulador Kubernetes + Rancher DevOps

Ambiente completo de desenvolvimento local para simular um cluster Kubernetes com 4 workers gerenciado pelo Rancher, utilizando Docker Compose e Infrastructure as Code.

## 📋 Visão Geral

Este projeto fornece um ambiente DevOps completo que simula:
- **Cluster Kubernetes** com 1 master + 4 workers usando K3s
- **Rancher Server** para gerenciamento visual do cluster
- **Infrastructure as Code** com 7 scripts automatizados
- **Persistência de dados** em volumes externos organizados
- **Backup e restore** automatizados com versionamento
- **Makefile** com 20+ comandos para operações cotidianas
- **Documentação completa** com guias de arquitetura e troubleshooting

### ✨ Características Principais
- 🐋 **Docker Compose v2** - Orquestração moderna de containers
- ☸️ **K3s v1.30.14+k3s2** - Distribuição leve do Kubernetes
- 🎯 **Rancher latest** - Interface web para gerenciamento
- 💾 **Volumes persistentes** - Dados preservados entre reinicializações
- 🔄 **Alta disponibilidade** - 4 workers para distribuição de carga
- 📋 **Monitoramento integrado** - Scripts de status e health check

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

## 🛠️ Pré-requisitos e Instalação

### 📋 Requisitos do Sistema
- **SO**: Linux (Ubuntu 20.04+, Debian 11+, CentOS 8+)
- **CPU**: 4+ cores (recomendado)
- **RAM**: 10GB+ disponível
- **Disco**: 250GB+ de espaço livre
- **Rede**: Portas 80, 443, 6443 disponíveis

### 🔧 Software Necessário

#### 1. Docker Engine (v20.10+)
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release

# Adicionar repositório oficial Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

#### 2. Docker Compose v2
```bash
# Instalar como plugin do Docker
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verificar instalação
docker compose version
```

#### 3. kubectl (Opcional - será instalado automaticamente)
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
```

### ⚙️ Configuração do Sistema

#### Preparação de Diretórios
```bash
# Criar diretório de dados (ajuste o caminho se necessário)
sudo mkdir -p /media/marcelo/dados
sudo chown -R $USER:$USER /media/marcelo/dados
```

#### Limites do Sistema (automático no setup)
O script `setup.sh` configura automaticamente:
- Limites de arquivos abertos: 65536
- Parâmetros do kernel para Kubernetes
- Watchers inotify para containers

### 🧪 Verificação dos Pré-requisitos
```bash
# Execute o script de verificação automática
make check-requirements

# Ou verifique manualmente:
docker --version              # Docker 20.10+
docker compose version       # v2.0+
free -h                      # RAM disponível
df -h                        # Espaço em disco
```

### 🚀 Instalação e Primeira Configuração

#### 1. Clone do Repositório
```bash
git clone <seu-repositorio>
cd simula-k8s-docker
```

#### 2. Preparação do Ambiente
```bash
# Tornar scripts executáveis
chmod +x scripts/*.sh

# Verificar pré-requisitos
make check-requirements

# Configurar sistema (aumenta limites, otimiza kernel)
make setup
```

#### 3. Deploy da Stack Completa
```bash
# Deploy completo (Rancher + Cluster K8s)
make deploy

# Monitorar progresso
make status
```

#### 4. Aguardar Inicialização (5-10 minutos)
```bash
# Verificar status dos containers
make status

# Aguardar todos os 4 workers ficarem "Ready"
make check-workers
```

#### 5. Acessar Interfaces

**Rancher UI**:
- URL: https://localhost (ou https://seu-ip)
- Setup inicial: seguir wizard de configuração
- Importar cluster K3s local automaticamente

**kubectl** (configurado automaticamente):
```bash
# Verificar cluster
kubectl get nodes -o wide

# Verificar pods do sistema
kubectl get pods -A
```

### 🔍 Verificação da Instalação

#### Comandos de Diagnóstico
```bash
# Status geral
make status

# Logs detalhados
make logs

# Verificar workers
make check-workers

# Teste de conectividade
make test-connectivity
```

#### Indicadores de Sucesso
- ✅ 5 containers rodando (1 Rancher + 1 Master + 4 Workers)
- ✅ Todos os nós com status "Ready"
- ✅ Rancher UI acessível via browser
- ✅ kubectl configurado e funcional
- ✅ Pods do sistema (kube-system) rodando

## � Guias e Operações

### 🔧 Comandos Make Disponíveis

| Comando | Descrição | Uso |
|---------|-----------|-----|
| `make setup` | Configuração inicial do sistema | Primeira execução |
| `make deploy` | Deploy da stack completa | Deploy inicial/restart |
| `make status` | Status de todos os containers | Monitoramento |
| `make stop` | Para todos os containers | Manutenção |
| `make destroy` | Remove stack completamente | Reset total |
| `make logs` | Visualiza logs de todos containers | Debugging |
| `make check-workers` | Verifica status dos workers K8s | Diagnóstico |
| `make backup` | Backup dos dados persistentes | Proteção dados |
| `make restore` | Restaura backup anterior | Recuperação |

### 🚨 Solução de Problemas Comuns

#### Problemas de Porta
```bash
# Verificar portas em uso
sudo netstat -tulpn | grep -E ':(80|443|6443)'

# Parar serviços conflitantes
sudo systemctl stop apache2 nginx
```

#### Problemas de Recursos
```bash
# Verificar uso de recursos
docker stats

# Limpar recursos não utilizados
docker system prune -f
```

#### Workers Não Ficam "Ready"
```bash
# Verificar logs dos workers
make logs | grep worker

# Restart de worker específico
docker compose restart k8s-worker-1
```

#### Rancher Não Carrega
```bash
# Verificar logs do Rancher
docker compose logs rancher-server

# Limpar dados do Rancher (reset)
make destroy && make deploy
```

### 📊 Monitoramento e Logs

#### Acompanhar Deploy em Tempo Real
```bash
# Terminal 1: Status dos containers
watch -n 5 "make status"

# Terminal 2: Logs em tempo real
make logs -f

# Terminal 3: Status do cluster K8s
watch -n 10 "kubectl get nodes -o wide"
```

#### Métricas e Performance
```bash
# Uso de recursos por container
docker stats

# Status detalhado dos nós K8s
kubectl describe nodes

# Pods por namespace
kubectl get pods -A -o wide
```

### � Ciclo de Vida do Ambiente

#### Deploy Completo (primeira vez)
```bash
make setup    # ← Configuração do sistema
make deploy   # ← Deploy da stack
make status   # ← Verificar status
```

#### Restart da Stack
```bash
make stop     # ← Parar containers
make deploy   # ← Subir novamente
```

#### Reset Completo
```bash
make backup   # ← Backup dos dados (opcional)
make destroy  # ← Remove tudo
make setup    # ← Reconfigurar sistema
make deploy   # ← Deploy limpo
```

### 🔐 Segurança e Backup

#### Backup Regular
```bash
# Backup automático (configurar crontab)
0 2 * * * cd /caminho/simula-k8s-docker && make backup

# Backup manual
make backup
```

#### Restauração
```bash
make destroy  # Remove ambiente atual
make restore  # Restaura backup
make deploy   # Reconectar containers
```

### 📈 Monitoramento Avançado

Para monitoramento mais detalhado, considere implementar:
- **Prometheus + Grafana**: Métricas detalhadas
- **ELK Stack**: Centralização de logs
- **Jaeger**: Tracing distribuído
- **Alertmanager**: Alertas automáticos

> 💡 **Dica**: Use `docs/TROUBLESHOOTING.md` para problemas específicos e `docs/ARCHITECTURE.md` para entender a estrutura do ambiente.

## � Estrutura de Dados e Configuração

### 📁 Organização de Dados
```
/media/marcelo/dados/
├── rancher/              # Dados persistentes do Rancher
├── k8s-master/          # Dados do nó master
├── k8s-worker-1/        # Dados do worker 1
├── k8s-worker-2/        # Dados do worker 2  
├── k8s-worker-3/        # Dados do worker 3
├── k8s-worker-4/        # Dados do worker 4
├── backups/             # Backups automáticos
└── logs/                # Logs centralizados
```

### ⚙️ Configurações Avançadas

#### Personalizar Recursos dos Workers
Edite `docker-compose.yml` para ajustar recursos:
```yaml
k8s-worker-1:
  deploy:
    resources:
      limits:
        memory: 4G      # Aumentar RAM
        cpus: '2.0'     # Aumentar CPU
```

#### Configurar Rede Personalizada
```bash
# Criar rede customizada
docker network create --driver bridge \
  --subnet=172.20.0.0/16 \
  --gateway=172.20.0.1 \
  k8s-network
```

#### Adicionar Workers Adicionais
```bash
# Copiar configuração de worker existente
# Ajustar nome e IP no docker-compose.yml
# Executar: docker compose up -d k8s-worker-5
```

### 🌐 URLs e Acessos

| Serviço | URL | Credenciais |
|---------|-----|-------------|
| **Rancher UI** | https://localhost | Setup inicial |
| **K8s API** | https://localhost:6443 | Via kubectl |
| **Traefik Dashboard** | http://localhost:8080 | Automático |

### 🔑 Gerenciamento de Credenciais

#### Rancher Setup Inicial
1. Acesse https://localhost
2. Defina senha do admin (primeira vez)
3. Configure URL do servidor Rancher
4. Importe cluster K3s local automaticamente

#### kubectl Configuration
```bash
# Kubeconfig configurado automaticamente em:
export KUBECONFIG=~/.kube/config

# Verificar contexto atual
kubectl config current-context

# Listar contextos disponíveis
kubectl config get-contexts
```

### 📈 Recursos do Sistema

#### Requisitos Mínimos vs Recomendados

| Componente | Mínimo | Recomendado | Produção |
|------------|--------|-------------|----------|
| **RAM** | 8GB | 12GB | 16GB+ |
| **CPU** | 4 cores | 6 cores | 8+ cores |
| **Disco** | 100GB | 250GB | 500GB+ |
| **Rede** | 100Mbps | 1Gbps | 10Gbps+ |

#### Monitoramento de Recursos
```bash
# Uso atual de recursos
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Espaço em disco
df -h /media/marcelo/dados

# Memória disponível no host
free -h
```

### 🔧 Troubleshooting Avançado

#### Logs Centralizados
```bash
# Todos os logs
make logs

# Log específico do Rancher
docker compose logs -f rancher-server

# Logs do master K8s
docker compose logs -f k8s-master

# Logs de worker específico
docker compose logs -f k8s-worker-1
```

#### Problemas de Conectividade
```bash
# Teste de conectividade interna
docker exec k8s-master ping k8s-worker-1

# Verificar rede do Docker
docker network inspect simula-k8s-docker_default

# Restart de rede
docker compose down && docker compose up -d
```

#### Reset de Componentes Específicos
```bash
# Reset apenas do Rancher
docker compose stop rancher-server
docker compose rm -f rancher-server
sudo rm -rf /media/marcelo/dados/rancher/*
docker compose up -d rancher-server

# Reset de worker específico  
docker compose stop k8s-worker-1
docker compose rm -f k8s-worker-1
sudo rm -rf /media/marcelo/dados/k8s-worker-1/*
docker compose up -d k8s-worker-1
## 📚 Documentação Adicional

### 📖 Documentos Disponíveis

| Documento | Descrição | Quando Usar |
|-----------|-----------|-------------|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Arquitetura técnica detalhada | Entender design e componentes |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Guia completo de problemas | Resolver erros e falhas |
| [`docs/INSTALLATION.md`](docs/INSTALLATION.md) | Instalação passo a passo | Setup em novos ambientes |
| [`docs/CONFIGURATION.md`](docs/CONFIGURATION.md) | Opções de configuração | Personalizar ambiente |
| [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) | Guia para desenvolvedores | Contribuir com o projeto |

### 🔗 Links Úteis

#### Documentação Oficial
- [Rancher Documentation](https://rancher.com/docs/)
- [K3s Documentation](https://rancher.com/docs/k3s/latest/en/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

#### Tutoriais e Guias
- [Kubernetes Learning Path](https://kubernetes.io/docs/tutorials/)
- [Rancher Academy](https://rancher.com/academy/)
- [K3s Quick Start](https://rancher.com/docs/k3s/latest/en/quick-start/)

### 🤝 Suporte e Contribuição

#### Reportar Problemas
1. Verifique [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) primeiro
2. Execute `make status` e `make logs` para coletar informações
3. Abra uma issue com logs e detalhes do ambiente

#### Contribuir
1. Fork do repositório
2. Crie branch para sua feature: `git checkout -b feature/nova-funcionalidade`
3. Commit das mudanças: `git commit -m "Adiciona nova funcionalidade"`
4. Push para branch: `git push origin feature/nova-funcionalidade`
5. Abra Pull Request

### ⚡ Quick Reference

#### Comandos Essenciais
```bash
# Deploy inicial
make setup && make deploy

# Verificar status
make status

# Parar ambiente
make stop

# Restart completo
make stop && make deploy

# Reset total
make destroy && make setup && make deploy

# Backup de emergência
make backup

# Ver logs
make logs
```

#### Portas Utilizadas
- **80**: HTTP Rancher (redirect para 443)
- **443**: HTTPS Rancher UI
- **6443**: Kubernetes API Server
- **8080**: Traefik Dashboard (interno)

#### Diretórios Importantes
- `/media/marcelo/dados/`: Dados persistentes
- `~/.kube/config`: Configuração kubectl
- `./logs/`: Logs do sistema
- `./scripts/`: Scripts de automação

---

## 🎯 Começar Agora

### Para Iniciantes
1. **Instale Docker e Docker Compose** (seção Pré-requisitos)
2. **Clone este repositório**
3. **Execute**: `make setup && make deploy`
4. **Acesse**: https://localhost (Rancher UI)
5. **Explore**: `kubectl get nodes`

### Para Usuários Avançados
1. **Customize** `docker-compose.yml` conforme necessário
2. **Ajuste** recursos e configurações avançadas
3. **Integre** com ferramentas de monitoring existentes
4. **Explore** documentação técnica em `docs/`

> 💡 **Dica Final**: Este ambiente é perfeito para aprender Kubernetes, testar deployments e simular cenários de produção em um ambiente controlado e local.

---

**📧 Suporte**: Para dúvidas ou problemas, consulte a documentação em `docs/` ou abra uma issue no repositório.

**🏷️ Versão**: 1.0.0 | **📅 Última Atualização**: $(date)
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