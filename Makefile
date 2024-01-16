RUNNER ?= docker

POLICIES=$(shell find policy -mindepth 2 -maxdepth 2 -type f -name 'Dockerfile' | sort -u | cut -f 2 -d'/')

RPM_VERSION := v0.1.1
RPM_RELEASE := testing

.PHONY: build
build:
	$(MAKE) $(addsuffix -build-clean, $(POLICIES))
	$(MAKE) $(addsuffix -build-image, $(POLICIES))
	$(MAKE) $(addsuffix -build-artefacts, $(POLICIES))

%-build-image:
	$(RUNNER) build --build-arg POLICY=$(subst :,/,$*) \
		-t rancher-selinux:$(subst :,/,$*) -f policy/$(subst :,/,$*)/Dockerfile .

%-build-clean:
	rm -rf $(shell pwd)/build/$(subst :,/,$*)
	mkdir -p $(shell pwd)/build/$(subst :,/,$*)

%-build-artefacts:
	$(RUNNER) run --rm \
		-e USER=$(shell id -u) -e GROUP=$(shell id -g) \
		-v $(shell pwd)/build/$(subst :,/,$*):/out \
		--workdir /src \
		rancher-selinux:$(subst :,/,$*) ./build $(RPM_VERSION) $(RPM_RELEASE)
