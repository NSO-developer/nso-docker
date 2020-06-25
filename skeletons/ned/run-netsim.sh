#!/bin/bash

source /opt/ncs/current/ncsrc
source /opt/ncs/installdirs
export NCS_CONFIG_DIR NCS_LOG_DIR NCS_RUN_DIR


# install signal handlers
trap sighup_handler HUP
trap sigint_handler INT
trap sigquit_handler QUIT
trap sigterm_handler TERM

sighup_handler() {
    echo "run-nso.sh: received SIGHUP, restarting netsim"
    RESTART_REQUESTED=true
    stop_netsim
    start_netsim
}

sigint_handler() {
    echo "run-nso.sh: received SIGINT, stopping netsim"
    stop_netsim
    exit 130 # 128+2
}

sigquit_handler() {
    echo "run-nso.sh: received SIGQUIT, stopping netsim"
    stop_netsim
    exit 131 # 128+3
}

sigterm_handler() {
    echo "run-nso.sh: received SIGTERM, stopping netsim"
    stop_netsim
    exit 143 # 128+15
}

# Start confd, we do this manually instead of using ncs-netsim so we can grab
# the PID and later wait on that.
# -+m is to turn off and on monitor mode for job control, we do this to ensure
# that confd does NOT end up in the same process group as this startup script,
# in turn to allow us to shut in down cleanly. In case the container is run
# interactively, the run-netsim.sh script will be in the foreground process
# group and pressing ^C will send SIGINT to all processes in the foreground
# process group. 'confd' is actually the Erlang BEAM VM renamed, and upon
# receiving SIGINT, BEAM will just immediately terminate. confd must instead be
# asked to shut down so that it may flush outstanding CDB changes etc to disk.
start_netsim() {
    set -m
    cd /netsim/dev/dev
    CONFD_FLAGS=--foreground ./start.sh &
    CONFD_PID="$!"
    set +m
}

# Stop confd
stop_netsim() {
    cd /netsim/dev/dev
    ./stop.sh
    CONFD_PID=""
}



NS_TYPE=$(ls /var/opt/ncs/packages/)

export CLI_SSH_PORT=22
export NETCONF_SSH_PORT=830

source_dir=/var/opt/ncs/packages/$NS_TYPE


# setup netsim device if it doesn't exist
if [[ ! -e /netsim/dev/dev ]]; then
    /opt/ncs/current/bin/ncs-netsim --dir /netsim create-device /var/opt/ncs/packages/$NS_TYPE $(hostname)
    mkdir -p /netsim/dev
    mv /netsim/$(hostname)/$(hostname) /netsim/dev/dev
    rmdir /netsim/$(hostname)
fi

# start confd in the background
start_netsim


# just wait forever
echo "waiting forever (or until I get a SIGTERM)"
while true; do
    RESTART_REQUESTED=false
    wait ${CONFD_PID}
    EXIT_CODE=$?
    if [ "${RESTART_REQUESTED}" = false ]; then
        echo "run-netsim.sh: netsim (confd) exited (exit code ${EXIT_CODE}) - exiting container"
        exit ${EXIT_CODE}
    fi
done
