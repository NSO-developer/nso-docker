#!/bin/sh

mv /etc/ncs/ncs.conf /etc/ncs/ncs.conf.orig
xmlstarlet edit -N x=http://tail-f.com/yang/tailf-ncs-config \
	--update "/x:ncs-config/x:netconf-north-bound/x:transport/x:ssh/x:enabled" --value "true" \
	/etc/ncs/ncs.conf.orig > /etc/ncs/ncs.conf
