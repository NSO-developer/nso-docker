# We actually only need the NSO_VERSION variable as we don't have any dependency
# on the information about which FILE or FILENAME which was used to build an NSO
# image. However, if NSO_VERSION isn't set, we try to dig out the NSO version
# number from the FILE/FILENAME
ifeq ($(NSO_VERSION),)
FILENAME:=$(shell basename $(FILE))
NSO_VERSION:=$(shell echo $(FILENAME) | sed -E -e 's/(ncs|nso)-([0-9.]*).linux.x86_64.installer.bin/\2/')
endif

ifneq ($(CI_JOB_ID),)
CNT_PREFIX:=ci-$(CI_JOB_ID)
else
CNT_PREFIX:=$(shell whoami)
endif

# Set PNS - our pseudo-namespace or pipeline namespace. All containers running
# within a CI pipeline will have the same namespace, which isn't a namespace
# like what Linux supports but it's just a prefix used for the docker containers
# to guarantee uniqueness.
ifneq ($(CI_PIPELINE_ID),)
PNS:=$(CI_PIPELINE_ID)
else
ifneq ($(NSO_VERSION),)
PNS:=$(shell whoami)
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


.PHONY: test-post-start-script

test:
	@echo "\n== Building test Docker image"
	docker build $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG) --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) .

	@echo "\n== Running single-version test cases"
	$(MAKE) test-shutdown
	$(MAKE) test-error-exit-code
	$(MAKE) test-ncs-stop
	$(MAKE) test-admin-user
	$(MAKE) test-admin-user-custom
	$(MAKE) test-admin-user-sshkey
	$(MAKE) test-post-start-script
	$(MAKE) test-http-disabled
	$(MAKE) test-https-disabled
	$(MAKE) test-http-enabled
	$(MAKE) test-https-enabled
	$(MAKE) test-java
	$(MAKE) test-python
	$(MAKE) test-docker-healthcheck

	$(MAKE) test-multiver


test-multiver:
	@echo "\n== Building test Docker images for multi-version testing"
	docker build $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG) --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(OLD_DOCKER_TAG) .
	docker build $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG) --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) .

	@echo "\n== Running multi-version test cases"
	$(MAKE) test-cdb-persistence
	$(MAKE) test-backup-restore
	$(MAKE) test-run-time-ssh-key-gen
	$(MAKE) test-persistent-ssh-key
	$(MAKE) test-run-time-ssl-cert-gen
	$(MAKE) test-persistent-ssl-cert


test-shutdown:
	@echo "\n== Verify normal shutdown (using docker stop) of container works and exits with code 0"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
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
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Stop NSO, wait for it to stop and clean up"
	docker stop $(CNT_PREFIX)-$@
	docker logs $(CNT_PREFIX)-$@ | grep "NCS stopping"
	docker logs $(CNT_PREFIX)-$@ | grep "Daemon logging terminating"
	docker inspect --format '{{.State.Running}}' $(CNT_PREFIX)-$@ | grep -q "false"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Break the CDB persisted in the volume"
	docker run --rm -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG) bash -lc "echo 'BROKEN' > /nso/run/cdb/A.cdb"
	@echo "-- Start NSO in foreground - it should exit on CDB failure"
	-docker run --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker inspect --format '{{.State.Running}}' $(CNT_PREFIX)-$@ | grep -q "false"
	docker inspect --format '{{.State.ExitCode}}' $(CNT_PREFIX)-$@ | grep -q "^15$$"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker volume rm -f $(CNT_PREFIX)-$@



test-ncs-stop:
	@echo "\n== Verify container stops and returns correct exit code when ncs exits"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container"
	docker run -td --name $(CNT_PREFIX)-$@ $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Stop NSO"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --stop'
	@echo "-- Wait for container to stop"
	-docker logs -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Check that container is not running"
	docker inspect --format '{{.State.Running}}' $(CNT_PREFIX)-$@ | grep -q "false"
	docker inspect --format '{{.State.ExitCode}}' $(CNT_PREFIX)-$@ | grep -q "^0$$"
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-admin-user:
	@echo "\n== Verify adding admin user works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td --name $(CNT_PREFIX)-$@ -e ADMIN_PASSWORD=foobar $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that SSH login works"
	sshpass -p foobar ssh -F /dev/null -o IdentityAgent=none -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l admin $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) exit
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-admin-user-custom:
	@echo "\n== Verify adding custom admin user works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td --name $(CNT_PREFIX)-$@ -e ADMIN_USERNAME=kalle -e ADMIN_PASSWORD=foobar $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that SSH login works"
	sshpass -p foobar ssh -F /dev/null -o IdentityAgent=none -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -l kalle $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) exit
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-admin-user-sshkey:
	@echo "\n== Verify adding admin user with SSH key works"
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td --name $(CNT_PREFIX)-$@ -e ADMIN_SSHKEY="$(shell cat test_ssh_key.pub)" $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that SSH login works"
	chmod 0600 test_ssh_key
