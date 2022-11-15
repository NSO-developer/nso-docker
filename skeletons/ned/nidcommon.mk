# The NSO in Docker ecosystem provides for parameterized execution of build and
# test environments for NSO package projects across multiple NSO versions.
#
# Running a test of a package means that we spin up one or more test containers
# based on a given state (commit) of a repository. They are part of one (CI)
# pipeline, though note that it can be run locally. We reuse the CI nomenclature
# even for local runs as it makes things easier to understand. The test
# environment (testenv) can consist of multiple containers, for example one
# netsim container and one NSO container.
#
# The version of NSO build and test with is always a parameter as it is crucial
# that packages can be built for different versions of NSO and it is good
# hygiene to continuously ensure that it works correctly with multiple versions
# of NSO (typically the tip of each release train). Each NSO version results in
# one CI job within a CI pipeline.
#
# For each CI job, there can be multiple containers. For example, one NSO
# container and one netsim container.
#
# The conceptual structure looks like this:
#
# - pipeline (per change / commit pushed / test started)
#   - job (per NSO version)
#     - multiple containers, as needed
#
# And here is what it might look like in reality. The commits FOO and BAR lead
# to starting CI pipelines to test the changes. Each CI pipeline runs two CI
# jobs, one for version 4.7.6 of NSO and one for NSO 5.3. In each CI job there
# are two containers, one for NSO itself and one for a netsim.
#
# - pipeline: commit FOO
#   - job: NSO 4.7.6
#     - NSO container
#     - netsim X container
#   - job: NSO 5.3
#     - NSO container
#     - netsim X container
# - pipeline: commit BAR
#   - job: NSO 4.7.6
#     - NSO container
#     - netsim X container
#   - job: NSO 5.3
#     - NSO container
#     - netsim X container
#
# - PNS is the pipeline or pseudo-namespace which is per CI pipeline. In a CI
#   environment it allows concurrent execution of multiple pipelines (to evalute
#   multiple changes) without collisions. When run locally it is based on your
#   username and thus you can conceptually not run testenvs for multiple commits
#   at the same time, however as git only allows checking out one version of a
#   time this is typically not an issue. Containers should have a label based on
#   PNS which allows the clean up of all containers through one single filter
#   and action.
# - CNT_PREFIX is per CI job and is what allows multiple jobs to be run in
#   parallel for different versions of NSO. When run locally, it is based on
#   your username as well as the NSO version, still making it possible to start
#   multiple testenvs for your code based on different NSO versions.
# - DOCKER_TAG must be unique per CI job and so is based on CI_JOB_ID when run
#   in CI (but also includes NSO version to make it easier to visually inspect)
#   or your username and NSO version when run locally.
# - OLD_DOCKER_TAG is just like DOCKER_TAG but allows a second NSO version to be
#   specified which is required for multi version tests (a.k.a upgrade tests)
#
# These Makefiles could be simplified, for example by removing the NSO version,
# but as it's considered good hygiene to test across multiple NSO versions, the
# recommendation is to get across the threshold and use them in the prescribed
# manner.

# helper function to turn a string into lower case
lc = $(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst F,f,$(subst G,g,$(subst H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst L,l,$(subst M,m,$(subst N,n,$(subst O,o,$(subst P,p,$(subst Q,q,$(subst R,r,$(subst S,s,$(subst T,t,$(subst U,u,$(subst V,v,$(subst W,w,$(subst X,x,$(subst Y,y,$(subst Z,z,$1))))))))))))))))))))))))))

# require that NSO_VERSION is set
ifeq ($(NSO_VERSION),)
$(error "ERROR: variable NSO_VERSION must be set, for example to '5.2.1' to build based on NSO version 5.2.1")
endif
NSO_VERSION_MAJOR=$(word 1,$(subst ., ,$(NSO_VERSION)))
NSO_VERSION_MINOR=$(word 2,$(subst ., ,$(subst _, ,$(NSO_VERSION))))
# NSO_VERSION_EXTRA is NSO_VERSION but just the extra part: 5.7.3_ps-123456 becomes _ps
ifneq (,$(findstring _,$(NSO_VERSION)))
NSO_VERSION_EXTRA=$(subst $(firstword $(subst _, ,$(firstword $(subst -, ,$(NSO_VERSION))))),,$(NSO_VERSION))
else
NSO_VERSION_EXTRA=
endif

