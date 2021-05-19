#!/bin/sh

# The following variables will be set before this script
# is invoked.

# CONFD_IPC_PORT     - The port this ConfD instance is listening to for IPC
# NETCONF_SSH_PORT   - The port this ConfD instance is listening to for NETCONF
# NETCONF_TCP_PORT
# CLI_SSH_PORT       - The port this ConfD instance is listening to for CLI/ssh
# SNMP_PORT          - The port this ConfD instance is listening to for SNMP
# NAME               - The name of this ConfD instance
# COUNTER            - The number of this ConfD instance
# CONFD              - Path to the confd executable
# CONFD_DIR          - Path to the ConfD installation
# PACKAGE_NETSIM_DIR - Path to the netsim directory in the package which
#                      was used to produce this netsim network

## If you need to start additional things, like C code etc in the
## netsim environment, this is the place to add that

test -f  cdb/O.cdb
first_time=$?

env sname=${NAME} ${CONFD} -c confd.conf ${CONFD_FLAGS} \
    --addloadpath ${CONFD_DIR}/etc/confd
ret=$?

if [ ! $first_time = 0 ]; then
   true;
   ## If there is anything we want to do after the
   ## first initial start, this is the place. An example could be
   ## to load CDB operational data from xml files
fi

exit $ret

