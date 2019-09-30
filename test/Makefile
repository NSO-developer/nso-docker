FILENAME:=$(shell basename $(FILE))
NCS_VERSION:=$(shell echo $(FILENAME) | sed -r -e 's/(ncs|nso)-([0-9.]*).linux.x86_64.installer.bin/\2/')

ifneq ($(CI_JOB_ID),)
CNT_PREFIX:=ci-$(CI_JOB_ID)
else
CNT_PREFIX:=$(shell whoami)
endif

# what to do?
# provided a base image, like cisco-nso:4.7.5
# we want to build our own image based on the base image
# adding on our own test package
# start up the finalized image as a new container
# verify volumes and stuff works by shutting down the container and starting it up again

# 1. using cisco-nso-dev image, compile our package

test:
	$(MAKE) test-cdb-persistence
	$(MAKE) test-run-time-ssh-key-gen
	$(MAKE) test-persistent-ssh-key
	$(MAKE) test-http-disabled
	$(MAKE) test-https-disabled
	$(MAKE) test-http-enabled
	$(MAKE) test-https-enabled

test-cdb-persistence:
	-@docker rm -f $(CNT_PREFIX)-testbuilder-$(NCS_VERSION) >/dev/null 2>&1
	@echo "-- Starting docker container for compiling test package ------------------------"
	docker run -td --name $(CNT_PREFIX)-testbuilder-$(NCS_VERSION) cisco-nso-dev:$(NCS_VERSION)
	@echo "-- Copying testpkg into compilation container ----------------------------------"
	docker cp testpkg $(CNT_PREFIX)-testbuilder-$(NCS_VERSION):/testpkg
	@echo "-- Compiling testpkg in compilation container ----------------------------------"
	docker exec -t $(CNT_PREFIX)-testbuilder-$(NCS_VERSION) bash -lc 'make -C /testpkg/src clean'
	docker exec -t $(CNT_PREFIX)-testbuilder-$(NCS_VERSION) bash -lc 'make -C /testpkg/src'
	@echo "-- Preserving user (outside of container) ownership ----------------------------"
	docker exec -t $(CNT_PREFIX)-testbuilder-$(NCS_VERSION) bash -lc "chown -Rv $(shell id -u):$(shell id -g) /testpkg/"
	@echo "-- Copying results back from compilation container -----------------------------"
	docker cp $(CNT_PREFIX)-testbuilder-$(NCS_VERSION):/testpkg/load-dir/ testpkg/
	@echo "-- Terminating compilation container -------------------------------------------"
	-@docker rm -f $(CNT_PREFIX)-testbuilder-$(NCS_VERSION) >/dev/null 2>&1

	@echo "-- Building cisco-nso test Docker image ----------------------------------------"
	docker build -t $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) --build-arg BASE_IMAGE=cisco-nso:$(NCS_VERSION) .

	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	-docker volume rm $(CNT_PREFIX)-nso-test-volume-$(NCS_VERSION)
	docker volume create $(CNT_PREFIX)-nso-test-volume-$(NCS_VERSION)
	@echo "-- Starting cisco-nso test container -------------------------------------------"
	-@docker rm -f $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION)
	docker run -td --name $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) -v $(CNT_PREFIX)-nso-test-volume-$(NCS_VERSION):/ncs $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) bash -lc 'echo "show packages" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) bash -lc 'echo -e "configure\nset testpkg a-value 1337\ncommit\nexit" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin -g ncsadmin'
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION)
	@echo "-- Starting cisco-nso test container (second time) -----------------------------"
	docker run -td --name $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) -v $(CNT_PREFIX)-nso-test-volume-$(NCS_VERSION):/ncs $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION) bash -lc 'echo "show configuration testpkg a-value" | ncs_cli -u admin -g ncsadmin' | grep "a-value 1337;"
	@echo "-- Stopping cisco-nso test container -------------------------------------------"
	-docker rm -f $(CNT_PREFIX)-test-cisco-nso-$(NCS_VERSION)
	@echo "-- Removing volume for cisco-nso test container --------------------------------"
	-docker volume rm $(CNT_PREFIX)-nso-test-volume-$(NCS_VERSION)


