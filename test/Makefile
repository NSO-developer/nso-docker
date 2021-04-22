# We actually only need the NSO_VERSION variable as we don't have any dependency
# on the information about which FILE or FILENAME which was used to build an NSO
# image. However, if NSO_VERSION isn't set, we try to dig out the NSO version
# number from the FILE/FILENAME
ifeq ($(NSO_VERSION),)
FILENAME:=$(shell basename $(FILE))
NSO_VERSION:=$(shell echo $(FILENAME) | sed -E -e 's/(ncs|nso)-([0-9.]*).linux.x86_64.installer.bin/\2/')
endif
NSO_VERSION_MAJOR=$(word 1,$(subst ., ,$(NSO_VERSION)))
NSO_VERSION_MINOR=$(word 2,$(subst ., ,$(subst _, ,$(NSO_VERSION))))

ifneq ($(CI_JOB_ID),)
CNT_PREFIX:=ci-$(CI_JOB_ID)
else
CNT_PREFIX:=$(shell whoami | sed 's/[^[:alnum:]._-]\+/_/g')
endif

# Set PNS - our pseudo-namespace or pipeline namespace. All containers running
# within a CI pipeline will have the same namespace, which isn't a namespace
# like what Linux supports but it's just a prefix used for the docker containers
# to guarantee uniqueness.
ifneq ($(CI_PIPELINE_ID),)
PNS:=$(CI_PIPELINE_ID)
else
ifneq ($(NSO_VERSION),)
PNS:=$(shell whoami | sed 's/[^[:alnum:]._-]\+/_/g')
endif
endif
# set the docker tag to use, if not already set
DOCKER_TAG?=$(NSO_VERSION)-$(PNS)

# Part of the test cases support testing across NSO versions, i.e. going from
# one version of NSO to another. Through the OLD_DOCKER_TAG variable we specify
# the old image tag. If not explicitly set, we will try to derive it's value
# from OLD_NSO_VERSION and if that is not set, we will use the same value as for
# DOCKER_TAG, i.e. run the tests with a single version of NSO
ifeq ($(OLD_DOCKER_TAG),)
ifneq ($(OLD_NSO_VERSION),)
OLD_DOCKER_TAG=$(OLD_NSO_VERSION)-$(PNS)
else
OLD_DOCKER_TAG=$(DOCKER_TAG)
endif
endif

ifneq ($(shell uname -m),x86_64)
DOCKER_PLATFORM_ARG ?= $(DOCKER_PLATFORM_ARG)
endif

IPV6?=true

.PHONY: test-post-start-script test-cdb-default

build-test-image:
	@echo "\n== Building test Docker image"
	docker build $(DOCKER_PLATFORM_ARG) $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG) --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) .

test:
	$(MAKE) build-test-image
	@echo "\n== Running single-version test cases"
	$(MAKE) test-version-gen
	$(MAKE) test-dev-entrypoint
	$(MAKE) test-shutdown
	$(MAKE) test-error-exit-code
	$(MAKE) test-ncs-stop
	$(MAKE) test-nso-restart
	$(MAKE) test-logrotate
	$(MAKE) test-admin-user
	$(MAKE) test-admin-user-custom
	$(MAKE) test-admin-user-sshkey
	$(MAKE) test-netconf
	$(MAKE) test-post-start-script
	$(MAKE) test-http-disabled
	$(MAKE) test-https-disabled
	$(MAKE) test-http-enabled
	$(MAKE) test-https-enabled
	$(MAKE) test-java
	$(MAKE) test-python
	$(MAKE) test-python-dap
	$(MAKE) test-docker-healthcheck
	$(MAKE) test-cdb-default
	$(MAKE) test-config-on-volume
	$(MAKE) test-mounted-config
	$(MAKE) test-no-ha
	$(MAKE) test-ha-old
	if [ $(NSO_VERSION_MAJOR) -ge 5 ] && [ $(NSO_VERSION_MINOR) -ge 4 ]; then $(MAKE) test-ha-new; fi

	$(MAKE) test-multiver

build-multiver-test-images:
	docker build $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG) --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(OLD_DOCKER_TAG) .
	docker build $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG) --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) .

