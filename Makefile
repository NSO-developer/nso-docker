# there are multiple entry points for building a NSO docker image
# * Based on NSO version
#   Assuming the NSO install file has been placed in the NSO_INSTALL_FILES_DIR
#   (per default 'nso-install-files/'), you can run:
#     make NSO_VERSION=5.2.1 build-version
#   To produce a docker image based on NSO 5.2.1. It requires that the
#   corresponding installer file is present, i.e.
#   nso-install-files/nso-5.2.1.linux.x86_64.installer.bin
#
# * Based on complete path to NSO installer file
#   You can use the ~build~ target to build a Docker image out of an NSO
#   installer. It requires that you specify the complete path to the NSO
#   installer file, for example:
#     make FILE=/home/foo/nso-docker/nso-install-files/nso-5.2.1.linux.x86_64.installer.bin build
#
# * For all NSO installer files in NSO_INSTALL_FILES_DIR
#   To build docker images for all the NSO installer files present in the NSO
#   installer directory, (specified by NSO_INSTALL_FILES_DIR), you can run:
#     make build-all
#
# There are targets to run tests that correspond with the above;
# * test-version
# * test
# * test-all
# They require the same variables to be set as their corresponding build target
# described above.
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
NSO_VERSION:=$(shell basename $(FILE) | sed -E -e 's/(ncs|nso)-([0-9.]*).linux.x86_64.installer.bin/\2/')
endif

ifneq ($(CI_JOB_ID),)
DOCKER_TAG?=$(CI_JOB_ID)
else
ifneq ($(NSO_VERSION),)
DOCKER_TAG?=$(shell whoami)-$(NSO_VERSION)
endif
endif

# If we are running in CI, disable the build cache for docker builds.
# We do this with ?= operator in make so we only set DOCKER_BUILD_CACHE_ARG if
# it is not already set, this makes it possible to still use the cache if
# explicitly set through environment variables in CI.
ifneq ($(CI),)
DOCKER_BUILD_CACHE_ARG?=--no-cache
export DOCKER_BUILD_CACHE_ARG
endif

.PHONY: all build build-all build-version test test-version $(NSO_BUILD) $(NSO_TEST)

all: build-all test-all

# build target based on NSO version as input
# run like: make NSO_VERSION=5.2.1 build-version
# assumes the corresponding NSO install file is located in the directory
# specified by NSO_INSTALL_FILES_DIR
build-version: export FILE=$(shell realpath $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin)
build-version:
	@if [ -z "$(NSO_VERSION)"]; then echo "ERROR: variable NSO_VERSION must be set, for example to '5.2.1' to build based on $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin"; false; fi
	$(MAKE) build

# test target based on NSO version as input
# run like: make NSO_VERSION=5.2.1 test-version
# assumes the corresponding NSO install file is located in the directory
# specified by NSO_INSTALL_FILES_DIR
test-version: export FILE=$(shell realpath $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin)
test-version:
	$(MAKE) test

# build target that takes FILE env arg (really just passed on through
# environment) as input. FILE should be an absolute path to the NSO install
# file.
build:
	@if [ -z "$(FILE)"]; then echo "ERROR: variable FILE must be set to the full path to the NSO installer, e.g. FILE=/data/foo/nso-5.2.1.linux.x86_64.install.bin"; echo "HINT: You probably want to invoke the 'build-version' target instead"; false; fi
	$(MAKE) -C development DOCKER_TAG=$(DOCKER_TAG) build
	$(MAKE) -C production-base DOCKER_TAG=$(DOCKER_TAG) build

# test target also takes FILE env arg as described above
test:
	@if [ -z "$(FILE)"]; then echo "ERROR: variable FILE must be set to the full path to the NSO installer, e.g. FILE=/data/foo/nso-5.2.1.linux.x86_64.install.bin"; echo "HINT: You probably want to invoke the 'build-version' target instead"; false; fi
	$(MAKE) -C test DOCKER_TAG=$(DOCKER_TAG) test

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
$(NSO_BUILD):
	$(MAKE) FILE=$(shell realpath $(@:build/%=%)) build

# builds images for all NSO versions (found in NSO_INSTALL_FILES_DIR)
build-all: $(NSO_BUILD)

# run tests for all NSO versions (found in NSO_INSTALL_FILES_DIR)
test-all: $(NSO_TEST)

$(NSO_TEST):
	$(MAKE) FILE=$(shell realpath $(@:test/%=%)) test
