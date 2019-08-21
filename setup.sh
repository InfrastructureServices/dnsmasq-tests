#!/bin/sh
# 
# vim: set sts=4:
# Helper tools for dnsmasq testing

# local settings
IN_NS="ip netns exec $NS"
CODEDIR="`(dirname -- "$0")`"

. $CODEDIR/settings.conf

bridge_create()
{
    # Create the '$BRDEV' - providing both 10.x ipv4 and 2620:52:0 ipv6 dhcp
    $IN_NS ip link add name $BRDEV type bridge forward_delay 0 stp_state 1
    $IN_NS ip link set $BRDEV up
    $IN_NS ip addr add ${IPV4_PREFIX}.1/24 dev $BRDEV
    $IN_NS ip -6 addr add ${IPV6_PREFIX}::1/64 dev $BRDEV
}

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
    # Add eth10 peer into the $BRDEV
    for IF in $BR_INTERFACES
    do
	$IN_NS ip link set dev ${IF}1 up master $BRDEV
    done
}

clean()
{
    ip netns delete $NS
    for IF in $BR_INTERFACES
    do
        ip link del dev ${IF}0 type veth
    done
}

setup()
{
    clean >/dev/null 2>&1 
    ip netns add $NS
    bridge_create
    interface_create
    bridge_populate
}

setup
