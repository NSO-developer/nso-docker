FROM bitnami/minideb:buster

ARG NSO_INSTALL_FILE

COPY $NSO_INSTALL_FILE /tmp/nso
RUN apt-get update \
  && apt-get install -y openssh-client \
  && sh /tmp/nso --system-install --non-interactive \
  && # Remove stuff we don't need/want from the NSO installation
  && rm -rf \
       /opt/ncs/current/doc \
       /opt/ncs/current/erlang \
       /opt/ncs/current/examples.ncs \
       /opt/ncs/current/include \
       /opt/ncs/current/lib/ncs-project \
       /opt/ncs/current/lib/ncs/lib/confdc \
       /opt/ncs/current/lib/pyang \
       /opt/ncs/current/man \
       /opt/ncs/current/netsim/confd/erlang/econfd/doc \
       /opt/ncs/current/netsim/confd/src/confd/pyapi/doc \
       /opt/ncs/current/packages \
       /opt/ncs/current/src/aaa \
       /opt/ncs/current/src/build \
       /opt/ncs/current/src/cli \
       /opt/ncs/current/src/configuration_policy \
       /opt/ncs/current/src/errors \
       /opt/ncs/current/src/ncs/pyapi/doc \
       /opt/ncs/current/src/ncs_config \
       /opt/ncs/current/src/netconf \
       /opt/ncs/current/src/package-skeletons \
       /opt/ncs/current/src/project-skeletons \
       /opt/ncs/current/src/snmp \
       /opt/ncs/current/src/tools \
       /opt/ncs/current/src/yang \
       /opt/ncs/current/support \
       /opt/ncs/current/var/ncs/webui

FROM bitnami/minideb:buster

RUN install_packages openssh-client default-jre-headless python \
  && echo '. /opt/ncs/current/ncsrc' >> /root/.bashrc \
  && rm -rf /tmp/* /var/tmp/* /var/lib/{apt,dpkg,cache,log}/ \
  && mkdir /var/log/ncs \
  && rm -rf /usr/share/doc

COPY --from=0 /etc/ncs /etc/ncs/
COPY --from=0 /var/opt/ncs /var/opt/ncs/
COPY --from=0 /opt/ncs /opt/ncs/
COPY --from=0 /etc/init.d/ncs /etc/init.d/.

COPY run-nso.sh /
COPY java.xml /var/opt/ncs/cdb/
COPY admin.xml /var/opt/ncs/cdb/

EXPOSE 80 830 2022 2023 4569

CMD ["/run-nso.sh"]
