# 🚀 Guia de Implantação de Aplicativos - DevOps & GitOps

## 📋 Índice

1. [Visão Geral](#visão-geral)
2. [Preparação do Ambiente](#preparação-do-ambiente)
3. [Métodos de Implantação](#métodos-de-implantação)
4. [Implantação via kubectl](#implantação-via-kubectl)
5. [Implantação via Rancher UI](#implantação-via-rancher-ui)
6. [Implantação via GitOps](#implantação-via-gitops)
7. [Implantação com Helm](#implantação-com-helm)
8. [CI/CD Pipelines](#cicd-pipelines)
9. [Estratégias de Deploy](#estratégias-de-deploy)
10. [Monitoramento e Logs](#monitoramento-e-logs)
11. [Troubleshooting](#troubleshooting)
12. [Melhores Práticas](#melhores-práticas)

---

## 🎯 Visão Geral

Este guia fornece orientações completas para que equipes de DevOps e GitOps realizem implantações de aplicativos na stack Kubernetes + Rancher simulada localmente.

### Características da Stack

- **Cluster Kubernetes**: 1 master + 4 workers (K3s v1.30.14+k3s2)
- **Gerenciamento**: Rancher Server (UI web)
- **Recursos**: 10GB RAM, 250GB storage distribuído
- **Rede**: Cluster CIDR `10.42.0.0/16`, Service CIDR `10.43.0.0/16`
- **Persistência**: Volumes externos em `/media/marcelo/dados`

### Casos de Uso

- ✅ Desenvolvimento e testes de aplicações
- ✅ Validação de manifests Kubernetes
- ✅ Testes de CI/CD pipelines
- ✅ Prototipação de arquiteturas
- ✅ Treinamento de equipes DevOps
- ✅ Simulação de ambientes de produção

---

## 🔧 Preparação do Ambiente

### 1. Verificar Status do Cluster

Antes de qualquer implantação, certifique-se de que o cluster está operacional:

```bash
# Verificar status completo
make status

# Ou usar o script diretamente
./scripts/status.sh

# Verificar nodes
kubectl get nodes

# Saída esperada:
# NAME           STATUS   ROLES                  AGE   VERSION
# k8s-master     Ready    control-plane,master   5m    v1.30.14+k3s2
# k8s-worker-1   Ready    <none>                 4m    v1.30.14+k3s2
# k8s-worker-2   Ready    <none>                 4m    v1.30.14+k3s2
# k8s-worker-3   Ready    <none>                 4m    v1.30.14+k3s2
# k8s-worker-4   Ready    <none>                 4m    v1.30.14+k3s2
```

### 2. Configurar kubectl

O `kubectl` é configurado automaticamente durante o deploy:

```bash
# Verificar configuração
kubectl config current-context

# Verificar conectividade
kubectl cluster-info

# Saída esperada:
# Kubernetes control plane is running at https://localhost:6443
# CoreDNS is running at https://localhost:6443/api/v1/namespaces/...
```

### 3. Acessar Rancher UI

```bash
# Abrir navegador em:
https://localhost

# Credenciais padrão:
# Usuário: admin
# Senha: admin123456 (ou verificar no .env)
```

### 4. Criar Namespace para seu Projeto

```bash
# Criar namespace via kubectl
kubectl create namespace meu-app

# Ou via Rancher UI:
# Projects/Namespaces → Create Namespace
```

---

## 📦 Métodos de Implantação

### Visão Geral dos Métodos

| Método | Complexidade | Controle | Recomendado Para |
|--------|--------------|----------|------------------|
| kubectl apply | Baixa | Alto | Deploys rápidos, testes |
| Rancher UI | Baixa | Médio | Usuários iniciantes, visualização |
| Helm Charts | Média | Alto | Aplicações complexas, reutilização |
| GitOps (ArgoCD/Flux) | Alta | Muito Alto | Produção, automação completa |
| CI/CD Pipeline | Alta | Muito Alto | Integração contínua |

---

## ⚙️ Implantação via kubectl

### 1. Deploy Simples de Aplicação

#### Exemplo: Aplicação Nginx

```bash
# Criar arquivo de deployment
cat > nginx-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  namespace: meu-app
  labels:
    app: nginx
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
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: meu-app
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
EOF

# Aplicar manifests
kubectl apply -f nginx-deployment.yaml

# Verificar deployment
kubectl get deployments -n meu-app
kubectl get pods -n meu-app
kubectl get services -n meu-app

# Testar aplicação
curl http://localhost:30080
```

### 2. Deploy com ConfigMap e Secrets

```bash
# Criar ConfigMap
kubectl create configmap app-config \
  --from-literal=APP_ENV=production \
  --from-literal=APP_DEBUG=false \
  -n meu-app

# Criar Secret
kubectl create secret generic app-secrets \
  --from-literal=DB_PASSWORD='senha-super-secreta' \
  --from-literal=API_KEY='chave-api-123' \
  -n meu-app

# Deployment usando ConfigMap e Secret
cat > app-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minha-app
  namespace: meu-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: minha-app
  template:
    metadata:
      labels:
        app: minha-app
    spec:
      containers:
      - name: app
        image: nginx:alpine
        env:
        - name: APP_ENV
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: APP_ENV
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DB_PASSWORD
        ports:
        - containerPort: 80
EOF

kubectl apply -f app-deployment.yaml
```

### 3. Deploy com Volumes Persistentes

```bash
cat > pvc-deployment.yaml << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-storage
  namespace: meu-app
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-storage
  namespace: meu-app
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
          claimName: app-storage
EOF

kubectl apply -f pvc-deployment.yaml
```

### 4. Comandos Úteis para Gerenciamento

```bash
# Listar recursos
kubectl get all -n meu-app
kubectl get pods -n meu-app -o wide
kubectl get deployments -n meu-app

# Escalar aplicação
kubectl scale deployment/nginx-app --replicas=5 -n meu-app

# Atualizar imagem
kubectl set image deployment/nginx-app nginx=nginx:1.26-alpine -n meu-app

# Rollback
kubectl rollout undo deployment/nginx-app -n meu-app

# Ver histórico
kubectl rollout history deployment/nginx-app -n meu-app

# Ver logs
kubectl logs -f deployment/nginx-app -n meu-app

# Executar comando em pod
kubectl exec -it <pod-name> -n meu-app -- /bin/sh

# Port-forward para testes
kubectl port-forward service/nginx-service 8080:80 -n meu-app

# Deletar recursos
kubectl delete -f nginx-deployment.yaml
kubectl delete namespace meu-app
```

---

## 🖥️ Implantação via Rancher UI

### 1. Acesso à Interface

1. Acesse: `https://localhost`
2. Login: `admin` / `admin123456`
3. Aceite termos e configure URL do servidor (se primeira vez)

### 2. Importar/Configurar Cluster Local

Se o cluster local não aparecer automaticamente:

1. **Menu**: `Cluster Management`
2. **Botão**: `Import Existing`
3. **Selecione**: `Generic`
4. **Nome**: `local-k3s`
5. **Execute** o comando fornecido no master:

```bash
docker exec k8s-master kubectl apply -f <rancher-import-url>
```

### 3. Deploy de Aplicação via UI

#### Método 1: Usando Workloads

1. **Selecione o cluster** → `local-k3s`
2. **Menu**: `Workloads` → `Deployments`
3. **Botão**: `Create`
4. **Preencha**:
   - **Name**: `nginx-app`
   - **Namespace**: `meu-app` (criar se necessário)
   - **Container Image**: `nginx:1.25-alpine`
   - **Replicas**: `3`
5. **Aba Ports**:
   - **Service Type**: `NodePort`
   - **Port**: `80`
   - **NodePort**: `30080`
6. **Aba Resources**:
   - **Memory Reservation**: `64Mi`
   - **Memory Limit**: `128Mi`
   - **CPU Reservation**: `100m`
   - **CPU Limit**: `200m`
7. **Criar**

#### Método 2: Usando YAML Editor

1. **Workloads** → `Deployments` → `Create from YAML`
2. **Cole o YAML** do seu deployment
3. **Create**

### 4. Configurar Service/Ingress

#### Service LoadBalancer:

1. **Menu**: `Service Discovery` → `Services`
2. **Create**:
   - **Name**: `nginx-lb`
   - **Namespace**: `meu-app`
   - **Type**: `Load Balancer`
   - **Selector**: `app=nginx`
   - **Port**: `80` → Target `80`

#### Ingress:

1. **Menu**: `Service Discovery` → `Ingresses`
2. **Create**:
   - **Name**: `nginx-ingress`
   - **Host**: `nginx.local`
   - **Path**: `/`
   - **Target Service**: `nginx-service:80`

### 5. Gerenciar ConfigMaps e Secrets via UI

#### ConfigMaps:

1. **Menu**: `More Resources` → `Core` → `ConfigMaps`
2. **Create**:
   - **Name**: `app-config`
   - **Key/Value**: Adicione pares chave-valor

#### Secrets:

1. **Menu**: `More Resources` → `Core` → `Secrets`
2. **Create**:
   - **Type**: `Opaque`
   - **Name**: `app-secrets`
   - **Data**: Adicione dados sensíveis

### 6. Monitoramento via Rancher

1. **Dashboard**: Visão geral de recursos
2. **Workloads**: Status de pods, deployments
3. **Pods**: Logs em tempo real, shell interativo
4. **Monitoring**: Gráficos de CPU/RAM (se habilitado)

---

## 🔄 Implantação via GitOps

### 1. Instalar ArgoCD

```bash
# Criar namespace
kubectl create namespace argocd

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar pods ficarem prontos
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Expor ArgoCD UI
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "nodePort": 30443}]}}'

# Obter senha inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Acessar UI
https://localhost:30443
# Usuário: admin
# Senha: <output do comando acima>
```

### 2. Estrutura GitOps Recomendada

```
meu-projeto/
├── apps/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── prod/
│       ├── kustomization.yaml
│       └── patches/
└── argocd/
    └── applications/
        ├── app-dev.yaml
        ├── app-staging.yaml
        └── app-prod.yaml
```

### 3. Exemplo de Aplicação ArgoCD

```bash
# Criar repositório Git (exemplo)
mkdir -p ~/gitops-apps/nginx-app/{base,dev,prod}

# Base deployment
cat > ~/gitops-apps/nginx-app/base/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
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
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
EOF

cat > ~/gitops-apps/nginx-app/base/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: NodePort
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30090
EOF

cat > ~/gitops-apps/nginx-app/base/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deployment.yaml
- service.yaml
EOF

# Dev overlay
cat > ~/gitops-apps/nginx-app/dev/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: dev
resources:
- ../base
replicas:
- name: nginx
  count: 1
EOF

# Prod overlay
cat > ~/gitops-apps/nginx-app/prod/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: prod
resources:
- ../base
replicas:
- name: nginx
  count: 3
EOF

# Inicializar Git
cd ~/gitops-apps
git init
git add .
git commit -m "Initial commit"

# Para ambiente local, você pode usar um repositório Git local
# ou fazer push para GitHub/GitLab
```

### 4. Criar Aplicação no ArgoCD

```bash
# Via CLI
kubectl apply -f - << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: file:///home/marcelo/gitops-apps  # Para repo local
    # repoURL: https://github.com/seu-usuario/gitops-apps  # Para repo remoto
    targetRevision: HEAD
    path: nginx-app/dev
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
EOF

# Verificar aplicação
kubectl get applications -n argocd

# Sincronizar manualmente (se automated sync estiver desabilitado)
# Via CLI do ArgoCD:
# argocd app sync nginx-dev
```

### 5. Workflow GitOps Completo

```bash
# 1. Desenvolvedor faz mudança no código
cd ~/gitops-apps/nginx-app/base
sed -i 's/nginx:1.25-alpine/nginx:1.26-alpine/' deployment.yaml

# 2. Commit e push
git add .
git commit -m "Update nginx to 1.26"
git push origin main

# 3. ArgoCD detecta mudança (se auto-sync habilitado)
# Ou sincronizar manualmente:
kubectl patch application nginx-dev -n argocd --type merge -p '{"operation": {"sync": {}}}'

# 4. Verificar status da aplicação
kubectl get application nginx-dev -n argocd -o jsonpath='{.status.sync.status}'

# 5. Ver mudanças aplicadas
kubectl get pods -n dev -w
```

### 6. Instalar Flux (Alternativa ao ArgoCD)

```bash
# Instalar Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Verificar pré-requisitos
flux check --pre

# Bootstrap Flux (exemplo para GitHub)
export GITHUB_TOKEN=<seu-token>
flux bootstrap github \
  --owner=<seu-usuario> \
  --repository=gitops-cluster \
  --branch=main \
  --path=./clusters/local-k3s \
  --personal

# Criar aplicação
flux create source git nginx-app \
  --url=https://github.com/<seu-usuario>/nginx-app \
  --branch=main \
  --interval=1m

flux create kustomization nginx-app \
  --source=nginx-app \
  --path="./dev" \
  --prune=true \
  --interval=5m
```

---

## 📊 Implantação com Helm

### 1. Instalar Helm

```bash
# Instalar Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verificar instalação
helm version
```

### 2. Adicionar Repositórios Helm

```bash
# Adicionar repositórios populares
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable
helm repo add jetstack https://charts.jetstack.io

# Atualizar repositórios
helm repo update

# Listar charts disponíveis
helm search repo bitnami
```

### 3. Deploy com Helm Chart Público

```bash
# Exemplo: WordPress
helm install my-wordpress bitnami/wordpress \
  --namespace wordpress \
  --create-namespace \
  --set wordpressUsername=admin \
  --set wordpressPassword=password123 \
  --set service.type=NodePort \
  --set service.nodePorts.http=30081

# Verificar status
helm status my-wordpress -n wordpress

# Listar releases
helm list -A

# Atualizar release
helm upgrade my-wordpress bitnami/wordpress \
  --namespace wordpress \
  --set replicaCount=2

# Rollback
helm rollback my-wordpress 1 -n wordpress

# Desinstalar
helm uninstall my-wordpress -n wordpress
```

### 4. Criar Helm Chart Customizado

```bash
# Criar estrutura do chart
helm create minha-app

# Estrutura criada:
# minha-app/
# ├── Chart.yaml
# ├── values.yaml
# ├── templates/
# │   ├── deployment.yaml
# │   ├── service.yaml
# │   ├── ingress.yaml
# │   └── ...
# └── charts/

# Editar values.yaml
cat > minha-app/values.yaml << 'EOF'
replicaCount: 2

image:
  repository: nginx
  tag: "1.25-alpine"
  pullPolicy: IfNotPresent

service:
  type: NodePort
  port: 80
  nodePort: 30082

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

env:
  - name: APP_ENV
    value: production
EOF

# Validar chart
helm lint minha-app/

# Fazer dry-run
helm install minha-app ./minha-app --dry-run --debug

# Instalar chart
helm install minha-app ./minha-app -n meu-app --create-namespace

# Template para ver YAML gerado
helm template minha-app ./minha-app > manifests.yaml
```

### 5. Empacotar e Compartilhar Charts

```bash
# Empacotar chart
helm package minha-app/

# Gerar index
helm repo index .

# Instalar de arquivo local
helm install my-release ./minha-app-0.1.0.tgz
```

---

## 🔁 CI/CD Pipelines

### 1. GitHub Actions - Exemplo Completo

```yaml
# .github/workflows/deploy.yml
name: Build and Deploy to K8s

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2

    - name: Log in to Container Registry
      uses: docker/login-action@v2
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v4
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=sha,prefix={{branch}}-
          type=semver,pattern={{version}}

    - name: Build and push Docker image
      uses: docker/build-push-action@v4
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'

    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Set up kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'latest'

    - name: Configure kubectl
      run: |
        mkdir -p ~/.kube
        echo "${{ secrets.KUBE_CONFIG }}" | base64 -d > ~/.kube/config
        chmod 600 ~/.kube/config

    - name: Update deployment image
      run: |
        kubectl set image deployment/minha-app \
          app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
          -n meu-app

    - name: Verify deployment
      run: |
        kubectl rollout status deployment/minha-app -n meu-app
        kubectl get pods -n meu-app

    - name: Run smoke tests
      run: |
        # Aguardar serviço estar disponível
        kubectl wait --for=condition=available --timeout=300s \
          deployment/minha-app -n meu-app
        
        # Executar testes básicos
        SERVICE_IP=$(kubectl get svc minha-app -n meu-app -o jsonpath='{.spec.clusterIP}')
        curl -f http://$SERVICE_IP || exit 1
```

### 2. GitLab CI/CD

```yaml
# .gitlab-ci.yml
stages:
  - build
  - test
  - deploy

variables:
  DOCKER_DRIVER: overlay2
  DOCKER_TLS_CERTDIR: "/certs"
  IMAGE_TAG: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $IMAGE_TAG .
    - docker push $IMAGE_TAG
  only:
    - main
    - develop

test:
  stage: test
  image: $IMAGE_TAG
  script:
    - echo "Running tests..."
    - npm test || true
  only:
    - main
    - develop

deploy:
  stage: deploy
  image: bitnami/kubectl:latest
  before_script:
    - mkdir -p ~/.kube
    - echo "$KUBE_CONFIG" | base64 -d > ~/.kube/config
    - chmod 600 ~/.kube/config
  script:
    - kubectl set image deployment/minha-app app=$IMAGE_TAG -n meu-app
    - kubectl rollout status deployment/minha-app -n meu-app
  environment:
    name: production
    url: https://minha-app.example.com
  only:
    - main
```

### 3. Jenkins Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'docker.io'
        IMAGE_NAME = 'meu-usuario/minha-app'
        KUBE_NAMESPACE = 'meu-app'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${BUILD_NUMBER}")
                }
            }
        }
        
        stage('Test') {
            steps {
                sh 'npm test || true'
            }
        }
        
        stage('Push') {
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", 'docker-credentials') {
                        docker.image("${IMAGE_NAME}:${BUILD_NUMBER}").push()
                        docker.image("${IMAGE_NAME}:${BUILD_NUMBER}").push('latest')
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                withKubeConfig([credentialsId: 'kube-config']) {
                    sh """
                        kubectl set image deployment/minha-app \
                            app=${IMAGE_NAME}:${BUILD_NUMBER} \
                            -n ${KUBE_NAMESPACE}
                        
                        kubectl rollout status deployment/minha-app \
                            -n ${KUBE_NAMESPACE}
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo 'Deploy realizado com sucesso!'
        }
        failure {
            echo 'Deploy falhou!'
        }
    }
}
```

### 4. Configurar Secrets para CI/CD

```bash
# Gerar kubeconfig para CI/CD (limitado ao namespace)
# 1. Criar ServiceAccount
kubectl create serviceaccount cicd-deployer -n meu-app

# 2. Criar Role
kubectl apply -f - << 'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deployer
  namespace: meu-app
rules:
- apiGroups: ["apps", ""]
  resources: ["deployments", "services", "pods", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

# 3. Criar RoleBinding
kubectl create rolebinding cicd-deployer \
  --role=cicd-deployer \
  --serviceaccount=meu-app:cicd-deployer \
  -n meu-app

# 4. Obter token
TOKEN=$(kubectl create token cicd-deployer -n meu-app --duration=8760h)

# 5. Criar kubeconfig para CI/CD
cat > cicd-kubeconfig.yaml << EOF
apiVersion: v1
kind: Config
clusters:
- name: local-k3s
  cluster:
    server: https://localhost:6443
    insecure-skip-tls-verify: true
users:
- name: cicd-deployer
  user:
    token: $TOKEN
contexts:
- name: cicd-context
  context:
    cluster: local-k3s
    user: cicd-deployer
    namespace: meu-app
current-context: cicd-context
EOF

# 6. Codificar em base64 para secrets
cat cicd-kubeconfig.yaml | base64 -w 0

# Use este output como secret KUBE_CONFIG no seu CI/CD
```

---

## 🎯 Estratégias de Deploy

### 1. Rolling Update (Padrão)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-app
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # Permite 1 pod extra durante update
      maxUnavailable: 1  # Permite 1 pod indisponível durante update
  selector:
    matchLabels:
      app: rolling-app
  template:
    metadata:
      labels:
        app: rolling-app
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

```bash
# Atualizar imagem
kubectl set image deployment/rolling-app app=nginx:1.26-alpine

# Monitorar rollout
kubectl rollout status deployment/rolling-app

# Pausar rollout
kubectl rollout pause deployment/rolling-app

# Retomar rollout
kubectl rollout resume deployment/rolling-app

# Rollback
kubectl rollout undo deployment/rolling-app
```

### 2. Blue-Green Deployment

```bash
# 1. Deploy versão Blue (atual)
cat > blue-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  type: NodePort
  selector:
    app: myapp
    version: blue  # Aponta para Blue
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30085
EOF

kubectl apply -f blue-deployment.yaml

# 2. Deploy versão Green (nova)
cat > green-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: nginx:1.26-alpine  # Nova versão
EOF

kubectl apply -f green-deployment.yaml

# 3. Testar Green
kubectl port-forward deployment/app-green 8080:80

# 4. Trocar tráfego para Green
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"green"}}}'

# 5. Rollback se necessário
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"blue"}}}'

# 6. Remover versão antiga após validação
kubectl delete deployment app-blue
```

### 3. Canary Deployment

```bash
# 1. Deployment estável (90% do tráfego)
cat > stable-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
spec:
  replicas: 9  # 90% das réplicas
  selector:
    matchLabels:
      app: myapp
      track: stable
  template:
    metadata:
      labels:
        app: myapp
        track: stable
    spec:
      containers:
      - name: app
        image: nginx:1.25-alpine
EOF

# 2. Deployment canary (10% do tráfego)
cat > canary-deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1  # 10% das réplicas
  selector:
    matchLabels:
      app: myapp
      track: canary
  template:
    metadata:
      labels:
        app: myapp
        track: canary
    spec:
      containers:
      - name: app
        image: nginx:1.26-alpine  # Nova versão
EOF

# 3. Service para ambos
cat > service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  type: NodePort
  selector:
    app: myapp  # Seleciona ambos stable e canary
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30086
EOF

kubectl apply -f stable-deployment.yaml
kubectl apply -f canary-deployment.yaml
kubectl apply -f service.yaml

# 4. Monitorar métricas e logs do canary
kubectl logs -f -l track=canary

# 5. Aumentar gradualmente tráfego canary
kubectl scale deployment app-canary --replicas=3  # 30%
kubectl scale deployment app-stable --replicas=7  # 70%

# 6. Promover canary para 100%
kubectl scale deployment app-canary --replicas=10
kubectl scale deployment app-stable --replicas=0
kubectl delete deployment app-stable
kubectl patch deployment app-canary --type='json' -p='[{"op": "remove", "path": "/spec/template/metadata/labels/track"}]'
```

### 4. A/B Testing

```bash
# Similar ao Canary, mas com roteamento baseado em headers/cookies
# Requer Ingress Controller com suporte (Nginx, Istio)

cat > ab-ingress.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ab-testing
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-by-header: "X-Version"
    nginx.ingress.kubernetes.io/canary-by-header-value: "beta"
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-beta
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: main-ingress
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-stable
            port:
              number: 80
EOF

# Testar versão beta:
# curl -H "X-Version: beta" http://myapp.local
```

---

## 📊 Monitoramento e Logs

### 1. Logs de Aplicações

```bash
# Ver logs de um pod
kubectl logs <pod-name> -n meu-app

# Seguir logs em tempo real
kubectl logs -f <pod-name> -n meu-app

# Logs de container específico (se múltiplos containers)
kubectl logs <pod-name> -c <container-name> -n meu-app

# Logs de todos os pods de um deployment
kubectl logs -f deployment/nginx-app -n meu-app

# Logs com timestamp
kubectl logs --timestamps <pod-name> -n meu-app

# Últimas 100 linhas
kubectl logs --tail=100 <pod-name> -n meu-app

# Logs de pod anterior (caso tenha reiniciado)
kubectl logs <pod-name> --previous -n meu-app

# Logs de múltiplos pods (com label selector)
kubectl logs -l app=nginx -n meu-app --all-containers=true
```

### 2. Monitoramento de Recursos

```bash
# Ver uso de recursos dos nodes
kubectl top nodes

# Ver uso de recursos dos pods
kubectl top pods -n meu-app

# Ver pods ordenados por CPU
kubectl top pods -n meu-app --sort-by=cpu

# Ver pods ordenados por memória
kubectl top pods -n meu-app --sort-by=memory

# Métricas de um pod específico
kubectl top pod <pod-name> -n meu-app
```

### 3. Eventos do Cluster

```bash
# Ver eventos de um namespace
kubectl get events -n meu-app --sort-by='.lastTimestamp'

# Ver eventos de um pod
kubectl describe pod <pod-name> -n meu-app

# Eventos em tempo real
kubectl get events -n meu-app --watch

# Filtrar eventos por tipo
kubectl get events -n meu-app --field-selector type=Warning
```

### 4. Health Checks e Probes

```yaml
# Exemplo de Liveness e Readiness Probes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-with-probes
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:alpine
        ports:
        - containerPort: 80
        
        # Liveness Probe - reinicia container se falhar
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        
        # Readiness Probe - remove de service se falhar
        readinessProbe:
          httpGet:
            path: /ready
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3
        
        # Startup Probe - para apps com inicialização lenta
        startupProbe:
          httpGet:
            path: /startup
            port: 80
          initialDelaySeconds: 0
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 30  # 30 * 10s = 5 minutos max
```

### 5. Instalar Stack de Monitoramento (Prometheus + Grafana)

```bash
# Adicionar repo Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Instalar Prometheus Stack
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=30090 \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=30091 \
  --set grafana.adminPassword=admin123

# Acessar Grafana
# URL: http://localhost:30091
# User: admin
# Password: admin123

# Acessar Prometheus
# URL: http://localhost:30090
```

### 6. Centralização de Logs com EFK Stack

```bash
# Instalar Elasticsearch
helm repo add elastic https://helm.elastic.co
helm install elasticsearch elastic/elasticsearch \
  --namespace logging \
  --create-namespace \
  --set replicas=1 \
  --set minimumMasterNodes=1

# Instalar Fluentd
kubectl apply -f https://raw.githubusercontent.com/fluent/fluentd-kubernetes-daemonset/master/fluentd-daemonset-elasticsearch.yaml

# Instalar Kibana
helm install kibana elastic/kibana \
  --namespace logging \
  --set service.type=NodePort \
  --set service.nodePort=30092

# Acessar Kibana
# URL: http://localhost:30092
```

---

## 🔧 Troubleshooting

### 1. Pod não inicia

```bash
# Verificar status do pod
kubectl get pod <pod-name> -n meu-app -o wide

# Ver detalhes e eventos
kubectl describe pod <pod-name> -n meu-app

# Verificar logs
kubectl logs <pod-name> -n meu-app

# Verificar logs do container anterior (se crashou)
kubectl logs <pod-name> --previous -n meu-app

# Problemas comuns:
# - ImagePullBackOff: Imagem não existe ou problemas de autenticação
# - CrashLoopBackOff: Aplicação está crashando
# - Pending: Recursos insuficientes ou problemas de scheduling
```

### 2. Service não acessível

```bash
# Verificar service
kubectl get svc -n meu-app
kubectl describe svc <service-name> -n meu-app

# Verificar endpoints
kubectl get endpoints <service-name> -n meu-app

# Testar de dentro do cluster
kubectl run test-pod --rm -it --image=busybox -- sh
/ # wget -O- http://<service-name>.<namespace>.svc.cluster.local

# Verificar labels dos pods
kubectl get pods -n meu-app --show-labels

# Verificar se labels do service correspondem aos pods
kubectl get svc <service-name> -n meu-app -o yaml | grep selector -A 5
```

### 3. Problemas de recursos

```bash
# Verificar recursos disponíveis nos nodes
kubectl describe nodes

# Verificar pods que não conseguem ser agendados
kubectl get pods -A | grep Pending

# Ver eventos de scheduling
kubectl get events --sort-by='.lastTimestamp' | grep -i "fail\|error"

# Ajustar resource requests/limits
kubectl set resources deployment/<name> \
  -c=<container> \
  --limits=cpu=200m,memory=512Mi \
  --requests=cpu=100m,memory=256Mi \
  -n meu-app
```

### 4. Problemas de rede

```bash
# Testar conectividade DNS
kubectl run test-dns --rm -it --image=busybox -- nslookup kubernetes.default

# Testar conectividade entre pods
kubectl exec -it <pod-name> -n meu-app -- ping <outro-pod-ip>

# Verificar NetworkPolicies
kubectl get networkpolicies -A

# Verificar regras de firewall do cluster
# (No K3s, verificar iptables nos nodes)
docker exec k8s-master iptables -L -n -v
```

### 5. Problemas de volumes

```bash
# Verificar PVCs
kubectl get pvc -n meu-app

# Ver detalhes do PVC
kubectl describe pvc <pvc-name> -n meu-app

# Verificar PVs
kubectl get pv

# Ver eventos relacionados a volumes
kubectl get events -n meu-app | grep -i volume

# Verificar permissões de montagem
kubectl exec -it <pod-name> -n meu-app -- ls -la /caminho/do/volume
```

### 6. Debug interativo

```bash
# Acessar shell do container
kubectl exec -it <pod-name> -n meu-app -- /bin/sh

# Executar comandos sem acessar shell
kubectl exec <pod-name> -n meu-app -- env
kubectl exec <pod-name> -n meu-app -- ps aux
kubectl exec <pod-name> -n meu-app -- df -h

# Copiar arquivos do pod
kubectl cp <pod-name>:/caminho/arquivo ./arquivo-local -n meu-app

# Copiar arquivos para o pod
kubectl cp ./arquivo-local <pod-name>:/caminho/arquivo -n meu-app

# Debug pod com imagem de debug
kubectl debug <pod-name> -it --image=busybox -n meu-app
```

---

## ✅ Melhores Práticas

### 1. Organização de Manifests

```
projeto/
├── base/                    # Configurações base
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── overlays/                # Overlays por ambiente
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── prod/
│       ├── kustomization.yaml
│       └── patches/
└── helm/                    # Helm charts (se usar)
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

### 2. Nomenclatura e Labels

```yaml
# Seguir convenções padrão
metadata:
  name: nginx-app
  labels:
    app.kubernetes.io/name: nginx
    app.kubernetes.io/instance: nginx-prod
    app.kubernetes.io/version: "1.25"
    app.kubernetes.io/component: webserver
    app.kubernetes.io/part-of: ecommerce
    app.kubernetes.io/managed-by: helm
    environment: production
    team: backend
```

### 3. Resource Limits e Requests

```yaml
# Sempre definir requests e limits
resources:
  requests:
    cpu: 100m      # Mínimo necessário
    memory: 128Mi
  limits:
    cpu: 500m      # Máximo permitido
    memory: 512Mi
```

### 4. Segurança

```yaml
# SecurityContext
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL

# Não usar :latest
image: nginx:1.25.3-alpine  # Versão específica

# Usar Secrets para dados sensíveis
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secrets
      key: password
```

### 5. Health Checks

```yaml
# Sempre definir probes apropriadas
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 6. ConfigMaps e Secrets

```bash
# Separar configuração do código
# ConfigMap para configs não-sensíveis
kubectl create configmap app-config \
  --from-file=config.json \
  --from-literal=LOG_LEVEL=info

# Secret para dados sensíveis
kubectl create secret generic app-secrets \
  --from-literal=API_KEY=xyz123 \
  --from-file=tls.crt \
  --from-file=tls.key

# Usar como volume ao invés de env vars (mais seguro)
volumes:
- name: config
  configMap:
    name: app-config
- name: secrets
  secret:
    secretName: app-secrets
```

### 7. Backup e Disaster Recovery

```bash
# Fazer backup regular
make backup

# Ou usar script diretamente
./scripts/backup.sh

# Versionar manifests no Git
git add k8s/
git commit -m "Update deployment config"
git push

# Exportar recursos críticos
kubectl get all -n meu-app -o yaml > backup-namespace.yaml
```

### 8. Monitoramento e Alertas

```yaml
# Adicionar anotações para Prometheus
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"
```

### 9. Rolling Updates Seguros

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0  # Zero downtime
minReadySeconds: 10    # Aguardar estabilização
```

### 10. Namespaces e RBAC

```bash
# Isolar ambientes em namespaces
kubectl create namespace prod
kubectl create namespace staging
kubectl create namespace dev

# Configurar RBAC apropriado
# Criar role
kubectl create role developer \
  --verb=get,list,watch,create,update,patch,delete \
  --resource=pods,deployments,services \
  -n dev

# Criar rolebinding
kubectl create rolebinding dev-team \
  --role=developer \
  --user=joao@empresa.com \
  -n dev
```

---

## 📚 Referências e Recursos

### Documentação Oficial

- **Kubernetes**: https://kubernetes.io/docs/
- **K3s**: https://docs.k3s.io/
- **Rancher**: https://rancher.com/docs/
- **Helm**: https://helm.sh/docs/
- **ArgoCD**: https://argo-cd.readthedocs.io/
- **Flux**: https://fluxcd.io/docs/

### Comandos Úteis do Projeto

```bash
# Deploy completo
make deploy

# Verificar status
make status

# Ver logs
make logs

# Backup
make backup

# Parar ambiente
make stop

# Ajuda completa
make help
```

### Estrutura de Diretórios

```
/media/marcelo/dados/
├── rancher-data/      # Dados do Rancher
├── k8s-master/        # Dados do master
├── k8s-worker-[1-4]/  # Dados dos workers
├── k8s-config/        # kubeconfig
└── backups/           # Backups automatizados
```

### Acesso Rápido

- **Rancher UI**: https://localhost
- **Kubernetes API**: https://localhost:6443
- **Kubeconfig**: `~/.kube/config`
- **Scripts**: `./scripts/*.sh`
- **Documentação**: `./docs/*.md`

---

## 🎓 Próximos Passos

Após dominar este guia:

1. **Explore Helm Charts** mais complexos
2. **Implemente GitOps** completo com ArgoCD/Flux
3. **Configure Service Mesh** (Istio/Linkerd)
4. **Adicione Observabilidade** avançada
5. **Implemente políticas** com OPA/Kyverno
6. **Teste disaster recovery** com backups
7. **Experimente com diferentes estratégias** de deploy

---

## 📞 Suporte

- Consulte `TROUBLESHOOTING.md` para problemas comuns
- Veja `ARCHITECTURE.md` para entender a arquitetura
- Use `make help` para lista completa de comandos

**Boas implantações! 🚀**
