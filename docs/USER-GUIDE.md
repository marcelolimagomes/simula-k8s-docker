# 📖 Guia do Usuário - Cluster Kubernetes Local

Este guia fornece todas as informações necessárias para usuários utilizarem o cluster Kubernetes local para instalar aplicações, criar namespaces e gerenciar serviços.

---

## 📋 Índice

1. [Visão Geral do Cluster](#visão-geral-do-cluster)
2. [Credenciais e URLs de Acesso](#credenciais-e-urls-de-acesso)
3. [Métodos de Acesso](#métodos-de-acesso)
4. [Trabalhando com Namespaces](#trabalhando-com-namespaces)
5. [Instalando Aplicações](#instalando-aplicações)
6. [Gerenciando Serviços](#gerenciando-serviços)
7. [Armazenamento Persistente](#armazenamento-persistente)
8. [ConfigMaps e Secrets](#configmaps-e-secrets)
9. [Ingress e Exposição de Serviços](#ingress-e-exposição-de-serviços)
10. [Monitoramento e Logs](#monitoramento-e-logs)
11. [Exemplos Práticos](#exemplos-práticos)
12. [Referência Rápida de Comandos](#referência-rápida-de-comandos)

---

## 🎯 Visão Geral do Cluster

### Arquitetura

O cluster Kubernetes local é composto por:

| Componente            | Descrição                                        | Versão           |
| --------------------- | ------------------------------------------------ | ---------------- |
| **Rancher Server**    | Interface de gerenciamento web com K3s integrado | rancher:latest   |
| **Control Plane**     | Nó master (local-node) interno ao Rancher        | K3s v1.33.1+k3s1 |
| **Workers**           | 4 nós de trabalho para execução de pods          | K3s v1.34.1+k3s1 |
| **Container Runtime** | containerd para execução de containers           | containerd 2.1.4 |
| **Bastion Host**      | Ponto de acesso SSH seguro                       | Ubuntu 22.04     |

### Topologia dos Nós

```
┌───────────────────────────────────────────────────────────────────────────┐
│                           CLUSTER KUBERNETES                               │
├───────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│   ┌─────────────────────────────────────────────────────────────────┐    │
│   │                    RANCHER SERVER (local-node)                   │    │
│   │                  Control Plane + etcd + Master                   │    │
│   │                        IP: 172.20.0.10                          │    │
│   │                      Versão: v1.33.1+k3s1                        │    │
│   └─────────────────────────────────────────────────────────────────┘    │
│                                    │                                      │
│          ┌─────────────┬──────────┼──────────┬─────────────┐             │
│          │             │          │          │             │             │
│   ┌──────▼──────┐ ┌────▼────┐ ┌───▼────┐ ┌───▼────┐                     │
│   │  Worker 1   │ │ Worker 2│ │Worker 3│ │Worker 4│                     │
│   │ 172.20.0.2  │ │172.20.0.3│ │172.20.0.4│ │172.20.0.5│                │
│   │   2GB RAM   │ │  2GB RAM │ │  2GB RAM │ │  2GB RAM │                │
│   └─────────────┘ └─────────┘ └──────────┘ └──────────┘                 │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

### Recursos do Cluster

| Recurso              | Valor                            |
| -------------------- | -------------------------------- |
| **Total de Memória** | ~10GB (2GB × 4 workers + master) |
| **Nós de Trabalho**  | 4 workers disponíveis            |
| **Cluster CIDR**     | 10.42.0.0/16 (pods)              |
| **Service CIDR**     | 10.43.0.0/16 (serviços)          |
| **DNS Cluster**      | 10.43.0.10 (CoreDNS)             |
| **Rede Docker**      | 172.20.0.0/16                    |

---

## 🔐 Credenciais e URLs de Acesso

### Rancher UI (Interface Web)

| Informação      | Valor             |
| --------------- | ----------------- |
| **URL**         | https://localhost |
| **Usuário**     | `admin`           |
| **Senha**       | `admin123456`     |
| **Porta HTTP**  | 80                |
| **Porta HTTPS** | 443               |

> ⚠️ **Nota**: O certificado SSL é auto-assinado. Aceite a exceção de segurança no navegador.

### Kubernetes API

| Informação      | Valor                       |
| --------------- | --------------------------- |
| **URL Externa** | https://localhost:6443      |
| **URL Interna** | https://rancher-server:6443 |
| **Protocolo**   | HTTPS (TLS)                 |

### Bastion Host (Acesso SSH)

| Informação  | Valor                        |
| ----------- | ---------------------------- |
| **Host**    | localhost                    |
| **Porta**   | 2222                         |
| **Usuário** | `root`                       |
| **Senha**   | `P@ssw0rd123!`               |
| **Comando** | `ssh root@localhost -p 2222` |

### DNS Interno do Cluster

| Serviço                | Endereço                                  |
| ---------------------- | ----------------------------------------- |
| **CoreDNS**            | 10.43.0.10                                |
| **Domínio interno**    | `.cluster.local`                          |
| **Formato de serviço** | `<service>.<namespace>.svc.cluster.local` |

---

## 🔌 Métodos de Acesso

### Método 1: Via Rancher UI (Recomendado para Iniciantes)

1. Acesse https://localhost no navegador
2. Faça login com `admin` / `admin123456`
3. Selecione o cluster **local** no menu
4. Use o terminal integrado ou navegue pela interface

**Vantagens:**

- Interface visual intuitiva
- Não requer configuração local
- Acesso a logs, métricas e shell em pods

### Método 2: Via kubectl Direto no Rancher

Execute comandos kubectl diretamente no container do Rancher:

```bash
# Sintaxe básica
docker exec rancher-server kubectl <comando>

# Exemplos
docker exec rancher-server kubectl get nodes
docker exec rancher-server kubectl get pods -A
docker exec rancher-server kubectl get namespaces
```

### Método 3: Via Bastion Host (Acesso SSH)

```bash
# Conectar ao bastion
ssh root@localhost -p 2222
# Senha: P@ssw0rd123!

# Dentro do bastion, use kubectl normalmente
kubectl get nodes
kubectl get pods -A
```

### Método 4: Configurar kubectl Local

Para usar kubectl diretamente na sua máquina:

```bash
# Exportar kubeconfig do Rancher
docker exec rancher-server cat /etc/rancher/k3s/k3s.yaml > ~/.kube/config-local

# Ajustar o endereço do servidor
sed -i 's/127.0.0.1/localhost/g' ~/.kube/config-local

# Usar o kubeconfig
export KUBECONFIG=~/.kube/config-local
kubectl get nodes
```

---

## 📁 Trabalhando com Namespaces

### Conceito

Namespaces são partições virtuais do cluster que isolam recursos. Use namespaces para:

- Separar ambientes (dev, staging, prod)
- Isolar equipes ou projetos
- Aplicar quotas de recursos
- Definir políticas de rede

### Namespaces do Sistema (Não Modificar)

| Namespace             | Descrição                       |
| --------------------- | ------------------------------- |
| `kube-system`         | Componentes internos do K8s     |
| `cattle-system`       | Componentes do Rancher          |
| `cattle-fleet-system` | GitOps e gerenciamento de fleet |
| `default`             | Namespace padrão (evite usar)   |

### Criar Namespace

```bash
# Via kubectl
docker exec rancher-server kubectl create namespace minha-aplicacao

# Com arquivo YAML
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: minha-aplicacao
  labels:
    environment: development
    team: devops
EOF
```

### Via Rancher UI

1. Menu lateral → **Cluster** → **Projects/Namespaces**
2. Clique em **Create Namespace**
3. Preencha o nome e labels
4. Clique em **Create**

### Listar Namespaces

```bash
docker exec rancher-server kubectl get namespaces
```

### Definir Namespace Padrão

```bash
# Via kubectl
docker exec rancher-server kubectl config set-context --current --namespace=minha-aplicacao
```

### Excluir Namespace

```bash
# Cuidado: Remove TODOS os recursos dentro do namespace
docker exec rancher-server kubectl delete namespace minha-aplicacao
```

---

## 🚀 Instalando Aplicações

### Método 1: Deployment Básico

```bash
# Criar deployment com nginx
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "250m"
EOF
```

### Método 2: Via Imagem Direta

```bash
# Criar deployment rápido
docker exec rancher-server kubectl create deployment meu-app \
  --image=nginx:alpine \
  --replicas=2 \
  -n default

# Expor como serviço
docker exec rancher-server kubectl expose deployment meu-app \
  --port=80 \
  --type=NodePort \
  -n default
```

### Método 3: Via Rancher UI

1. Acesse **Workloads** → **Deployments**
2. Clique em **Create**
3. Configure:
   - Nome: `meu-app`
   - Namespace: selecione ou crie
   - Container Image: `nginx:alpine`
   - Portas: adicione as necessárias
4. Clique em **Create**

### Método 4: Via Helm Charts

```bash
# Adicionar repositório
docker exec rancher-server helm repo add bitnami https://charts.bitnami.com/bitnami
docker exec rancher-server helm repo update

# Instalar aplicação
docker exec rancher-server helm install meu-wordpress bitnami/wordpress \
  --namespace minha-aplicacao \
  --create-namespace
```

### Verificar Status da Aplicação

```bash
# Ver deployments
docker exec rancher-server kubectl get deployments -n default

# Ver pods
docker exec rancher-server kubectl get pods -n default

# Ver logs
docker exec rancher-server kubectl logs deployment/nginx-app -n default

# Descrever pod
docker exec rancher-server kubectl describe pod <nome-do-pod> -n default
```

---

## 🌐 Gerenciando Serviços

### Tipos de Serviços

| Tipo             | Descrição                          | Uso                             |
| ---------------- | ---------------------------------- | ------------------------------- |
| **ClusterIP**    | IP interno do cluster              | Comunicação entre pods          |
| **NodePort**     | Expõe em porta do nó (30000-32767) | Acesso externo simples          |
| **LoadBalancer** | Load balancer externo              | Produção (não disponível local) |

### Criar Serviço ClusterIP

```bash
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: meu-servico
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
EOF
```

### Criar Serviço NodePort

```bash
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: meu-servico-nodeport
  namespace: default
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
EOF
```

### Acessar Serviço NodePort

Após criar um serviço NodePort, acesse via:

- `http://localhost:30080` (porta definida em nodePort)

### Listar Serviços

```bash
# Todos os serviços
docker exec rancher-server kubectl get services -A

# Em um namespace específico
docker exec rancher-server kubectl get services -n default

# Com mais detalhes
docker exec rancher-server kubectl get services -n default -o wide
```

---

## 💾 Armazenamento Persistente

### PersistentVolumeClaim (PVC)

```bash
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: meu-storage
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
EOF
```

### Usar PVC em um Pod

```bash
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-com-storage
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-storage
  template:
    metadata:
      labels:
        app: app-storage
    spec:
      containers:
      - name: app
        image: nginx:alpine
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: meu-storage
EOF
```

### Verificar Storage

```bash
# Ver PVCs
docker exec rancher-server kubectl get pvc -n default

# Ver PVs
docker exec rancher-server kubectl get pv
```

---

## 🔒 ConfigMaps e Secrets

### Criar ConfigMap

```bash
# Via comando
docker exec rancher-server kubectl create configmap app-config \
  --from-literal=DATABASE_HOST=postgres \
  --from-literal=DATABASE_PORT=5432 \
  -n default

# Via YAML
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  DATABASE_HOST: "postgres"
  DATABASE_PORT: "5432"
  LOG_LEVEL: "info"
EOF
```

### Criar Secret

```bash
# Via comando
docker exec rancher-server kubectl create secret generic app-secrets \
  --from-literal=DATABASE_PASSWORD='senha-segura-123' \
  --from-literal=API_KEY='minha-chave-api' \
  -n default

# Via YAML (valores em base64)
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: default
type: Opaque
data:
  DATABASE_PASSWORD: c2VuaGEtc2VndXJhLTEyMw==
  API_KEY: bWluaGEtY2hhdmUtYXBp
EOF
```

### Usar ConfigMap e Secret em Pod

```bash
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-com-config
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-config
  template:
    metadata:
      labels:
        app: app-config
    spec:
      containers:
      - name: app
        image: nginx:alpine
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: app-secrets
EOF
```

---

## 🔗 Ingress e Exposição de Serviços

### Criar Ingress

O cluster usa o Traefik como Ingress Controller (incluído no K3s).

```bash
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: meu-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: meuapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: meu-servico
            port:
              number: 80
EOF
```

### Configurar /etc/hosts

Para acessar via hostname local:

```bash
# Adicionar ao /etc/hosts
echo "127.0.0.1 meuapp.local" | sudo tee -a /etc/hosts
```

---

## 📊 Monitoramento e Logs

### Ver Logs de um Pod

```bash
# Logs do pod
docker exec rancher-server kubectl logs <nome-pod> -n default

# Seguir logs em tempo real
docker exec rancher-server kubectl logs -f <nome-pod> -n default

# Logs de um container específico
docker exec rancher-server kubectl logs <nome-pod> -c <container> -n default

# Últimas 100 linhas
docker exec rancher-server kubectl logs --tail=100 <nome-pod> -n default
```

### Ver Eventos do Cluster

```bash
# Eventos recentes
docker exec rancher-server kubectl get events -n default --sort-by='.lastTimestamp'

# Eventos de todo o cluster
docker exec rancher-server kubectl get events -A
```

### Métricas de Recursos

```bash
# Uso de recursos dos nós
docker exec rancher-server kubectl top nodes

# Uso de recursos dos pods
docker exec rancher-server kubectl top pods -n default
```

### Via Rancher UI

1. Acesse **Workloads** → **Pods**
2. Clique nos **três pontos** do pod
3. Selecione **View Logs** ou **Execute Shell**

---

## 📝 Exemplos Práticos

### Exemplo 1: Deploy Completo de Aplicação Web

```bash
# Criar namespace
docker exec rancher-server kubectl create namespace web-app

# Deploy da aplicação
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: web-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: web-frontend-svc
  namespace: web-app
spec:
  type: NodePort
  selector:
    app: web-frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30081
EOF

# Verificar
docker exec rancher-server kubectl get all -n web-app

# Acessar: http://localhost:30081
```

### Exemplo 2: Aplicação com Banco de Dados

```bash
# Criar namespace
docker exec rancher-server kubectl create namespace db-app

# Deploy PostgreSQL
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secrets
  namespace: db-app
type: Opaque
data:
  POSTGRES_PASSWORD: cG9zdGdyZXMxMjM=
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: db-app
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: local-path
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: db-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "mydb"
        - name: POSTGRES_USER
          value: "admin"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-secrets
              key: POSTGRES_PASSWORD
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-svc
  namespace: db-app
spec:
  type: ClusterIP
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
EOF

# Verificar
docker exec rancher-server kubectl get all -n db-app
```

### Exemplo 3: CronJob para Tarefas Agendadas

```bash
cat <<EOF | docker exec -i rancher-server kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
  namespace: default
spec:
  schedule: "0 2 * * *"  # Executa às 2h da manhã
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: alpine:latest
            command: ["/bin/sh", "-c"]
            args:
            - |
              echo "Iniciando backup às $(date)"
              # Comandos de backup aqui
              echo "Backup concluído!"
          restartPolicy: OnFailure
EOF
```

---

## 📚 Referência Rápida de Comandos

### Comandos Essenciais

```bash
# Prefixo para todos os comandos
PREFIX="docker exec rancher-server kubectl"

# === CLUSTER ===
$PREFIX cluster-info                    # Informações do cluster
$PREFIX get nodes                       # Listar nós
$PREFIX get nodes -o wide               # Nós com mais detalhes

# === NAMESPACES ===
$PREFIX get namespaces                  # Listar namespaces
$PREFIX create namespace <nome>         # Criar namespace
$PREFIX delete namespace <nome>         # Deletar namespace

# === PODS ===
$PREFIX get pods -n <ns>               # Listar pods
$PREFIX get pods -A                     # Pods em todos os namespaces
$PREFIX describe pod <pod> -n <ns>     # Detalhes do pod
$PREFIX logs <pod> -n <ns>             # Logs do pod
$PREFIX logs -f <pod> -n <ns>          # Seguir logs
$PREFIX exec -it <pod> -n <ns> -- sh   # Shell no pod
$PREFIX delete pod <pod> -n <ns>       # Deletar pod

# === DEPLOYMENTS ===
$PREFIX get deployments -n <ns>        # Listar deployments
$PREFIX scale deployment/<nome> --replicas=3 -n <ns>  # Escalar
$PREFIX rollout restart deployment/<nome> -n <ns>      # Reiniciar
$PREFIX rollout status deployment/<nome> -n <ns>       # Status do rollout

# === SERVICES ===
$PREFIX get services -n <ns>           # Listar serviços
$PREFIX get svc -n <ns> -o wide        # Serviços com detalhes
$PREFIX delete svc <nome> -n <ns>      # Deletar serviço

# === CONFIGMAPS E SECRETS ===
$PREFIX get configmaps -n <ns>         # Listar ConfigMaps
$PREFIX get secrets -n <ns>            # Listar Secrets
$PREFIX describe configmap <nome> -n <ns>  # Ver ConfigMap
$PREFIX get secret <nome> -n <ns> -o yaml  # Ver Secret (base64)

# === STORAGE ===
$PREFIX get pvc -n <ns>                # Listar PVCs
$PREFIX get pv                          # Listar PVs

# === RECURSOS ===
$PREFIX get all -n <ns>                # Todos os recursos
$PREFIX api-resources                   # Listar tipos de recursos
$PREFIX explain <resource>              # Documentação do recurso
```

### Tabela de Portas

| Serviço        | Porta       | Protocolo | Descrição              |
| -------------- | ----------- | --------- | ---------------------- |
| Rancher UI     | 443         | HTTPS     | Interface web          |
| Rancher UI     | 80          | HTTP      | Redireciona para HTTPS |
| Kubernetes API | 6443        | HTTPS     | API do cluster         |
| SSH Bastion    | 2222        | SSH       | Acesso remoto          |
| NodePort Range | 30000-32767 | TCP/UDP   | Serviços externos      |

### Aliases Úteis (bash)

Adicione ao seu `~/.bashrc`:

```bash
# Alias para kubectl via docker
alias k='docker exec rancher-server kubectl'
alias kget='docker exec rancher-server kubectl get'
alias kdesc='docker exec rancher-server kubectl describe'
alias klogs='docker exec rancher-server kubectl logs'
alias kexec='docker exec -it rancher-server kubectl exec -it'

# Exemplos de uso:
# k get pods -A
# kget nodes
# klogs <pod-name> -n <namespace>
```

---

## ❓ Dúvidas Frequentes

### Como saber se meu pod está funcionando?

```bash
docker exec rancher-server kubectl get pods -n <namespace>
# STATUS deve ser "Running"
# READY deve mostrar todos os containers prontos (ex: 1/1)
```

### Meu pod está com erro. Como debugar?

```bash
# Ver eventos
docker exec rancher-server kubectl describe pod <pod-name> -n <ns>

# Ver logs
docker exec rancher-server kubectl logs <pod-name> -n <ns>

# Se o pod reinicia, ver logs do container anterior
docker exec rancher-server kubectl logs <pod-name> -n <ns> --previous
```

### Como acessar minha aplicação externamente?

1. **NodePort**: Exponha o serviço como NodePort e acesse via `localhost:<nodePort>`
2. **Ingress**: Configure um Ingress com hostname e adicione ao `/etc/hosts`
3. **Port-forward**: Use `kubectl port-forward` para acesso temporário

### Como limpar todos os recursos de um namespace?

```bash
# Deletar o namespace (remove tudo dentro)
docker exec rancher-server kubectl delete namespace <nome>
```

---

## 📞 Suporte

Para mais informações, consulte:

- [Documentação de Arquitetura](ARCHITECTURE.md)
- [Guia de Implantação](DEPLOYMENT-GUIDE.md)
- [Troubleshooting](TROUBLESHOOTING.md)
- [Bastion Host](BASTION.md)

---

> **Última atualização**: Novembro 2025  
> **Versão do Cluster**: K3s v1.33.1+k3s1 (master) / v1.34.1+k3s1 (workers)  
> **Rancher**: latest
