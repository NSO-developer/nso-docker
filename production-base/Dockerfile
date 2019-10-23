FROM debian:buster

ARG NSO_INSTALL_FILE

COPY $NSO_INSTALL_FILE /tmp/nso
RUN apt-get update \
  && apt-get install -qy \
     openssh-client \
     libexpat1 \
  && sh /tmp/nso --system-install --non-interactive --run-dir /nso/run --log-dir /log \
  # wipe SSH keys
  && rm -f /etc/ncs/ssh/* \
  # Remove stuff we don't need/want from the NSO installation \
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
       /opt/ncs/current/var/ncs/webui \
  && sed -i \
     -e 's,<dir>${NCS_RUN_DIR}/packages</dir>,<dir>/var/opt/ncs/packages</dir>,' \
     /etc/ncs/ncs.conf \
  && sed -i -e 's/exec python -u/exec python3 -u/' /opt/ncs/current/bin/ncs-start-python-vm

FROM debian:buster

RUN apt-get update \
 && apt-get install -qy \
  default-jre-headless \
  iputils-ping \
  libexpat1 \
  openssh-client \
  procps \
  python3 \
  tcpdump \
  telnet \
  xmlstarlet \
  && apt-get -qy autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /root/.cache \
  && echo '. /opt/ncs/current/ncsrc' >> /root/.bashrc \
  && rm -rf /usr/share/doc

COPY --from=0 /etc/ncs /etc/ncs/
COPY --from=0 /nso /nso
COPY --from=0 /opt/ncs /opt/ncs/
COPY --from=0 /etc/init.d/ncs /etc/init.d/.

COPY run-nso.sh /
COPY mangle-config.sh /etc/ncs/pre-ncs-start.d/50-mangle-config.sh
COPY add-user.sh /etc/ncs/pre-ncs-start.d/55-add-user.sh
COPY add_user_template.xml /add_user_template.xml

EXPOSE 22 80 443 830 4334

HEALTHCHECK --start-period=60s --interval=5s --retries=3 --timeout=5s CMD /opt/ncs/current/bin/ncs_cmd -c get_phase

CMD ["/run-nso.sh"]
