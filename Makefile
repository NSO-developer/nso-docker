NSO_INSTALL_FILES_DIR?=nso-install-files/
NSO_INSTALL_FILES=$(wildcard $(NSO_INSTALL_FILES_DIR)*.bin)
NSOS=$(NSO_INSTALL_FILES:%=build/%)
NSO_DEV=$(NSO_INSTALL_FILES:%=development/%)
NSO_BASE=$(NSO_INSTALL_FILES:%=base/%)
NSO_TEST=$(NSO_INSTALL_FILES:%=test/%)

.PHONY: all build build-all build-version $(NSO_DEV) $(NSO_BASE)

all: build-all

# build target based on NSO version as input
# run like: make NSO_VERSION=4.7.5 build-version
# assumes the corresponding NSO install file is located in the directory
# specified by NSO_INSTALL_FILES_DIR
build-version: export FILE=$(shell realpath $(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin)
build-version:
	$(MAKE) build

# build target that takes FILE env arg (really just passed on through
# environment) as input. FILE should be an absolute path to the NSO install
# file.
build:
	$(MAKE) -C development build
	$(MAKE) -C production-base build
	$(MAKE) -C test test

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
