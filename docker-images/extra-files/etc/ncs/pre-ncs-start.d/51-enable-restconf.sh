#!/bin/sh
CONF_FILE=/etc/ncs/ncs.conf

# enable RESTCONF
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           --update '/x:ncs-config/x:restconf/x:enabled' --value 'true' \
           $CONF_FILE
