NSO_INSTALL_FILES_DIR?=nso-install-files/
NSO_INSTALL_FILES=$(shell ls $(NSO_INSTALL_FILES_DIR)*.bin)
NSO_DEV=$(NSO_INSTALL_FILES:%=development/%)
#NSO_DEV=
NSO_PROD=$(NSO_INSTALL_FILES:%=production/%)

.PHONY: build $(NSO_DEV) $(NSO_PROD)

# build all (both development and production images)
build: $(NSO_DEV) $(NSO_PROD)

$(NSO_DEV):
	$(MAKE) -C development FILE=$(shell realpath $(@:development/%=%)) build

$(NSO_PROD):
	$(MAKE) -C production FILE=$(shell realpath $(@:production/%=%)) build
