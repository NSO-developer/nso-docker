#!/bin/sh
# this will run a simple command against NCS demonstrating that NCS has
# correctly started to its normal phase2 and is listening on commands
ncs_cli -u admin -g ncsadmin -c "show version"
if [ $? -eq 0 ]; then
    echo "post-start-script result: success"
else
    echo "post-start-script result: fail"
fi