test-multiver:
	@echo "\n== Building test Docker images for multi-version testing"
	$(MAKE) build-multiver-test-images

	@echo "\n== Running multi-version test cases"
	$(MAKE) test-cdb-persistence
	$(MAKE) test-backup-restore
	$(MAKE) test-backup-restore-nonempty-volume
	$(MAKE) test-run-time-ssh-key-gen
	$(MAKE) test-persistent-ssh-key
	$(MAKE) test-run-time-ssl-cert-gen
	$(MAKE) test-persistent-ssl-cert

test-version-gen:
	python3 test_version-gen.py

########################
# Single Version tests #
########################

test-dev-entrypoint:
	@echo "\n== Verify magic entrypoint of -dev images works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Verify that starting the -dev image without args results in an interactive shell"
	NSO_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) CNT_NAME=$(CNT_PREFIX)-$@ expect expect-dev-entrypoint.script
	@echo "-- Clean up after us"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Verify docker run correctly passes arguments. In this case we should"
	@echo "   pass '/proc/self/cgroup' to 'ls' and the output should thus be"
	@echo "   '/proc/self/cgroup' which we grep on. Note how the '| grep ...' part"
	@echo "   is run in our normal shell invoked by make, outside of the container."
	@echo "   It is only the last arguments to docker run that are fed into the"
	@echo "   container entrypoint."
	docker run -t --rm $(DOCKER_PLATFORM_ARG) $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) ls /proc/self/cgroup | grep /proc/self/cgroup
	@echo "-- Verify docker run works with nested call to bash -lc. In particular"
	@echo "   that quoted inner argument works for preserving white space. Test"
	@echo "   by passing argument with whitespace to 'cat' and verify error"
	@echo "   message is as expected."
	docker run -t --rm $(DOCKER_PLATFORM_ARG) $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) bash -lc 'cat "foo bar"' | grep "cat: 'foo bar': No such file or directory"


test-shutdown:
	@echo "\n== Verify normal shutdown (using docker stop) of container works and exits with code 0"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker stop $(CNT_PREFIX)-$@
	docker logs $(CNT_PREFIX)-$@ | grep "NCS stopping"
	docker logs $(CNT_PREFIX)-$@ | grep "Daemon logging terminating"
	docker inspect --format '{{.State.Running}}' $(CNT_PREFIX)-$@ | grep -q "false"
	docker inspect --format '{{.State.ExitCode}}' $(CNT_PREFIX)-$@ | grep -q "^143$$"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-error-exit-code:
	@echo "\n== Verify container exits with code 15 on error"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Clean and setup volume"
	-docker volume rm -f $(CNT_PREFIX)-$@
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- Start NSO to write initial CDB"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Stop NSO, wait for it to stop and clean up"
	docker stop $(CNT_PREFIX)-$@
	docker logs $(CNT_PREFIX)-$@ | grep "NCS stopping"
	docker logs $(CNT_PREFIX)-$@ | grep "Daemon logging terminating"
	docker inspect --format '{{.State.Running}}' $(CNT_PREFIX)-$@ | grep -q "false"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Break the CDB persisted in the volume"
	docker run --rm $(DOCKER_PLATFORM_ARG) --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) bash -lc "echo 'BROKEN' > /nso/run/cdb/A.cdb"
	@echo "-- Start NSO in foreground - it should exit on CDB failure"
	-docker run --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker inspect --format '{{.State.Running}}' $(CNT_PREFIX)-$@ | grep -q "false"
	docker inspect --format '{{.State.ExitCode}}' $(CNT_PREFIX)-$@ | grep -q "^15$$"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker volume rm -f $(CNT_PREFIX)-$@



