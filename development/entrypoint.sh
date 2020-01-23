#!/bin/sh

# magic entrypoint that runs an interactive bash login shell if no arguments are
# given, which means that invoking the container with docker run and no
# arguments will yield a interactive bash login shell. Being a login shell, it
# has read the .profile that contains the necessary includes for setting NSO
# specific paths.
#
# If arguments are provided, it is treated as a command and will again be run by
# a bash login shell, allowing a user to do for example:
#   docker run -it cisco-nso-dev:5.3 ncs-make-package --help
#

if [ $# -eq 0 ]; then
    exec /bin/bash -l
else
    exec /bin/bash -lc "$*"
fi
