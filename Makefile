# Makefile

.PHONY: help install-argocd uninstall-argocd deploy-project deploy-apps deploy-dev deploy-staging deploy-prod \
        destroy-all destroy-apps destroy-project status port-forward-argocd port-forward-api \
        get-argocd-password sync-dev sync-staging sync-prod logs-dev logs-staging logs-prod

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

# Default namespace
ARGOCD_NS := argocd

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2}'

# =============================================================================
# ArgoCD Installation
# =============================================================================

install-argocd: ## Install ArgoCDmak on the cluster
	@echo "$(GREEN)Installing ArgoCD...$(NC)"
	kubectl create namespace $(ARGOCD_NS) --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n $(ARGOCD_NS) -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "$(YELLOW)Waiting for ArgoCD pods to be ready...$(NC)"
	kubectl wait --for=condition=Ready pods --all -n $(ARGOCD_NS) --timeout=300s
	@echo "$(GREEN)ArgoCD installed successfully!$(NC)"
	@make get-argocd-password

uninstall-argocd: ## Uninstall ArgoCD from the cluster
	@echo "$(RED)Uninstalling ArgoCD...$(NC)"
	kubectl delete -n $(ARGOCD_NS) -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --ignore-not-found
	kubectl delete namespace $(ARGOCD_NS) --ignore-not-found
	@echo "$(GREEN)ArgoCD uninstalled successfully!$(NC)"

get-argocd-password: ## Get ArgoCD admin password
	@echo "$(GREEN)ArgoCD Admin Password:$(NC)"
	@kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo ""

# =============================================================================
# Deploy Infrastructure
# =============================================================================

deploy-all: deploy-project deploy-apps ## Deploy everything (project + all apps)
	@echo "$(GREEN)All resources deployed!$(NC)"

deploy-project: ## Deploy ArgoCD Project
	@echo "$(GREEN)Deploying ArgoCD Project...$(NC)"
	kubectl apply -f argocd/project.yaml
	@echo "$(GREEN)Project deployed!$(NC)"

deploy-apps: deploy-dev deploy-staging deploy-prod ## Deploy all environment applications
	@echo "$(GREEN)All applications deployed!$(NC)"

deploy-dev: ## Deploy dev environment
	@echo "$(GREEN)Deploying dev environment...$(NC)"
	kubectl apply -f argocd/applications/dev.yaml
	@echo "$(GREEN)Dev environment deployed!$(NC)"

deploy-staging: ## Deploy staging environment
	@echo "$(GREEN)Deploying staging environment...$(NC)"
	kubectl apply -f argocd/applications/staging.yaml
	@echo "$(GREEN)Staging environment deployed!$(NC)"

deploy-prod: ## Deploy prod environment
	@echo "$(GREEN)Deploying prod environment...$(NC)"
	kubectl apply -f argocd/applications/prod.yaml
	@echo "$(GREEN)Prod environment deployed!$(NC)"

# =============================================================================
# Destroy Infrastructure
# =============================================================================

destroy-all: destroy-apps destroy-project destroy-namespaces ## Destroy everything (apps + project + namespaces)
	@echo "$(GREEN)All resources destroyed!$(NC)"

destroy-apps: ## Destroy all ArgoCD applications
	@echo "$(RED)Destroying all applications...$(NC)"
	kubectl delete -f argocd/applications/ --ignore-not-found
	@echo "$(GREEN)Applications destroyed!$(NC)"

destroy-project: ## Destroy ArgoCD project
	@echo "$(RED)Destroying ArgoCD project...$(NC)"
	kubectl delete -f argocd/project.yaml --ignore-not-found
	@echo "$(GREEN)Project destroyed!$(NC)"

destroy-namespaces: ## Destroy application namespaces
	@echo "$(RED)Destroying namespaces...$(NC)"
	kubectl delete namespace simpleapp-dev --ignore-not-found
	kubectl delete namespace simpleapp-staging --ignore-not-found
	kubectl delete namespace simpleapp-prod --ignore-not-found
	@echo "$(GREEN)Namespaces destroyed!$(NC)"

destroy-dev: ## Destroy dev environment only
	@echo "$(RED)Destroying dev environment...$(NC)"
	kubectl delete -f argocd/applications/dev.yaml --ignore-not-found
	kubectl delete namespace simpleapp-dev --ignore-not-found
	@echo "$(GREEN)Dev environment destroyed!$(NC)"

destroy-staging: ## Destroy staging environment only
	@echo "$(RED)Destroying staging environment...$(NC)"
	kubectl delete -f argocd/applications/staging.yaml --ignore-not-found
	kubectl delete namespace simpleapp-staging --ignore-not-found
	@echo "$(GREEN)Staging environment destroyed!$(NC)"

destroy-prod: ## Destroy prod environment only
	@echo "$(RED)Destroying prod environment...$(NC)"
	kubectl delete -f argocd/applications/prod.yaml --ignore-not-found
	kubectl delete namespace simpleapp-prod --ignore-not-found
	@echo "$(GREEN)Prod environment destroyed!$(NC)"

# =============================================================================
# Nuke Everything (Full Reset)
# =============================================================================