test-ncs-stop:
	@echo "\n== Verify container stops and returns correct exit code when ncs exits"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Stop NSO - ignoring return code because NSO 5.4 returns non-0, which should be fine here, as long as main return code, as seen by docker inspect, is 0"
	-docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --stop'
	@echo "-- Wait for container to stop"
	-docker logs -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Check that container is not running"
	docker inspect --format '{{.State.Running}}' $(CNT_PREFIX)-$@ | grep -q "false"
	docker inspect --format '{{.State.ExitCode}}' $(CNT_PREFIX)-$@ | grep -q "^0$$"
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-nso-restart:
	@echo "\n== Verify NSO restarts on SIGHUP to container"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container"
	docker run -td --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Restart NSO process in container"
	docker kill --signal HUP $(CNT_PREFIX)-$@
	@echo "-- Check that NSO process restarted, we should see 2 'starting' messages... (for some reason we get double messages, but can unique them based on pid)"
	I=0; while true; do \
		docker logs $(CNT_PREFIX)-$@ 2>&1 | grep "^ncs.*Starting NCS vsn:" | uniq | wc -l | grep "^2$$" && EXIT_CODE=true && break; \
		if [ $${I} -gt 30 ]; then echo "Timed out waiting for NSO to restart"; EXIT_CODE=false; break; fi; \
		sleep 1; I=$$((I+1)); \
	done; $$($${EXIT_CODE})
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-admin-user:
	@echo "\n== Verify adding admin user works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -e ADMIN_PASSWORD=foobar $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that SSH login works"
	USERNAME=admin NSO_IP=$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) expect expect-ssh-login-password.script
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-admin-user-custom:
	@echo "\n== Verify adding custom admin user works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -e ADMIN_USERNAME=kalle -e ADMIN_PASSWORD=foobar $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that SSH login works"
	USERNAME=kalle NSO_IP=$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) expect expect-ssh-login-password.script
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-admin-user-sshkey:
	@echo "\n== Verify adding admin user with SSH key works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -e ADMIN_SSHKEY="$(shell cat test_ssh_key.pub)" $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that SSH login works"
	chmod 0600 test_ssh_key
# prevent SSH from reading the normal SSH config of the user running the test
# suite through -F /dev/null and prevent ssh-agent use
	NSO_IP=$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) expect expect-ssh-login-key.script
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-post-start-script:
	@echo "\n== Testing post-start script is run after NCS start"
	docker build $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-$@ --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) $@
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(CNT_PREFIX)-$@
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Verify that our post-start script ran by grepping in the container log"
	docker logs -f $(CNT_PREFIX)-$@ | grep -m 1 "post-start-script result"
	docker logs $(CNT_PREFIX)-$@ | grep "post-start-script result: success"
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Remove the container image"
	-docker rmi $(CNT_PREFIX)-$@


