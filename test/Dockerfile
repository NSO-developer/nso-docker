ARG BASE_IMAGE
ARG BUILD_IMAGE
FROM $BUILD_IMAGE

COPY testpkg /testpkg
# default shell is ["/bin/sh", "-c"]. We add -l so we get a login shell which
# means the shell reads /etc/profile on startup. /etc/profile includes the files
# in /etc/profile.d where we have ncs.sh that sets the right paths so we can
# access ncsc and other NSO related tools.
SHELL ["/bin/sh", "-lc"]
RUN make -C /testpkg/src

FROM $BASE_IMAGE

COPY --from=0 /testpkg /packages/testpkg
