##@ Testing deploy

testing-deploy: testing-image testing-deploy-prepare testing-deploy-apply-safe testing-deploy-samples ## Test deployment using kustomize

testing-deploy-prepare: IMG = $(BUILD_IMAGE_TAG_BASE):$(BUILD_VERSION)
testing-deploy-prepare:
	@echo "+ $@"
	cd config/testing; \
	kustomize edit set image testing=${OPERATOR_IMAGE}; \
	kustomize edit set namespace ${TEST_OPERATOR_NAMESPACE}; \
	kustomize edit set nameprefix ${TEST_OPERATOR_NAMEPREFIX}
	cd config/testing/m4e; \
	kustomize edit set namespace ${TEST_OPERATOR_NAMESPACE}; \
	kustomize edit set nameprefix ${TEST_OPERATOR_NAMEPREFIX}
	cd config/testing/nfs; \
	kustomize edit set namespace ${TEST_OPERATOR_NAMESPACE}; \
	kustomize edit set nameprefix ${TEST_OPERATOR_NAMEPREFIX}
	cd config/testing/rook-nfs/operator; \
	kustomize edit set namespace ${TEST_OPERATOR_NAMESPACE}
	cd config/testing/rook-nfs/server; \
	kustomize edit set namespace ${TEST_OPERATOR_NAMESPACE}

testing-deploy-apply-safe:
	@echo "+ $@"
	@$(MAKE) testing-deploy-apply || { $(MAKE) testing-undeploy; exit 2; }

testing-deploy-apply:
	@echo "+ $@"
	kustomize build config/testing/rook-nfs/operator | kubectl apply -f -
	kustomize build config/testing/rook-nfs/server | kubectl apply -f -
	kustomize build config/testing/nfs | kubectl apply -f -
	kustomize build config/testing/m4e | kubectl apply -f -
	kustomize build --load-restrictor LoadRestrictionsNone config/testing | kubectl apply -f -

testing-deploy-samples:
	@echo "+ $@"
	kustomize build config/samples | kubectl apply -f -
	kubectl wait --for=condition=ready --timeout=600s Site site-sample

testing-undeploy: testing-undeploy-samples testing-undeploy-delete testing-undeploy-restore ## Test undeployment using kustomize

testing-undeploy-samples:
	@echo "+ $@"
	kustomize build config/samples | kubectl delete --timeout=600s --wait=true --cascade=foreground -f - || echo

testing-undeploy-delete:
	@echo "+ $@"
	kustomize build --load-restrictor LoadRestrictionsNone config/testing | kubectl delete -f - || echo
	kustomize build config/testing/nfs | kubectl delete -f - || echo
	kustomize build config/testing/m4e | kubectl delete -f - || echo
	kustomize build config/testing/rook-nfs/server | kubectl delete -f - || echo
	kustomize build config/testing/rook-nfs/operator | kubectl delete -f - || echo

testing-undeploy-restore:
	@echo "+ $@"
	cd config/testing; \
	kustomize edit set image testing=testing-operator; \
	kustomize edit set namespace kio-test; \
	kustomize edit set nameprefix kio-
	cd config/testing/m4e; \
	kustomize edit set namespace kio-test; \
	kustomize edit set nameprefix kio-
	cd config/testing/nfs; \
	kustomize edit set namespace kio-test; \
	kustomize edit set nameprefix kio-
	cd config/testing/rook-nfs/operator; \
	kustomize edit set namespace kio-test
	cd config/testing/rook-nfs/server; \
	kustomize edit set namespace kio-test

##@ Dependant operators

deploy-operators: ## Deploy kio operator and dependant operators to the K8s cluster specified in ~/.kube/config.
	@echo "+ $@"
	cd config/manager && kustomize edit set image controller=${IMG}
	kustomize build config/operators | kubectl apply -f -

undeploy-operators: ## Undeploy kio operator and dependant operators from the K8s cluster specified in ~/.kube/config.
	@echo "+ $@"
	kustomize build config/operators | kubectl delete -f -
