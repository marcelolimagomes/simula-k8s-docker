# 🔧 Guia de Instalação Detalhado

## 📋 Pré-requisitos Detalhados

### Sistema Operacional

- **Linux**: Ubuntu 20.04+ ou Debian 11+
- **Distribuições testadas**: Ubuntu 22.04, Debian 11, CentOS 8+
- **Kernel**: 5.4+

### Software Necessário

#### 1. Docker Engine

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker
```

#### 2. Docker Compose v2

```bash
# Instalar Docker Compose v2
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verificar instalação
docker compose version
```

**⚠️ Importante**: Use `docker compose` (espaço) ao invés de `docker-compose` (hífen). O projeto foi atualizado para Docker Compose v2.

#### 3. kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

## 🏗️ Preparação do Ambiente

### 1. Verificação de Recursos

```bash
# Verificar CPU
nproc
lscpu

# Verificar RAM
free -h

# Verificar espaço em disco
df -h ./data/backup_ext4
```

### 2. Configuração do Sistema

#### Limites de Sistema

```bash
# Aumentar limites de arquivos
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "root soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "root hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Configurar kernel
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.conf

# Aplicar mudanças
sudo sysctl -p
```

#### Configuração de Rede

```bash
# Verificar portas disponíveis
sudo netstat -tulpn | grep -E ':(80|443|6443)\s'

# Se necessário, parar serviços conflitantes
sudo systemctl stop apache2 nginx # Se estiverem rodando
```

### 3. Preparação dos Diretórios

```bash
# Criar estrutura base
sudo mkdir -p ./data/backup_ext4
sudo chown -R $USER:$USER ./data/backup_ext4
chmod 755 ./data/backup_ext4

# Verificar permissões
ls -la ./data/backup_ext4
```

## 🚀 Instalação

### 1. Clone do Repositório

```bash
git clone https://github.com/marcelolimagomes/simula-k8s-docker.git
cd simula-k8s-docker
```

### 2. Executar Setup

```bash
chmod +x scripts/*.sh
./scripts/setup.sh
```

### 3. Primeira Execução

```bash
./scripts/deploy.sh
```

## ✅ Verificação da Instalação

### 1. Verificar Containers

```bash
docker compose ps
```

Saída esperada:

```
NAME           COMMAND     SERVICE        STATUS    PORTS
k8s-master     server      k8s-master     Up        0.0.0.0:6443->6443/tcp
k8s-worker-1   agent       k8s-worker-1   Up
k8s-worker-2   agent       k8s-worker-2   Up
k8s-worker-3   agent       k8s-worker-3   Up
k8s-worker-4   agent       k8s-worker-4   Up
rancher-server             rancher-server Up        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

### 2. Verificar Kubernetes

```bash
kubectl get nodes
```

Saída esperada:

```
NAME           STATUS   ROLES                  AGE   VERSION
k8s-master     Ready    control-plane,master   5m    v1.25.4+k3s1
k8s-worker-1   Ready    <none>                 4m    v1.25.4+k3s1
k8s-worker-2   Ready    <none>                 4m    v1.25.4+k3s1
k8s-worker-3   Ready    <none>                 4m    v1.25.4+k3s1
k8s-worker-4   Ready    <none>                 4m    v1.25.4+k3s1
```

### 3. Verificar Rancher

```bash
curl -k -I https://localhost
```

Saída esperada:

```
HTTP/2 200
server: nginx/1.20.2
```

## 🔧 Configurações Opcionais

### 1. Configurar Aliases

```bash
echo "alias k='kubectl'" >> ~/.bashrc
echo "alias dc='docker compose'" >> ~/.bashrc
source ~/.bashrc
```

### 2. Autocompletar kubectl

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

### 3. Configurar Vim para YAML

```bash
cat >> ~/.vimrc << EOF
autocmd FileType yaml setlocal ai ts=2 sw=2 et
set nu
EOF
```

## 🚨 Solução de Problemas na Instalação

### Erro: Docker não instalado

```bash
# Verificar instalação
which docker
docker --version

# Reinstalar se necessário
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Erro: Permissões insuficientes

```bash
# Adicionar usuário ao grupo docker
sudo usermod -aG docker $USER
newgrp docker

# Ou executar logout/login
```

### Erro: Portas em uso

```bash
# Identificar processo usando porta
sudo netstat -tulpn | grep :443
sudo lsof -i :443

# Parar processo
sudo systemctl stop nginx # exemplo

# Verificar especificamente conflito com porta 80
sudo netstat -tulpn | grep :80
```

### Erro: Warning "version is obsolete" no Docker Compose

```bash
# Este é apenas um warning, pode ser ignorado
# O arquivo foi atualizado para remover a linha 'version:'
# Se quiser evitar o warning, certifique-se de usar Docker Compose v2
docker compose version
```

### Erro: Espaço em disco insuficiente

```bash
# Limpar Docker
docker system prune -a -f

# Limpar logs
sudo journalctl --vacuum-time=7d

# Verificar espaço
df -h
```

## 📝 Próximos Passos

Após a instalação bem-sucedida:

1. **Acessar o Rancher**: https://localhost
2. **Configurar primeiro acesso**: Usar senha `admin123456`
3. **Explorar o cluster**: Verificar nodes e recursos
4. **Deploy de aplicações**: Testar deployments
5. **Configurar monitoramento**: Instalar ferramentas de observabilidade

---

✅ **Instalação concluída com sucesso!**
