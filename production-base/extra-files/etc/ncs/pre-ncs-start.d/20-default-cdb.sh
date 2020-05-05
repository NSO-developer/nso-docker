#!/bin/sh

if [ ! -f "/nso/run/cdb/C.cdb" ]; then
    echo "No existing CDB detected, adding default CDB data:"
    cp -av /nid/cdb-default/. /nso/run/cdb/
    echo "End of CDB default data files."
fi
