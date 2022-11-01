include ../testenv-common.mk

# Enable IPv6 per default, set to false to disable (in Makefile, not here)
IPV6?=true
# start: start the test environment in a configuration that allows
# Python Remote Debugging. Exposes port 5678 on a random port on localhost.
# Per default, the IPv6 prefix is a randomly generated IPv6 network prefix in
# the ULA address space. Override by setting IPV6_NET variable to e.g.:
# IPV6_NET=2001:db8:1234:456:  # which becomes 2001:db8:1234:456::/64
# If the IPv6 prefix is not in the public unicast space (2000::/3), the IPv6
# default route will be removed. This makes it possible to have local IPv6
# connectivity within the network, yet not slow down attempts to reach Internet
# resources (where IPv6 would normally be tried first, and fail due to
# non-public addresses).
start:
	docker network inspect $(CNT_PREFIX) >/dev/null 2>&1 || docker network create $(CNT_PREFIX) $(shell [ "$(IPV6)" = "true" ] && export LC_ALL=C && echo --ipv6 --subnet $${IPV6_NET:-fd00:$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):$$(< /dev/urandom tr -dc a-f0-9 | head -c4):}:/64)
	docker run -td --name $(CNT_PREFIX)-nso --network-alias nso $(DOCKER_NSO_ARGS) $(IMAGE_BASENAME)/testnso:$(DOCKER_TAG)
	docker run -td --name $(CNT_PREFIX)-netsim --network-alias dev1 --hostname dev1 $(DOCKER_ARGS) $(IMAGE_BASENAME)/netsim:$(DOCKER_TAG)
	-[ "$(IPV6)" = "true" ] && echo $$(docker network inspect --format '{{range .IPAM.Config}}{{- if (gt (split .Subnet ":"|len) 1) -}}{{.Subnet}}{{- end}}{{end}}' $(CNT_PREFIX)) | egrep "^[23]...:" || (echo "Removing IPv6 default route" && docker ps -aq --filter label=com.cisco.nso.testenv.name=$(CNT_PREFIX) | $(XARGS) -I CNT -n1 docker run --rm --net=container:CNT --cap-add=NET_ADMIN $(NSO_IMAGE_PATH)cisco-nso-base:$(NSO_VERSION) ip -6 route del default >/dev/null 2>&1 || true)

	$(MAKE) wait-started-nso
# The following is an example (but a working example) of how to add the netsim
# device started per default in the NED skeleton to NSO. Feel free to use it,
# remove or modify as you see fit for your environment.
	$(MAKE) add-device


ifeq ($(NSO_VERSION_MAJOR),4)
STRIP_NED:=--delete "//x:ned-id"
endif

add-device:
	@echo "-- Add device to NSO"
	@echo "   Get the package-meta-data.xml file from the compiled NED (we grab it from the netsim build)"
# The netsim container only has a single version (ned-d) in the packages directory
	docker exec $(CNT_PREFIX)-netsim bash -c "cp /var/opt/ncs/packages/*/package-meta-data.xml /tmp"
	mkdir -p tmp
	docker cp $(CNT_PREFIX)-netsim:/tmp/package-meta-data.xml tmp/package-meta-data.xml
	@echo "   Fill in the device-type in add-device.xml by extracting the relevant part from the package-meta-data of the NED"
	xmlstarlet sel -t -c "//*[_:ned-id] | //_:ned/_:netconf | //_:ned/_:cli | //_:ned/_:snmp | //_:ned/_:generic" tmp/package-meta-data.xml | xmlstarlet edit --subnode '_:*[not(_:ned-id)]' --type elem -n ned-id -v dummy | xmlstarlet sel -R -t -c '/' -c "document('test/add-device.xml')" | xmlstarlet edit -O -N x=http://tail-f.com/ns/ncs-packages -N y=http://tail-f.com/ns/ncs -d "/x:xsl-select/*[x:ned-id]/*[not(self::x:ned-id)]" -m "/x:xsl-select/*[x:ned-id]" "/x:xsl-select/y:devices/y:device/y:device-type" $(STRIP_NED) | tail -n +2 | sed '$$d' | cut -c 3- > tmp/add-device.xml
	docker cp tmp/add-device.xml $(CNT_PREFIX)-nso:/add-device.xml
	$(MAKE) runcmdJ CMD="configure\nload merge /add-device.xml\ncommit\nexit"
	$(MAKE) runcmdJ CMD="show devices brief"
	$(MAKE) runcmdJ CMD="request devices device dev1 ssh fetch-host-keys"

# Place your tests in test. Feel free to define a target per test case
# and call them from test in case you have more than a handful of cases.
# Sometimes when there is a "setup" or "preparation" part of a test, it can be
# useful to separate into its own target as to make it possible to run that
# prepare phase and then manually inspect the state of the system. You can
# achieve this by further refining the make targets you have.
test:
	@echo "\n== Running tests"
	@echo "-- Verify packages are operationally up"
	$(MAKE) runcmdJ CMD="show packages" | docker run -i --rm $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) bash -c '! grep -P "oper-status (?!up)" >/dev/null' || (echo "ERROR: packages not operationally up:" && $(MAKE) runcmdJ CMD="show packages" && false)
	@echo "TODO: Fill in your tests here"
# Some examples for how to run commands in the ncs_cli:
#	$(MAKE) runcmdJ CMD="show packages"
#	$(MAKE) runcmdJ CMD="request packages reload"
# Multiple commands in a single session also works - great for configuring stuff:
#	$(MAKE) runcmdJ CMD="configure\n set foo bar\n commit"
# We can test for certain output by combining show commands in the CLI with for
# example grep:
#	$(MAKE) runcmdJ CMD="show configuration foo" | grep bar

# Included below is an example test that covers the basics for a working NED and
# netsim. The standard start target, defined in nidned.mk, will set up
# the test environment by starting:
# - a netsim container based on the NED YANG models
# - an NSO container with the NED loaded
#
# Already by starting up we have verified that the YANG models of the netsim /
# NED pass load time verification. For example, this could fail if there are
# constraints in the YANG model that require certain data to be present (and
# it's not when we start up as CDB is empty).
#
# As part of the testenv startup, in start-extra, we:
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

	$(MAKE) runcmdJ CMD="request devices device dev1 sync-from"

	@echo "Configure hostname on device through NSO"
	docker cp test/device-config-hostname.xml $(CNT_PREFIX)-nso:/device-config-hostname.xml
	$(MAKE) runcmdJ CMD="configure\nload merge /device-config-hostname.xml\ncommit\nexit"
	$(MAKE) runcmdJ CMD="show configuration devices device dev1 config" | grep foobarhostname
	$(MAKE) runcmdJ CMD="request devices device dev1 sync-from"
	$(MAKE) runcmdJ CMD="show configuration devices device dev1 config" | grep foobarhostname