# prevent SSH from reading the normal SSH config of the user running the test
# suite through -F /dev/null and prevent ssh-agent use
	ssh -o IdentityAgent=none -o IdentitiesOnly=yes -F /dev/null -l admin -i test_ssh_key -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) exit
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-post-start-script:
	@echo "\n== Testing post-start script is run after NCS start"
	docker build $(DOCKER_BUILD_CACHE_ARG) -t $(CNT_PREFIX)-$@ --build-arg BASE_IMAGE=$(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG) --build-arg BUILD_IMAGE=$(DOCKER_REGISTRY)cisco-nso-dev:$(DOCKER_TAG) $@
	@echo "-- Clean any already running containers with 'our' name"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Start NSO container with admin password"
	docker run -td --name $(CNT_PREFIX)-$@ $(CNT_PREFIX)-$@
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
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
	@echo "-- Start NSO container with admin password"
	docker run -td --name $(CNT_PREFIX)-$@ -e SSH_PORT=2024 $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	@echo "-- Wait for NSO in container to start"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Test that SSH is listening on expected port"
	ssh-keyscan -p 2024 $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) | grep "Connection refused"; test $$? -eq 1
	@echo "-- Remove the container"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-http-disabled:
	@echo "\n== Verify that the HTTP webUI is disabled per default"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	curl --noproxy '*' $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) 2>&1 | grep "Connection refused"
	@echo "Connection to HTTP TCP port 80 was refused, I'm happy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-https-disabled:
	@echo "\n== Verify that the HTTP webUI is disabled per default"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	curl --noproxy '*' https://$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) 2>&1 | grep "Connection refused"
	@echo "Connection to HTTPS TCP port 443 was refused, I'm happy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-http-enabled:
	@echo "\n== Verify that the HTTP webUI works when enabled"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ --env HTTP_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	curl --noproxy '*' $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "Connection to HTTP (TCP port 80) was accepted, I'm happy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-https-enabled:
	@echo "\n== Verify that the HTTP webUI works when enabled"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	curl --noproxy '*' --insecure https://$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "Connection to HTTPS (TLS/TCP port 443) was accepted, I'm happy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-java:
	@echo "\n== Verify that a java package works"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-java java-test" | ncs_cli -u admin -g ncsadmin' | grep "Hello world from Java"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-python:
	@echo "\n== Verify that a Python package works"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "request testpkg-python python-test" | ncs_cli -u admin -g ncsadmin' | grep "Hello world from Python"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-docker-healthcheck:
	@echo "\n== Verify that docker healthcheck works"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Starting cisco-nso test container -------------------------------------------"
	docker run -td --name $(CNT_PREFIX)-$@ $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	@echo "-- Ensuring health is 'starting' -----------------------------------------------"
	docker inspect --format='{{.State.Health.Status}}' $(CNT_PREFIX)-$@ | grep "starting"
	@echo "-- Waiting for NCS to start ----------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	@echo "-- Waiting 5 seconds to allow healthcheck to run -------------------------------"
	sleep 5
	@echo "-- Ensuring health is 'healthy' ------------------------------------------------"
	docker inspect --format='{{.State.Health.Status}}' $(CNT_PREFIX)-$@ | grep "healthy"
	@echo "-- Fake an unresponsive NSO by STOP signal -------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'killall -STOP ncs.smp'
	@echo "-- Waiting 30 seconds to allow healthcheck retries and fail"
