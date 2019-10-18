#!/bin/bash

source /opt/ncs/current/ncsrc
source /opt/ncs/installdirs
export NCS_CONFIG_DIR NCS_LOG_DIR NCS_RUN_DIR

# install signal handler to stop NCS and exit
trap term_handler INT TERM

# Increase JAVA VM MAX Heap size to 4GB, also enable the new G1 GC in Java 8
export NCS_JAVA_VM_OPTIONS="-Xmx4G -XX:+UseG1GC -XX:+UseStringDeduplication"

# enable core dump
mkdir -p /log /nso/coredumps
echo '/nso/coredumps/core.%e.%t' > /proc/sys/kernel/core_pattern

term_handler() {
    echo "run-nso.sh: received signal, stopping NSO"
    ncs --stop
    wait ${nso_pid}

    exit 143; # 128 + 15 -- SIGTERM
}

# create required directories
mkdir -p /nso/run/cdb /nso/run/rollbacks /nso/run/scripts /nso/run/streams /nso/run/state /nso/run/backups
mkdir -p /log/traces

# generate SSH key if one doesn't exist
if [ ! -f /nso/ssh/ssh_host_rsa_key ]; then
    mkdir /nso/ssh
    ssh-keygen -m PEM -t rsa -f /nso/ssh/ssh_host_rsa_key -N ''
fi

# generate SSL cert if one doesn't exist
if [ ! -f /nso/ssl/cert/host.cert ]; then
    mkdir -p /nso/ssl/cert
    openssl req -new -newkey rsa:4096 -x509 -sha256 -days 30 -nodes -out /nso/ssl/cert/host.cert -keyout /nso/ssl/cert/host.key \
            -subj "/C=SE/ST=NA/L=/O=NSO/OU=WebUI/CN=Mr. Self-Signed"
fi

# pre-start scripts
for FILE in $(ls /etc/ncs/pre-ncs-start.d/*.sh); do
    . ${FILE}
done

# start NSO in the background
# output logs to stdout a la container style
ncs --cd ${NCS_RUN_DIR} -c ${NCS_CONFIG_DIR}/ncs.conf --foreground -v &
nso_pid="$!"

# post-start scripts
for FILE in $(ls /etc/ncs/post-ncs-start.d/*.sh); do
    . ${FILE}
done

# wait forever on the ncs process, we run ncs in background and wait on it like
# this, with a signal handler for INT & TERM so that we upon receiving those
# signals can run ncs --stop rather than having those signals sent raw to ncs
wait ${!}
echo "run-nso.sh: NSO exited - exiting container"