nuke: ## DANGER: Destroy everything including ArgoCD
	@echo "$(RED)WARNING: This will destroy EVERYTHING!$(NC)"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@make destroy-all
	@make uninstall-argocd
	@echo "$(GREEN)Everything has been nuked!$(NC)"

# =============================================================================
# Sync Applications
# =============================================================================

sync-all: sync-dev sync-staging sync-prod ## Sync all environments
	@echo "$(GREEN)All environments synced!$(NC)"

sync-dev: ## Sync dev environment
	@echo "$(GREEN)Syncing dev...$(NC)"
	argocd app sync simpleapp-api-dev --prune

sync-staging: ## Sync staging environment
	@echo "$(GREEN)Syncing staging...$(NC)"
	argocd app sync simpleapp-api-staging --prune

sync-prod: ## Sync prod environment
	@echo "$(GREEN)Syncing prod...$(NC)"
	argocd app sync simpleapp-api-prod --prune

# =============================================================================
# Status & Monitoring
# =============================================================================

status: ## Show status of all resources
	@echo "$(GREEN)=== ArgoCD Applications ===$(NC)"
	@argocd app list 2>/dev/null || kubectl get applications -n $(ARGOCD_NS)
	@echo ""
	@echo "$(GREEN)=== Dev Pods ===$(NC)"
	@kubectl get pods -n simpleapp-dev 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "$(GREEN)=== Staging Pods ===$(NC)"
	@kubectl get pods -n simpleapp-staging 2>/dev/null || echo "Namespace not found"
	@echo ""
	@echo "$(GREEN)=== Prod Pods ===$(NC)"
	@kubectl get pods -n simpleapp-prod 2>/dev/null || echo "Namespace not found"

status-argocd: ## Show ArgoCD status
	@echo "$(GREEN)=== ArgoCD Pods ===$(NC)"
	@kubectl get pods -n $(ARGOCD_NS)
	@echo ""
	@echo "$(GREEN)=== ArgoCD Services ===$(NC)"
	@kubectl get svc -n $(ARGOCD_NS)

# =============================================================================
# Port Forwarding
# =============================================================================

port-forward-argocd: ## Port forward ArgoCD UI (https://localhost:8080)
	@echo "$(GREEN)ArgoCD UI available at: https://localhost:8080$(NC)"
	@echo "Username: admin"
	@echo "Password: $$(kubectl -n $(ARGOCD_NS) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
	kubectl port-forward svc/argocd-server -n $(ARGOCD_NS) 8080:443

port-forward-dev: ## Port forward dev API (http://localhost:8081)
	@echo "$(GREEN)Dev API available at: http://localhost:8081$(NC)"
	kubectl port-forward svc/simpleapp-api -n simpleapp-dev 8081:80

port-forward-staging: ## Port forward staging API (http://localhost:8082)
	@echo "$(GREEN)Staging API available at: http://localhost:8082$(NC)"
	kubectl port-forward svc/simpleapp-api -n simpleapp-staging 8082:80

port-forward-prod: ## Port forward prod API (http://localhost:8083)
	@echo "$(GREEN)Prod API available at: http://localhost:8083$(NC)"
	kubectl port-forward svc/simpleapp-api -n simpleapp-prod 8083:80

# =============================================================================
# Logs
# =============================================================================

logs-dev: ## Show dev API logs
	kubectl logs -n simpleapp-dev -l app=simpleapp-api -f --tail=100

logs-staging: ## Show staging API logs
	kubectl logs -n simpleapp-staging -l app=simpleapp-api -f --tail=100

logs-prod: ## Show prod API logs
	kubectl logs -n simpleapp-prod -l app=simpleapp-api -f --tail=100

logs-postgres-dev: ## Show dev PostgreSQL logs
	kubectl logs -n simpleapp-dev -l app=postgres -f --tail=100

# =============================================================================
# Kustomize Validation
# =============================================================================

validate: validate-dev validate-staging validate-prod ## Validate all kustomize overlays
	@echo "$(GREEN)All overlays validated!$(NC)"

validate-dev: ## Validate dev overlay
	@echo "$(GREEN)Validating dev overlay...$(NC)"
	kustomize build k8s/overlays/dev | kubectl apply --dry-run=client -f -
	@echo "$(GREEN)Dev overlay is valid!$(NC)"

validate-staging: ## Validate staging overlay
	@echo "$(GREEN)Validating staging overlay...$(NC)"
	kustomize build k8s/overlays/staging | kubectl apply --dry-run=client -f -
	@echo "$(GREEN)Staging overlay is valid!$(NC)"

validate-prod: ## Validate prod overlay
	@echo "$(GREEN)Validating prod overlay...$(NC)"
	kustomize build k8s/overlays/prod | kubectl apply --dry-run=client -f -
	@echo "$(GREEN)Prod overlay is valid!$(NC)"

# =============================================================================
# Quick Setup
# =============================================================================

setup: install-argocd deploy-all ## Full setup: Install ArgoCD and deploy everything
	@echo "$(GREEN)Setup complete!$(NC)"
	@echo ""
	@echo "Run 'make port-forward-argocd' to access ArgoCD UI"
	@echo "Run 'make status' to check deployment status"

teardown: destroy-all ## Teardown: Destroy all apps and namespaces (keeps ArgoCD)
	@echo "$(GREEN)Teardown complete!$(NC)"
