MK_PIPELINES_PROJECT_TYPE_DIR ?= $(MK_PIPELINES_DIR)/$(PROJECT_TYPE)
MK_PIPELINES_PRESUBMIT_FILE ?= $(MK_PIPELINES_DIR)/presubmit.mk
MK_PIPELINES_PRESUBMIT_SKIP_FILE ?= $(MK_PIPELINES_DIR)/presubmit-skip.mk
MK_PIPELINES_PRESUBMIT_PROJECT_TYPE_FILE ?= $(MK_PIPELINES_PROJECT_TYPE_DIR)/presubmit.mk
MK_PIPELINES_PRESUBMIT_PROJECT_FILE ?= $(MK_PIPELINES_PROJECT_TYPE_DIR)/presubmit-$(PROJECT_SHORTNAME).mk
MK_PIPELINES_POSTSUBMIT_FILE ?= $(MK_PIPELINES_DIR)/postsubmit.mk
MK_PIPELINES_POSTSUBMIT_SKIP_FILE ?= $(MK_PIPELINES_DIR)/postsubmit-skip.mk
MK_PIPELINES_POSTSUBMIT_PROJECT_TYPE_FILE ?= $(MK_PIPELINES_PROJECT_TYPE_DIR)/postsubmit.mk
MK_PIPELINES_POSTSUBMIT_PROJECT_FILE ?= $(MK_PIPELINES_PROJECT_TYPE_DIR)/postsubmit-$(PROJECT_SHORTNAME).mk

##@ Pipelines

## start if not SKIP_PIPELINE
ifeq ($(origin SKIP_PIPELINE),undefined)

## Presummit type of pipelines (pull request)
ifneq (,$(wildcard $(MK_PIPELINES_PRESUBMIT_PROJECT_FILE)))
include $(MK_PIPELINES_PRESUBMIT_PROJECT_FILE)
else ifneq (,$(wildcard $(MK_PIPELINES_PRESUBMIT_PROJECT_TYPE_FILE)))
include $(MK_PIPELINES_PRESUBMIT_PROJECT_TYPE_FILE)
else
include $(MK_PIPELINES_PRESUBMIT_FILE)
endif

## Postsummit type of pipelines (when merging to master)
ifneq (,$(wildcard $(MK_PIPELINES_POSTSUBMIT_PROJECT_FILE)))
include $(MK_PIPELINES_POSTSUBMIT_PROJECT_FILE)
else ifneq (,$(wildcard $(MK_PIPELINES_POSTSUBMIT_PROJECT_TYPE_FILE)))
include $(MK_PIPELINES_POSTSUBMIT_PROJECT_TYPE_FILE)
else
include $(MK_PIPELINES_POSTSUBMIT_FILE)
endif

## else if SKIP_PIPELINE
else
$(info SKIP_PIPELINE set:)

## Presummit type of pipelines (pull request)
include $(MK_PIPELINES_PRESUBMIT_SKIP_FILE)

## Postsummit type of pipelines (when merging to master)
include $(MK_PIPELINES_POSTSUBMIT_SKIP_FILE)

## end if not SKIP_PIPELINE
endif