include ../../nidvars.mk
include ../../nidcommon.mk

# The name of the current test environment is the final directory name
# containing the test Makefile. The testenvs are defined as subdirectories of
# the testenvs/ directory. The subdirectories (like "testenvs/quick" or
# "testenvs/quick-alu-sr") contain Makefiles. Only directories that contain
# (capital M) Makefiles are considered testenvs. For example, take the
# structure:
#
# testenvs/
# ├── cmd.py
# ├── quick
# │   ├── authgroup-password.xml
# │   ├── authgroup-rsa-key-error.xml
# │   ├── authgroup-rsa-key.xml
# │   ├── da-create.xml
# │   └── quick-common.mk
# ├── quick-alu-sr
# │   └── Makefile
# └── testenv-common.mk
#
# and the $(MAKEFILE_LIST) [ Makefile ../quick/quick-common.mk ../testenv-common.mk ../../nidcommon.mk ]
# To get the name of the testenv, take the first Makefile ("Makefile") and
# determine the base directory name ("quick-alu-sr"). The "quick" directory is
# not a testenv because it does not contain a Makefile.
TESTENV:=$(shell basename $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST)))))

# Each testenv supports at minimum the three "standard" targets: start, test and
# stop. The start and test targets are specific to the testenv and are not part
# of this common file.

.PHONY: test dap-port debug-vscode build clean-build stop shell cli runcmdC runcmdJ loadconf saveconfxml save-logs check-logs dev-shell wait-healthy

# dap-port: get the host port mapping for the DAP daemon in the container
dap-port:
	@docker inspect -f '{{(index (index .NetworkSettings.Ports "5678/tcp") 0).HostPort}}' $(CNT_PREFIX)-nso$(NSO)

# debug-vscode: modifies VSCode launch.json to connect the python remote
# debugger to the environment. Existing contents of the file are preserved.
# First check if the file exists, and if not, create a valid empty file. Next
# check if "Python: NID Remote Attach" debug config is present. If yes, update
# it, otherwise add a new one.
debug-vscode:
	@LAUNCH_FILE=$(PROJECT_DIR)/.vscode/launch.json; \
	if [ ! -f $${LAUNCH_FILE} ]; then \
		mkdir -p $(PROJECT_DIR)/.vscode; \
		echo '{"version": "0.2.0","configurations":[]}' > $${LAUNCH_FILE}; \
		echo "== Created .vscode/launch.json"; \
	fi; \
	HOST_PORT=$$($(MAKE) --no-print-directory dap-port); \
	LAUNCH_NO_COMMENTS=$$(sed '/\s*\/\/.*/d' $${LAUNCH_FILE}); \
	if ! echo $${LAUNCH_NO_COMMENTS} | jq --exit-status "(.configurations[] | select(.name == \"Python: NID Remote Attach\"))" >/dev/null 2>&1; then \
		echo $${LAUNCH_NO_COMMENTS} | jq '.configurations += [{"name":"Python: NID Remote Attach","type":"python","request":"attach","port":'"$${HOST_PORT}"',"host":"localhost","pathMappings":[{"localRoot":"$${workspaceFolder}/packages","remoteRoot":"/nso/run/state/packages-in-use/1"}]}]' > $${LAUNCH_FILE}; \
		echo "== Added \"Python: NID Remote Attach\" debug configuration"; \
	else \
		echo $${LAUNCH_NO_COMMENTS} | jq "(.configurations[] | select(.name == \"Python: NID Remote Attach\") | .port) = $${HOST_PORT}" > $${LAUNCH_FILE}; \
		echo "== Updated .vscode/launch.json for Python remote debugging"; \
	fi

# rebuild - incrementally recompile and load new packages in running NSO
# See the nid/testenv-build script for more details.
rebuild:
	for NSO in $$(docker ps --format '{{.Names}}' --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --filter label=com.cisco.nso.testenv.type=nso); do \
		echo "-- Rebuilding for NSO: $${NSO}"; \
		docker run -t --rm -v $(PROJECT_DIR):/src --volumes-from $${NSO} -v $(CNT_PREFIX)-pip-cache:/root/.cache/pip --network=container:$${NSO} -e NSO=$${NSO} -e PACKAGE_RELOAD=$(PACKAGE_RELOAD) -e SKIP_LINT=$(SKIP_LINT) -e PKG_FILE=$(IMAGE_BASENAME)package:$(DOCKER_TAG) $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) /src/nid/testenv-build; \
	done

