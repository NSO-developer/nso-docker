# You can set the default NSO_IMAGE_PATH & PKG_PATH to point to your docker
# registry so that developers don't have to manually set these variables.
# Similarly for NSO_VERSION you can set a default version. Note how the ?=
# operator only sets these variables if not already set, thus you can easily
# override them by explicitly setting them in your environment and they will be
# overridden by variables in CI.
# TODO: uncomment and fill in values for your environment
# Default variables:
#export NSO_IMAGE_PATH ?= registry.example.com:5000/my-group/nso-docker/
#export PKG_PATH ?= registry.example.com:5000/my-group/
#export NSO_VERSION ?= 5.4

# The default testenv should be a "quick" testenv, containing a simple test that
# is quick to run.
DEFAULT_TESTENV?=quick

# Include standard NID (NSO in Docker) package Makefile that defines all
# standard make targets
include nidpackage.mk

