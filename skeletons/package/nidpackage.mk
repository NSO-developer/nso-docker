# Common Makefile for NSO in Docker package standard form.
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
	docker build $(DOCKER_BUILD_CACHE_ARG) --target testnso -t $(IMAGE_PATH)$(PROJECT_NAME)/testnso:$(DOCKER_TAG) --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) .
	docker build $(DOCKER_BUILD_CACHE_ARG) --target package -t $(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH) --build-arg NSO_VERSION=$(NSO_VERSION) --build-arg PKG_FILE=$(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) .

push:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG)

tag-release:
	docker tag $(IMAGE_PATH)$(PROJECT_NAME)/package:$(DOCKER_TAG) $(IMAGE_PATH)$(PROJECT_NAME)/package:$(NSO_VERSION)

push-release:
	docker push $(IMAGE_PATH)$(PROJECT_NAME)/package:$(NSO_VERSION)


dev-shell:
	docker run -it -v $$(pwd):/src $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION)

# Test environment targets

# testenv-start: start the test environment in a configuration that allows
# Python Remote Debugging. Exposes port 5678 on a random port on localhost.
testenv-start:
	docker network inspect $(CNT_PREFIX) >/dev/null 2>&1 || docker network create $(CNT_PREFIX)
	docker run -td --name $(CNT_PREFIX)-nso --network-alias nso $(DOCKER_NSO_ARGS) -e ADMIN_PASSWORD=NsoDocker1337 $${NSO_EXTRA_ARGS} $(IMAGE_PATH)$(PROJECT_NAME)/testnso:$(DOCKER_TAG)
	$(MAKE) testenv-start-extra
	$(MAKE) testenv-wait-started-nso

# testenv-dap-port: get the host port mapping for the DAP daemon in the container
testenv-dap-port:
	@docker inspect -f '{{(index (index .NetworkSettings.Ports "5678/tcp") 0).HostPort}}' $(CNT_PREFIX)-nso$(NSO)

# testenv-debug-vscode: modifies VSCode launch.json to connect the python remote
# debugger to the environment. Existing contents of the file are preserved.
# First check if the file exists, and if not, create a valid empty file. Next
# check if "Python: NID Remote Attach" debug config is present. If yes, update
# it, otherwise add a new one.
testenv-debug-vscode:
	@if [ ! -f .vscode/launch.json ]; then \
		mkdir -p .vscode; \
		echo '{"version": "0.2.0","configurations":[]}' > .vscode/launch.json; \
		echo "== Created .vscode/launch.json"; \
	fi; \
	HOST_PORT=$$($(MAKE) --no-print-directory testenv-dap-port); \
	LAUNCH_NO_COMMENTS=`sed '/\s*\/\/.*/d' .vscode/launch.json`; \
	if ! echo $${LAUNCH_NO_COMMENTS} | jq --exit-status "(.configurations[] | select(.name == \"Python: NID Remote Attach\"))" >/dev/null 2>&1; then \
		echo $${LAUNCH_NO_COMMENTS} | jq '.configurations += [{"name":"Python: NID Remote Attach","type":"python","request":"attach","port":'"$${HOST_PORT}"',"host":"localhost","pathMappings":[{"localRoot":"$${workspaceFolder}/packages","remoteRoot":"/nso/run/state/packages-in-use.cur/1"}]}]' > .vscode/launch.json; \
		echo "== Added \"Python: NID Remote Attach\" debug configuration"; \
	else \
		echo $${LAUNCH_NO_COMMENTS} | jq "(.configurations[] | select(.name == \"Python: NID Remote Attach\") | .port) = $${HOST_PORT}" > .vscode/launch.json; \
		echo "== Updated .vscode/launch.json for Python remote debugging"; \
	fi

# testenv-build - incrementally recompile and load new packages in running NSO
# See the nid/testenv-build script for more details.
testenv-build:
	for NSO in $$(docker ps --format '{{.Names}}' --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --filter label=com.cisco.nso.testenv.type=nso); do \
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
	for NSO in $$(docker ps --format '{{.Names}}' --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --filter label=com.cisco.nso.testenv.type=nso); do \
		echo "-- Cleaning NSO: $${NSO}"; \
		docker run -it --rm -v $(PWD):/src --volumes-from $${NSO} $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) bash -lc 'rsync -aEim --delete /src/packages/. /src/test-packages/. /var/opt/ncs/packages/ >/dev/null'; \
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
	docker ps -aq --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | $(XARGS) docker rm -vf
	-docker network rm $(CNT_PREFIX)

testenv-shell:
	docker exec -it $(CNT_PREFIX)-nso$(NSO) bash -l

testenv-cli:
	docker exec -it $(CNT_PREFIX)-nso$(NSO) bash -lc 'ncs_cli -u admin'

testenv-runcmdC testenv-runcmdJ:
	@if [ -z "$(CMD)" ]; then echo "CMD variable must be set"; false; fi
	docker exec -t $(CNT_PREFIX)-nso$(NSO) bash -lc 'echo -e "$(CMD)" | ncs_cli --noninteractive --stop-on-error -$(subst testenv-runcmd,,$@)u admin'

# Wait for all NSO instances in testenv to start up, as determined by `ncs
# --wait-started`, or display the docker log for the first failed NSO instance.
testenv-wait-started-nso:
	@for NSO in $$(docker ps --format '{{.Names}}' --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --filter label=com.cisco.nso.testenv.type=nso); do \
		docker exec -t $${NSO} bash -lc 'ncs --wait-started 600' || (echo "NSO instance $${NSO} failed to start in 600 seconds, displaying logs:"; docker logs $${NSO}; exit 1); \
		echo "NSO instance $${NSO} has started"; \
	done; \
	echo "All NSO instance have started"

# Find all NSO containers using the nidtype=nso and CNT_PREFIX labels, then
# save logs from /log. For all containers (NSO inclusive) save docker logs.
testenv-save-logs:
	@for nso in $$(docker ps -a --filter label=com.cisco.nso.testenv.type=nso --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --format '{{.Names}}'); do \
		NSO_SUFFIX=$$(echo $${nso} | sed "s/$(CNT_PREFIX)-//"); \
		echo "== Collecting NSO logs from $${NSO_SUFFIX}"; \
		mkdir -p $${NSO_SUFFIX}-logs; \
		docker exec $${nso} bash -lc 'ncs --debug-dump /log/debug-dump'; \
		docker exec $${nso} bash -lc 'ncs --printlog /log/ncserr.log > /log/ncserr.log.txt'; \
		docker cp $${nso}:/log $${NSO_SUFFIX}-logs; \
	done
	@for c in $$(docker ps -a --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --format '{{.Names}}'); do \
		mkdir -p docker-logs; \
		echo "== Collecting docker logs from $${c}"; \
		docker logs $${c} > docker-logs/$${c} 2>&1; \
	done


.PHONY: all build dev-shell push push-release tag-release test testenv-build testenv-clean-build testenv-start testenv-stop testenv-test testenv-wait-started-nso testenv-save-logs
