#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/dnsmasq/Sanity/dhcp-smoke-test
#   Description: checks the very basic functionality of the DHCP daemon
#   Author: Ales Zelinka <azelinka@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/bin/rhts-environment.sh
. /usr/lib/beakerlib/beakerlib.sh

PACKAGE="dnsmasq"
BRIDGE=brname8

# cannot use own ports because "dhcp_lease_time" tool has hardcoded port 67 for DHCP server
#SRV_PORT=10102
#CLT_PORT=10103

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlAssertRpm "dnsmasq-utils"
        rlFileBackup --clean --missing-ok "/var/lib/dnsmasq/dnsmasq.leases"

        # helper vars
        rlIsRHEL '>7' && DHCLIENT_REQ_OPT="--request-options" || DHCLIENT_REQ_OPT="-R"
        rpm -q --quiet net-tools && NETSTAT="netstat" || NETSTAT="ss"

        # setup testing network environment
        rlRun "rlImport initscripts/basic"
        init-NM
        init-sim-veth emac0 $BRIDGE
        init-sim-veth emac1 $BRIDGE

        # assign address to "server" interface
        rlRun "ip a a 172.16.1.1/16 dev emac0"
        rlRun "SERVER_LOG=$(mktemp)"

        #debug
        $NETSTAT -tulen

        # run dnsmasq/DHCP server
        if lsof -t -i:67 -i:68; then
            rlRun "rlWaitForCmd 'kill -9 $(lsof -t -i:67 -i:68)' -r 1 -m 30"
        fi
        rlLog "running dhcp server on background"
        dnsmasq  -i emac0 -d --log-dhcp --dhcp-range=172.16.1.100,172.16.1.100 -p 0 > $SERVER_LOG 2>&1 &
        SERVER_PID=$!
        sleep 5
        ip a
    rlPhaseEnd


    rlPhaseStartTest
        # check lease time for an unassigned address
        LEASE_TIME=`dhcp_lease_time 172.16.1.100`
        rlRun "[ \"$LEASE_TIME\" = '' ]" 0 "dhcp_lease_time: no lease time returned for an unassigned address"

        # run dhclient
        rlLog "running dhclient on emac1"
        dhclient -v -d $DHCLIENT_REQ_OPT subnet-mask,broadcast-address,time-offset,interface-mtu,domain-name,host-name "emac1" &
        CLIENT_PID=$!
        sleep 60
        ip a

        # dhcp_lease_time utility test
        rlRun "ip a l dev emac1 |grep 'inet.*172.16.1.100'"              0 "address assigned to the interface via dhcp"
        LEASE_TIME=`dhcp_lease_time 172.16.1.100`
        rlRun "[[ \"$LEASE_TIME\" =~ [0-9][0-9]m.* ]]"                   0 "dhcp_lease_time: lease time of an assigned address returned"
        MAC_EMAC1=` ip l l dev emac1 |grep link/ether |awk '{print $2}'`
        rlRun "dhcp_release emac0  172.16.1.100 $MAC_EMAC1"              0 "dhcp_release: releasing assigned address from emac1"
        LEASE_TIME=`dhcp_lease_time 172.16.1.100`
        rlRun "[ \"$LEASE_TIME\" = '' ]"                                 0 "dhcp_lease_time: no lease time returned for a released address"
    rlPhaseEnd


    rlPhaseStartCleanup
        rlFileRestore

        # make sure client & server are stopped
        rlWaitForCmd "kill $SERVER_PID" -r 1 -m 30
        rlWaitForCmd "kill $CLIENT_PID" -r 1 -m 30

        # cleanup testing network environment
        init-sim-veth-cleanup emac0
        init-sim-veth-cleanup emac1
        init-NM-cleanup

        # logs
        rlBundleLogs server_clients_logs $SERVER_LOG
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
