#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/dnsmasq/Sanity/bz1375569-added-dhcp_release6-binary
#   Description: test if release sanity is there
#   Author: Jan Scotka <jscotka@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2017 Red Hat, Inc.
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
BRIDGE="brkahjsfd"

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        #init-NM
        #init-sim-veth emac0 $BRIDGE
        #init-sim-veth emac1 $BRIDGE
    rlPhaseEnd

    rlPhaseStartTest
        rlRun "rpm -ql $PACKAGE-utils | grep dhcp_release6"
        rlRun "dhcp_release6" 255
        rlRun "dhcp_release6 --help" 0
    rlPhaseEnd

    rlPhaseStartCleanup
        #init-sim-veth-cleanup emac0
        #init-sim-veth-cleanup emac1
        #init-NM-cleanup
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
