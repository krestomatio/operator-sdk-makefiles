##@ Kio Web App API


KUSTOMIZE_DIR ?= .config/
KIND_CLUSTER_NAME ?= kio-web-app
KIND_NAMESPACE ?= local-kio-web-app-system
KIO_WEB_APP_ENV ?= local
ifeq ($(KIO_WEB_APP_ENV),local)
KIO_WEB_APP_KUBECONFIG_NAME ?= kubeconfig__dev__kio-web-app
else
KIO_WEB_APP_KUBECONFIG_NAME ?= kubeconfig__$(KIO_WEB_APP_ENV)__kio-web-app
endif

install: kustomize skaffold kubectl kind kind-create kind-context kubeconfig-download-if dot-env-download-if

deploy: ## Deploy to the K8s cluster specified in ~/.kube/config.
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(KUSTOMIZE) build $(KUSTOMIZE_DIR)/$(KIO_WEB_APP_ENV) | kubectl apply -f -

undeploy: ## Undeploy  from the K8s cluster specified in ~/.kube/config.
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(KUSTOMIZE) build $(KUSTOMIZE_DIR)/$(KIO_WEB_APP_ENV) | kubectl delete --ignore-not-found=true -f -

kind-create: ## Create kind clusters
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	@$(KIND) get clusters 2>/dev/null | grep -q $(KIND_CLUSTER_NAME) || \
	{ $(KIND) create cluster --name $(KIND_CLUSTER_NAME) --image=kindest/node:v$(KIND_IMAGE_VERSION); }

kind-delete: ## Delete kind clusters
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(KIND) delete cluster --name $(KIND_CLUSTER_NAME)

kind-context: ## Use kind cluster by setting its context
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(KUBECTL) config use-context kind-$(KIND_CLUSTER_NAME)
	$(KUBECTL) config set-context --current --namespace=$(KIND_NAMESPACE)

kind-pause: ## Pause kind cluster container
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(KIND) get nodes --name $(KIND_CLUSTER_NAME) | xargs docker pause

kind-unpause: ## Unpause kind cluster container
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(KIND) get nodes --name $(KIND_CLUSTER_NAME) | xargs docker unpause

local-deploy-base: kubeconfig-download-if ## Deploy base manifests for local env
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	@echo "# deploying base..."
	cp -pf ~/.kube/$(KIO_WEB_APP_KUBECONFIG_NAME) $(KUSTOMIZE_DIR)/$(KIO_WEB_APP_ENV)/base/$(KIO_WEB_APP_KUBECONFIG_NAME)
	$(KUSTOMIZE) build $(KUSTOMIZE_DIR)/local/base | kubectl apply -f -
	rm $(KUSTOMIZE_DIR)/$(KIO_WEB_APP_ENV)/base/$(KIO_WEB_APP_KUBECONFIG_NAME)

local-deploy-db: local-deploy-base ## Deploy db manifests for local env
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	@echo "# deploying db, it could take some seconds..."
	$(KUSTOMIZE) build $(KUSTOMIZE_DIR)/local/db --load-restrictor LoadRestrictionsNone | kubectl apply -f -
	$(KUBECTL) -n $(KIND_NAMESPACE) wait --for=condition=Available --timeout=90s deploy postgres-deploy

local-undeploy-base: local-undeploy-db ## Delete base manifests for local env
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(KUSTOMIZE) build $(KUSTOMIZE_DIR)/local/base | kubectl delete --ignore-not-found=true -f -

local-undeploy-db: ## Delete db manifests for local env
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(KUSTOMIZE) build $(KUSTOMIZE_DIR)/local/db --load-restrictor LoadRestrictionsNone | kubectl delete --ignore-not-found=true -f -

local-purge: local-undeploy-base kind-delete ## Purge local env: base (ns, db, pvc), k8s objects and local cluster

local-dev: install ## Run local dev
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	@[ -f .env ] || { echo "${RED}# .env file does not exist${RESET}"; exit 1; }
ifeq (n,$(findstring n,$(firstword -$(MAKEFLAGS))))
	@$(SKAFFOLD) dev
else
	@bash -c "trap '$(MAKE) local-undeploy-db' EXIT; $(SKAFFOLD) dev"
endif

local-db: install ## Run local db only
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	@[ -f .env ] || { echo "${RED}# .env file does not exist${RESET}"; exit 1; }
ifeq (n,$(findstring n,$(firstword -$(MAKEFLAGS))))
	$(SKAFFOLD) dev -p db-only
else
	bash -c "trap '$(MAKE) local-undeploy-db' EXIT; $(SKAFFOLD) dev -p db-only"
endif

## Download files
kubeconfig-download-if: vault ## download kubeconfig file for kio web app role, but only if it does not exist on disk
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
ifeq (,$(wildcard ~/.kube/$(KIO_WEB_APP_KUBECONFIG_NAME)))
	vault kv get -field $(KIO_WEB_APP_KUBECONFIG_NAME) kio_secrets/kio-web-app > ~/.kube/$(KIO_WEB_APP_KUBECONFIG_NAME)
endif

kubeconfig-download: vault ## download and overwrite kubeconfig file for kio web app role
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	$(info $(VAULT_ADDR))
	vault kv get -field $(KIO_WEB_APP_KUBECONFIG_NAME) kio_secrets/kio-web-app > ~/.kube/$(KIO_WEB_APP_KUBECONFIG_NAME)

dot-env-download-if: vault ## download and overwrite .env file for kio web app api, but only if it does not exist on disk
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
ifeq (,$(wildcard .env))
	vault kv get -field kio-api-env kio_secrets/kio-web-app > .env
endif

dot-env-download: vault ## download and overwrite .env file for kio web app api
	@echo -e "${LIGHTPURPLE}+ make target: $@${RESET}"
	vault kv get -field kio-api-env kio_secrets/kio-web-app > .env
