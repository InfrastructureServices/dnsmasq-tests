#!/bin/sh
# vim: sts=4:
#
# Reproducer for https://bugzilla.redhat.com/show_bug.cgi?id=1728701
#
# TODO: use bats!

TIMEOUT=${1:-0.1}

CODEDIR="`(dirname -- "$0")`"
source $CODEDIR/settings.conf
source $CODEDIR/setup.bash

if ! ./dig.sh -v; then
    echo "FAIL: dig not found!"
    exit 1
fi

setup_ns

START=$(date '+%Y-%m-%d %H:%M:%S')
echo starting
dnsmasq_start --no-resolv --interface=$BRDEV --interface=lo --bind-dynamic
sleep $TIMEOUT
$IN_NS ./dig.sh --status=NOERROR +tcp @${IPV4_PREFIX}.1 localhost

$IN_NS ip link show dev $BRDEV

interfaces_destroy
interfaces_create

echo recreated interfaces
$IN_NS ip link show dev $BRDEV
$IN_NS ./dig.sh --status=NOERROR +tcp @${IPV4_PREFIX}.1 localhost
R=$?
sleep $TIMEOUT

echo terminating
dnsmasq_stop

clean_ns

if [ "$R" -ne 0 ]; then
    echo "FAIL: no response after recreation!"
    exit 1
else
    echo "PASS: response worked after recreation."
fi

