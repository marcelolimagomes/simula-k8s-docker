# Bastion Host - Acesso Seguro ao Kubernetes

## Visão Geral

O Bastion Host é um container Ubuntu que fornece acesso seguro e controlado ao cluster Kubernetes, atuando como um ponto de entrada único para usuários externos.

## Características

- **SO Linux**: Ubuntu 22.04 com ferramentas essenciais
- **Acesso SSH**: Porta 2222 exposta no host
- **kubectl**: Pré-instalado e configurado
- **Ferramentas**: vim, nano, htop, git, curl, wget
- **Aliases**: Atalhos convenientes para kubectl
- **Kubeconfig**: Montado como volume read-only

## Configuração Inicial

```bash
# Configurar o bastion
make setup-bastion

# Iniciar o bastion
make start-bastion
```

## Acesso

```bash
# Conectar via SSH
ssh bastion@localhost -p 2222

# Credenciais padrão
Usuário: bastion
Senha: P@ssw0rd123!
```

## Comandos Disponíveis no Bastion

### kubectl Aliases

```bash
k        # kubectl
kg       # kubectl get
kga      # kubectl get all
```

### Comandos Úteis

```bash
# Ver status do cluster
kubectl get nodes
kubectl get pods -A

# Ver logs
kubectl logs <pod-name> -f

# Executar comandos em pods
kubectl exec -it <pod-name> -- /bin/bash

# Aplicar manifests
kubectl apply -f <file.yaml>

# Ver recursos
kubectl get all -A
```

## Gerenciamento

```bash
# Ver logs do bastion
make logs-bastion

# Reiniciar bastion
make restart-bastion

# Parar bastion
make stop-bastion

# Acessar shell diretamente
make shell-bastion
```

## Segurança

### Recomendações

1. **Mude a senha padrão** imediatamente após o primeiro acesso
2. **Use chaves SSH** em vez de senha para autenticação
3. **Configure firewall** para restringir acesso à porta 2222
4. **Monitore logs** de acesso regularmente

### Configuração de Chaves SSH

1. Gere uma chave SSH no seu computador:

```bash
ssh-keygen -t rsa -b 4096 -C "your-email@example.com"
```

2. Copie a chave pública para o bastion:

```bash
ssh-copy-id -p 2222 bastion@localhost
```

3. Desabilite autenticação por senha no SSH do bastion (opcional):

```bash
# Dentro do bastion
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

## Arquitetura

```
[Usuários Externos] --> [Bastion Host (Porta 2222)] --> [Cluster Kubernetes]
                        - Ubuntu 22.04
                        - kubectl + ferramentas
                        - Kubeconfig montado
```

## Volumes

- `${ROOT_DATA_DIR}/k8s-config:/root/.kube:ro` - Kubeconfig (read-only)
- `${ROOT_DATA_DIR}/bastion-ssh:/root/.ssh` - Chaves SSH persistentes

## Troubleshooting

### Não consegue conectar

```bash
# Verificar se o bastion está rodando
docker compose ps bastion

# Ver logs
make logs-bastion

# Reiniciar
make restart-bastion
```

### kubectl não funciona no bastion

```bash
# Verificar kubeconfig
cat ~/.kube/config

# Testar conectividade
kubectl cluster-info
```

### Porta 2222 ocupada

```bash
# Verificar processos na porta
sudo lsof -i :2222

# Mudar porta no docker-compose.yml se necessário
```

## Próximos Passos

- Configurar RBAC para usuários específicos
- Implementar auditoria de comandos
- Adicionar autenticação multifator
- Integrar com sistemas de identidade corporativos
