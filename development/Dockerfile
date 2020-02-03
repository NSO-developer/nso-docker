FROM debian:buster

ARG NSO_INSTALL_FILE

COPY $NSO_INSTALL_FILE /tmp/nso
RUN apt-get update \
  && apt-get install -qy \
  openssh-client \
  libexpat1 \
  && sh /tmp/nso --system-install --non-interactive --run-dir /nso/run --log-dir /log \
  && sed -i -e 's/exec python -u/exec python3 -u/' /opt/ncs/current/bin/ncs-start-python-vm

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

RUN apt-get update \
  && apt-get install -qy \
     ant \
     iputils-tracepath \
     less \
     liblog4cplus-1.1-9 \
     libuv1 \
     libxml2-utils \
     logrotate \
     make \
     man \
     mypy \
     openssl \
     pylint3 \
     snmp \
     vim-tiny \
     xsltproc \
  && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 3 \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3.7 3 \
  && update-alternatives --install /usr/bin/pylint pylint /usr/bin/pylint3 1 \
  && apt-get -qy autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /root/.cache

# default shell is ["/bin/sh", "-c"]. We add -l so we get a login shell which
# means the shell reads /etc/profile on startup. /etc/profile includes the files
# in /etc/profile.d where we have ncs.sh that sets the right paths so we can
# access ncsc and other NSO related tools. This makes it possible for
# Dockerfiles, using this image as a base, to directly invoke make for NSO
# package compilation.
SHELL ["/bin/sh", "-lc"]

COPY /entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
