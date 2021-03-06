#!/bin/sh
# vim: sts=4:
#
# Reproducer for https://bugzilla.redhat.com/show_bug.cgi?id=1739797
#
# TODO: use bats!

TIMEOUT=${1:-20}
MAXLINES=100
GOODLINES=10

CODEDIR="`(dirname -- "$0")`"
source $CODEDIR/settings.conf
source $CODEDIR/setup.bash

setup_ns

START=$(date '+%Y-%m-%d %H:%M:%S')
echo starting
$IN_NS ip a show dev $BRDEV
# Run joint DHCP4/DHCP6 server with router advertisement enabled in veth namespace
dnsmasq_start --interface=$BRDEV --bind-interfaces --dhcp-range=${IPV4_PREFIX}.10,${IPV4_PREFIX}.254,240 --dhcp-range=${IPV6_PREFIX}::10,${IPV6_PREFIX}::1ff,slaac,64,240 --enable-ra

$IN_NS ip -6 address show dev $BRDEV

echo waiting
timeout $TIMEOUT $IN_NS ip monitor | while read LINE; do echo "`date '+%02H:%02M:%02S.%3N'`> $LINE"; done

echo terminating
dnsmasq_stop

COUNT=$(journalctl -exn $MAXLINES -t 'dnsmasq' -t 'dnsmasq-dhcp' -S "$START" --no-pager | grep "RTR-ADVERT($BRDEV)" | wc -l)

clean_ns

if [ "$COUNT" -gt "$GOODLINES" ]; then
    echo "FAIL: $COUNT RTR-ADVERT lines, dnsmasq seems broken!"
    exit 1
else
    echo "PASS: $COUNT RTR-ADVERT lines"
fi

