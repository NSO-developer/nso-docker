FROM bitnami/minideb:buster

ARG NSOVER

COPY nso-$NSOVER.linux.x86_64.installer.bin /tmp/nso
RUN apt-get update; \
    apt-get install -y openssh-client; \
    sh /tmp/nso --system-install; \
    # Generate SSH key in PEM format
    rm -f /etc/ncs/ssh/*; \
    ssh-keygen -m PEM -t rsa -f /etc/ncs/ssh/ssh_host_rsa_key -N ''; \
    # Remove stuff we don't need/want from the NSO installation
    rm -rf /opt/ncs/current/var/ncs/webui; \
    rm -rf /opt/ncs/current/doc; \
    rm -rf /opt/ncs/current/man; \
    rm -rf /opt/ncs/current/examples.ncs; \
    rm -rf /opt/ncs/current/include; \
    rm -rf /opt/ncs/current/packages; \
    rm -rf /opt/ncs/current/support; \
    rm -rf /opt/ncs/current/src/aaa; \
    rm -rf /opt/ncs/current/src/build; \
    rm -rf /opt/ncs/current/src/cli; \
    rm -rf /opt/ncs/current/src/configuration_policy; \
    rm -rf /opt/ncs/current/src/errors; \
    rm -rf /opt/ncs/current/src/ncs_config; \
    rm -rf /opt/ncs/current/src/netconf; \
    rm -rf /opt/ncs/current/src/package-skeletons; \
    rm -rf /opt/ncs/current/src/project-skeletons; \
    rm -rf /opt/ncs/current/src/snmp; \
    rm -rf /opt/ncs/current/src/tools; \
    rm -rf /opt/ncs/current/src/yang; \
    rm -rf /opt/ncs/current/lib/ncs/lib/confdc; \
    rm -rf /opt/ncs/current/lib/ncs-project; \
    rm -rf /opt/ncs/current/lib/pyang; \
    rm -rf /opt/ncs/current/erlang \
    rm -rf /opt/ncs/current/netsim/confd/src/confd/pyapi/doc \
    rm -rf /opt/ncs/current/netsim/confd/erlang/econfd/doc \
    rm -rf /opt/ncs/current/src/ncs/pyapi/doc

FROM bitnami/minideb:buster

# The hashed pwd was generated on a Linux (doesn't seem to work on Mac OS)
# python3 -c 'import crypt; print(crypt.crypt("cisco123", crypt.mksalt(crypt.METHOD_SHA512)))'

RUN install_packages openssh-client default-jre-headless python; \
    echo '. /opt/ncs/current/ncsrc' >> /root/.bashrc; \
    rm -rf /tmp/* /var/tmp/* /var/lib/{apt,dpkg,cache,log}/; \
    mkdir /var/log/ncs; \
    groupadd ncsadmin; \
    useradd admin -g ncsadmin; \
    echo 'admin:$6$xCnzTvhGBo5JwBnF$A7eeqpeUDeDzBLF0/..3QqGqtEaFYbDK2xsHrrQHm4RkQkX5W/AiCwwMx2osocS7qTv2a35zKTE3kS3oSKE2G.' | chpasswd -e; \
    rm -rf /usr/share/doc

COPY --from=0 /etc/ncs /etc/ncs/
COPY --from=0 /var/opt/ncs /var/opt/ncs/
COPY --from=0 /opt/ncs /opt/ncs/
COPY --from=0 /etc/init.d/ncs /etc/init.d/.

COPY run-nso.sh /
COPY java.xml /var/opt/ncs/cdb/
COPY admin.xml /var/opt/ncs/cdb/

EXPOSE 80 830 2022 2023 4569

CMD ["/run-nso.sh"]
