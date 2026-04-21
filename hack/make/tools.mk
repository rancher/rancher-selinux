MKFILE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
TOOLS_BIN := $(shell mkdir -p build/tools && realpath build/tools)
ARCH := $(shell uname -m | sed 's/arm64/aarch64/')

# renovate-local: awscli-exe-linux-x86_64=2.34.30
AWSCLI_VERSION := 2.34.30
AWSCLI_PUB_KEY := $(MKFILE_DIR)/awscli-publickey.pub

AWSCLI = $(TOOLS_BIN)/aws/dist/aws
$(AWSCLI): ## Download, verify, and install awscliv2.
	@mkdir -p $(TOOLS_BIN)
	@echo "Downloading AWS CLI v$(AWSCLI_VERSION) for ${ARCH}"
	curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-$(ARCH)-$(AWSCLI_VERSION).zip" -o "$(TOOLS_BIN)/awscliv2.zip"
	curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-$(ARCH)-$(AWSCLI_VERSION).zip.sig" -o "$(TOOLS_BIN)/awscliv2.sig"
	@echo "Verifying GPG signature using $(AWSCLI_PUB_KEY)"
	gpg --import $(AWSCLI_PUB_KEY)
	gpg --verify $(TOOLS_BIN)/awscliv2.sig $(TOOLS_BIN)/awscliv2.zip
	cd $(TOOLS_BIN) && unzip -q awscliv2.zip
	@rm $(TOOLS_BIN)/awscliv2.zip $(TOOLS_BIN)/awscliv2.sig
	@echo "AWS CLI installed to $(AWSCLI)"

GH = $(shell which gh)
$(GH):
	@echo "GitHub CLI gh was not found. To install use your package manager."
	@exit 1
