# There are multiple entry points for building a NSO docker image, see
# README.org for details on how to invoke them.

NSO_INSTALL_FILES_DIR?=nso-install-files/
NSO_INSTALL_FILES=$(wildcard $(NSO_INSTALL_FILES_DIR)*.bin)
NSO_BUILD=$(NSO_INSTALL_FILES:%=build/%)
NSO_TEST=$(NSO_INSTALL_FILES:%=test/%)

# if DOCKER_REGISTRY is set, use that
# if DOCKER_REGISTRY is not set and CI_REGISTRY_IMAGE is set, use that
ifneq ($(CI_REGISTRY_IMAGE),)
DOCKER_REGISTRY?=$(CI_REGISTRY_IMAGE)/
endif
export DOCKER_REGISTRY

ifneq ($(FILE),)
NSO_VERSION:=$(shell basename $(FILE) | sed -E -e 's/(ncs|nso)-(.+).linux.x86_64.installer.bin/\2/')
endif

ifneq ($(CI_PIPELINE_ID),)
DOCKER_TAG?=$(NSO_VERSION)-$(CI_PIPELINE_ID)
else
ifneq ($(NSO_VERSION),)
DOCKER_TAG?=$(NSO_VERSION)-$(shell whoami | sed 's/[^[:alnum:]._-]\+/_/g')
endif
endif

# If we are running in CI and on the default branch (like 'main' or 'master'),
# disable the build cache for docker builds. We do this with ?= operator in make
# so we only set DOCKER_BUILD_CACHE_ARG if it is not already set, this makes it
# possible to still use the cache if explicitly set through environment
# variables in CI.
ifneq ($(CI),)
ifeq ($(CI_COMMIT_REF_NAME),$(CI_DEFAULT_BRANCH))
DOCKER_BUILD_CACHE_ARG?=--no-cache
endif
endif
export DOCKER_BUILD_CACHE_ARG


.PHONY: all build build-all build-file test test-file test-file-multiver tag-release push-release $(NSO_BUILD) $(NSO_TEST)

all:
	@echo "The default make target will build Docker images out of all the NSO"
	@echo "versions found in $(NSO_INSTALL_FILES_DIR). To also run the test"
	@echo "suite for the built images, run 'make test-all'"
	$(MAKE) build-all

# build target based on NSO version as input
# run like: make NSO_VERSION=5.2.1 build
# assumes the corresponding NSO install file is located in the directory
# specified by NSO_INSTALL_FILES_DIR
build: export FILE=$(shell realpath -q -e $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin $(NSO_INSTALL_FILES_DIR)/ncs-$(NSO_VERSION).linux.x86_64.installer.bin)
build:
	@if [ -z "$(NSO_VERSION)" ]; then echo "ERROR: variable NSO_VERSION must be set, for example to '5.2.1' to build based on $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin"; false; fi
	$(MAKE) build-file

# test target based on NSO version as input
# run like: make NSO_VERSION=5.2.1 test
# assumes the corresponding NSO install file is located in the directory
# specified by NSO_INSTALL_FILES_DIR
test:
	@if [ -z "$(NSO_VERSION)" ]; then echo "ERROR: variable NSO_VERSION must be set, for example to '5.2.1' to run tests based on $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin"; false; fi
	$(MAKE) -C test NSO_VERSION=$(NSO_VERSION) DOCKER_TAG=$(DOCKER_TAG) test

# test target based on NSO version as input, just for the multi-version test
# run like: make OLD_NSO_VERSION=5.2.1 NSO_VERSION=5.3 test-multiver
test-multiver:
	@if [ -z "$(OLD_NSO_VERSION)" ]; then echo "ERROR: variable OLD_NSO_VERSION must be set, for example to '5.2.1' to run multi-version tests between OLD_NSO_VERSION and NSO_VERSION"; false; fi
	@if [ -z "$(NSO_VERSION)" ]; then echo "ERROR: variable NSO_VERSION must be set, for example to '5.2.1' to build based on $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin"; false; fi
	$(MAKE) -C test NSO_VERSION=$(NSO_VERSION) DOCKER_TAG=$(DOCKER_TAG) test-multiver

# Test NID skeletons
# NSO_VERSION is set to to DOCKER_TAG, since we want to test the version we've just built!
test-skeletons:
	$(MAKE) -C skeletons/test NSO_VERSION=$(DOCKER_TAG) DOCKER_TAG=$(DOCKER_TAG)

# build target that takes FILE env arg (really just passed on through
# environment) as input. FILE should be an absolute path to the NSO install
# file.
build-file:
	@if [ -z "$(FILE)" ]; then echo "ERROR: variable FILE must be set to the full path to the NSO installer, e.g. FILE=/data/foo/nso-5.2.1.linux.x86_64.install.bin"; echo "HINT: You probably want to invoke the 'build' target instead"; false; fi
	$(MAKE) -C docker-images DOCKER_TAG=$(DOCKER_TAG) build

# test target also takes FILE env arg as described above
test-file test-file-multiver:
	@if [ -z "$(FILE)" ]; then echo "ERROR: variable FILE must be set to the full path to the NSO installer, e.g. FILE=/data/foo/nso-5.2.1.linux.x86_64.install.bin"; echo "HINT: You probably want to invoke the 'test' target instead"; false; fi
	$(MAKE) -C test DOCKER_TAG=$(DOCKER_TAG) $(subst -file,,$@)

# builds images for all NSO versions (found in NSO_INSTALL_FILES_DIR)
build-all: $(NSO_BUILD)

# run tests for all NSO versions (found in NSO_INSTALL_FILES_DIR)
test-all: $(NSO_TEST)

# individual make targets for building where the NSO install file is embedded as
# part of the build target name rather than passed separately as a env var
$(NSO_BUILD):
	$(MAKE) FILE=$(shell realpath $(@:build/%=%)) build-file

$(NSO_TEST):
	$(MAKE) FILE=$(shell realpath $(@:test/%=%)) test-file

pull:
	docker pull $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG)
	docker pull $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)

push:
	docker push $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG)
	docker push $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)

tag-release:
	docker tag $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) $(DOCKER_REGISTRY)cisco-nso-dev:$(NSO_VERSION)
	docker tag $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) $(DOCKER_REGISTRY)cisco-nso-base:$(NSO_VERSION)

push-release:
	docker push $(DOCKER_REGISTRY)cisco-nso-dev:$(NSO_VERSION)
	docker push $(DOCKER_REGISTRY)cisco-nso-base:$(NSO_VERSION)
