# Makefile para Kubernetes + Rancher Environment

.PHONY: help setup deploy start stop restart status clean destroy backup restore health logs

# Cores para output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Variáveis
DATA_DIR := /media/marcelo/dados
COMPOSE_FILE := docker-compose.yml

help: ## Exibe esta ajuda
	@echo -e "${BLUE}Kubernetes + Rancher DevOps Environment${NC}"
	@echo -e "${BLUE}=======================================${NC}"
	@echo ""
	@echo -e "${YELLOW}Comandos disponíveis:${NC}"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  ${GREEN}%-15s${NC} %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo -e "${YELLOW}Exemplos de uso:${NC}"
	@echo -e "  make setup     # Configuração inicial"
	@echo -e "  make deploy    # Deploy completo"
	@echo -e "  make status    # Verificar status"
	@echo -e "  make logs      # Ver logs"

setup: ## Executar configuração inicial do ambiente
	@echo -e "${BLUE}[SETUP]${NC} Executando configuração inicial..."
	@./scripts/setup.sh

deploy: ## Fazer deploy completo do ambiente
	@echo -e "${BLUE}[DEPLOY]${NC} Fazendo deploy do ambiente..."
	@./scripts/deploy.sh

start: deploy ## Iniciar o ambiente (alias para deploy)

stop: ## Parar o ambiente (mantém dados)
	@echo -e "${YELLOW}[STOP]${NC} Parando ambiente..."
	@./scripts/stop.sh

restart: ## Reiniciar o ambiente
	@echo -e "${BLUE}[RESTART]${NC} Reiniciando ambiente..."
	@docker compose restart
	@echo -e "${GREEN}[INFO]${NC} Ambiente reiniciado!"

status: ## Verificar status detalhado do ambiente
	@./scripts/status.sh

clean: ## Limpar recursos não utilizados
	@echo -e "${YELLOW}[CLEAN]${NC} Limpando recursos não utilizados..."
	@docker system prune -f
	@docker volume prune -f
	@echo -e "${GREEN}[INFO]${NC} Limpeza concluída!"

destroy: ## Destruir completamente o ambiente (REMOVE TODOS OS DADOS!)
	@echo -e "${RED}[DESTROY]${NC} Destruindo ambiente..."
	@./scripts/destroy.sh

backup: ## Criar backup completo do ambiente
	@echo -e "${BLUE}[BACKUP]${NC} Criando backup..."
	@./scripts/backup.sh

restore: ## Restaurar backup (uso: make restore TIMESTAMP=20240823_143022)
	@if [ -z "$(TIMESTAMP)" ]; then \
		echo -e "${RED}[ERROR]${NC} Especifique o timestamp: make restore TIMESTAMP=20240823_143022"; \
		echo -e "${YELLOW}Backups disponíveis:${NC}"; \
		ls -la $(DATA_DIR)/backups/ 2>/dev/null | grep k8s_rancher_backup || echo "Nenhum backup encontrado"; \
		exit 1; \
	fi
	@echo -e "${BLUE}[RESTORE]${NC} Restaurando backup $(TIMESTAMP)..."
	@./scripts/restore.sh $(TIMESTAMP)

health: ## Verificar saúde do ambiente
	@echo -e "${BLUE}[HEALTH]${NC} Verificando saúde do ambiente..."
	@echo -e "${YELLOW}Docker Status:${NC}"
	@docker info >/dev/null 2>&1 && echo -e "  ${GREEN}✓${NC} Docker OK" || echo -e "  ${RED}✗${NC} Docker com problemas"
	@echo -e "${YELLOW}Containers:${NC}"
	@docker compose ps -q | wc -l | xargs -I {} echo -e "  {} containers ativos"
	@echo -e "${YELLOW}Rancher:${NC}"
	@curl -k -s -o /dev/null -w "  Status: %{http_code}\n" https://localhost/ping 2>/dev/null || echo -e "  ${RED}✗${NC} Não disponível"
	@echo -e "${YELLOW}Kubernetes:${NC}"
	@kubectl get nodes --no-headers 2>/dev/null | wc -l | xargs -I {} echo -e "  {} nodes disponíveis" || echo -e "  ${RED}✗${NC} Não disponível"

logs: ## Exibir logs dos serviços
	@echo -e "${BLUE}[LOGS]${NC} Logs dos serviços (use Ctrl+C para sair)..."
	@docker compose logs -f

logs-rancher: ## Logs apenas do Rancher
	@echo -e "${BLUE}[LOGS]${NC} Logs do Rancher..."
	@docker compose logs -f rancher-server

