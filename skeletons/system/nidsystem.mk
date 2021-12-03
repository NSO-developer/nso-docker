# Common Makefile for NSO in Docker system standard form.
#
# A repository that follows the standard form for a NID (NSO in Docker) system
# repository contains one or more NSO packages in the `/packages` directory,
# which are built and assembled into a Docker image of those packages on top of
# a base NSO image.
#
# The test environment, called testenv, assumes that a Docker image has already
# been built that contains the primary package artifacts. Changing any package
# would in normal Docker operations typically involve rebuilding the Docker
# image and restarting the entire testenv, however, an optimized procedure is
# available; NSO containers in the testenv are started with the packages
# directory on a volume which allows the testenv-build job to mount this
# directory, copy in the updated source code onto the volume, recompile the code
# and then reload it in NSO. This drastically reduces the length of the REPL
# loop and thus improves the environment for the developer.

include nidcommon.mk

all:
	$(MAKE) build
	$(MAKE) test

test:
	$(MAKE) testenv-start
	$(MAKE) testenv-test
	$(MAKE) testenv-stop


Dockerfile: Dockerfile.in $(wildcard includes/*)
	@echo "-- Generating Dockerfile"
# Expand variables before injecting them into the Dockerfile as otherwise we
# would have to pass all the variables as build-args which makes this much
# harder to do in a generic manner. This works across GNU and BSD awk.
	cp Dockerfile.in Dockerfile
	for DEP_NAME in $$(ls includes/); do export DEP_URL=$$(awk '{ print "echo", $$0 }' includes/$${DEP_NAME} | $(SHELL) -); awk "/DEP_END/ { print \"FROM $${DEP_URL} AS $${DEP_NAME}\" }; /DEP_INC_END/ { print \"COPY --from=$${DEP_NAME} /var/opt/ncs/packages/ /includes/\" }; 1" Dockerfile > Dockerfile.tmp; mv Dockerfile.tmp Dockerfile; done

# Dockerfile is defined as a PHONY target which means it will always be rebuilt.
# As the build of the Dockerfile relies on environment variables which we have
# no way of getting a timestamp for, we must rebuild in order to be safe.
.PHONY: Dockerfile


DOCKER_BUILD_ARGS:= --platform=linux/amd64
DOCKER_BUILD_ARGS+= --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH)
DOCKER_BUILD_ARGS+= --build-arg NSO_VERSION=$(NSO_VERSION)
DOCKER_BUILD_ARGS+= --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG)
DOCKER_BUILD_ARGS+= --progress=plain
# We explicitly build the first 'build' stage, which allows us to control
# caching of it through the DOCKER_BUILD_CACHE_ARG.
build: export DOCKER_BUILDKIT=1
build: ensure-fresh-nid-available Dockerfile
	docker build --target build -t $(IMAGE_PATH)$(PROJECT_NAME)/build:$(DOCKER_TAG) $(DOCKER_BUILD_ARGS) $(DOCKER_BUILD_CACHE_ARG) .
	docker build --target nso   -t $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG)   $(DOCKER_BUILD_ARGS) .

push:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG)

tag-release:
	docker tag $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG) $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(NSO_VERSION)

push-release:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(NSO_VERSION)


dev-shell:
	docker run -it -v $$(pwd):/src $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION)

.PHONY: all build dev-shell push push-release tag-release test

# Proxy target for running (legacy) default testenv. We explicitly list the
# "common" targets here to enable tab autocompletion.
testenv-start testenv-test testenv-test testenv-rebuild:
testenv-%:
	$(MAKE) -C testenvs/$(DEFAULT_TESTENV) $(subst testenv-,,$@)