test-ssh-custom-port:
	@echo "\n== Verify configuring custom SSH port works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Create network"
	docker network inspect $(CNT_PREFIX)-$@ >/dev/null 2>&1 || docker network create $(CNT_PREFIX)-$@ $(shell [ "$(IPV6)" = "true" ] && LC_ALL=C && echo --ipv6 --subnet $${IPV6_NET:-fd00:$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):}:/64)
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ -e SSH_PORT=2024 $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that SSH is listening on expected port"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) ssh-keyscan -p 2024 $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) | grep "Connection refused"; test $$? -eq 1
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) ssh-keyscan -p 2024 $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' $(CNT_PREFIX)-$@) | grep "Connection refused"; test $$? -eq 1
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-netconf:
	@echo "\n== Verify NETCONF northbound works on port 830"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Create network"
	docker network inspect $(CNT_PREFIX)-$@ >/dev/null 2>&1 || docker network create $(CNT_PREFIX)-$@ $(shell [ "$(IPV6)" = "true" ] && LC_ALL=C && echo --ipv6 --subnet $${IPV6_NET:-fd00:$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):}:/64)
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ --env ADMIN_PASSWORD=admin $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that NETCONF works on port 830"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) netconf-console --host $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) --port 830 --hello >/dev/null
	@echo "-- NETCONF <hello> received"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) netconf-console --host $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' $(CNT_PREFIX)-$@) --port 830 --hello >/dev/null
	@echo "-- NETCONF <hello> received over IPv6"
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-http-disabled:
	@echo "\n== Verify that the HTTP webUI is disabled per default"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	curl --noproxy '*' $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) 2>&1 | grep "Connection refused"
	@echo "Connection to HTTP TCP port 80 was refused, I'm happy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-https-disabled:
	@echo "\n== Verify that the HTTP webUI is disabled per default"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	curl --noproxy '*' https://$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) 2>&1 | grep "Connection refused"
	@echo "Connection to HTTPS TCP port 443 was refused, I'm happy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-http-enabled:
	@echo "\n== Verify that the HTTP webUI works when enabled"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Create network"
	docker network inspect $(CNT_PREFIX)-$@ >/dev/null 2>&1 || docker network create $(CNT_PREFIX)-$@ $(shell [ "$(IPV6)" = "true" ] && LC_ALL=C && echo --ipv6 --subnet $${IPV6_NET:-fd00:$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):}:/64)
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ --env HTTP_ENABLE=true --env ADMIN_PASSWORD=admin $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "Connection to HTTP (TCP port 80) was accepted, I'm happy"
	@echo "\n== Verify that the HTTP webUI works over IPv6 when enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' -g http://[$$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' $(CNT_PREFIX)-$@)] >/dev/null
	@echo "Connection to HTTP (TCP port 80) via IPv6 was accepted, I'm happy"
	@echo "\n== Verify that RESTCONF works over HTTP when enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl -u admin:admin --noproxy '*' -H "Accept: application/yang-data+xml" http://$$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@)/restconf | grep yang-library-version >/dev/null
	@echo "Connection to RESTCONF (TCP port 80) was accepted, I'm happy"
	@echo "\n== Verify that RESTCONF works over HTTP and IPv6 when enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl -u admin:admin --noproxy '*' -H "Accept: application/yang-data+xml" -g http://[$$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' $(CNT_PREFIX)-$@)]/restconf | grep yang-library-version >/dev/null
	@echo "Connection to RESTCONF (TCP port 80) via IPv6 was accepted, I'm happy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-https-enabled:
	@echo "\n== Verify that the HTTPS webUI works when enabled"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Create network"
	docker network inspect $(CNT_PREFIX)-$@ >/dev/null 2>&1 || docker network create $(CNT_PREFIX)-$@ $(shell [ "$(IPV6)" = "true" ] && LC_ALL=C && echo --ipv6 --subnet $${IPV6_NET:-fd00:$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):}:/64)
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ --env HTTPS_ENABLE=true --env ADMIN_PASSWORD=admin $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' --insecure https://$$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "Connection to HTTPS (TLS/TCP port 443) was accepted, I'm happy"
	@echo "\n== Verify that the HTTPS webUI works over IPv6 when enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' --insecure -g https://[$$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' $(CNT_PREFIX)-$@)] >/dev/null; \
	echo "Connection to HTTPS (TLS/TCP port 443) via IPv6 was accepted, I'm happy"
	@echo "\n== Verify that RESTCONF works over HTTPS when enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl -u admin:admin --noproxy '*' --insecure -H "Accept: application/yang-data+xml" https://$$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@)/restconf | grep yang-library-version >/dev/null
	@echo "Connection to RESTCONF (TLS/TCP port 443) was accepted, I'm happy"
	@echo "\n== Verify that RESTCONF works over HTTPS and IPv6 when enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl -u admin:admin --noproxy '*' --insecure -H "Accept: application/yang-data+xml" -g https://[$$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.GlobalIPv6Address}}{{end}}' $(CNT_PREFIX)-$@)]/restconf | grep yang-library-version >/dev/null
	@echo "Connection to RESTCONF (TCP port 443) via IPv6 was accepted, I'm happy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-java:
	@echo "\n== Verify that a java package works"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-java java-test" | ncs_cli -u admin' | grep "Hello world from Java"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-python:
	@echo "\n== Verify that a Python package works"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin' | grep oper-status.up | wc -l | grep '^\s*5$$'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python python-test" | ncs_cli -u admin' | grep "Hello world from Python"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-pyvenv-a python-test" | ncs_cli -u admin' | grep "Lorum"
	@echo "\n== Verify that Python remote debugging is disabled"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'sleep 1 | telnet localhost 5678' | grep 'Unable to connect to remote host'
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-python-dap:
	@echo "\n== Verify that Python remote debugging works (via Debug Adapter Protocol)"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -e DEBUGPY=python-test-package $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	NSO_IP=$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) expect expect-dap.script
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-no-ha:
	@echo "\n== Verify HA is disabled per default"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show ncs-state ha mode" | ncs_cli -u admin' | grep "No entries found"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


# This limited HA test is used on NSO < 5.4 where HA roles can only be assigned
# in code. We could include a package that uses the HA API but the one from
# examples is also broken ...
test-ha-old:
	@echo "\n== Verify we can enable HA via environment variable"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -e HA_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Node starts up in 'none' mode"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show ncs-state ha mode" | ncs_cli -u admin' | grep "none"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


