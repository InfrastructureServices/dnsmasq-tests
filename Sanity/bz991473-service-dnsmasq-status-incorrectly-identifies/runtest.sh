#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/dnsmasq/Sanity/bz991473-service-dnsmasq-status-incorrectly-identifies
#   Description: Test for BZ#991473 ('service dnsmasq status' incorrectly identifies)
#   Author: Jan Scotka <jscotka@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="dnsmasq"
CNTT=2
NUME="0 1 2"
NADD="3"
BRIDGE=brnma

DHCP_SRV_PORT=10267
DHCP_CLT_PORT=10268

rlJournalStart
    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~< SETUP Phase >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        rlFileBackup --clean "/etc/dnsmasq.conf"

        # stop some relevant services
        rlServiceStop NetworkManager
        rlServiceStop $PACKAGE

        # setup testing network environment
        rlRun "rlImport initscripts/basic"
        init-NM
        for i in $NUME $NADD; do
            init-sim-veth emaca$i $BRIDGE$i
            init-sim-veth emacb$i $BRIDGE$i
            rlRun "ip a a 172.16.10$i.1/24 dev emaca$i"
        done       
        sleep 20
        ip a
    rlPhaseEnd

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~< TEST Phase >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    rlPhaseStartTest
        SERVER_PID=""
        SERVER_LOG=`mktemp`
        rlRun "rlWaitForCmd 'kill -9 dhclient' -r 1 -m 30"

        # run dnsmasq servers on all created interfaces
        rlLog "Run one instance of DHCP server for each interface"
        for i in $NUME; do
            /usr/sbin/dnsmasq --dhcp-alternate-port=$DHCP_SRV_PORT,$DHCP_CLT_PORT -d --log-dhcp --bind-interfaces -a 172.16.10$i.1 -F 172.16.10$i.120,172.16.10$i.120 -9 -p 0 &> $SERVER_LOG &
            SERVER_PID="$! $SERVER_PID"
            sleep 5
        done
        rlLog "SERVER_PID:  $SERVER_PID"
        
        # run dnsmasq with default config
        rlRun "cat $SERVER_LOG"
        rlRun "service $PACKAGE status |grep -E 'stop|inactive'"
        rlRun "service $PACKAGE status |grep runn" 1

        # setup own config file
        echo "log-dhcp"                                          > /etc/dnsmasq.conf
        echo "bind-interfaces"                                  >> /etc/dnsmasq.conf
        echo "listen-address=172.16.10$NADD.1"                  >> /etc/dnsmasq.conf
        echo "dhcp-range=172.16.10$NADD.120,172.16.10$NADD.120" >> /etc/dnsmasq.conf

        # run dnsmasq again with own config
        rlRun "rlServiceStart $PACKAGE"
        sleep 5
        rlRun "service $PACKAGE status |grep -E 'stop|inactive'" 1
        rlRun "service $PACKAGE status |grep runn"
    rlPhaseEnd

    #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~< CLEANUP Phase >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    rlPhaseStartCleanup
        # kill all dnsmasq servers left behind
        for i in $SERVER_PID; do
           rlRun "rlWaitForCmd 'kill -9 $i' -r 1 -m 30"
        done

        # restore files/directories
        rlFileRestore
        
        # cleanup testing network environment
        for i in $NUME $NADD; do
            init-sim-veth-cleanup emaca$i
            init-sim-veth-cleanup emacb$i
        done    
        init-NM-cleanup
        sleep 5

        # restore initial state of some services
        rlServiceStop    "$PACKAGE"
        rlServiceRestore "$PACKAGE"
        rlServiceRestore "NetworkManager"

        # logs
        rlBundleLogs server_clients_logs $SERVER_LOG
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
