
load dhcp

DHCLIENT=/usr/sbin/dhclient
PID_PREFIX="/run/dhclient-test.$$."

@test "Check DHCP client is installed" {
	[ -x $DHCLIENT ]
}

@test "configuring" {
setup_ns
}

@test "start dnsmasq" {
dnsmasq_start --no-resolv --interface=$BRDEV --interface=lo --bind-dynamic --dhcp-range=$IPV4_PREFIX.5,$IPV4_PREFIX.30
}

@test "Assign DHCP" {
	$DHCLIENT -sf /bin/true -pf ${PID_PREFIX}1 -1
}

@test "stop dnsmasq" {
dnsmasq_stop
}

@test "cleaning" {
clean_ns
}

