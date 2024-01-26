TAG ?= $(GITHUB_TAG)
TREE_STATE := clean
COMMIT := $(shell git rev-parse --short HEAD)

CHANGES = $(shell git status --porcelain --untracked-files=no)
ifneq ($(CHANGES),)
	TREE_STATE = dirty
	DIRTY = dirty
endif

# If worktree is clean and a TAG was not provided, try to
# get the first tag that points to the current commit.
ifeq ($(TREE_STATE),clean)
	ifeq ($(TAG),)
    	TAG = $(shell git tag -l --contains HEAD | head -n 1)
	endif
endif

VERSION := 
# Expected tag format: v0.1.{testing,production}.1
ifneq ($(TAG),)
	ifeq ($(TREE_STATE),clean)
		VERSION = $(TAG)
	endif
endif

# If a tag was not set, or worktree is dirty, fallback
# to default format: v0.0~aaaaaadirty.testing.0
ifeq ($(VERSION),)
	VERSION = "v0.0~$(COMMIT)$(DIRTY).testing.0"
endif

rpm_version_regex := s/\-/~/g; s/^v([0-9]+\.[0-9]+[-~a-zA-Z0-9]*)\.[a-z]+\.[0-9]+$$/\1/;
rpm_channel_regex := s/^v[0-9]+\.[0-9]+[-~a-zA-Z0-9]*\.([a-z]+)\.[0-9]+$$/\1/;
rpm_release_regex := s/^v[0-9]+\.[0-9]+[-~a-zA-Z0-9]*\.[a-z]+\.([0-9]+)$$/\1/;

CHECKED_VERSION = $(shell echo $(VERSION) | grep -E 'v[0-9]+\.[0-9]+[~a-zA-Z0-9]*\.[a-z]+\.[0-9]+')

ifneq ($(CHECKED_VERSION),)
	RPM_VERSION = $(shell sed -E -e "$(rpm_version_regex)" <<<"$(VERSION)")
	RPM_RELEASE = $(shell sed -E -e "$(rpm_release_regex)" <<<"$(VERSION)")
	RPM_CHANNEL = $(shell sed -E -e "$(rpm_channel_regex)" <<<"$(VERSION)")

	ALLOWED_CHANNELS := production testing
	ifneq ($(filter-out $(ALLOWED_CHANNELS),$(RPM_CHANNEL)),)
		VERSION_MSG = "RPM_CHANNEL $(RPM_CHANNEL) does not match one of: [testing, production]"
	endif
else
	VERSION_MSG = "Tag ($(TAG)) or version ($(VERSION)) does not match expected format"
endif
