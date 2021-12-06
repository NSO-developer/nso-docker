FILENAME:=$(shell basename $(FILE))
NSO_VERSION:=$(shell echo $(FILENAME) | sed -E -e 's/(ncs|nso)-(.+)\.linux.x86_64.installer.bin/\2/')

DOCKER_BUILD_PROXY_ARGS ?= --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy

.PHONY: build

# We use buildkit, which allows Docker to work on multiple stages in parallel as
# it automatically figures out dependencies and the synchronization points it
# needs. Unfortunately we cannot tell it to build multiple targets with a single
# command, so we have to invoke it twice. The dev image is built first and then
# the base image. For the base build, we don't inject the
# $(DOCKER_BUILD_CACHE_ARG) since if the previous build of the dev target
# invalidated any image layer due to caching, then the base target will be
# rebuilt anyway.
build: export DOCKER_BUILDKIT=1
build:
	@echo "Building NSO development Docker image cisco-nso-dev:$(NSO_VERSION) based on $(FILE)"
	rm -f *.bin
	cp $(FILE) $(FILENAME)
	docker build --platform=linux/amd64 $(DOCKER_BUILD_PROXY_ARGS) --build-arg NSO_INSTALL_FILE=$(FILENAME) --target dev  -t $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) $(DOCKER_BUILD_CACHE_ARG) .
	docker build --platform=linux/amd64 $(DOCKER_BUILD_PROXY_ARGS) --build-arg NSO_INSTALL_FILE=$(FILENAME) --target base -t $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) .
	rm -f *.bin
