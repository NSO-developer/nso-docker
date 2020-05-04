FROM debian:buster

ARG NSO_INSTALL_FILE

COPY $NSO_INSTALL_FILE /tmp/nso
RUN apt-get update \
  && apt-get install -qy \
     openssh-client \
     libexpat1 \
  && sh /tmp/nso --system-install --non-interactive --run-dir /nso/run --log-dir /log \
  && sed -i -e 's/exec python -u/exec python3 -u/' /opt/ncs/current/bin/ncs-start-python-vm

  # wipe SSH keys
RUN rm -f /etc/ncs/ssh/* \
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
  && sed -i \
     -e 's,<dir>${NCS_RUN_DIR}/packages</dir>,<dir>/var/opt/ncs/packages</dir>,' \
     /etc/ncs/ncs.conf

FROM debian:buster

# This installation command needs to be kept in sync between the base image and
# development image as to result in the same Docker image layer and thus achieve
# layer reuse between the -base and -dev image
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
  # Add root to ncsadmin group for easier command-line tools usage
  && groupadd ncsadmin \
  && usermod -a -G ncsadmin root

COPY --from=0 /etc/profile.d /etc/profile.d
COPY --from=0 /etc/init.d/ncs /etc/init.d/.
COPY --from=0 /etc/ncs /etc/ncs/
COPY --from=0 /opt/ncs /opt/ncs/
COPY --from=0 /nso /nso

COPY extra-files/ /

EXPOSE 22 80 443 830 4334

HEALTHCHECK --start-period=60s --interval=5s --retries=3 --timeout=5s CMD /opt/ncs/current/bin/ncs_cmd -c get_phase

CMD ["/run-nso.sh"]
