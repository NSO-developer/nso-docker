ARG BASE_IMAGE
ARG BUILD_IMAGE
FROM $BUILD_IMAGE

COPY packages /packages
RUN make -C /packages/testpkg/src
RUN make -C /packages/testpkg-java/src
RUN make -C /packages/testpkg-python/src

FROM $BASE_IMAGE

COPY --from=0 /packages /var/opt/ncs/packages
