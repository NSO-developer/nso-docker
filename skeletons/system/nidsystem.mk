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

# Determine our project name, either from CI_PROJECT_NAME which is normally set
# by GitLab CI or by looking at the name of our directory (that we are in).
ifneq ($(CI_PROJECT_NAME),)
PROJECT_NAME=$(CI_PROJECT_NAME)
else
PROJECT_NAME:=$(shell basename $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST)))))
endif

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
	for DEP_NAME in $$(ls includes/* | $(XARGS) -n1 basename); do export DEP_URL=$$(awk '{ print "echo", $$0 }' includes/$${DEP_NAME} | $(SHELL) -); awk "/DEP_END/ { print \"FROM $${DEP_URL} AS $${DEP_NAME}\" }; /DEP_INC_END/ { print \"COPY --from=$${DEP_NAME} /var/opt/ncs/packages/ /var/opt/ncs/packages/\" }; 1" Dockerfile > Dockerfile.tmp; mv Dockerfile.tmp Dockerfile; done

build: check-nid-available Dockerfile
	docker build --target nso -t $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG) --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) .

push:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG)

tag-release:
	docker tag $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG) $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(NSO_VERSION)

push-release:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(NSO_VERSION)


dev-shell:
	docker run -it -v $$(pwd):/src $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION)

# Test environment targets

testenv-start:
	-docker network create $(CNT_PREFIX)
	docker run -td --name $(CNT_PREFIX)-nso --network-alias nso $(DOCKER_ARGS) -e ADMIN_PASSWORD=NsoDocker1337 -v /var/opt/ncs/packages $${NSO_EXTRA_ARGS} $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG)
	$(MAKE) testenv-start-extra
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'ncs --wait-started 600'
	$(MAKE) testenv-runcmdJ CMD="show packages"

testenv-build:
	docker run -it --rm -v $(PWD):/src --volumes-from $(CNT_PREFIX)-nso $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) bash -lc 'cp -a /src/packages/. /var/opt/ncs/packages/; for PKG in $$(ls -d /src/packages/* 2>/dev/null | $(XARGS) -n1 basename); do make -C /var/opt/ncs/packages/$${PKG}/src; done'
	$(MAKE) testenv-runcmdJ CMD="request packages reload"
	$(MAKE) testenv-runcmdJ CMD="show packages"

testenv-clean:
	docker run -it --rm -v $(PWD):/src --volumes-from $(CNT_PREFIX)-nso $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) bash -lc 'for PKG in $$(ls -d /src/packages/* 2>/dev/null | $(XARGS) -n1 basename); do make -C /var/opt/ncs/packages/$${PKG}/src clean; done'

testenv-stop:
	docker ps -aq --filter label=$(CNT_PREFIX) | $(XARGS) docker rm -vf
	-docker network rm $(CNT_PREFIX)

testenv-shell:
	docker exec -it $(CNT_PREFIX)-nso bash -l

testenv-cli:
	docker exec -it $(CNT_PREFIX)-nso bash -lc 'ncs_cli -u admin'

testenv-runcmdC testenv-runcmdJ:
	@if [ -z "$(CMD)" ]; then echo "CMD variable must be set"; false; fi
	docker exec -t $(CNT_PREFIX)-nso$(NSO) bash -lc 'echo -e "$(CMD)" | ncs_cli -$(subst testenv-runcmd,,$@)u admin'

.PHONY: all build dev-shell push push-release tag-release test testenv-build testenv-clean testenv-start testenv-stop testenv-test
