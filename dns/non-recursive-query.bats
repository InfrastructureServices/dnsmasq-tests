#!/usr/bin/env bats
# vim: sts=4:
#
# Reproducer for https://bugzilla.redhat.com/show_bug.cgi?id=1728701
#
# TODO: use bats!

load dns

@test "dig present" {
$CODEDIR/dig.sh -v
}

@test "configuring" {
setup_ns
}

@test "start dnsmasq" {
dnsmasq_start --no-resolv --interface=$BRDEV --interface=lo --bind-dynamic --addn-hosts=`pwd`/addn-hosts.conf
}

@test "recursive query" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 dnsmasq-only.test.
}

@test "non-recursive query" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR +norecurse @${IPV4_PREFIX}.1 dnsmasq-only.test.
}

@test "stop dnsmasq" {
dnsmasq_stop
}

@test "cleaning" {
clean_ns
}

