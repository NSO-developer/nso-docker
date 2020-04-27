# Include standard NID (NSO in Docker) package Makefile that defines all
# standard make targets
include nidpackage.mk

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
