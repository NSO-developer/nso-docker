#!/bin/sh
CONF_FILE=/etc/ncs/ncs.conf

# Use the Python VM startup script shipped with NSO in Docker
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           --update '/x:ncs-config/x:python-vm/x:start-command' --value '/opt/ncs/nid/ncs-start-python-vm' \
           $CONF_FILE
