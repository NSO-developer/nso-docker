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
	for DEP_NAME in $$(ls includes/); do export DEP_URL=$$(awk '{ print "echo", $$0 }' includes/$${DEP_NAME} | $(SHELL) -); awk "/DEP_END/ { print \"FROM $${DEP_URL} AS $${DEP_NAME}\" }; /DEP_INC_END/ { print \"COPY --from=$${DEP_NAME} /var/opt/ncs/packages/ /includes/\" }; 1" Dockerfile > Dockerfile.tmp; mv Dockerfile.tmp Dockerfile; done

# Dockerfile is defined as a PHONY target which means it will always be rebuilt.
# As the build of the Dockerfile relies on environment variables which we have
# no way of getting a timestamp for, we must rebuild in order to be safe.
.PHONY: Dockerfile


build: ensure-fresh-nid-available Dockerfile
	docker build $(DOCKER_BUILD_CACHE_ARG) --target build -t $(IMAGE_PATH)$(PROJECT_NAME)/build:$(DOCKER_TAG) --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) .
	docker build $(DOCKER_BUILD_CACHE_ARG) --target nso -t $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG) --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) .

push:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG)

tag-release:
	docker tag $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG) $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(NSO_VERSION)

push-release:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(NSO_VERSION)


dev-shell:
	docker run -it -v $$(pwd):/src $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION)

# Test environment targets

# testenv-start: start the test environment in a configuration that allows
# Python Remote Debugging. Exposes port 5678 on a random port on localhost.
testenv-start:
	docker network inspect $(CNT_PREFIX) >/dev/null 2>&1 || docker network create $(CNT_PREFIX)
	docker run -td --name $(CNT_PREFIX)-nso --network-alias nso $(DOCKER_NSO_ARGS) -e ADMIN_PASSWORD=NsoDocker1337 $${NSO_EXTRA_ARGS} $(IMAGE_PATH)$(PROJECT_NAME)/nso:$(DOCKER_TAG)
	$(MAKE) testenv-start-extra
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'ncs --wait-started 600'

# testenv-debug-vscode: modifies VSCode launch.json to connect the python remote
# debugger to the environment
testenv-debug-vscode:
	if [ -f .vscode/launch.json ]; then \
		HOST_PORT=$$(docker inspect -f '{{(index (index .NetworkSettings.Ports "5678/tcp") 0).HostPort}}' $(CNT_PREFIX)-nso$(NSO)); \
		echo "\n== Updating .vscode/launch.json for Python remote debugging"; \
		LAUNCH=`sed '/\s*\/\/.*/d' .vscode/launch.json | jq "(.configurations[] | select(.name == \"Python: NID Remote Attach\")) |= .+ {port: $${HOST_PORT}}"` && \
		echo "$${LAUNCH}" > .vscode/launch.json && echo "== Updated Python Remote Debugging port to $${HOST_PORT}"; \
	fi

# testenv-build - incrementally recompile and load new packages in running NSO
# See the nid/testenv-build script for more details.
testenv-build:
	for NSO in $$(docker ps --format '{{.Names}}' --filter label=$(CNT_PREFIX) --filter label=nidtype=nso); do \
		echo "-- Rebuilding for NSO: $${NSO}"; \
		docker run -it --rm -v $(PWD):/src --volumes-from $${NSO} --network=container:$${NSO} -e NSO=$${NSO} -e PACKAGE_RELOAD=$(PACKAGE_RELOAD) -e SKIP_LINT=$(SKIP_LINT) -e PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) /src/nid/testenv-build; \
	done

# testenv-clean-build - clean and rebuild from scratch
# We rsync (with --delete) in sources, which effectively is a superset of 'make
# clean' per package, as this will delete any built packages as well as removing
# old sources files that no longer exist. It also removes included packages and
# as we don't have those in the source repository, we must bring them in from
# the build container image where we previously pulled them in into the
# /includes directory. We start up the build image and copy the included
# packages to /var/opt/ncs/packages/ folder.
testenv-clean-build:
	for NSO in $$(docker ps --format '{{.Names}}' --filter label=$(CNT_PREFIX) --filter label=nidtype=nso); do \
		echo "-- Cleaning NSO: $${NSO}"; \
		docker run -it --rm -v $(PWD):/src --volumes-from $${NSO} $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) bash -lc 'rsync -aEim --delete /src/packages/. /var/opt/ncs/packages/ >/dev/null'; \
		echo "-- Copying in pristine included packages for NSO: $${NSO}"; \
		docker run -it --rm --volumes-from $${NSO} $(IMAGE_PATH)$(PROJECT_NAME)/build:$(DOCKER_TAG) cp -a /includes/. /var/opt/ncs/packages/; \
	done
	@echo "-- Done cleaning, rebuilding with forced package reload..."
	$(MAKE) testenv-build PACKAGE_RELOAD="true"

# testenv-stop - stop the testenv
# This finds the currently running containers that are part of our testenv based
# on their labels and then stops them, finally removing the docker network too.
# All containers that are part of our testenv must be started with the correct
# labels for this to work correctly. Use the variables DOCKER_ARGS or
# DOCKER_NSO_ARGS when running 'docker run', see testenv-start.
testenv-stop:
	docker ps -aq --filter label=$(CNT_PREFIX) | $(XARGS) docker rm -vf
	-docker network rm $(CNT_PREFIX)

testenv-shell:
	docker exec -it $(CNT_PREFIX)-nso$(NSO) bash -l

testenv-cli:
	docker exec -it $(CNT_PREFIX)-nso$(NSO) bash -lc 'ncs_cli -u admin'

testenv-runcmdC testenv-runcmdJ:
	@if [ -z "$(CMD)" ]; then echo "CMD variable must be set"; false; fi
	docker exec -t $(CNT_PREFIX)-nso$(NSO) bash -lc 'echo -e "$(CMD)" | ncs_cli --stop-on-error -$(subst testenv-runcmd,,$@)u admin'

.PHONY: all build dev-shell push push-release tag-release test testenv-build testenv-clean-build testenv-start testenv-stop testenv-test
