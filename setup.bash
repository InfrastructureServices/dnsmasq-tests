#!/bin/sh
# 
# vim: set sts=4:
# Helper tools for dnsmasq testing

# local settings
IN_NS="ip netns exec $NS"
if [ -n "$BATS_TEST_DIRNAME" ]; then
    CODEDIR="$BATS_TEST_DIRNAME"
else
    CODEDIR="`(dirname -- "$0")`"
fi

. $CODEDIR/settings.conf

bridge_create()
{
    # Create the '$BRDEV' - providing both 10.x ipv4 and 2620:52:0 ipv6 dhcp
    $IN_NS ip link add name $BRDEV type bridge forward_delay 0 stp_state 1
    $IN_NS ip link set $BRDEV up
    $IN_NS ip addr add ${IPV4_PREFIX}.1/24 dev $BRDEV
    $IN_NS ip -6 addr add ${IPV6_PREFIX}::1/64 dev $BRDEV
}

# create veth interfaces
interface_create()
{
    for IF in $BR_INTERFACES
    do
        ip link add ${IF}0 type veth peer name ${IF}1
	ip link set dev ${IF}1 netns $NS
        ip link set dev ${IF}0 up
    done
}

bridge_populate()
{
    for IF in $BR_INTERFACES
    do
	$IN_NS ip link set dev ${IF}1 up master $BRDEV
    done
}

bridge_destroy()
{
    $IN_NS ip link del dev $BRDEV
}

# Create all network devices and set their addresses
interfaces_create()
{
    bridge_create
    interface_create
    bridge_populate
}

interfaces_destroy()
{
    for IF in $BR_INTERFACES
    do
        ip link del dev ${IF}0 type veth
    done
    bridge_destroy
}

netns_create()
{
    ip netns add $NS
}

netns_destroy()
{
    ip netns delete $NS
}

dnsmasq_start()
{
    $IN_NS $DNSMASQ --conf-file=/dev/null --pid-file=/tmp/dnsmasq-$NS-$BRDEV.pid --dhcp-leasefile=/tmp/dnsmasq-$NS-$BRDEV.lease "$@"
}

dnsmasq_stop()
{
    kill $(cat /tmp/dnsmasq-$NS-$BRDEV.pid)
    rm -f /tmp/dnsmasq-$NS-$BRDEV.pid
}

clean_ns()
{
    interfaces_destroy
    netns_destroy
}

setup_ns()
{
    clean >/dev/null 2>&1 || :
    netns_create
    $IN_NS ip link set lo up
    interfaces_create
}

case "$1" in
    start|init)   setup_ns;;
    clean|stop)   clean_ns;;
    *) ;;
esac
