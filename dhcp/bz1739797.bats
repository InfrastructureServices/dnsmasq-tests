#!/usr/bin/bats
# vim: sts=4:
#
# Reproducer for https://bugzilla.redhat.com/show_bug.cgi?id=1739797
#

TIMEOUT=${1:-20}
MAXLINES=100
GOODLINES=10

load dhcp

@test "dig present" {
$CODEDIR/dig.sh -v
}

@test "configuring" {
setup_ns
}

#
# Need to retain state, test in single test
@test "checking RHBZ#1739797" {
START=$(date '+%Y-%m-%d %H:%M:%S')
# Run joint DHCP4/DHCP6 server with router advertisement enabled in veth namespace
dnsmasq_start --interface=$BRDEV --bind-interfaces --dhcp-range=${IPV4_PREFIX}.10,${IPV4_PREFIX}.254,240 --dhcp-range=${IPV6_PREFIX}::10,${IPV6_PREFIX}::1ff,slaac,64,240 --enable-ra

echo "waiting"
timeout $TIMEOUT $IN_NS ip monitor | while read LINE; do echo "`date '+%02H:%02M:%02S.%3N'`> $LINE"; done

dnsmasq_stop

COUNT=$(journalctl -exn $MAXLINES -t 'dnsmasq' -t 'dnsmasq-dhcp' -S "$START" --no-pager | grep "RTR-ADVERT($BRDEV)" | wc -l)
echo "Found lines: $COUNT"
[ "$COUNT" -le "$GOODLINES" ]
}

@test "cleaning" {
clean_ns
}

