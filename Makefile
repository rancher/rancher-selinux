CENTOS7_TARGETS := $(addprefix centos7-,$(shell ls policy/centos7/scripts))
CENTOS8_TARGETS := $(addprefix centos8-,$(shell ls policy/centos8/scripts))
CENTOS9_TARGETS := $(addprefix centos9-,$(shell ls policy/centos9/scripts))
MICROOS_TARGETS := $(addprefix microos-,$(shell ls policy/microos/scripts))
FEDORA37_TARGETS := $(addprefix fedora37-,$(shell ls policy/fedora37/scripts))

.dapper:
	@echo Downloading dapper
	@curl -sL https://releases.rancher.com/dapper/latest/dapper-$$(uname -s)-$$(uname -m) > .dapper.tmp
	@@chmod +x .dapper.tmp
	@./.dapper.tmp -v
	@mv .dapper.tmp .dapper

$(CENTOS7_TARGETS): .dapper
	./.dapper -f Dockerfile.centos7.dapper $(@:centos7-%=%)

$(CENTOS8_TARGETS): .dapper
	./.dapper -f Dockerfile.centos8.dapper $(@:centos8-%=%)

$(CENTOS9_TARGETS): .dapper
	./.dapper -f Dockerfile.centos9.dapper $(@:centos9-%=%)

$(MICROOS_TARGETS): .dapper
	./.dapper -f Dockerfile.microos.dapper $(@:microos-%=%)

$(FEDORA37_TARGETS): .dapper
	./.dapper -f Dockerfile.fedora37.dapper $(@:fedora37-%=%)

.PHONY: $(CENTOS7_TARGETS) $(CENTOS8_TARGETS) $(CENTOS9_TARGETS) $(MICROOS_TARGETS) $(FEDORA37_TARGETS)
