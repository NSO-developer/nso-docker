NSO_INSTALL_FILES_DIR?=nso-install-files/
NSO_INSTALL_FILES=$(wildcard $(NSO_INSTALL_FILES_DIR)*.bin)
NSO_DEV=$(NSO_INSTALL_FILES:%=development/%)
NSO_PROD=$(NSO_INSTALL_FILES:%=production/%)
NSO_TEST=$(NSO_INSTALL_FILES:%=test/%)

.PHONY: build $(NSO_DEV) $(NSO_PROD)

all: build test

build: export FILE=$(NSO_INSTALL_FILES_DIR)/nso-$(NSO_VERSION).linux.x86_64.installer.bin
build:
	$(MAKE) -C development build
	$(MAKE) -C production build
#	$(MAKE) -C test FILE=$(@:test/%=%) test

# build all (both development and production images)
build-all: $(NSO_DEV) $(NSO_PROD)

$(NSO_DEV):
	$(MAKE) -C development FILE=$(shell realpath $(@:development/%=%)) build

$(NSO_PROD):
	$(MAKE) -C production FILE=$(shell realpath $(@:production/%=%)) build

$(NSO_TEST):
	$(MAKE) -C test FILE=$(@:test/%=%) test

test: $(NSO_TEST)
