NSO_INSTALL_FILES_DIR?=nso-install-files/
NSO_INSTALL_FILES=$(wildcard $(NSO_INSTALL_FILES_DIR)*.bin)
NSO_DEV=$(NSO_INSTALL_FILES:%=development/%)
NSO_PROD=$(NSO_INSTALL_FILES:%=production/%)
NSO_TEST=$(NSO_INSTALL_FILES:%=test/%)

ifeq ($(NSO_INSTALL_FILES),)
$(error "ERROR: No NSO install files found in $(NSO_INSTALL_FILES_DIR). Either place the NSO install file(s) in $(NSO_INSTALL_FILES_DIR) or set the environment variable NSO_INSTALL_FILES_DIR to the directory containing the NSO install file(s)")
endif

.PHONY: build $(NSO_DEV) $(NSO_PROD)

# build all (both development and production images)
build: $(NSO_DEV) $(NSO_PROD)

$(NSO_DEV):
	$(MAKE) -C development FILE=$(shell realpath $(@:development/%=%)) build

$(NSO_PROD):
	$(MAKE) -C production FILE=$(shell realpath $(@:production/%=%)) build

$(NSO_TEST):
	$(MAKE) -C test FILE=$(@:test/%=%) test

test: $(NSO_TEST)
