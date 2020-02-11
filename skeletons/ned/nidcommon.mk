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
CNT_PREFIX?=testenv-$(PROJECT_NAME)-$(NSO_VERSION)-$(PNS)

# Path for the NSO docker images (NSO_IMAGE_PATH) is derived based on
# information we get from Gitlab CI, if available. Similarly, the path we use
# for the images we produce is also based on information from Gitlab CI.
ifneq ($(CI_REGISTRY),)
NSO_IMAGE_PATH?=$(CI_REGISTRY)/$(CI_PROJECT_NAMESPACE)/nso-docker/
IMAGE_PATH?=$(CI_REGISTRY_IMAGE)/
PKG_PATH?=$(CI_REGISTRY)/$(CI_PROJECT_NAMESPACE)/
endif
