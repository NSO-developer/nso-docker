#!/bin/sh

if [ ! -f "/nso/run/cdb/C.cdb" ]; then
    echo "No existing CDB detected, adding aaa_init.xml"
    cp /nid/aaa_init.xml /nso/run/cdb/
fi
