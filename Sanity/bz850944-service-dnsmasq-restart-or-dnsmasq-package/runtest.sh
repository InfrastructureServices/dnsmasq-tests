#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/dnsmasq/Sanity/bz850944-service-dnsmasq-restart-or-dnsmasq-package
#   Description: Test for BZ#850944 ("service dnsmasq restart (or dnsmasq package)
#   Author: Jan Scotka <jscotka@redhat.com>
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="dnsmasq"

SRV_PORT=10367
CLT_PORT=10368

rlJournalStart
SERVER_LOG=`mktemp`
    rlPhaseStartTest
        rlServiceStop "dnsmasq"
        sleep 5
        rlRun "service dnsmasq status" 3

        rlRun "service dnsmasq start"
        sleep 5
        rlRun "service dnsmasq status"

        rlLog "running dhcp server on background, on loopback"
        dnsmasq -i lo -d --log-dhcp --dhcp-range=172.16.1.100,172.16.1.100 -p 0 --dhcp-alternate-port=$SRV_PORT,$CLT_PORT &> $SERVER_LOG &
        SERVER_PID=$!
        rlLog "SERVER_PID: $SERVER_PID"
        sleep 5

        rlRun -l "cat $SERVER_LOG"
        rlRun "ps $SERVER_PID |grep dnsmasq"
        rlRun "service dnsmasq stop"
        sleep 5
        rlRun "ps $SERVER_PID |grep dnsmasq"
        rlRun "service dnsmasq stop"
        sleep 5
        rlLog "Instance have to be running still"
        rlRun "ps $SERVER_PID |grep dnsmasq"
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rlWaitForCmd 'kill $SERVER_PID' -r 1 -m 30"
        rlServiceRestart "dnsmasq"
        rlRun "rm -f $SERVER_LOG"
    rlPhaseEnd

rlJournalPrintText
rlJournalEnd