# This HA test sets up two nodes to verify HA operation. The nodes are
# configured with the tailf-ncs-high-availability.yang module and is only
# supported in NSO >= 5.4.
test-ha-new:
	@echo "\n== Verify we can enable HA via environment variable"
	mkdir -p tmp-$@
	-docker rm -f $(CNT_PREFIX)-$@-1 >/dev/null 2>&1
	-docker rm -f $(CNT_PREFIX)-$@-2 >/dev/null 2>&1
	-docker volume rm $(CNT_PREFIX)-$@ > /dev/null 2>&1
# The encryption keys must be kept in sync to ensure both nodes can decrypt
# encrypted leaves. Create a volume for sharing the /nso/etc/ncs.crypto_keys
# file between containers. Wait until the first container is up before starting
# the second to avoid a race creating the file.
	docker volume create $(CNT_PREFIX)-$@
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@-1 --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -e HA_ENABLE=true -e NCS_HA_NODE=n1 -v $(CNT_PREFIX)-$@:/nso/etc $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@-1 bash -lc 'ncs --wait-started 600'
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@-2 --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -e HA_ENABLE=true -e NCS_HA_NODE=n2 -v $(CNT_PREFIX)-$@:/nso/etc $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@-2 bash -lc 'ncs --wait-started 600'
	@echo "-- Load HA config"
	cp high-availability.xml tmp-$@/
	sed -i "s/N1_ADDRESS/$$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@-1)/" tmp-$@/high-availability.xml
	sed -i "s/N2_ADDRESS/$$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@-2)/" tmp-$@/high-availability.xml
	docker cp tmp-$@/high-availability.xml $(CNT_PREFIX)-$@-1:/
	docker cp tmp-$@/high-availability.xml $(CNT_PREFIX)-$@-2:/
	docker exec -t $(CNT_PREFIX)-$@-1 bash -lc 'ncs --mergexmlfiles /high-availability.xml'
	docker exec -t $(CNT_PREFIX)-$@-2 bash -lc 'ncs --mergexmlfiles /high-availability.xml'
	@echo "-- Node starts up in 'none' mode"
	docker exec -t $(CNT_PREFIX)-$@-1 bash -lc 'echo "show ncs-state ha mode" | ncs_cli -u admin' | grep "none"
	docker exec -t $(CNT_PREFIX)-$@-2 bash -lc 'echo "show ncs-state ha mode" | ncs_cli -u admin' | grep "none"
	@echo "-- Enable HA (n1=master)"
	docker exec -t $(CNT_PREFIX)-$@-1 bash -lc 'echo "request high-availability enable" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@-2 bash -lc 'echo "request high-availability enable" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@-1 bash -lc 'echo "show ncs-state ha mode" | ncs_cli -u admin' | grep "master"
	docker exec -t $(CNT_PREFIX)-$@-2 bash -lc 'echo "show ncs-state ha mode" | ncs_cli -u admin' | grep "slave"
	@echo "-- Failover HA (n2=master)"
	docker exec -t $(CNT_PREFIX)-$@-2 bash -lc 'echo "request high-availability be-master" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@-1 bash -lc 'echo "request high-availability be-slave-to node n2" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@-1 bash -lc 'echo "show ncs-state ha mode" | ncs_cli -u admin' | grep "slave"
	docker exec -t $(CNT_PREFIX)-$@-2 bash -lc 'echo "show ncs-state ha mode" | ncs_cli -u admin' | grep "master"
	rm -rf tmp-$@
	-docker rm -f $(CNT_PREFIX)-$@-1 >/dev/null 2>&1
	-docker rm -f $(CNT_PREFIX)-$@-2 >/dev/null 2>&1
	-docker volume rm $(CNT_PREFIX)-$@ > /dev/null 2>&1


test-docker-healthcheck:
	@echo "\n== Verify that docker healthcheck works"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Starting cisco-nso test container -------------------------------------------"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Ensuring health is 'starting' -----------------------------------------------"
	docker inspect --format='{{.State.Health.Status}}' $(CNT_PREFIX)-$@ | grep "starting"
	@echo "-- Waiting for NCS to start ----------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Waiting 5+1 seconds to allow healthcheck to run -------------------------------"
	sleep 6
	@echo "-- Ensuring health is 'healthy' ------------------------------------------------"
	docker inspect --format='{{.State.Health.Status}}' $(CNT_PREFIX)-$@ | grep "healthy"
	@echo "-- Fake an unresponsive NSO by STOP signal -------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'killall -STOP ncs.smp'
	@echo "-- Waiting 30+1 seconds to allow healthcheck retries and fail"
