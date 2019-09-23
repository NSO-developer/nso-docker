#!/bin/bash
#
# Script to start ncs and monitor the process
# Environment variables:
#       NSO_USE_HA: use HA configuration if set to 'true'
#
#       SLEEP_TIMER: Time period between each wake up to check for signals
#                    docker does not seem to send the signal to the sleeping
#                    process until the timer expires. So do not make this too
#                    long. Default = 1 (second)
#
#       CHECK_TIMER: Time period between checking the state of ncs daemon
#                    Default = 60 (seconds), should be a multiple of
#                    SLEEP_TIMER

# install signal handler to stop NCS and exit
trap ncs_exit INT TERM

# enable core dump

# Increase JAVA VM MAX Heap size to 4GB, also enable the new G1 GC in Java 8
export NCS_JAVA_VM_OPTIONS="-Xmx4G -XX:+UseG1GC -XX:+UseStringDeduplication"

mkdir -p /log /ncs/coredumps
echo '/ncs/coredumps/core.%e.%t' > /proc/sys/kernel/core_pattern

ncs_start() {
    # we disable SNMP northbound by not loading the $NCS_DIR/etc/ncs/snmp,
    # but in NCS 4.5.6 the file ietf-yang-smiv2.fxs is moved to this dir,
    # we need this for our SNMP packages
    smiv2=/opt/ncs/current/etc/ncs/snmp/ietf-yang-smiv2.fxs
    if [ -f $smiv2 ]
    then
        cp $smiv2 /opt/ncs/current/etc/ncs
    fi
    # always reload the packages, needed to handle upgrade
    NCS_RELOAD_PACKAGES=force /etc/init.d/ncs start
}

ncs_exit() {
    echo "run-ncs.sh: Got signal, stopping NCS now"
    /etc/init.d/ncs stop
    exit $?
}

ncs_check() {
    # loop up to 5 times
    iter=0
    status=1
    while (( $iter < 5 && $status != 0 ))
    do
        error_msg=`/etc/init.d/ncs status 2>&1`
        status=$?
        iter=$(($iter + 1))
        if (( $status != 0 ))
        then
            echo "run-ncs.sh: NCS check failed, wait another ${CHECK_TIMER}s"
            sleep $CHECK_TIMER
        fi
    done
    if [ $status != 0 ]
    then
        echo "run-ncs.sh: NCS died, error $error_msg"
    fi
    return $status
}

# create required directories
mkdir -p /ncs/cdb /ncs/rollbacks /ncs/scripts /ncs/streams /ncs/state /ncs/backups
mkdir -p /log/traces

for FILE in $(ls /etc/ncs/pre-ncs-start.d/*.sh); do
    . ${FILE}
done

OK_FILE=/.ncs-ok
rm -f $OK_FILE

ncs_start

for FILE in $(ls /etc/ncs/post-ncs-start.d/*.sh); do
    . ${FILE}
done

# wait for NCS to start and write OK file
echo "run-ncs.sh: Waiting (max 600s) for NCS to start..."
/opt/ncs/current/bin/ncs --wait-started 600 || (echo "run-ncs.sh: NCS failed to start in 600 seconds, exiting"; exit 1)
echo "run-ncs.sh: NCS started!"
touch $OK_FILE

# run periodic check loop until interrupted or NCS daemon dies

counter=0
echo "run-ncs.sh: Wait timer is ${SLEEP_TIMER:=1} seconds"
echo "run-ncs.sh: Status check timer is ${CHECK_TIMER:=60} seconds"
while true
do
    sleep $SLEEP_TIMER
    counter=$((SLEEP_TIMER + counter))

    if [ $counter -ge ${CHECK_TIMER} ]
    then
        counter=0
        echo "run-ncs.sh: Checking NCS status at $(date +'%Y-%m-%d %H:%M:%S')"
        ncs_check || exit $?
        echo "run-ncs.sh: NCS OK"
        touch $OK_FILE
    fi

done
