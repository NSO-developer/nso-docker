FILENAME:=$(shell basename $(FILE))
NCS_VERSION:=$(shell echo $(FILENAME) | sed -r -e 's/(ncs|nso)-([0-9.]*).linux.x86_64.installer.bin/\2/')

.PHONY: build

build:
	@echo "Building NSO production Docker image cisco-nso:$(NCS_VERSION) based on $(FILE)"
	rm -f *.bin
	cp $(FILE) $(FILENAME)
	docker build --build-arg NSO_INSTALL_FILE=$(FILENAME) -t cisco-nso:$(NCS_VERSION) .
	rm -f *.bin
