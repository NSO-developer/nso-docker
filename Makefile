NSO_INSTALL_FILES_DIR?=nso-install-files/
NSO_INSTALL_FILES=$(wildcard $(NSO_INSTALL_FILES_DIR)*.bin)
NSOS=$(NSO_INSTALL_FILES:%=build/%)
NSO_DEV=$(NSO_INSTALL_FILES:%=development/%)
NSO_BASE=$(NSO_INSTALL_FILES:%=base/%)
NSO_TEST=$(NSO_INSTALL_FILES:%=test/%)

# if DOCKER_REGISTRY is set, use that
# if DOCKER_REGISTRY is not set and CI_REGISTRY_IMAGE is set, use that
ifneq ($(CI_REGISTRY_IMAGE),)
DOCKER_REGISTRY?=$(CI_REGISTRY_IMAGE)/
endif

ifneq ($(CI_JOB_ID),)
DOCKER_TAG?=$(CI_JOB_ID)
else
DOCKER_TAG?=$(shell whoami)-dev
endif

# If we are running in CI, disable the build cache for docker builds.
# We do this with ?= operator in make so we only set DOCKER_BUILD_CACHE_ARG if
# it is not already set, this makes it possible to still use the cache if
# explicitly set through environment variables in CI.
ifneq ($(CI),)
DOCKER_BUILD_CACHE_ARG?=--no-cache
export DOCKER_BUILD_CACHE_ARG
endif

.PHONY: all build build-all build-version $(NSO_DEV) $(NSO_BASE)

all: build-all

# build target based on NSO version as input
# run like: make NSO_VERSION=4.7.5 build-version
# assumes the corresponding NSO install file is located in the directory
# specified by NSO_INSTALL_FILES_DIR
build-version: export FILE=$(shell realpath $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin)
build-version:
	$(MAKE) DOCKER_REGISTRY=$(DOCKER_REGISTRY) DOCKER_TAG=$(DOCKER_TAG) build

# build target that takes FILE env arg (really just passed on through
# environment) as input. FILE should be an absolute path to the NSO install
# file.
build:
	$(MAKE) -C development build
	$(MAKE) -C production-base build
	$(MAKE) -C test test

push:
	docker push $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG)
	docker push $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)

version-tag:
	docker tag $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) $(DOCKER_REGISTRY)cisco-nso-dev:$(NSO_VERSION)
	docker tag $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) $(DOCKER_REGISTRY)cisco-nso-base:$(NSO_VERSION)

push-latest:
	docker push $(DOCKER_REGISTRY)cisco-nso-dev:$(NSO_VERSION)
	docker push $(DOCKER_REGISTRY)cisco-nso-base:$(NSO_VERSION)

# individual make targets for building where the NSO install file is embedded as
# part of the build target name rather than passed separately as a env var
$(NSOS):
	$(MAKE) FILE=$(shell realpath $(@:build/%=%)) build

# builds images for all NSO versions
build-all: $(NSOS)

$(NSO_DEV):
	$(MAKE) -C development FILE=$(shell realpath $(@:development/%=%)) build

$(NSO_BASE):
	$(MAKE) -C production-base FILE=$(shell realpath $(@:base/%=%)) build

$(NSO_TEST):
	$(MAKE) -C test FILE=$(@:test/%=%) test
