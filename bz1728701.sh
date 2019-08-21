#!/bin/sh
# vim: sts=4:
#
# Reproducer for https://bugzilla.redhat.com/show_bug.cgi?id=1728701
#
# TODO: use bats!

TIMEOUT=${1:-0.1}

CODEDIR="`(dirname -- "$0")`"
source $CODEDIR/settings.conf
source $CODEDIR/setup.sh

if ! dig -v; then
    echo "FAIL: dig not found!"
fi

setup

START=$(date '+%Y-%m-%d %H:%M:%S')
echo starting
$IN_NS $DNSMASQ --pid-file=/tmp/dns_$BRDEV.pid --dhcp-leasefile=/tmp/dns_$BRDEV.lease --no-resolv --interface=$BRDEV --interface=lo --bind-dynamic
sleep $TIMEOUT
$IN_NS dig +tcp @${IPV4_PREFIX}.1 localhost

clean
setup

echo recreated interfaces
$IN_NS dig +tcp @${IPV4_PREFIX}.1 localhost
R=$?
sleep $TIMEOUT

echo terminating
kill $(cat /tmp/dns_$BRDEV.pid)

clean

if [ "$R" -ne 0 ]; then
    echo "FAIL: no response after recreation!"
    exit 1
else
    echo "PASS: response worked after recreation."
fi

