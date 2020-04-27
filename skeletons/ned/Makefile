# Include standard NID (NSO in Docker) package Makefile that defines all
# standard make targets
include nidned.mk

# The rest of this file is specific to this repository.

# For development purposes it is useful to be able to start a testenv once and
# then run the tests, defined in testenv-test, multiple times, adjusting the
# code in between each run. That is what a normal development cycle looks like.
# There is usually some form of initial configuration that we want to apply
# once, after the containers have started up, but avoid applying it for each
# invocation of testenv-test. Such configuration can be placed at the end of
# testenv-start-extra. You can also start extra containers with
# testenv-start-extra, for example netsims or virtual routers.

# TODO: you should modify the make targets below for your package
# TODO: clean up your Makefile by removing comments explaining how to do things

# Start extra containers or place things you want to run once, after startup of
# the containers, in testenv-start-extra.
testenv-start-extra:
	@echo "\n== Starting repository specific testenv"
# Start extra things, for example a netsim container by doing:
# docker run -td --name $(CNT_PREFIX)-my-netsim --network-alias mynetsim1 $(DOCKER_ARGS) $(IMAGE_PATH)my-ned-repo/netsim:$(DOCKER_TAG)
# Use --network-alias to give it a name that will be resolvable from NSO and
# other containers in our testenv network, i.e. in NSO, the above netsim should
# be configured with the address 'mynetsim1'.
# Make sure to include $(DOCKER_ARGS) as it sets the right docker network and
# label which other targets, such as testenv-stop, operates on. If you start an
# extra NSO container, use $(DOCKER_NSO_ARGS) and give a unique name but
# starting with '-nso', like so:
# docker run -td --name $(CNT_PREFIX)-nsofoo --network-alias nsofoo $(DOCKER_NSO_ARGS) $(IMAGE_PATH)$(PROJECT_NAME)/testnso:$(DOCKER_TAG)
#
# Add things to be run after startup is complete. If you want to configure NSO,
# be sure to wait for it to start, using e.g.:
#docker exec -t $(CNT_PREFIX)-nso bash -lc 'ncs --wait-started 600'
#
# For example, to load an XML configuration file:
# docker cp test/initial-config.xml $(CNT_PREFIX)-nso:/tmp/initial-config.xml
#	$(MAKE) testenv-runcmdJ CMD="configure\n load merge /tmp/initial-config.xml\n commit"
#
	@echo "-- Wait for NSO to start up"
	docker exec -t $(CNT_PREFIX)-nso bash -lc 'ncs --wait-started 600'
# The following is an example (but a working example) of how to add the netsim
# device started per default in the NED skeleton to NSO. Feel free to use it,
# remove or modify as you see fit for your environment.
	@echo "-- Add device to NSO"
	@echo "   Get the package-meta-data.xml file from the compiled NED (we grab it from the netsim build)"
	mkdir -p tmp
	docker cp $(CNT_PREFIX)-netsim:/var/opt/ncs/packages/$(NED_NAME)/package-meta-data.xml tmp/package-meta-data.xml
	@echo "   Fill in the device-type in add-device.xml by extracting the relevant part from the package-meta-data of the NED"
	echo $(NSO_VERSION) | grep "^4" && xmlstarlet sel -N x=http://tail-f.com/ns/ncs-packages -t -c "//x:ned-id" tmp/package-meta-data.xml | grep cli && STRIP_NED=' -d "//x:ned-id" '; \
		xmlstarlet sel -R -N x=http://tail-f.com/ns/ncs-packages -t -c "//*[x:ned-id]" -c "document('test/add-device.xml')" tmp/package-meta-data.xml | xmlstarlet edit -O -N x=http://tail-f.com/ns/ncs-packages -N y=http://tail-f.com/ns/ncs -d "/x:xsl-select/*[x:ned-id]/*[not(self::x:ned-id)]" -m "/x:xsl-select/*[x:ned-id]" "/x:xsl-select/y:devices/y:device/y:device-type" $${STRIP_NED} | tail -n +2 | sed '$$d' | cut -c 3- > tmp/add-device.xml
	docker cp tmp/add-device.xml $(CNT_PREFIX)-nso:/add-device.xml
	$(MAKE) testenv-runcmdJ CMD="configure\nload merge /add-device.xml\ncommit\nexit"
	$(MAKE) testenv-runcmdJ CMD="show devices brief"
	$(MAKE) testenv-runcmdJ CMD="request devices device dev1 ssh fetch-host-keys"


# Place your tests in testenv-test. Feel free to define a target per test case
# and call them from testenv-test in case you have more than a handful of cases.
# Sometimes when there is a "setup" or "preparation" part of a test, it can be
# useful to separate into its own target as to make it possible to run that
# prepare phase and then manually inspect the state of the system. You can
# achieve this by further refining the make targets you have.
testenv-test:
	@echo "\n== Running tests"
	@echo "TODO: Fill in your tests here"
# Some examples for how to run commands in the ncs_cli:
#	$(MAKE) testenv-runcmdJ CMD="show packages"
#	$(MAKE) testenv-runcmdJ CMD="request packages reload"
# Multiple commands in a single session also works - great for configuring stuff:
#	$(MAKE) testenv-runcmdJ CMD="configure\n set foo bar\n commit"
# We can test for certain output by combining show commands in the CLI with for
# example grep:
#	$(MAKE) testenv-runcmdJ CMD="show configuration foo" | grep bar

# Included below is an example test that covers the basics for a working NED and
# netsim. The standard testenv-start target, defined in nidned.mk, will set up
# the test environment by starting:
# - a netsim container based on the NED YANG models
# - an NSO container with the NED loaded
#
# Already by starting up we have verified that the YANG models of the netsim /
# NED pass load time verification. For example, this could fail if there are
# constraints in the YANG model that require certain data to be present (and
# it's not when we start up as CDB is empty).
#
# As part of the testenv startup, in testenv-start-extra, we:
# - add the netsim container as a device to the test NSO
# - fetch SSH host-keys
# - run sync-from
#
# This test then consists of:
# - configuring the hostname on the netsim device to the magic string foobarhostname
#   - we then grep for this magic string
#   - ensuring we can send config and commit on the netsim device
# - doing sync-from again
#   - we check that the hostname is as expected
#
# TODO: to complete the test from the NED skeleton, you have to provide the
# configuration to set the hostname on the device in the file
# test/device-config-hostname.xml
#

	$(MAKE) testenv-runcmdJ CMD="request devices device dev1 sync-from"

	@echo "Configure hostname on device through NSO"
	docker cp test/device-config-hostname.xml $(CNT_PREFIX)-nso:/device-config-hostname.xml
	$(MAKE) testenv-runcmdJ CMD="configure\nload merge /device-config-hostname.xml\ncommit\nexit"
	$(MAKE) testenv-runcmdJ CMD="show configuration devices device dev1 config" | grep foobarhostname
	$(MAKE) testenv-runcmdJ CMD="request devices device dev1 sync-from"
	$(MAKE) testenv-runcmdJ CMD="show configuration devices device dev1 config" | grep foobarhostname