test-run-time-ssh-key-gen:
	@echo "== Test that SSH keys are generated at runtime ================================="
	@echo "Starts the NSO container twice and ensure the SSH keys are different."
	@echo "SSH keys are written to the /ncs directory which can be shared mounted so"
	@echo "it is trivial to persist over time."
	mkdir -p tmp
	rm -rf tmp/testrtskg*
	-@docker rm -f $(CNT_PREFIX)-testrtskg-$(NCS_VERSION) >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-testrtskg-$(NCS_VERSION) cisco-nso:$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-testrtskg-$(NCS_VERSION) bash -lc "ncs --wait-started"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-testrtskg-$(NCS_VERSION)) | awk '{ print $$3 }' > tmp/testrtskg1
	-@docker rm -f $(CNT_PREFIX)-testrtskg-$(NCS_VERSION) >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-testrtskg-$(NCS_VERSION) cisco-nso:$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-testrtskg-$(NCS_VERSION) bash -lc "ncs --wait-started"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-testrtskg-$(NCS_VERSION)) | awk '{ print $$3 }' > tmp/testrtskg2
	-@docker rm -f $(CNT_PREFIX)-testrtskg-$(NCS_VERSION) >/dev/null 2>&1
	ret=0; diff -u tmp/testrtskg1 tmp/testrtskg2; \
	[ $$? -eq 0 ] && echo "ERROR: SSH key identical, should be different per run" && ret=1; exit $$ret
	@echo "SSH keys are different across invocations, I'm happy"

test-persistent-ssh-key:
	@echo "== Test that SSH key is persisted on shared volume ============================="
	mkdir -p tmp
	rm -rf tmp/testpsk*
	@echo "-- Creating volume for cisco-nso test container --------------------------------"
	-docker volume rm $(CNT_PREFIX)-testpsk-$(NCS_VERSION)
	docker volume create $(CNT_PREFIX)-testpsk-$(NCS_VERSION)
	@echo "-- Starting cisco-nso test container, first invocation -------------------------"
	-@docker rm -f $(CNT_PREFIX)-testpsk-$(NCS_VERSION) >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-testpsk-$(NCS_VERSION) -v $(CNT_PREFIX)-testpsk-$(NCS_VERSION):/ncs cisco-nso:$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-testpsk-$(NCS_VERSION) bash -lc "ncs --wait-started"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-testpsk-$(NCS_VERSION)) | awk '{ print $$3 }' > tmp/testpsk1
	-@docker rm -f $(CNT_PREFIX)-testpsk-$(NCS_VERSION) >/dev/null 2>&1
	@echo "-- Starting cisco-nso test container, second invocation ------------------------"
	-@docker rm -f $(CNT_PREFIX)-testpsk-$(NCS_VERSION) >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-testpsk-$(NCS_VERSION) -v $(CNT_PREFIX)-testpsk-$(NCS_VERSION):/ncs cisco-nso:$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-testpsk-$(NCS_VERSION) bash -lc "ncs --wait-started"
	ssh-keyscan $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-testpsk-$(NCS_VERSION)) | awk '{ print $$3 }' > tmp/testpsk2
	-@docker rm -f $(CNT_PREFIX)-testpsk-$(NCS_VERSION) >/dev/null 2>&1
	-docker volume rm $(CNT_PREFIX)-testpsk-$(NCS_VERSION)
	@echo "-- Comparing output ------------------------"
	diff -u tmp/testpsk1 tmp/testpsk2 || (echo "ERROR: SSH key different across runs, should be persisted" && exit 1)
	@echo "SSH keys are the same across invocations, I'm happy"


test-http-disabled:
	@echo "== Test that the HTTP webUI is disabled per default ============================"
	-@docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ cisco-nso:$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started"
	curl $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) 2>&1 | grep "Connection refused"
	@echo "Connection to HTTP TCP port 80 was refused, I'm happy"
	-@docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1

test-https-disabled:
	@echo "== Test that the HTTP webUI is disabled per default ============================"
	-@docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ cisco-nso:$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started"
	curl https://$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) 2>&1 | grep "Connection refused"
	@echo "Connection to HTTPS TCP port 443 was refused, I'm happy"
	-@docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1

test-http-enabled:
	@echo "== Test that the HTTP webUI works when enabled ================================="
	-@docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ --env HTTP_ENABLE=true cisco-nso:$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started"
	curl $$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "Connection to HTTP TCP port 80 was accepted, I'm happy"
	-@docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1

test-https-enabled:
	@echo "== Test that the HTTP webUI works when enabled ================================="
	-@docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
	docker run -td --name $(CNT_PREFIX)-$@ --env HTTPS_ENABLE=true cisco-nso:$(NCS_VERSION)
	docker exec -t $(CNT_PREFIX)-$@ bash -lc "ncs --wait-started"
	curl --insecure https://$$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $(CNT_PREFIX)-$@) >/dev/null
	@echo "Connection to HTTP TCP port 80 was accepted, I'm happy"
	-@docker rm -f $(CNT_PREFIX)-$@ >/dev/null 2>&1
