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
ifneq ($(TAG),)
	ifeq ($(TREE_STATE),clean)
		VERSION = $(TAG)
	endif
endif

# Expected tag formats (see "Versioning" in README.md):
#   v{MAJOR}.{MINOR}.{PATCH}-{alpha,beta,rc}{N}.testing.{RELEASE}
#   v{MAJOR}.{MINOR}.{PATCH}.production.{RELEASE}
#
# Pre-releases map to an RPM version with a tilde (1.0.0-rc1 -> 1.0.0~rc1),
# which RPM sorts before the final version (1.0.0). Pre-releases may only
# be published to testing and final versions only to production, so the
# same RPM version-release is never built twice with different content.
#
# If a tag was not set, or worktree is dirty, fallback to a development
# version: v0.0.0~{commit}[dirty].testing.0
ifeq ($(VERSION),)
	VERSION = v0.0.0~$(COMMIT)$(DIRTY).testing.0
endif

define parse_version
[[ "$(VERSION)" =~ ^v([0-9]+\.[0-9]+\.[0-9]+)(-((alpha|beta|rc)[0-9]+)|~([a-fA-F0-9]{7,10}(dirty)?))?\.(production|testing)\.([0-9]+)$$ ]] || exit 0; \
	ver=$${BASH_REMATCH[1]}; pre=$${BASH_REMATCH[3]}; dev=$${BASH_REMATCH[5]}; \
	channel=$${BASH_REMATCH[7]}; release=$${BASH_REMATCH[8]}; \
	if [[ -n "$$dev" ]]; then [[ "$$ver" == 0.0.0 && "$$channel" == testing ]] || exit 0; ver="$$ver~$$dev"; \
	elif [[ -n "$$pre" ]]; then [[ "$$channel" == testing ]] || exit 0; ver="$$ver~$$pre"; \
	else [[ "$$channel" == production ]] || exit 0; fi;
endef

RPM_VERSION = $(shell $(parse_version) echo $$ver)
RPM_RELEASE = $(shell $(parse_version) echo $$release)
RPM_CHANNEL = $(shell $(parse_version) echo $$channel)

ifeq ($(RPM_VERSION),)
	VERSION_MSG = "Tag ($(TAG)) or Version ($(VERSION)) does not match expected format, see Versioning in README.md"
endif
