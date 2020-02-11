#!/bin/bash

# Usage: netsim package-name netsim-prefix [-x module-name | -p | -s ]
# use -x to exclude certain module from netsim, useful to run netsim when
# running netsim with different versions of modules
# use -p to show the IPC port
# use -s to stop the devices
# use -r to restart, remove all exising config and reload initial config

delete-network() {
    touch /.netsim-rebuild
    # dump the netsim device config to /tmp/config.xml
    CONFD_IPC_PORT=`/netsim -p` /opt/ncs/current/netsim/confd/bin/confd_load /tmp/config.xml
    /opt/ncs/current/bin/ncs-netsim --dir /nsim delete-network
}

restart-network() {
    touch /.netsim-rebuild
    /opt/ncs/current/bin/ncs-netsim --dir /nsim restart
    rm /.netsim-rebuild
}

while getopts x:prs opt; do
    case $opt in
        x)
          EXC_MODULE=$OPTARG
          shift $((OPTIND-1))
          echo "Removing module $EXC_MODULE"
          ;;
        p)
          /opt/ncs/current/bin/ncs-netsim --dir /nsim list | grep -oP 'ipc=\K[0-9]+'
          exit 0
          ;;
        s)
          delete-network
          exit 0
          ;;
        r)
          restart-network
          exit 0
          ;;
    esac
done

NS_TYPE=$1
NS_PREFIX=$2
# input validation?

export CLI_SSH_PORT=22
export NETCONF_SSH_PORT=830

netsim_check() {
    if [[ -f /.netsim-rebuild ]]; then
        return 0
    else
        /opt/ncs/current/bin/ncs-netsim --dir /nsim is-alive | grep FAIL
        test $? -eq 1
        return $?
    fi
}

already_running() {
    if [[ -f /.ncs-ok ]]; then
        return 0
    else
        return 1
    fi
}


source_dir=/var/opt/ncs/packages/$NS_TYPE

# restore NED package if files were removed previously, then stop & remove netsim device
if already_running; then
    if [[ -e /tmp/backup-$NS_TYPE ]]; then
        echo "Restoring package $NS_TYPE to original state"
        rm -rf $source_dir
        mv /tmp/backup-$NS_TYPE $source_dir
    fi

    # stop netsim if it's not yet stopped
    if [[ ! -f /.netsim-rebuild ]]; then
        delete-network
        # Wait so device monitor can detect device failures
        sleep 30
    fi
fi

# create netsim network if it doesn't exist
if [[ ! -e /nsim ]]; then
    /opt/ncs/current/bin/ncs-netsim --dir /nsim create-network /var/opt/ncs/packages/$NS_TYPE 1 $NS_PREFIX
    # remove new excluded files if needed
    if [ -n "$EXC_MODULE" ]; then
        FILES=$(find /nsim -name "${EXC_MODULE}.fxs" -o -name "${EXC_MODULE}.yang")
        echo "Removing $FILES"
        if [ -n "$FILES" ]; then
            rm -f $FILES
        fi
    fi
fi

# start netsim
/opt/ncs/current/bin/ncs-netsim --dir /nsim start


if already_running; then
    rm -f /.netsim-rebuild

    # load the save config from /tmp/config.xml
    # loading parts of the configuration may fail because of changed namespaces
    CONFD_IPC_PORT=`/netsim -p` /opt/ncs/current/netsim/confd/bin/confd_load -e -l /tmp/config.xml || true
else
    # just wait forever
    echo "waiting forever (or until I get a SIGTERM)"
    while true; do
        sleep 1
        touch /.ncs-ok
        netsim_check || exit $?
    done
fi