# NSO_VERSION_MM is NSO_VERSION but just the major, minor and extra parts:
# 5.7.3_ps-123456 becomes 5.7_ps. This is used for includes which do not require
# the package to be built with the exact same patch version of NSO. For example,
# a package built with 5.8.1_ps can be loaded in all NSO versions in the 5.8_ps
# train.
# This version variable is exported to make it available to the shell script
# doing variable expansion in the includes files.
export NSO_VERSION_MM?=$(NSO_VERSION_MAJOR).$(NSO_VERSION_MINOR)$(NSO_VERSION_EXTRA)

# Determine our project name, either from CI_PROJECT_NAME which is normally set
# by GitLab CI or by looking at the name of our directory (that we are in).
ifneq ($(CI_PROJECT_NAME),)
PROJECT_NAME=$(CI_PROJECT_NAME)
else
PROJECT_NAME:=$(shell basename $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST)))))
endif

# Determine our project directory by taking the absolute path of the last
# makefile in $(MAKEFILE_LIST) - this makefile ("nidcommon.mk").
PROJECT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

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
DOCKER_TAG_MM?=$(NSO_VERSION_MM)-$(PNS)
CNT_PREFIX?=$(call lc,testenv-$(PROJECT_NAME)-$(TESTENV)-$(NSO_VERSION)-$(PNS))

# There are three important paths that we provide:
# - NSO_IMAGE_PATH is the path to where we can find the standard nso-docker images
#   cisco-nso-base and cisco-nso-dev
# - IMAGE_PATH is the path to where we should write our resulting output images
# - PKG_PATH is the path from where we pull in dependencies, i.e. the included
#   packages
# All three are derived from information we get from GitLab CI, if available.
# These defaults can be overridden simply by setting the variables in the
# environment. Makefile variable macros are available from within the Makefile,
# we export them to also make them available to subshells.
ifneq ($(CI_REGISTRY),)
export NSO_IMAGE_PATH?=$(call lc,$(CI_REGISTRY)/$(CI_PROJECT_NAMESPACE)/nso-docker/)
export IMAGE_PATH?=$(call lc,$(CI_REGISTRY)/$(CI_PROJECT_NAMESPACE)/)
export PKG_PATH?=$(call lc,$(CI_REGISTRY)/$(CI_PROJECT_NAMESPACE)/)
endif
export IMAGE_BASENAME=$(call lc,$(IMAGE_PATH)$(PROJECT_NAME))

# If we are not on x86_64, use --platform arg to Docker to enable emulation of
# x86 for the container. NSO is only compiled for x86_64, so we can never run
# without emulation.
ifneq ($(shell uname -m),x86_64)
DOCKER_PLATFORM_ARG ?= --platform=linux/amd64
endif

DOCKER_BUILD_PROXY_ARGS ?= --build-arg http_proxy --build-arg https_proxy --build-arg no_proxy


DOCKER_BUILD_ARGS+= $(DOCKER_PLATFORM_ARG) $(DOCKER_BUILD_PROXY_ARGS)
DOCKER_BUILD_ARGS+= --build-arg NSO_IMAGE_PATH=$(NSO_IMAGE_PATH)
DOCKER_BUILD_ARGS+= --build-arg NSO_VERSION=$(NSO_VERSION)
DOCKER_BUILD_ARGS+= --build-arg PKG_FILE=$(IMAGE_BASENAME)/package:$(DOCKER_TAG)
DOCKER_BUILD_ARGS+= --progress=plain

# DOCKER_ARGS contains arguments to 'docker run' for any type of container in
# the test environment.
# DOCKER_NSO_ARGS contains additional arguments specific to an NSO container.
# This includes exposing tcp/5678 for Python Remote Debugging using debugpy.
DOCKER_LABEL_ARG?=--label com.cisco.nso.testenv.name=$(CNT_PREFIX)
DOCKER_ARGS+=$(DOCKER_PLATFORM_ARG)
DOCKER_ARGS+=--network $(CNT_PREFIX) $(DOCKER_LABEL_ARG)
# DEBUGPY?=$(PROJECT_NAME)
DOCKER_NSO_ARGS=$(DOCKER_ARGS) --label com.cisco.nso.testenv.type=nso --volume /var/opt/ncs/packages -e DEBUGPY=$(DEBUGPY) --expose 5678 --publish-all

