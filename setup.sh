#!/bin/sh
#
# Helper tools for dnsmasq testing

NS=vethsetup
IN_NS="ip netns exec $NS"

BRDEV=simbr
IPV4_PREFIX=10.16.1
IPV6_PREFIX=2620:52:0:1086

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
    for IF in vetha vethb
    do
        ip link add ${IF}0 type veth peer name ${IF}1
	ip link ${IF}1 set netns $NS
        ip link ${IF}0 set up
    done
}

bridge_populate()
{
    # Add eth10 peer into the $BRDEV
    for IF in vetha vethb
    do
	$IN_NS ip link set ${IF}1 master $BRDEV
    done
}

setup()
{
    bridge_create
    interface_create
    bridge_populate
}

setup

# Run joint DHCP4/DHCP6 server with router advertisement enabled in veth namespace
$IN_NS dnsmasq --pid-file=/tmp/dhcp_$BRDEV.pid --dhcp-leasefile=/tmp/dhcp_$BRDEV.lease --dhcp-range=${IPV4_PREFIX}.10,${IPV4_PREFIX}.254,240 --dhcp-range=${IPV6_PREFIX}::10,${IPV6_PREFIX}::1ff,slaac,64,240 --enable-ra --interface=$BRDEV --bind-interfaces
