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