# It's 31 seconds because the checks run at the interval after the completion of
# the previous check. Reaching timeout constitutes completion (failed though).
# With an interval of 5 seconds, 3 retries and timeout of 5s we get 30 seconds
# as the spacing is essentially timeout+interval = 10s * 3 = 30s.. plus a margin
# of one second.
	sleep 31
	@echo "-- Ensuring health is 'unhealthy' ----------------------------------------------"
	docker inspect --format='{{.State.Health.Status}}' $(CNT_PREFIX)-$@ | grep "unhealthy"
	@echo "-- Continue NSO execution"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'killall -CONT ncs.smp'
	@echo "-- Waiting 5+1 seconds to allow healthcheck to run -------------------------------"
	sleep 6
	@echo "-- Ensuring health is 'healthy' ------------------------------------------------"
	docker inspect --format='{{.State.Health.Status}}' $(CNT_PREFIX)-$@ | grep "healthy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-cdb-default:
	@echo "\n== Verify CDB is properly persisted on a docker volume"
	docker build $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-$@ --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) $@
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(CNT_PREFIX)-$@
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Verify that our post-start script ran by grepping in the container log"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration devices authgroup" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration devices authgroup" | ncs_cli -u admin' | grep "foobarmagicstring"
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Remove the container image"
	-docker rmi $(CNT_PREFIX)-$@


test-config-on-volume:
	@echo "\n== Verify configuration is read from a docker volume"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Create network"
	docker network inspect $(CNT_PREFIX)-$@ >/dev/null 2>&1 || docker network create $(CNT_PREFIX)-$@ $(shell [ "$(IPV6)" = "true" ] && LC_ALL=C && echo --ipv6 --subnet $${IPV6_NET:-fd00:$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):}:/64)
	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	-docker volume rm -f $(CNT_PREFIX)-$@
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- Start NSO to let it generate an ncs.conf with HTTP enabled"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso --env HTTP_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Verify HTTP is enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "-- Copy the config file to the persistent volume"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'cp /etc/ncs/ncs.conf /nso/etc/ncs.conf'
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Start NSO, without enabling HTTP (but it should be enabled since we now use config from volume)"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Verify HTTP is enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Start NSO, forcing config mangling and explicitly disable HTTP"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso --env MANGLE_CONFIG=true --env HTTP_ENABLE=false $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Verify HTTP is disabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) 2>&1 | grep "Connection refused"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker volume rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-mounted-config:
	@echo "\n== Verify mounted configuration is used"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Create network"
	docker network inspect $(CNT_PREFIX)-$@ >/dev/null 2>&1 || docker network create $(CNT_PREFIX)-$@ $(shell [ "$(IPV6)" = "true" ] && LC_ALL=C && echo --ipv6 --subnet $${IPV6_NET:-fd00:$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):}:/64)
	@echo "-- Start NSO to let it generate an ncs.conf with HTTP enabled"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso --env HTTP_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Verify HTTP is enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "-- Copy the config file to our temp dir"
	mkdir -p tmp-$@
	docker cp $(CNT_PREFIX)-$@:/etc/ncs/ncs.conf tmp-$@/ncs.conf
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Start NSO, without enabling HTTP (but it should be enabled since we now use a mounted config)"
	@echo "Fakes using a volume like -v tmp-$@/ncs.conf:/etc/ncs/ncs.conf by running create & start "
	docker create -t --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker cp tmp-$@/ncs.conf $(CNT_PREFIX)-$@:/etc/ncs/ncs.conf
	docker start $(CNT_PREFIX)-$@
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Verify HTTP is enabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Start NSO, forcing config mangling and explicitly disable HTTP"
	@echo "Fakes using a volume like -v tmp-$@/ncs.conf:/etc/ncs/ncs.conf by running create & start "
	docker create -t --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --network $(CNT_PREFIX)-$@ --env MANGLE_CONFIG=true --env HTTP_ENABLE=false $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker cp tmp-$@/ncs.conf $(CNT_PREFIX)-$@:/etc/ncs/ncs.conf
	docker start $(CNT_PREFIX)-$@
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Verify HTTP is disabled"
	docker run --rm $(DOCKER_PLATFORM_ARG) --network $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) curl --noproxy '*' $$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(CNT_PREFIX)-$@) 2>&1 | grep "Connection refused"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker network rm $(CNT_PREFIX)-$@ >/dev/null 2>&1
	rm -rf tmp-$@


