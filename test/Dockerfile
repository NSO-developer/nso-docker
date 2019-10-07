ARG BASE_IMAGE
ARG BUILD_IMAGE
FROM $BUILD_IMAGE

COPY packages /packages
# default shell is ["/bin/sh", "-c"]. We add -l so we get a login shell which
# means the shell reads /etc/profile on startup. /etc/profile includes the files
# in /etc/profile.d where we have ncs.sh that sets the right paths so we can
# access ncsc and other NSO related tools.
SHELL ["/bin/sh", "-lc"]
RUN make -C /packages/testpkg/src
RUN make -C /packages/testpkg-python/src

FROM $BASE_IMAGE

COPY --from=0 /packages /var/opt/ncs/packages
