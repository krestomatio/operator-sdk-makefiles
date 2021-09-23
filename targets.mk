##@ Common

image-build: ## Build container image with the manager.
	@echo "+ $@"
ifeq ($(OPERATOR_TYPE),ansible)
	$(CONTAINER_BUILDER) build . -t $(IMG) \
		--build-arg COLLECTION_FILE=$(COLLECTION_FILE)
else
	$(CONTAINER_BUILDER) build . -t $(IMG)
endif

image-push: ## Push container image with the manager.
	@echo "+ $@"
	$(CONTAINER_BUILDER) push $(IMG)

.PHONY: git
git: ## Git add, commit, tag and push
	@echo "+ $@"
	git add $(GIT_ADD_FILES)
	git commit -m "chore(release): $(VERSION)" -m "[$(SKIP_MSG)]"
	git tag v$(VERSION)
	git push $(GIT_REMOTE) $(GIT_BRANCH) --tags

.PHONY: set-manager-image
set-manager-image: ## Set manager image using kustomize
	@echo "+ $@"
	cd config/manager && kustomize edit set image controller=$(IMAGE_TAG_BASE):$(VERSION)

.PHONY: skopeo-copy
skopeo-copy: ## Copy images using skopeo
	@echo "+ $@"
	# full version
	skopeo copy --src-tls-verify=$(SKOPEO_SRC_TLS) --dest-tls-verify=$(SKOPEO_DEST_TLS) docker://$(BUILD_IMAGE_TAG_BASE):$(BUILD_VERSION) docker://$(IMAGE_TAG_BASE):$(VERSION)
	# major + minor
	skopeo copy --src-tls-verify=$(SKOPEO_SRC_TLS) --dest-tls-verify=$(SKOPEO_DEST_TLS) docker://$(BUILD_IMAGE_TAG_BASE):$(BUILD_VERSION) docker://$(IMAGE_TAG_BASE):$(word 1,$(subst ., ,$(VERSION))).$(word 2,$(subst ., ,$(VERSION)))
	# major
	skopeo copy --src-tls-verify=$(SKOPEO_SRC_TLS) --dest-tls-verify=$(SKOPEO_DEST_TLS) docker://$(BUILD_IMAGE_TAG_BASE):$(BUILD_VERSION) docker://$(IMAGE_TAG_BASE):$(word 1,$(subst ., ,$(VERSION)))

##@ JX

.PHONY: jx-changelog
jx-changelog: ## Generate changelog file using jx
	@echo "+ $@"
ifeq (0, $(shell test -d  "charts/$(REPO_NAME)"; echo $$?))
	sed -i "s/^version:.*/version: $(VERSION)/" charts/$(REPO_NAME)/Chart.yaml
	sed -i "s/tag:.*/tag: $(VERSION)/" charts/$(REPO_NAME)/values.yaml
	sed -i "s@repository:.*@repository: $(IMAGE_TAG_BASE)@" charts/$(REPO_NAME)/values.yaml
	git add charts/
else
	echo no charts
endif
	jx changelog create --verbose --version=$(VERSION) --rev=$(CHANGELOG_FROM) --output-markdown=$(CHANGELOG_FILE) --update-release=false
	git add $(CHANGELOG_FILE)

ifneq (,$(wildcard $(MK_INCLUDE_DIR)/targets-$(OPERATOR_SHORTNAME).mk))
include $(MK_INCLUDE_DIR)/targets-$(OPERATOR_SHORTNAME).mk
endif

include $(MK_INCLUDE_DIR)/targets-$(OPERATOR_TYPE).mk
