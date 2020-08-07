#!/bin/sh

SSH_PORT=${SSH_PORT:-22}
CONF_FILE=/etc/ncs/ncs.conf

# enable IPv6 for NETCONF northbound
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           -s '/x:ncs-config/x:netconf-north-bound/x:transport/x:ssh' -t elem -n extra-listen \
           -s '/x:ncs-config/x:netconf-north-bound/x:transport/x:ssh/extra-listen' -t elem -n ip -v '::' \
           -s '/x:ncs-config/x:netconf-north-bound/x:transport/x:ssh/extra-listen' -t elem -n port -v '830' \
           $CONF_FILE

# enable IPv6 for NETCONF Call Home northbound
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           -s '/x:ncs-config/x:netconf-call-home/x:transport/x:tcp' -t elem -n extra-listen \
           -s '/x:ncs-config/x:netconf-call-home/x:transport/x:tcp/extra-listen' -t elem -n ip -v '::' \
           -s '/x:ncs-config/x:netconf-call-home/x:transport/x:tcp/extra-listen' -t elem -n port -v '4334' \
           $CONF_FILE

# enable IPv6 for SSH northbound
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           -s '/x:ncs-config/x:cli/x:ssh' -t elem -n extra-listen \
           -s '/x:ncs-config/x:cli/x:ssh/extra-listen' -t elem -n ip -v '::' \
           -s '/x:ncs-config/x:cli/x:ssh/extra-listen' -t elem -n port -v "${SSH_PORT}" \
           $CONF_FILE

# enable IPv6 for webUI (no TLS) northbound
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           -s '/x:ncs-config/x:webui/x:transport/x:tcp' -t elem -n extra-listen \
           -s '/x:ncs-config/x:webui/x:transport/x:tcp/extra-listen' -t elem -n ip -v '::' \
           -s '/x:ncs-config/x:webui/x:transport/x:tcp/extra-listen' -t elem -n port -v '80' \
           $CONF_FILE

# enable IPv6 for webUI (with TLS) northbound
xmlstarlet edit --inplace -N x=http://tail-f.com/yang/tailf-ncs-config \
           -s '/x:ncs-config/x:webui/x:transport/x:ssl' -t elem -n extra-listen \
           -s '/x:ncs-config/x:webui/x:transport/x:ssl/extra-listen' -t elem -n ip -v '::' \
           -s '/x:ncs-config/x:webui/x:transport/x:ssl/extra-listen' -t elem -n port -v '443' \
           $CONF_FILE