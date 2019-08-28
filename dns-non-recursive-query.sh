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

if ! ./dig.sh -v; then
    echo "FAIL: dig not found!"
    exit 1
fi

setup

START=$(date '+%Y-%m-%d %H:%M:%S')
echo starting
dnsmasq_start --no-resolv --interface=$BRDEV --interface=lo --bind-dynamic --addn-hosts=`pwd`/addn-hosts.conf
sleep $TIMEOUT
$IN_NS ./dig.sh --status=NOERROR @${IPV4_PREFIX}.1 dnsmasq-only.test.

echo non-recursive query
$IN_NS ./dig.sh --status=NOERROR +norecurse @${IPV4_PREFIX}.1 dnsmasq-only.test.
R=$?
sleep $TIMEOUT

echo terminating
dnsmasq_stop

clean

if [ "$R" -ne 0 ]; then
    echo "FAIL: non-recursive-query."
    exit 1
else
    echo "PASS: non-recursive query."
fi

