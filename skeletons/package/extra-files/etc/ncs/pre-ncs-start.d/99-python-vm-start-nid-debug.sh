#!/bin/sh
CONF_FILE=/etc/ncs/ncs.conf

# Enable Python Remote Debugging in VSCode by using the "remote debugging"
# flavor of the NSO Python VM startup script. This configuration will only take
# effect in the testnso docker image built by this repository. It will *not* be
# included in the final composed image.
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           --update '/x:ncs-config/x:python-vm/x:start-command' --value '/opt/ncs/nid/ncs-start-python-vm-debug' \
           $CONF_FILE