#######################
# Multi Version tests #
#######################

test-cdb-persistence:
	@echo "\n== Verify CDB is properly persisted on a docker volume"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	-docker volume rm -f $(CNT_PREFIX)-$@
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- Starting cisco-nso test container -------------------------------------------"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin'
	@echo "-- Store a value ---------------------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg-python a-value 1337\ncommit\nexit" | ncs_cli -u admin'
	@echo "-- Store an encrypted value ---------------------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg-python encrypted-value 1338\ncommit\nexit" | ncs_cli -u admin'
	@echo "-- Ensure we can decrypt encrypted value --------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python decrypt" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python decrypt" | ncs_cli -u admin' | grep "cleartext: 1338"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg-python" | ncs_cli -u admin'
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Starting cisco-nso test container (second time) -----------------------------"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg-python" | ncs_cli -u admin'
	@echo "-- Validate stored value -------------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg-python a-value" | ncs_cli -u admin' | grep "a-value 1337;"
	@echo "-- Validate encrypted value ----------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python decrypt" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python decrypt" | ncs_cli -u admin' | grep "cleartext: 1338"
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Removing volume for cisco-nso test container --------------------------------"
	-docker volume rm -f $(CNT_PREFIX)-$@


test-backup-restore-nonempty-volume:
	$(MAKE) test-backup-restore NONEMPTY_VOLUME=true

test-backup-restore:
	@echo "\n== Verify that ncs-backup and restore works properly"
	rm -rf tmp
	mkdir -p tmp
	-docker rm -f $(CNT_PREFIX)-$@
	-docker rm -f $(CNT_PREFIX)-$@-helper
	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	-docker volume rm -f $(CNT_PREFIX)-$@
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- If NONEMPTY_VOLUME=true, create a file in volume, so the volume is non-empty --------------------------------"
	[ "$(NONEMPTY_VOLUME)" = "true" ] && docker run -t --rm --name $(CNT_PREFIX)-$@-helper --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/vol $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) touch /vol/foo || true
	@echo "-- Starting cisco-nso test container -------------------------------------------"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg a-value 1337\ncommit\nexit" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg-python encrypted-value 42\ncommit\nexit" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python decrypt" | ncs_cli -u admin' | grep "cleartext: 42"
	@echo "-- Taking backup ---------------------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs-backup'
	docker cp $(CNT_PREFIX)-$@:/nso/run/backups ./tmp/backups
	@echo "-- Copying /nso/etc/ncs.crypto_keys --------------------------------------------"
	docker cp $(CNT_PREFIX)-$@:/nso/etc/ncs.crypto_keys ./tmp/
	@echo "-- Do 'bad' change -------------------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg a-value 1338\ncommit\nexit" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg-python encrypted-value 43\ncommit\nexit" | ncs_cli -u admin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python decrypt" | ncs_cli -u admin'
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Recreate the data volume to ensure everything was backed up -----------------"
	docker volume rm -f $(CNT_PREFIX)-$@
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- If NONEMPTY_VOLUME=true, create a file in volume, so the volume is non-empty --------------------------------"
	[ "$(NONEMPTY_VOLUME)" = "true" ] && docker run -t --rm --name $(CNT_PREFIX)-$@-helper --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/vol $(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) touch /vol/foo || true
	@echo "-- Restore from backup ---------------------------------------------------------"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@-helper --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG) bash -lc 'read DUMMY'
	docker exec -t $(CNT_PREFIX)-$@-helper mkdir -p /nso/run /nso/etc
	docker cp tmp/backups/. $(CNT_PREFIX)-$@-helper:/nso/run/backups
	docker cp tmp/ncs.crypto_keys $(CNT_PREFIX)-$@-helper:/nso/etc/ncs.crypto_keys
	docker exec -t $(CNT_PREFIX)-$@-helper bash -lc "ncs-backup --restore /nso/run/backups/*.gz --non-interactive"
	docker rm -f $(CNT_PREFIX)-$@-helper
	@echo "-- Starting cisco-nso test container (second time) -----------------------------"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin' | grep "a-value 1337;"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python decrypt" | ncs_cli -u admin' | grep "cleartext: 42"
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@


