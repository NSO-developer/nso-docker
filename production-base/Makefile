FILENAME:=$(shell basename $(FILE))
NCS_VERSION:=$(shell echo $(FILENAME) | sed -E -e 's/(ncs|nso)-([0-9.]*).linux.x86_64.installer.bin/\2/')

.PHONY: build

build:
	@echo "Building NSO production Docker image cisco-nso-base:$(NCS_VERSION) based on $(FILE)"
	rm -f *.bin
	cp $(FILE) $(FILENAME)
	docker build --build-arg NSO_INSTALL_FILE=$(FILENAME) -t $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) .
	rm -f *.bin

version-tag:
	docker tag $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) $(DOCKER_REGISTRY)cisco-nso-base:$(NSO_VERSION)

push:
	docker push $(DOCKER_REGISTRY)cisco-nso-base:$(NSO_VERSION)
