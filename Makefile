RUNNER ?= docker
POLICIES = $(shell find policy -mindepth 1 -maxdepth 1 -type d | sort -u | cut -f 2 -d'/')
DISTROS = $(shell find hack/e2e -type f | grep .yaml | sort -u | cut -f3 -d'/' | cut -f1 -d.)
LIMA_DEBUG :=

# GPG Signing
DRY_RUN ?= false
SIGN_KEY_EMAIL ?= ci@rancher.com
PRIVATE_KEY ?=
PRIVATE_KEY_PASS_PHRASE ?=
TESTING_PRIVATE_KEY ?= 
TESTING_PRIVATE_KEY_PASS_PHRASE ?=

# S3 Upload
TESTING_AWS_ACCESS_KEY_ID ?=
TESTING_AWS_SECRET_ACCESS_KEY ?=
TESTING_AWS_S3_BUCKET ?=
PRODUCTION_AWS_ACCESS_KEY_ID ?=
PRODUCTION_AWS_SECRET_ACCESS_KEY ?=
PRODUCTION_AWS_S3_BUCKET ?=

ifeq ($(DRY_RUN),true)
	DRY_RUN_SIGN := --dry-run
endif

SHELL := /bin/bash

include hack/make/version.mk
include hack/make/tools.mk

.PHONY: build
build: ## build all policies.
	$(MAKE) $(addsuffix -build, $(POLICIES))

%-build: version ## build a specific policy.
	$(MAKE) $(subst :,/,$*)-build-clean
	$(MAKE) $(subst :,/,$*)-build-image
	$(MAKE) $(subst :,/,$*)-build-artefacts
	$(MAKE) $(subst :,/,$*)-build-sign
	$(MAKE) $(subst :,/,$*)-build-metadata

%-build-image: ## build the container image used to generate a given policy.
	$(RUNNER) build --build-arg POLICY=$(subst :,/,$*) \
		-t rancher-selinux:$(subst :,/,$*) -f Dockerfile .

%-build-clean: ## remove any artefacts related to the building of a policy.
	rm -rf $(shell pwd)/build/$(subst :,/,$*)
	mkdir -p $(shell pwd)/build/$(subst :,/,$*)

%-build-artefacts: ## generate artefacts of a given policy.
	$(RUNNER) run --rm \
		-e USER=$(shell id -u) -e GROUP=$(shell id -g) \
		-v $(shell pwd)/build/$(subst :,/,$*):/out \
		rancher-selinux:$(subst :,/,$*) ./build $(RPM_VERSION) $(RPM_RELEASE)

%-build-sign: ## sign the generate rpms of a given policy.
	@$(RUNNER) run --rm \
		-e USER=$(shell id -u) -e GROUP=$(shell id -g) \
		-e SIGN_KEY_EMAIL="$(SIGN_KEY_EMAIL)" -e RPM_CHANNEL="$(RPM_CHANNEL)" \
		-e TESTING_PRIVATE_KEY_PASS_PHRASE \
		-e TESTING_PRIVATE_KEY \
		-e PRIVATE_KEY -e PRIVATE_KEY_PASS_PHRASE \
		-v $(shell pwd)/build/$(subst :,/,$*):/dist \
		rancher-selinux:$(subst :,/,$*) sign $(DRY_RUN_SIGN)

%-build-metadata: ## generate repository metadata for a given policy.
	$(RUNNER) run --rm \
		-e USER=$(shell id -u) -e GROUP=$(shell id -g) \
		-v $(shell pwd)/build/$(subst :,/,$*):/dist \
		rancher-selinux:$(subst :,/,$*) ./metadata

upload: $(AWSCLI) version ## uploads all artefacts from each policy into S3.
	$(MAKE) $(addsuffix -upload, $(POLICIES))

%-upload: 
	RPM_CHANNEL=$(RPM_CHANNEL) POLICY=$(subst :,/,$*) \
    TESTING_AWS_ACCESS_KEY_ID="$(TESTING_AWS_ACCESS_KEY_ID)" \
    TESTING_AWS_SECRET_ACCESS_KEY="$(TESTING_AWS_SECRET_ACCESS_KEY)" \
    TESTING_AWS_S3_BUCKET="$(TESTING_AWS_S3_BUCKET)" \
    PRODUCTION_AWS_ACCESS_KEY_ID="$(PRODUCTION_AWS_ACCESS_KEY_ID)" \
    PRODUCTION_AWS_SECRET_ACCESS_KEY="$(PRODUCTION_AWS_SECRET_ACCESS_KEY)" \
    PRODUCTION_AWS_S3_BUCKET="$(PRODUCTION_AWS_S3_BUCKET)" \
		./hack/upload

upload-gh: $(GH) ## upload all artefacts to the GitHub release.
	$(MAKE) $(addsuffix -upload-gh, $(POLICIES))

%-upload-gh:
	TAG=$(TAG) \
		./hack/upload-gh $(subst :,/,$*)

version: ## parse and display version.
ifdef VERSION_MSG
	@echo  $(VERSION_MSG); exit 1
endif

	@echo Version Information
	@echo RPM_VERSION: $(RPM_VERSION)
	@echo RPM_RELEASE: $(RPM_RELEASE)
	@echo RPM_CHANNEL: $(RPM_CHANNEL)
	@echo VERSION: $(VERSION)

e2e:
	$(MAKE) $(addprefix push-tool-, $(DISTROS))

e2e-%:
	make $(subst :,/,$*)-build-image
	make $(subst :,/,$*)-build-artefacts
	
	limactl start $(LIMA_DEBUG) --tty=false --cpus 6 --memory 8 --plain --name=$(subst :,/,$*) hack/e2e/$(subst :,/,$*).yaml
	limactl cp build/$(subst :,/,$*)/noarch/rancher-*.rpm $(subst :,/,$*):/tmp/rancher-selinux.rpm
	limactl cp hack/e2e/setup-vm.sh $(subst :,/,$*):/tmp/setup-vm.sh
	limactl shell $(subst :,/,$*) sudo /tmp/setup-vm.sh
	
	limactl stop $(subst :,/,$*)
	limactl delete $(subst :,/,$*)

e2e-%-clean:
	limactl stop $(subst :,/,$*)
	limactl delete $(subst :,/,$*)

help: ## display Makefile's help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