test-run-time-ssh-key-gen:
	@echo "\n== Verify that SSH keys are generated at runtime"
	@echo "Starts the NSO container twice and ensure the SSH keys are different."
	@echo "SSH keys are written to the /nso directory which can be shared mounted so"
	@echo "it is trivial to persist over time."
	mkdir -p tmp
	rm -rf tmp/testrtskg*
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) | awk '{ print $$3 }' > tmp/testrtskg1
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) | awk '{ print $$3 }' > tmp/testrtskg2
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	ret=0; diff -u tmp/testrtskg1 tmp/testrtskg2; \
	[ $$? -eq 0 ] && echo "ERROR: SSH key identical, should be different per run" && ret=1; exit $$ret
	@echo "SSH keys are different across invocations, I'm happy"


test-persistent-ssh-key:
	@echo "\n== Verify that SSH key is persisted on shared volume"
	mkdir -p tmp
	rm -rf tmp/testpsk*
	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	-docker volume rm -f $(CNT_PREFIX)-$@
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- Starting cisco-nso test container, first invocation -------------------------"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) | awk '{ print $$3 }' > tmp/testpsk1
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Starting cisco-nso test container, second invocation ------------------------"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) | awk '{ print $$3 }' > tmp/testpsk2
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker volume rm -f $(CNT_PREFIX)-$@
	@echo "-- Comparing output ------------------------"
	diff -u tmp/testpsk1 tmp/testpsk2 || (echo "ERROR: SSH key different across runs, should be persisted" && exit 1)
	@echo "SSH keys are the same across invocations, I'm happy"


test-run-time-ssl-cert-gen:
	@echo "\n== Verify that SSL certs are generated at runtime"
	@echo "Starts the NSO container twice and ensure the SSL certs are different."
	@echo "SSL certs are written to the /nso directory which can be shared mounted so"
	@echo "it is trivial to persist over time."
	mkdir -p tmp
	rm -rf tmp/testrtscg*
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	echo | openssl s_client -showcerts -connect $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@):443 2>/dev/null | openssl x509 -inform pem -noout -text > tmp/testrtscg1

	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	echo | openssl s_client -showcerts -connect $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@):443 2>/dev/null | openssl x509 -inform pem -noout -text > tmp/testrtscg2
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	ret=0; diff -u tmp/testrtscg1 tmp/testrtscg2; \
	[ $$? -eq 0 ] && echo "ERROR: SSL cert identical, should be different per run" && ret=1; exit $$ret
	@echo "SSL cert are different across invocations, I'm happy"


test-persistent-ssl-cert:
	@echo "\n== Verify that SSL cert is persisted on shared volume"
	mkdir -p tmp
	rm -rf tmp/$@*
	@echo "-- Clean up (from potential previous run) --------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker volume rm -f $(CNT_PREFIX)-$@
	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- Starting cisco-nso test container, first invocation -------------------------"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	echo | openssl s_client -showcerts -connect $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@):443 2>/dev/null | openssl x509 -inform pem -noout -text > tmp/$@-1
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Starting cisco-nso test container, second invocation ------------------------"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) -v $(CNT_PREFIX)-$@:/nso --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	echo | openssl s_client -showcerts -connect $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@):443 2>/dev/null | openssl x509 -inform pem -noout -text > tmp/$@-2
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker volume rm -f $(CNT_PREFIX)-$@
	@echo "-- Comparing output ------------------------"
	diff -u tmp/$@-1 tmp/$@-2 || (echo "ERROR: SSL cert different across runs, should be persisted" && exit 1)
	@echo "SSL cert are the same across invocations, I'm happy"

test-logrotate:
	@echo "\n== Verify logrotate works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container"
	docker run -td $(DOCKER_PLATFORM_ARG) --name $(CNT_PREFIX)-$@ --label com.cisco.nso.testenv.name=$(CNT_PREFIX) $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Run logrotate with --force"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'logrotate --verbose --force /etc/logrotate.conf'
	@echo "-- Verify logs were rotated"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ls /log/' | grep "devel\.log\.1\.gz"
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1

clean:
# stop all containers with out CNT_PREFIX
	-docker ps -aqf label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | xargs --no-run-if-empty docker rm -f
	-docker rmi $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG) $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG) $(CNT_PREFIX)-test-post-start-script
# errors from previous command are ignored but make will still exit with the
#	exit code of the last command and since we don't want CI to fail we return
	true
