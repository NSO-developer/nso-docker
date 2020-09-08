FROM debian:buster AS nso_install

RUN apt-get update \
  && apt-get install -qy \
  openssh-client \
  libexpat1 \
  && apt-get -qy autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /root/.cache

ARG NSO_INSTALL_FILE
COPY $NSO_INSTALL_FILE /tmp/nso

RUN sh /tmp/nso --system-install --non-interactive --run-dir /nso/run --log-dir /log \
  && sed -i -e 's/exec python -u/exec python3 -u/' /opt/ncs/current/bin/ncs-start-python-vm

FROM nso_install AS nso_stripped

  # wipe SSH keys
RUN rm -f /etc/ncs/ssh/* \
  # save the default aaa_init for later
  && mkdir -p /nid/cdb-default \
  && mv /nso/run/cdb/aaa_init.xml /nid/cdb-default/ \
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


FROM debian:buster AS deb_base

RUN apt-get update \
  && apt-get install -qy \
  default-jre-headless \
  iputils-ping \
  less \
  libexpat1 \
  openssh-client \
  procps \
  python3 \
  tcpdump \
  telnet \
  xmlstarlet \
  # install debugpy via pip3, then immediately remove pip3 from base
  && apt-get install -qy --no-install-recommends python3-pip \
  && pip3 install debugpy \
  && apt-get -qy purge python3-pip \
  && apt-get -qy autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /root/.cache \
  && echo '. /opt/ncs/current/ncsrc' >> /root/.bashrc \
  # Add root to ncsadmin group for easier command-line tools usage
  && groupadd ncsadmin \
  && usermod -a -G ncsadmin root


FROM deb_base AS dev

RUN echo "deb http://deb.debian.org/debian buster-backports main" > /etc/apt/sources.list.d/buster-backports.list \
  && apt-get update \
  && apt-get install -qy \
     ant \
     curl \
     gawk \
     git \
     iputils-tracepath \
     liblog4cplus-1.1-9 \
     libuv1 \
     libxml2-utils \
     logrotate \
     make \
     man \
     mypy \
     openssl \
     pylint3 \
     python3-pip \
     python3-venv \
     python3-wheel \
     rsync \
     snmp \
     vim-tiny \
     xsltproc \
  && apt-get install -qy -t buster-backports \
     # paramiko is required by netconf-console
     python3-paramiko \
  && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 3 \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3.7 3 \
  && update-alternatives --install /usr/bin/pylint pylint /usr/bin/pylint3 1 \
  && apt-get -qy autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /root/.cache

COPY --from=nso_install /etc/profile.d /etc/profile.d
COPY --from=nso_install /etc/init.d/ncs /etc/init.d/.
COPY --from=nso_install /etc/ncs /etc/ncs/
COPY --from=nso_install /opt/ncs /opt/ncs/
COPY --from=nso_install /nso /nso
COPY extra-files/ /

# default shell is ["/bin/sh", "-c"]. We add -l so we get a login shell which
# means the shell reads /etc/profile on startup. /etc/profile includes the files
# in /etc/profile.d where we have ncs.sh that sets the right paths so we can
# access ncsc and other NSO related tools. This makes it possible for
# Dockerfiles, using this image as a base, to directly invoke make for NSO
# package compilation.
SHELL ["/bin/sh", "-lc"]

ENTRYPOINT ["/enter-shell.sh"]


FROM deb_base AS base

COPY --from=nso_stripped /etc/profile.d /etc/profile.d
COPY --from=nso_stripped /etc/init.d/ncs /etc/init.d/.
COPY --from=nso_stripped /etc/ncs /etc/ncs/
COPY --from=nso_stripped /opt/ncs /opt/ncs/
COPY --from=nso_stripped /nso /nso
COPY --from=nso_stripped /nid /nid
COPY extra-files/ /

EXPOSE 22 80 443 830 4334

HEALTHCHECK --start-period=60s --interval=5s --retries=3 --timeout=5s CMD /opt/ncs/current/bin/ncs_cmd -c get_phase

CMD ["/run-nso.sh"]