# It's 30 seconds because the checks run at the interval after the completion of
# the previous check. Reaching timeout constitutes completion (failed though).
# With an interval of 5 seconds, 3 retries and timeout of 5s we get 30 seconds
# as the spacing is essentially timeout+interval = 10s * 3 = 30s
	sleep 30
	@echo "-- Ensuring health is 'unhealthy' ----------------------------------------------"
	docker inspect --format='{{.State.Health.Status}}' $(CNT_PREFIX)-$@ | grep "unhealthy"
	@echo "-- Continue NSO execution"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'killall -CONT ncs.smp'
	@echo "-- Waiting 5 seconds to allow healthcheck to run -------------------------------"
	sleep 5
	@echo "-- Ensuring health is 'healthy' ------------------------------------------------"
	docker inspect --format='{{.State.Health.Status}}' $(CNT_PREFIX)-$@ | grep "healthy"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1


test-cdb-persistence:
	@echo "\n== Verify CDB is properly persisted on a docker volume"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	-docker volume rm -f $(CNT_PREFIX)-$@
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- Starting cisco-nso test container -------------------------------------------"
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg a-value 1337\ncommit\nexit" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin -g ncsadmin'
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Starting cisco-nso test container (second time) -----------------------------"
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin -g ncsadmin' | grep "a-value 1337;"
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Removing volume for cisco-nso test container --------------------------------"
	-docker volume rm -f $(CNT_PREFIX)-$@


test-backup-restore:
	@echo "\n== Verify that ncs-backup and restore works properly"
	rm -rf tmp
	mkdir -p tmp
	-docker rm -f $(CNT_PREFIX)-$@
	-docker rm -f $(CNT_PREFIX)-$@-helper
	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	-docker volume rm -f $(CNT_PREFIX)-$@
	docker volume create $(CNT_PREFIX)-$@
	@echo "-- Starting cisco-nso test container -------------------------------------------"
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show packages" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg a-value 1337\ncommit\nexit" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin -g ncsadmin'
	@echo "-- Taking backup ---------------------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs-backup'
	docker cp $(CNT_PREFIX)-$@:/nso/run/backups ./tmp/backups
	@echo "-- Do 'bad' change -------------------------------------------------------------"
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo -e "configure\nset testpkg a-value 1338\ncommit\nexit" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin -g ncsadmin'
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-$@
	@echo "-- Restore from backup ---------------------------------------------------------"
	docker run -td --name $(CNT_PREFIX)-$@-helper -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG) bash -lc 'read DUMMY'
	docker cp tmp/backups $(CNT_PREFIX)-$@-helper:/nso/run/backups
	docker exec -t $(CNT_PREFIX)-$@-helper bash -lc "ncs-backup --restore /nso/run/backups/*.gz --non-interactive"
	docker rm -f $(CNT_PREFIX)-$@-helper
	@echo "-- Starting cisco-nso test container (second time) -----------------------------"
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-$@ bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin -g ncsadmin' | grep "a-value 1337;"
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
	docker run -td --name $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) | awk '{ print $$3 }' > tmp/testrtskg1
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
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
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) | awk '{ print $$3 }' > tmp/testpsk1
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Starting cisco-nso test container, second invocation ------------------------"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
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
	docker run -td --name $(CNT_PREFIX)-$@ --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	echo | openssl s_client -showcerts -connect $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@):443 2>/dev/null | openssl x509 -inform pem -noout -text > tmp/testrtscg1

	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
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
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(OLD_DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	echo | openssl s_client -showcerts -connect $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@):443 2>/dev/null | openssl x509 -inform pem -noout -text > tmp/$@-1
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	@echo "-- Starting cisco-nso test container, second invocation ------------------------"
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ -v $(CNT_PREFIX)-$@:/nso --env HTTPS_ENABLE=true $(DOCKER_REGISTRY)cisco-nso-base:$(DOCKER_TAG)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started 600"
	echo | openssl s_client -showcerts -connect $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@):443 2>/dev/null | openssl x509 -inform pem -noout -text > tmp/$@-2
	-docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	-docker volume rm -f $(CNT_PREFIX)-$@
	@echo "-- Comparing output ------------------------"
	diff -u tmp/$@-1 tmp/$@-2 || (echo "ERROR: SSL cert different across runs, should be persisted" && exit 1)
	@echo "SSL cert are the same across invocations, I'm happy"


clean:
	-docker rmi $(CNT_PREFIX)-test-cisco-nso-$(OLD_DOCKER_TAG) $(CNT_PREFIX)-test-cisco-nso-$(DOCKER_TAG) $(CNT_PREFIX)-test-post-start-script
