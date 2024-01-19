RUNNER ?= docker
POLICIES = $(shell find policy -mindepth 2 -maxdepth 2 -type d | sort -u | cut -f 2 -d'/')

include hack/make/version.mk

.PHONY: build
build: ## build all policies.
	$(MAKE) $(addsuffix -build, $(POLICIES))

%-build: version ## build a specific policy.
	$(MAKE) $(subst :,/,$*)-build-clean
	$(MAKE) $(subst :,/,$*)-build-image
	$(MAKE) $(subst :,/,$*)-build-artefacts
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

%-build-metadata: ## generate repository metadata for a given policy.
	$(RUNNER) run --rm \
		-e USER=$(shell id -u) -e GROUP=$(shell id -g) \
		-v $(shell pwd)/build/$(subst :,/,$*):/dist \
		rancher-selinux:$(subst :,/,$*) ./repo-metadata

version: ## parse and display version.
ifdef VERSION_MSG
	@echo  $(VERSION_MSG); exit 1
endif

	@echo Version Information
	@echo 
	@echo RPM_VERSION: $(RPM_VERSION)
	@echo RPM_RELEASE: $(RPM_RELEASE)
	@echo RPM_CHANNEL: $(RPM_CHANNEL)
	@echo VERSION: $(VERSION)

help: ## display Makefile's help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
