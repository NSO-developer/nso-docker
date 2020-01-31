ARG NSO_IMAGE_PATH
ARG NSO_VERSION

FROM ${NSO_IMAGE_PATH}cisco-nso-dev:${NSO_VERSION} AS build

COPY packages /packages
RUN for PKG in $(ls /packages); do make -C /packages/${PKG}/src; done

COPY test-packages /test-packages
RUN for PKG in $(ls /test-packages); do make -C /test-packages/${PKG}/src; done


FROM ${NSO_IMAGE_PATH}cisco-nso-base:${NSO_VERSION} AS testnso
COPY --from=build /packages/ /var/opt/ncs/packages/
COPY --from=build /test-packages/ /var/opt/ncs/packages/


FROM scratch AS package
COPY --from=build /packages/ /var/opt/ncs/packages/
