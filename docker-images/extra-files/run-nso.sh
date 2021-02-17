#!/bin/bash

source /opt/ncs/current/ncsrc
source /opt/ncs/installdirs
export NCS_CONFIG_DIR NCS_LOG_DIR NCS_RUN_DIR

# install signal handlers
trap sigint_handler INT
trap sigquit_handler QUIT
trap sigterm_handler TERM

sigint_handler() {
    echo "run-nso.sh: received SIGINT, stopping NSO"
    ncs --stop
    exit 130 # 128+2
}

sigquit_handler() {
    echo "run-nso.sh: received SIGQUIT, stopping NSO"
    ncs --stop
    exit 131 # 128+3
}

sigterm_handler() {
    echo "run-nso.sh: received SIGTERM, stopping NSO"
    ncs --stop
    exit 143 # 128+15
}

# Increase JAVA VM MAX Heap size to 4GB, also enable the new G1 GC in Java 8
export NCS_JAVA_VM_OPTIONS="-Xmx4G -XX:+UseG1GC -XX:+UseStringDeduplication"

# enable core dump
mkdir -p /log /nso/coredumps
echo '/nso/coredumps/core.%e.%t' > /proc/sys/kernel/core_pattern

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

# if necessary, i.e. if starting NSO 5 on a CDB written by NSO 4, compact CDB
# if there is no CDB on disk, ncs --cdb-debug-dump will return "Error..." and we
# won't match that, thus such an error is handled correctly.
CDB_MAJVER=$(ncs --cdb-debug-dump /nso/run/cdb | awk '/^Version:.*from.*version/ { printf($2) }')
NSO_MAJVER=$(ncs --version | head -c 1)
if [ -n "${CDB_MAJVER}" ] && [ "${CDB_MAJVER}" -eq 4 ] && [ "${NSO_MAJVER}" -eq 5 ]; then
    echo "run-nso.sh: CDB written by NSO version 4 but now running version 5. Will attempt to compact CDB"
    ncs --cdb-compact /nso/run/cdb
    echo "run-nso.sh: CDB compaction done"
fi

# pre-start scripts
for FILE in $(ls /etc/ncs/pre-ncs-start.d/*.sh 2>/dev/null); do
    echo "run-nso.sh: running pre start script ${FILE}"
    . ${FILE}
done

# -- start NSO in the background
# The 'set +-m' are for job control monitor mode. As job control monitor mode is
# disabled per default, starting new processes places them in the same process
# group as this script. When ctrl-c is pressed, SIGINT is delivered to all the
# processes in the foreground process group, which would then include ncs. ncs
# is really the Erlang BEAM VM, just renamed, and it doesn't handle ^c well - it
# doesn't shut down ncs cleanly. To avoid this, we enable job control monitor
# mode so that ncs is started as a background task in a different process group,
# thus avoiding sending SIGINT to it on ^c. Instead we can handle SIGINT and
# nicely ask ncs to shut down.
set -m
# output logs to stdout a la container style
ncs --cd ${NCS_RUN_DIR} -c ${NCS_CONFIG_DIR}/ncs.conf --foreground -v --with-package-reload-force &
NSO_PID="$!"
set +m

# sleep a bit so ncs has a chance to start its IPC port
# this doesn't slow down startup since we wait for ncs to start as the next step
# anyway and that wait is much longer
sleep 3
ncs --wait-started 600

# post-start scripts
for FILE in $(ls /etc/ncs/post-ncs-start.d/*.sh 2>/dev/null); do
    echo "run-nso.sh: running post start script ${FILE}"
    . ${FILE}
done

# wait forever on the ncs process, we run ncs in background and wait on it like
# this, with a signal handler for INT & TERM so that we upon receiving those
# signals can run ncs --stop rather than having those signals sent raw to ncs
wait ${NSO_PID}
EXIT_CODE=$?
echo "run-nso.sh: NSO exited (exit code ${EXIT_CODE}) - exiting container"
exit ${EXIT_CODE}
