FILENAME:=$(shell basename $(FILE))
NSO_VERSION:=$(shell echo $(FILENAME) | sed -E -e 's/(ncs|nso)-(.+)\.linux.x86_64.installer.bin/\2/')

.PHONY: build

build:
	@echo "Building NSO production Docker image cisco-nso-base:$(NSO_VERSION) based on $(FILE)"
	rm -f *.bin
	cp $(FILE) $(FILENAME)
	docker build $(DOCKER_BUILD_CACHE_ARG) --build-arg NSO_INSTALL_FILE=$(FILENAME) -t $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) .
	rm -f *.bin
