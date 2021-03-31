# We actually only need the NSO_VERSION variable as we don't have any dependency
# on the information about which FILE or FILENAME which was used to build an NSO
# image. However, if NSO_VERSION isn't set, we try to dig out the NSO version
# number from the FILE/FILENAME
ifeq ($(NSO_VERSION),)
$(error ERROR: variable NSO_VERSION must be set, for example to '5.2.1' to run tests based on NSO version 5.2.1)
endif

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

DOCKER_BASE_IMAGE=$(NSO_IMAGE_PATH)cisco-nso-base:$(DOCKER_TAG)
DOCKER_DEV_IMAGE=$(NSO_IMAGE_PATH)cisco-nso-dev:$(DOCKER_TAG)

# run all tests
all: test-ned test-package test-system

# same as above but run in parallel
test-parallel:
	$(MAKE) --output-sync=recurse -j8 all

test-ned:
	$(MAKE) ned-build-test-ietf-ned

test-package:
	$(MAKE) package-test-common

test-system:
	$(MAKE) system-test-common


# common tests for all skeleton types
%-test-common:
	$(MAKE) $*-build-test-python-package
# TODO: Enable this! Currently disabled as we don't support building packages without a src directory
#	$(MAKE) $*-no-src

clean:
	rm -rf repos


# Do clean & initialize
INIT=mkdir -p repos; rm -rf repos/$@; cp -av ../$* repos/$@
# We pass the current $(DOCKER_TAG) as NSO_VERSION because we want to use the
# NSO images from this PNS. The skeletons also append their own PNS suffixes for
# their images and container. A side effect of this is ending up with images
# like package/package:5.5.1-123456-123456
MKBUILDTEST=NSO_VERSION=$(DOCKER_TAG) make -C repos/$@ build test

# Run a command in a dev container. Note how this doesn't work in CI as it uses
# a bind mount.
DEVRUN=docker run -t --rm -v $$(pwd):/src $(DOCKER_DEV_IMAGE) bash -lc


.PHONY: props/python-package props/template-package props/ietf-ned
# This is a standard package which we can use for our most basic tests.
props/python-package:
	mkdir -p props
	$(DEVRUN) 'cd /src/props && ncs-make-package --service-skeleton python-and-template python-package && chown -R 1000:1000 . && xmlstarlet edit --inplace -N x=http://tail-f.com/ns/ncs-packages --update "/x:ncs-package/x:ncs-min-version" --value 4.7 python-package/package-meta-data.xml'
	rm -rf $@/test

# This package just contains a template, which can be invoked from another
# package. This is not a "template service", since that would also require a
# YANG model with a servicepoint defined. We are trying to emulate someone who
# uses a package for storing common service configuration templates.
props/template-package:
	mkdir -p props
	$(DEVRUN) 'cd /src/props && ncs-make-package --service-skeleton python-and-template template-package && chown -R 1000:1000 . && xmlstarlet edit --inplace -N x=http://tail-f.com/ns/ncs-packages --update "/x:ncs-package/x:ncs-min-version" --value 4.7 --delete "/x:ncs-package/x:component" template-package/package-meta-data.xml'
	rm -rf $@/test $@/src $@/python

props/ietf-ned:
	mkdir -p props
	$(DEVRUN) 'cd /src/props && ncs-make-package --netconf-ned ietf-yang-models ietf-ned && chown -R 1000:1000 . && xmlstarlet edit --inplace -N x=http://tail-f.com/ns/ncs-packages --update "/x:ncs-package/x:ncs-min-version" --value 4.7 ietf-ned/src/package-meta-data.xml.in'
	sed -i -e '/^\s\+--fail-on-warnings/d' -e 's/ --fail-on-warnings//' $@/src/Makefile
	sed -i -e '/<AES256CFB128>/,+2d' $@/netsim/confd.conf.netsim


%-build-test-ietf-ned:
	@echo "-- Testing $@ on $* skeleton"
	$(INIT)
	cp -av props/ietf-ned repos/$@/packages/
	$(MKBUILDTEST)

%-build-test-python-package:
	@echo "-- Testing $@ on $* skeleton"
	$(INIT)
	cp -av props/python-package repos/$@/packages/
	$(MKBUILDTEST)

# Make sure that the skeletons support compiling packages that do not have a src directory
%-no-src:
	@echo "-- Testing $@ on $* skeleton"
	$(INIT)
	cp -av props/template-package repos/$@/packages/
	$(MKBUILDTEST)