# clean-rebuild - clean and rebuild from scratch
# We rsync (with --delete) in sources, which effectively is a superset of 'make
# clean' per package, as this will delete any built packages as well as removing
# old sources files that no longer exist. It also removes included packages and
# as we don't have those in the source repository, we must bring them in from
# the build container image where we previously pulled them in into the
# /includes directory. We start up the build image and copy the included
# packages to /var/opt/ncs/packages/ folder.
clean-rebuild:
	for NSO in $$(docker ps --format '{{.Names}}' --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --filter label=com.cisco.nso.testenv.type=nso); do \
		echo "-- Cleaning NSO: $${NSO}"; \
		docker run -t --rm -v $(PROJECT_DIR):/src --volumes-from $${NSO} $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) bash -lc 'rsync -aEim --delete /src/packages/. /src/test-packages/. /var/opt/ncs/packages/ >/dev/null'; \
		echo "-- Copying in pristine included packages for NSO: $${NSO}"; \
		docker run -t --rm --volumes-from $${NSO} $(IMAGE_BASENAME)build:$(DOCKER_TAG) cp -a /includes/. /var/opt/ncs/packages/; \
	done
	@echo "-- Done cleaning, rebuilding with forced package reload..."
	$(MAKE) rebuild PACKAGE_RELOAD="true"

# stop - stop the testenv
# This finds the currently running containers that are part of our testenv based
# on their labels and then stops them, finally removing the docker network too.
# Volumes that were created as part of the test are removed as well. All
# containers that are part of our testenv must be started with the correct
# labels for this to work correctly. Use the variables DOCKER_ARGS or
# DOCKER_NSO_ARGS when running 'docker run', see start.
stop:
	docker ps -aq --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | $(XARGS) docker rm -vf
	-docker network rm $(CNT_PREFIX)
	docker volume ls -qf label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | $(XARGS) docker volume rm

shell:
	docker exec -it $(CNT_PREFIX)-nso$(NSO) bash -l

cli:
	docker exec -it $(CNT_PREFIX)-nso$(NSO) bash -lc 'ncs_cli -u admin'

runcmdC runcmdJ:
	@if [ -z "$(CMD)" ]; then echo "CMD variable must be set"; false; fi
	docker exec -t $(CNT_PREFIX)-nso$(NSO) bash -lc 'echo -e "$(CMD)" | ncs_cli --stop-on-error -$(subst runcmd,,$@)u admin'

loadconf:
	@if [ -z "$(FILE)" ]; then echo "FILE variable must be set"; false; fi
	@echo "Loading configuration $(FILE)"
	@docker exec -t $(CNT_PREFIX)-nso$(NSO) bash -lc "mkdir -p /tmp/$(shell echo $(FILE) | xargs dirname)"
	@docker cp $(FILE) $(CNT_PREFIX)-nso$(NSO):/tmp/$(FILE)
	@$(MAKE) runcmdJ CMD="configure\nload merge /tmp/$(FILE)\ncommit"

saveconfxml:
	@if [ -z "$(FILE)" ]; then echo "FILE variable must be set"; false; fi
	@echo "Saving configuration to $(FILE)"
	docker exec -t $(CNT_PREFIX)-nso$(NSO) bash -lc "mkdir -p /tmp/$(shell echo $(FILE) | xargs dirname)"
	@$(MAKE) runcmdJ CMD="show configuration $(CONFPATH) | display xml | save /tmp/$(FILE)"
	@docker cp $(CNT_PREFIX)-nso$(NSO):/tmp/$(FILE) $(FILE)

# Wait for all NSO instances in testenv to start up, as determined by `ncs
# --wait-started`, or display the docker log for the first failed NSO instance.
wait-started-nso:
	@for NSO in $$(docker ps --format '{{.Names}}' --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --filter label=com.cisco.nso.testenv.type=nso); do \
		docker exec -t $${NSO} bash -lc 'ncs --wait-started 600' || (echo "NSO instance $${NSO} failed to start in 600 seconds, displaying logs:"; docker logs $${NSO}; exit 1); \
		echo "NSO instance $${NSO} has started"; \
	done; \
	echo "All NSO instance have started"

# Find all NSO containers using the nidtype=nso and CNT_PREFIX labels, then
# save logs from /log. For all containers (NSO inclusive) save docker logs.
save-logs:
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

