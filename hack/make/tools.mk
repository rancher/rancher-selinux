TOOLS_BIN := $(shell mkdir -p build/tools && realpath build/tools)

AWSCLI = $(TOOLS_BIN)/aws/dist/aws
$(AWSCLI): ## Download awscliv2 if not yet downloaded.
	curl "https://awscli.amazonaws.com/awscli-exe-linux-$(shell uname -m).zip" -o "$(TOOLS_BIN)/awscliv2.zip"
	cd $(TOOLS_BIN) && unzip -q $(TOOLS_BIN)/awscliv2.zip
	rm $(TOOLS_BIN)/awscliv2.zip
