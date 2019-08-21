#!/bin/sh
# vim: sts=4:
#
# Reproducer for https://bugzilla.redhat.com/show_bug.cgi?id=1739797

TIMEOUT=${1:-30}
LINES=100

CODEDIR="`(dirname -- "$0")`"
source $CODEDIR/settings.conf
source $CODEDIR/setup.sh

echo starting
# Run joint DHCP4/DHCP6 server with router advertisement enabled in veth namespace
$IN_NS dnsmasq --pid-file=/tmp/dhcp_$BRDEV.pid --dhcp-leasefile=/tmp/dhcp_$BRDEV.lease --dhcp-range=${IPV4_PREFIX}.10,${IPV4_PREFIX}.254,240 --dhcp-range=${IPV6_PREFIX}::10,${IPV6_PREFIX}::1ff,slaac,64,240 --enable-ra --interface=$BRDEV --bind-interfaces

echo waiting
sleep $TIMEOUT

echo terminating
kill $(cat /tmp/dhcp_$BRDEV.pid)

journalctl -exn $LINES -t 'dnsmasq' -t 'dnsmasq-dhcp' --no-pager

cleanup
