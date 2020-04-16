#!/usr/bin/env bats
# vim: sts=4:
#
# Reproducer for https://bugzilla.redhat.com/show_bug.cgi?id=1728701
#

load dns

TIMEOUT=${1:-0.1}

@test "dig present" {
$CODEDIR/dig.sh -v
}

@test "configuring" {
setup_ns
}

@test "start dnsmasq" {
START=$(date '+%Y-%m-%d %H:%M:%S')
dnsmasq_start --no-resolv --interface=$BRDEV --interface=lo --bind-dynamic
}

@test "checking response over TCP before" {
$IN_NS ip link show dev $BRDEV
$IN_NS $CODEDIR/dig.sh --status=NOERROR +tcp @${IPV4_PREFIX}.1 localhost
}

@test "recreate interface" {
interfaces_destroy
interfaces_create
}

@test "checking response over TCP after" {
$IN_NS ip link show dev $BRDEV
$IN_NS $CODEDIR/dig.sh --status=NOERROR +tcp @${IPV4_PREFIX}.1 localhost
}

@test "stop dnsmasq" {
dnsmasq_stop
}

@test "cleaning" {
clean_ns
}
