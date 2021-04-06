# Common Makefile for NSO in Docker NED standard form.
#
# A repository that follows the standard form for a NID (NSO in Docker) package
# repository contains one or more NSO packages in the `/packages` directory.
# These packages, in their compiled form, are the primary output artifacts of
# the repository. In order to test the functionality of the packages, as part of
# the test make target, an NSO instance is started with the packages loaded. To
# enable actual testing, extra test-packages are loaded from the
# `/test-packages` folder. test-packages are not part of the primary output
# artifacts and are thus only included in the Docker image used for testing.
#
# The test environment, called testenv, assumes that a Docker image has already
# been built that contains the primary package artifacts and any necessary
# test-packages. Changing any package or test-packages would in normal Docker
# operations typically involve rebuilding the Docker image and restarting the
# entire testenv, however, an optimized procedure is available; NSO containers
# in the testenv are started with the packages directory on a volume which
# allows the testenv-build job to mount this directory, copy in the updated
# source code onto the volume, recompile the code and then reload it in NSO.
# This drastically reduces the length of the REPL loop and thus improves the
# environment for the developer.

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


# We explicitly build the first 'build' stage, which allows us to control
# caching of it through the DOCKER_BUILD_CACHE_ARG.
build: ensure-fresh-nid-available Dockerfile
	docker build --target build   -t $(IMAGE_PATH)$(PROJECT_NAME)/build:$(DOCKER_TAG)   --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) $(DOCKER_BUILD_CACHE_ARG) .
	docker build --target netsim  -t $(IMAGE_PATH)$(PROJECT_NAME)/netsim:$(DOCKER_TAG)  --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) --build-arg NED_NAME=$(NED_NAME) .
	docker build --target testnso -t $(IMAGE_PATH)$(PROJECT_NAME)/testnso:$(DOCKER_TAG) --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) .
	docker build --target package -t $(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) .

push:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG)
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/netsim:$(DOCKER_TAG)

tag-release:
	docker tag $(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) $(IMAGE_PATH)$(PROJECT_NAME)/package:$(NSO_VERSION)
	docker tag $(IMAGE_PATH)$(PROJECT_NAME)/netsim:$(DOCKER_TAG) $(IMAGE_PATH)$(PROJECT_NAME)/netsim:$(NSO_VERSION)

push-release:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/package:$(NSO_VERSION)
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/netsim:$(NSO_VERSION)


dev-shell:
	docker run -it -v $$(pwd):/src $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION)

.PHONY: all build dev-shell push push-release tag-release test

# Proxy target for running (legacy) default testenv. We explicitly list the
# "common" targets here to enable tab autocompletion.
testenv-start testenv-test testenv-test testenv-rebuild:
testenv-%:
	$(MAKE) -C testenvs/$(DEFAULT_TESTENV) $(subst testenv-,,$@)
