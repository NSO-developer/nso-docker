#!/bin/bash

CRON_ENABLE=${CRON_ENABLE:-true}
LOGROTATE_ENABLE=${LOGROTATE_ENABLE:-true}

echo "== Logrotate and cron config variables"
echo "CRON_ENABLE: ${CRON_ENABLE}"
echo "LOGROTATE_ENABLE: ${LOGROTATE_ENABLE}"

if [ ${LOGROTATE_ENABLE} = "true" ] && [ ${CRON_ENABLE} = "false" ]; then
    echo "Logrotate requires cron, please set CRON_ENABLE=true"
    exit 1
fi

if [ ${CRON_ENABLE} = "true" ]; then
    echo "Starting cron"
    cron
fi

if [ ${LOGROTATE_ENABLE} = "true" ]; then
    # logrotate refuses to use the config if it is writable by the world.
    # /etc/logrotate.d/ncs from NSO system install already comes with the
    # correct permissions, but if the users have replaced it with their own via
    # /extra-files then logrotate may silently fail for them.
    echo "Ensuring -rw-r--r-- permissions on /etc/logrotate.d/ncs"
    chmod 644 /etc/logrotate.d/ncs
else
    echo "Removing /etc/logrotate.d/ncs"
    rm /etc/logrotate.d/ncs
fi
