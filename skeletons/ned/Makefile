# Include standard NID (NSO in Docker) package Makefile that defines all
# standard make targets
include nidned.mk

# The following are specific to this repositories packages
testenv-start-extra:
	@echo "\n== Starting repository specific testenv containers"
# Start extra things, for example a netsim container by doing:
# docker run -td --name $(CNT_PREFIX)-my-netsim --network-alias mynetsim1 $(DOCKER_ARGS) $(IMAGE_PATH)my-netsim-image:$(DOCKER_TAG)
# Note how it becomes available under the name 'mynetsim1' from the NSO
# container, i.e. you can set the device address to 'mynetsim1' and it will
# magically work.

testenv-test:
	@echo "TODO: Fill in your tests here"
# Some examples for how to run commands in the ncs_cli:
#	$(MAKE) testenv-runcmd CMD="show packages"
#	$(MAKE) testenv-runcmd CMD="request packages reload"
# Multiple commands in a single session also works - great for configuring stuff:
#	$(MAKE) testenv-runcmd CMD="configure\n set foo bar\n commit"
# We can test for certain output by combining show commands in the CLI with for
# example grep:
#	$(MAKE) testenv-runcmd CMD="show configuration foo" | grep bar

# Included below is an example test that covers the basics for a working NED and
# netsim. The testenv-start target will set up the test environment by starting:
# - a netsim container based on the NED YANG models
# - an NSO container with the NED loaded
#
# Already by starting up we have verified that the YANG models of the netsim /
# NED pass load time verification. For example, this could fail if there are
# constraints in the YANG model that require certain data to be present (and
# it's not when we start up as CDB is empty).
#
# This test then consists of:
# - adding the netsim container as a device to the test NSO
# - fetching SSH host-keys
# - doing sync-from
# - configuring the hostname on the netsim device to the magic string foobarhostname
#   - we then grep for this
#   - ensuring we can send config and commit on the netsim device
# - doing sync-from again
#   - we check that the hostname is as expected
#

	docker exec -t $(CNT_PREFIX)-nso bash -lc 'ncs --wait-started 600'
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo "show packages" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo "show packages" | ncs_cli -u admin -g ncsadmin' | grep "oper-status up"

	@echo "-- Add device to NSO"
	@echo "   Get the package-meta-data.xml file from the compiled NED (we grab it from the netsim build)"
	mkdir -p tmp
	docker cp $(CNT_PREFIX)-netsim:/var/opt/ncs/packages/$(NED_NAME)/package-meta-data.xml tmp/package-meta-data.xml
	@echo "   Fill in the device-type in add-device.xml by extracting the relevant part from the package-meta-data of the NED"
	echo $(NSO_VERSION) | grep "^4" && xmlstarlet sel -N x=http://tail-f.com/ns/ncs-packages -t -c "//x:ned-id" tmp/package-meta-data.xml | grep cli && STRIP_NED=' -d "//x:ned-id" '; \
		xmlstarlet sel -R -N x=http://tail-f.com/ns/ncs-packages -t -c "//*[x:ned-id]" -c "document('test/add-device.xml')" tmp/package-meta-data.xml | xmlstarlet edit -O -N x=http://tail-f.com/ns/ncs-packages -N y=http://tail-f.com/ns/ncs -d "/x:xsl-select/*[x:ned-id]/*[not(self::x:ned-id)]" -m "/x:xsl-select/*[x:ned-id]" "/x:xsl-select/y:devices/y:device/y:device-type" $${STRIP_NED} | tail -n +2 | head -n -1 | cut -c 3- > tmp/add-device.xml
	docker cp tmp/add-device.xml $(CNT_PREFIX)-nso:/add-device.xml
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo -e "configure\nload merge /add-device.xml\ncommit\nexit" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo "show devices brief" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo "request devices device dev1 ssh fetch-host-keys" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo "request devices device dev1 sync-from" | ncs_cli -u admin -g ncsadmin'
	@echo "Configure hostname on device through NSO"
	docker cp test/device-config-hostname.xml $(CNT_PREFIX)-nso:/device-config-hostname.xml
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo -e "configure\nload merge /device-config-hostname.xml\ncommit\nexit" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo -e "show configuration devices device dev1 config" | ncs_cli -u admin -g ncsadmin' | grep foobarhostname
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo -e "request devices device dev1 sync-from" | ncs_cli -u admin -g ncsadmin'
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'echo -e "show configuration devices device dev1 config" | ncs_cli -u admin -g ncsadmin' | grep foobarhostname
