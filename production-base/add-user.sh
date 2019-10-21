#!/bin/sh

ADMIN_USERNAME=${ADMIN_USERNAME:-admin}

# create user if either password or sshkey is set!
if [ "${ADMIN_PASSWORD}" != "" -o "${ADMIN_SSHKEY}" != "" ]; then
    echo "Adding admin user '${ADMIN_USERNAME}'"
    xmlstarlet edit --inplace \
               -N c='http://tail-f.com/ns/config/1.0' \
               -N n='urn:ietf:params:xml:ns:yang:ietf-netconf-acm' \
               -N a='http://tail-f.com/ns/aaa/1.1' \
               --update "/c:config/n:nacm/n:groups/n:group[n:name='ncsadmin']/n:user-name" --value "${ADMIN_USERNAME}" \
               --update "/c:config/a:aaa/a:authentication/a:users/a:user/a:name" --value "${ADMIN_USERNAME}" \
               --update "/c:config/a:aaa/a:authentication/a:users/a:user/a:homedir" --value "/home/${ADMIN_USERNAME}" \
               --update "/c:config/a:aaa/a:authentication/a:users/a:user/a:ssh_keydir" --value "/home/${ADMIN_USERNAME}/.ssh" \
               /add_user_template.xml

    if [ "${ADMIN_PASSWORD}" != "" ]; then
        xmlstarlet edit --inplace \
                   -N c='http://tail-f.com/ns/config/1.0' \
                   -N n='urn:ietf:params:xml:ns:yang:ietf-netconf-acm' \
                   -N a='http://tail-f.com/ns/aaa/1.1' \
                   --update "/c:config/a:aaa/a:authentication/a:users/a:user/a:password" --value "${ADMIN_PASSWORD}" \
                   /add_user_template.xml
    fi
    if [ "${ADMIN_SSHKEY}" != "" ]; then
        mkdir -p /home/${ADMIN_USERNAME}/.ssh
        # add ssh key to authorized_keys if it's not already in there
        # we append to the authorized_keys file as to avoid overwriting an
        # existing list of keys
        grep "${ADMIN_SSHKEY}" /home/${ADMIN_USERNAME}/.ssh/authorized_keys || echo ${ADMIN_SSHKEY} >> /home/${ADMIN_USERNAME}/.ssh/authorized_keys
    fi

    cp /add_user_template.xml /nso/run/cdb/add_admin_user.xml
fi
