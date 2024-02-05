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

VERSION_REGEX = ^v([0-9]+\.[0-9]+)(-rc[0-9]+){0,1}\.(production|testing)\.([0-9]+)$$

# If a tag was not set, or worktree is dirty, fallback
# to default format: v0.0~aaaaaadirty.testing.0
ifeq ($(VERSION),)
	VERSION = "v0.0~$(COMMIT)$(DIRTY).testing.0"
	VERSION_REGEX = ^v([0-9]+\.[0-9]+)(~[a-fA-F0-9]{7,10}$(DIRTY))\.(testing)\.([0-9]+)$$
endif

RPM_VERSION = $(shell [[ $(VERSION) =~ $(VERSION_REGEX) ]] && echo $${BASH_REMATCH[1]})
RPM_RELEASE = $(shell [[ $(VERSION) =~ $(VERSION_REGEX) ]] && echo $${BASH_REMATCH[4]})
RPM_CHANNEL = $(shell [[ $(VERSION) =~ $(VERSION_REGEX) ]] && echo $${BASH_REMATCH[3]})

ifeq ($(RPM_VERSION),)
	VERSION_MSG = "Tag ($(TAG)) or Version ($(VERSION)) does not match expected format"
else ifeq ($(RPM_RELEASE),)
	VERSION_MSG = "Tag ($(TAG)) or Version ($(VERSION)) does not match expected format"
else ifeq ($(RPM_CHANNEL),)
	VERSION_MSG = "Tag ($(TAG)) or Version ($(VERSION)) does not match expected format"
endif
