NCS_VERSION=$(shell echo $(FILE) | sed -r -e 's/(ncs|nso)-([0-9.]*).linux.x86_64.installer.bin/\2/')

.PHONY: build

build:
	@echo "Building NSO production Docker image cisco-nso:$(NCS_VERSION) based on $(FILE)"
	docker build --build-arg NSO_INSTALL_FILE=$(FILE) -t cisco-nso:$(NCS_VERSION) .
