#!/bin/sh
CONF_FILE=/etc/ncs/ncs.conf

# enable SSH CLI, NETCONF over SSH northbound and NETCONF call-home
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           --update '/x:ncs-config/x:python-vm/x:start-command' --value '/opt/ncs/nid/ncs-start-python-vm' \
           $CONF_FILE
