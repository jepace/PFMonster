#!/bin/sh
# $Id: kanga-on.sh,v 1.3 2014/09/02 21:48:07 jepace Exp $
set -x

if [ "$1" == "on" ]
then
    echo "pass from 192.168.42.200 to any keep state" | /usr/local/bin/sudo /sbin/pfctl -a pfm_jepace -f -
else
    /usr/local/bin/sudo /sbin/pfctl -a pfm_jepace -Fa
fi
/usr/local/bin/sudo /sbin/pfctl -a pfm_jepace -sr