# Determine which xargs we have. BSD xargs does not have --no-run-if-empty,
# rather, it is the default behavior so the argument is simply superfluous. We
# check if we are using GNU xargs by trying to run xargs --version and grep for
# 'GNU', if that returns 0 we are on GNU and will use 'xargs --no-run-if-empty',
# otherwise we are on BSD and will use 'xargs' straight up.
XARGS_CHECK := $(shell xargs --version 2>&1 | grep GNU >/dev/null 2>&1; echo $$?)
ifeq ($(XARGS_CHECK),0)
	XARGS := xargs --no-run-if-empty
else
	XARGS := xargs
endif

# If we are running in CI and on the default branch (like 'main' or 'master'),
# disable the build cache for docker builds. We do this with ?= operator in make
# so we only set DOCKER_BUILD_CACHE_ARG if it is not already set, this makes it
# possible to still use the cache if explicitly set through environment
# variables in CI.
ifneq ($(CI),)
ifeq ($(CI_COMMIT_REF_NAME),$(CI_DEFAULT_BRANCH))
DOCKER_BUILD_CACHE_ARG?=--no-cache
endif
endif
export DOCKER_BUILD_CACHE_ARG


.PHONY: ensure-fresh-nid-available

# Check for the existance of the NID base and dev images and attempt to get the
# latest versions. We don't need this check from a strictly functional
# perspective as builds or tests would fail anyway but by explicitly checking we
# can make some guesstimates and provide hints to the user on what might be
# wrong. By ensuring we have the latest version we avoid errors where newer
# functionality would be lacking in older images.
ensure-fresh-nid-available:
	@echo "Checking NSO in Docker images are available..."; \
		docker inspect $(NSO_IMAGE_PATH)cisco-nso-base:$(NSO_VERSION) >/dev/null 2>&1 && \
		(if [ "$(SKIP_PULL)" = "true" ]; then \
			echo "INFO: SKIP_PULL=$(SKIP_PULL), skipping pull of latest Docker images"; \
		else \
			if [ -n "$(NSO_IMAGE_PATH)" ]; then \
				echo "INFO: $(NSO_IMAGE_PATH)cisco-nso-base:$(NSO_VERSION) exists, attempting pull of latest version"; \
				docker pull $(NSO_IMAGE_PATH)cisco-nso-base:$(NSO_VERSION); \
				docker pull $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION); \
			fi; \
		fi); \
		docker inspect $(NSO_IMAGE_PATH)cisco-nso-base:$(NSO_VERSION) >/dev/null 2>&1 \
		|| (echo "ERROR: The docker image $(NSO_IMAGE_PATH)cisco-nso-base:$(NSO_VERSION) does not exist"; \
			if [ -z "$(NSO_IMAGE_PATH)" ]; then \
				docker image inspect $(NSO_IMAGE_PATH)cisco-nso-base:$(DOCKER_TAG) >/dev/null 2>&1 \
					&& echo "HINT: You have a locally built image cisco-nso-base:$(DOCKER_TAG), use it for this build by setting NSO_VERSION=$(DOCKER_TAG) or retag it by using the 'tag-release' make target in the nso-docker repo where the image was built" && exit 1; \
				docker image inspect $(NSO_IMAGE_PATH)cisco-nso-base:$(DOCKER_TAG) >/dev/null 2>&1 \
					|| echo "HINT: Set NSO_IMAGE_PATH to the registry path of the nso-docker repo, for example 'registry.gitlab.com/nso-developer/nso-docker/'" && false; \
			else \
				echo "Image not found locally, pulling from registry..."; \
				docker pull $(NSO_IMAGE_PATH)cisco-nso-base:$(NSO_VERSION) 2>/dev/null \
					|| (echo "ERROR: $(NSO_IMAGE_PATH)cisco-nso-base:$(NSO_VERSION) not found"; \
							echo "$(NSO_IMAGE_PATH)" | grep "/$$" >/dev/null || echo "HINT: did you forget a trailing '/' in NSO_IMAGE_PATH?"; \
							echo "HINT: Is NSO_IMAGE_PATH correctly set? Set NSO_IMAGE_PATH to the registry URL of the nso-docker repo, for example 'registry.gitlab.com/nso-developer/nso-docker/'"; \
							false); \
				docker pull $(NSO_IMAGE_PATH)cisco-nso-dev:$(NSO_VERSION) 2>/dev/null; \
			fi)
