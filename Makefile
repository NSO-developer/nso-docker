NSO_INSTALL_FILES=$(shell ls nso-install-files/*.bin)
NSOS=$(NSO_INSTALL_FILES:nso-install-files/%=%)
NSO_DEV=$(NSOS:%=development/%)
NSO_DEV=
NSO_PROD=$(NSOS:%=production/%)

.PHONY: build $(NSO_DEV) $(NSO_PROD)

$(NSO_DEV):
	@echo "Building development NSO image $(@:development/%=%) based on $(@:development/%=nso-install-files/%)"
	rm -f development/*.bin
	cp $(@:development/%=nso-install-files/%) development/
	$(MAKE) -C development FILE=$(@:development/%=%) build
	rm -f development/*.bin

$(NSO_PROD):
	@echo "Building production NSO image $(@:production/%=%) based on $(@:production/%=nso-install-files/%)"
	rm -f production/*.bin
	cp $(@:production/%=nso-install-files/%) production/
	$(MAKE) -C production FILE=$(@:production/%=%) build
	rm -f production/*.bin

# build all (both development and production images)
build: $(NSO_DEV) $(NSO_PROD)
