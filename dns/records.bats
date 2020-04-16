#!/usr/bin/env bats
# vim: sts=4:
#
# Reproducer for https://bugzilla.redhat.com/show_bug.cgi?id=1728701
#

load dns

@test "dig present" {
$CODEDIR/dig.sh -v
}

@test "configuring" {
setup_ns
}

@test "start dnsmasq" {
dnsmasq_start --no-resolv --interface=$BRDEV --interface=lo --bind-dynamic --conf-file=$CODEDIR/dns-records.conf --addn-hosts=$CODEDIR/addn-hosts.conf
}

@test "recursive query" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 dnsmasq-only.test.
}

@test "checking interface-name" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 simbr-address.test.
}

@test "checking cname" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 bridge.test.
}

@test "checking txt" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 -t txt txt.test.
}

@test "checking srv dhcp" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 -t srv _dhcp._udp.test.
}

@test "checking srv dns" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 -t srv _dns._udp.test. && \
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 -t srv _dns._tcp.test.
}

@test "checking host-record" {
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 -t a host1.test. && \
$IN_NS $CODEDIR/dig.sh --status=NOERROR @${IPV4_PREFIX}.1 -t aaaa host1.test.
}

@test "stop dnsmasq" {
dnsmasq_stop
}

@test "cleaning" {
clean_ns
}

