#!/bin/bash

create_or_update_venv () {
    # $1 - package directory
    # $2 - path to the requirements.txt file
    # $3 - venv directory name
    # $4 - use --clear for creating the venv (defaults to true)
    local pkg_dir=$1
    local req_txt=$2
    local venv=$3
    local clear=${4:-true}
    pushd "${pkg_dir}" > /dev/null
    if [ -f "${req_txt}" ]; then
        if [ ! -f "${venv}/pyvenv.cfg" ] || [ "${clear}" == "true" ]; then
            echo "Creating '${venv}' venv and installing packages from ${req_txt} (clear=${clear})"
            # use --system-site-packages to be able to use already installed things,
            # like pylint (which is built with the venv activated), without also having
            # to install it in our venv
            python3 -m venv --symlinks --system-site-packages $([ "${clear}" == "true" ] && echo "--clear") "${venv}"
            # venv starts by resolving the symlink of its own location, thus doesn't
            # think /var/opt/ncs/packages/ is its location but /src/(test-)?packages
            # - we fix that with sed...
            find "${venv}" -type f -print0 | xargs -0 sed -i -e 's,/src/\(test-\)\?packages/,/var/opt/ncs/packages/,'
            . "${venv}"/bin/activate
            # upgrade pip to latest version (in the venv) to deal with correct
            # downloading of wheel packages
            pip3 install --upgrade pip
        else
            echo "Activating existing '${venv}' venv and installing packages from ${req_txt}"
            pwd
            . "${venv}"/bin/activate
        fi
        # we ignore-installed to installed things even thought they are already
        # installed in the system as otherwise we depend on the system packages and
        # as those can shift between the -dev container and the -base container we
        # might get unexpected results
        pip3 install -r "${req_txt}" --ignore-installed
        chown -R $(ls -nd /src | awk '{ print $3":"$4 }') "${venv}"
        deactivate
    fi
    popd > /dev/null
}