logs-k8s: ## Logs do Kubernetes master
	@echo -e "${BLUE}[LOGS]${NC} Logs do Kubernetes master..."
	@docker compose logs -f k8s-master

logs-workers: ## Logs dos workers
	@echo -e "${BLUE}[LOGS]${NC} Logs dos workers..."
	@docker compose logs -f k8s-worker-1 k8s-worker-2 k8s-worker-3 k8s-worker-4

ps: ## Listar containers
	@docker compose ps

top: ## Mostrar uso de recursos dos containers
	@docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

shell-rancher: ## Acessar shell do Rancher
	@docker exec -it rancher-server /bin/bash

shell-master: ## Acessar shell do Kubernetes master
	@docker exec -it k8s-master /bin/sh

shell-worker: ## Acessar shell do worker 1 (uso: make shell-worker WORKER=2 para outros)
	$(eval WORKER_NUM := $(or $(WORKER),1))
	@docker exec -it k8s-worker-$(WORKER_NUM) /bin/sh

kubectl: ## Executar comando kubectl (uso: make kubectl CMD="get pods")
	@if [ -z "$(CMD)" ]; then \
		echo -e "${RED}[ERROR]${NC} Especifique o comando: make kubectl CMD=\"get pods\""; \
		exit 1; \
	fi
	@kubectl $(CMD)

nodes: ## Listar nodes do Kubernetes
	@kubectl get nodes -o wide

pods: ## Listar todos os pods
	@kubectl get pods -A -o wide

services: ## Listar todos os services
	@kubectl get svc -A

config: ## Mostrar configuração atual
	@echo -e "${BLUE}[CONFIG]${NC} Configuração atual:"
	@echo -e "${YELLOW}Data Directory:${NC} $(DATA_DIR)"
	@echo -e "${YELLOW}Compose File:${NC} $(COMPOSE_FILE)"
	@if [ -f .env ]; then \
		echo -e "${YELLOW}Environment:${NC}"; \
		cat .env | grep -v "^#" | sed 's/^/  /'; \
	else \
		echo -e "${RED}Arquivo .env não encontrado${NC}"; \
	fi

urls: ## Mostrar URLs de acesso
	@echo -e "${BLUE}[URLs]${NC} URLs de acesso:"
	@echo -e "${YELLOW}Rancher UI:${NC}     https://localhost"
	@echo -e "${YELLOW}Kubernetes API:${NC} https://localhost:6443"
	@echo -e "${YELLOW}Credenciais:${NC}    admin / admin123456"

update: ## Atualizar imagens Docker
	@echo -e "${BLUE}[UPDATE]${NC} Atualizando imagens..."
	@docker compose pull
	@echo -e "${GREEN}[INFO]${NC} Imagens atualizadas! Execute 'make restart' para aplicar"

version: ## Mostrar versões dos componentes
	@echo -e "${BLUE}[VERSION]${NC} Versões dos componentes:"
	@echo -e "${YELLOW}Docker:${NC}"
	@docker --version | sed 's/^/  /'
	@echo -e "${YELLOW}Docker Compose:${NC}"
	@docker compose version | sed 's/^/  /'
	@echo -e "${YELLOW}kubectl:${NC}"
	@kubectl version --client --short 2>/dev/null | sed 's/^/  /' || echo -e "  ${RED}não disponível${NC}"
	@echo -e "${YELLOW}Rancher:${NC}"
	@docker inspect rancher-server --format='  {{.Config.Image}}' 2>/dev/null || echo -e "  ${RED}não disponível${NC}"
	@echo -e "${YELLOW}Kubernetes:${NC}"
	@kubectl version --short 2>/dev/null | head -1 | sed 's/^/  /' || echo -e "  ${RED}não disponível${NC}"

# Comandos de conveniência
up: deploy  ## Alias para deploy
down: stop  ## Alias para stop
rm: destroy ## Alias para destroy (CUIDADO!)

# Validações
check-setup:
	@if [ ! -f .env ]; then \
		echo -e "${RED}[ERROR]${NC} Ambiente não configurado. Execute: make setup"; \
		exit 1; \
	fi

check-docker:
	@docker info >/dev/null 2>&1 || (echo -e "${RED}[ERROR]${NC} Docker não está rodando!" && exit 1)

# Targets que dependem de validações
deploy start restart status logs: check-setup check-docker
stop clean: check-docker

# Meta informação
.DEFAULT_GOAL := help