# The check-logs target can be executed at the end of a test run. The plan is
# for it to fail in the presence of "errors" in various logs. This will catch
# unhandled errors / bugs in NCS.
#
# What counts as an error:
#  - restart of the python VM
#  - tracebacks
#  - critical errors
#  - internal errors
check-logs:
# This multiline regex used in the perl script below matches lines that begin
# with 'Traceback', then either:
#  1. followed by text, followed by two empty lines,
#  2. followed by text, followed by a line that ends with '- '
#
# For example 1:
#	Traceback (most recent call last):
#	  File "/var/opt/ncs/state/packages-in-use/1/terastream/python/terastream/device_monitor.py", line 437, in run
#	    self._read_settings()
#	  File "/var/opt/ncs/state/packages-in-use/1/terastream/python/terastream/device_monitor.py", line 486, in _read_settings
#	    with self._maapi.start_read_trans() as t:
#	  File "/opt/ncs/ncs-4.6.3.2/src/ncs/pyapi/ncs/maapi.py", line 542, in start_read_trans
#	    product, version, client_id)
#	  File "/opt/ncs/ncs-4.6.3.2/src/ncs/pyapi/ncs/maapi.py", line 530, in start_trans
#	    vendor, product, version, client_id)
#	_ncs.error.Error: operation in wrong state (17): node is in upgrade mode
#
# For example 2:
#	Traceback (most recent call last):
#	<ERROR> 05-Mar-2019::13:42:43.391 paramiko.transport Thread-347: -   File "/usr/local/lib/python3.5/dist-packages/paramiko/transport.py", line 2138, in _check_banner
#	<ERROR> 05-Mar-2019::13:42:43.391 paramiko.transport Thread-347: -     buf = self.packetizer.readline(timeout)
#	<ERROR> 05-Mar-2019::13:42:43.391 paramiko.transport Thread-347: -   File "/usr/local/lib/python3.5/dist-packages/paramiko/packet.py", line 367, in readline
#	<ERROR> 05-Mar-2019::13:42:43.391 paramiko.transport Thread-347: -     buf += self._read_timeout(timeout)
#	<ERROR> 05-Mar-2019::13:42:43.391 paramiko.transport Thread-347: -   File "/usr/local/lib/python3.5/dist-packages/paramiko/packet.py", line 563, in _read_timeout
#	<ERROR> 05-Mar-2019::13:42:43.391 paramiko.transport Thread-347: -     raise EOFError()
#	<ERROR> 05-Mar-2019::13:42:43.391 paramiko.transport Thread-347: - EOFError
#	<ERROR> 05-Mar-2019::13:42:43.391 paramiko.transport Thread-347: -
	@ERRORS=0; \
	for nso in $$(docker ps -a --filter label=com.cisco.nso.testenv.type=nso --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) --format '{{.Names}}'); do \
		echo "== Checking logs of $${nso}"; \
		docker exec $${nso} sh -c 'grep --color "Restarted PyVM" /log/ncs-python-vm.log' && ERRORS=$$(($${ERRORS}+1)); \
		docker exec $${nso} sh -c 'perl -n0e "BEGIN {\$$e=1;} END {\$$?=\$$e;} \$$e=0, print \"\e[31m\$$1\n\e[39m\" while m/(Traceback.*?(\n\n|-\s+\n))/gs" /log/ncs-python-vm*' && ERRORS=$$(($${ERRORS}+1)); \
		docker exec $${nso} sh -c 'grep --color CRIT /log/*.log' && ERRORS=$$(($${ERRORS}+1)); \
		docker exec $${nso} bash -lc 'ncs --printlog /log/ncserr.log > /log/ncserr.log.txt'; [ -s /log/ncserr.log.txt ] && ERRORS=$$(($${ERRORS}+1)); \
		docker exec $${nso} bash -lc 'echo -ne "\e[31m"; head -200 /log/ncserr.log.txt; echo -ne "\e[39m"'; \
	done; \
	echo "== Found $${ERRORS} error messages"; \
	if [ $${ERRORS} -gt 0 ]; then exit 1; fi

# dev-shell: start a shell in the -dev container, but with the volumes
# and network namespace of the testenv NSO container. This allows running
# python script and IPython that interface with NSO.
dev-shell:
	docker run -it --rm -v $(PROJECT_DIR):/src --pid container:$(CNT_PREFIX)-nso$(NSO) --volumes-from $(CNT_PREFIX)-nso$(NSO) --network container:$(CNT_PREFIX)-nso$(NSO) $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION)

# Wait for all containers in the testenv (as found via the testenv label) to
# become healthy! If a container has exited, we exit immediately.
# The implicit assumption is that all containers as part of the testenv should
# be running. If a temporary container is used, i.e. its normal life cycle is
# that it is started, run shortly and then exits, it must also be removed!
wait-healthy:
	@echo "Waiting (up to 900 seconds) for testenv container(s) to become healthy"
	@OLD_COUNT=0; SECONDS=0; for I in $$(seq 1 900); do \
		STOPPED=$$(docker ps -a --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | grep "Exited"); \
		if [ -n "$${STOPPED}" ]; then \
			echo "\e[31m===  $${SECONDS}s elapsed - Container(s) unexpectedly exited"; \
			echo "$${STOPPED} \\e[0m"; \
			exit 1; \
		fi; \
		COUNT=$$(docker ps --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | egrep "(unhealthy|health: starting)" | wc -l); \
		if [ $${COUNT} -gt 0 ]; then  \
			if [ $${OLD_COUNT} -ne $${COUNT} ];\
			then \
				echo "\e[31m===  $${SECONDS}s elapsed - Found unhealthy/starting ($${COUNT}) containers";\
				docker ps --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | egrep "(unhealthy|health: starting)" | awk '{ print $$(NF) }';\
				echo "Checking again every 1 second, no more messages until changes detected\\e[0m"; \
			fi;\
			sleep 1; \
			OLD_COUNT=$${COUNT};\
			continue; \
		else \
			echo "\e[32m=== $${SECONDS}s elapsed - Did not find any unhealthy containers, all is good.\e[0m"; \
			exit 0; \
		fi ;\
	done; \
	echo "\e[31m===  $${SECONDS}s elapsed - Found unhealthy/starting ($${COUNT}) containers";\
	docker ps --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | egrep "(unhealthy|health: starting)" | awk '{ print $$(NF) }';\
	echo "\e[0m"; \
	exit 1
