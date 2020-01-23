FROM debian:buster

ARG NSO_INSTALL_FILE

COPY $NSO_INSTALL_FILE /tmp/nso
RUN apt-get update \
  && apt-get install -qy \
     ant \
     default-jre-headless \
     iputils-ping \
     iputils-tracepath \
     less \
     libexpat1 \
     liblog4cplus-1.1-9 \
     libuv1 \
     libxml2-utils \
     logrotate \
     make \
     mypy \
     openssh-client \
     openssl \
     pylint3 \
     python3.7 \
     snmp \
     tcpdump \
     telnet \
     vim-tiny \
     xsltproc \
  && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.7 3 \
  && update-alternatives --install /usr/bin/python python /usr/bin/python3.7 3 \
  && sh /tmp/nso --system-install --non-interactive --run-dir /nso/run --log-dir /log \
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
