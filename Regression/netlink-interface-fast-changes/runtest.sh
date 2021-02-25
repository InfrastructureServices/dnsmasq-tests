#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/dnsmasq/Regression/netlink-interface-fast-changes
#   Description: Test for BZ#1887649 (dnsmasq stops replying to upstream queries)
#   Author: Petr Mensik <pemensik@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2021 Red Hat, Inc.
#
#   This program is free software: you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation, either version 2 of
#   the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE.  See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see http://www.gnu.org/licenses/.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="dnsmasq"
: ${REPEATS:=10}
: ${STRACE_LOG:=n}
: ${STRACE_PARAMS:=-r}
: ${FAIL_WAIT:=10}
: ${DEBUG:=n}
: ${DEBUG_FAIL:=n}

count_listeners() {
	local FILTER=${1:-UDP}
	local PID=$(pidof dnsmasq)
	lsof -n -p $PID | grep "$FILTER" | wc -l
}

one_retry() {
	local MAX=254
	local DOWN_DELAY=0
	for X in `seq 1 $MAX`; do 
		ifconfig eth0:${X} 100.123.1.${X} netmask 255.255.255.0
		#ip address add 100.123.1.${X} dev eth0 label eth0:${X}
	done && sleep $DOWN_DELAY && for X in `seq 1 $MAX`; do 
		ifconfig eth0:${X} down
		#ip address del 100.123.1.${X} dev eth0 label eth0:${X}
	done
}

loop_interfaces() {
	one_retry
	for Y in `seq 1 20`; do
		rlLog "Retry #${Y}..."
		one_retry && [ $(count_listeners UDP) -gt 12 ] && break
		sleep 2
	done
}

rlJournalStart
  for REPEAT in $(seq 1 $REPEATS); do
    rlPhaseStartSetup "Setup #$REPEAT"
        rlAssertRpm $PACKAGE
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
	rlRun "TestDir=\$(pwd)"
	rlRun "rlFileBackup /etc/dnsmasq.conf"
	rlRun "sed -e 's/^\s*bind-interfaces/# &/' -e 's/^\s*interface=lo/# &/' -i /etc/dnsmasq.conf"
	rlRun "rlFileBackup --missing-ok /etc/dnsmasq.d/origin{,-upstream-dns}.conf"
	rlRun "install origin-dns.conf /etc/dnsmasq.conf"
	rlRun "install -d -m 775 /var/log/dnsmasq"
	if getent group dnsmasq; then
		rlRun "chgrp dnsmasq /var/log/dnsmasq"
	else
		rlRun "chgrp nobody /var/log/dnsmasq"
	fi
	[ -f /var/log/dnsmasq/test.log ] && rlRun "rm -f /var/log/dnsmasq/test.log"
        rlRun "pushd $TmpDir"
	rlRun "ip link add dummy0 type dummy" 0-255
	rlRun "ip addr add 172.17.0.1/24 dev dummy0" 0-255
	rlRun "awk '\"nameserver\" == \$1 { print \"server=\"\$2 }' /etc/resolv.conf > /etc/dnsmasq.d/origin-upstream-dns.conf"
	rlServiceStart dnsmasq
	sleep 2
	rlRun "DNSMASQ_PID=$(pidof dnsmasq)"
	rlRun "strace -p $DNSMASQ_PID -o dnsmasq.strace $STRACE_PARAMS &"
	STRACE_PID=$!
	rlRun "$TestDir/netlink_stats.sh $DNSMASQ_PID > netlink.log &"
	NETLINK_PID=$!
	rlRun "ps u $STRACE_PID $DNSMASQ_PID $NETLINK_PID || rlDie 'Some process not running'"
    rlPhaseEnd

    rlPhaseStartTest "Test #$REPEAT"
	rlLog "Listeners UDP: $(count_listeners UDP) TCP: $(count_listeners TCP)"
	rlRun "loop_interfaces"
	# give it time to release them again
	for LREP in $(seq 1 $FAIL_WAIT)
	do
		rlLog "Listeners UDP: $(count_listeners UDP) TCP: $(count_listeners TCP)"
		sleep 2
	done
	rlRun "lsof -n -p $DNSMASQ_PID | tee dnsmasq.sockets" 0 "List remaining dnsmasq listeners"
	LISTENERS_UDP=$(count_listeners UDP)
	LISTENERS_TCP=$(count_listeners TCP)
	rlAssertLesser "Check number of UDP listeners" $LISTENERS_UDP 5
	rlAssertLesser "Check number of TCP listeners" $LISTENERS_TCP 5
	rlAssertEquals "Check listeners number match both protocols" $LISTENERS_UDP $LISTENERS_TCP
	rlRun "kill $STRACE_PID $NETLINK_PID"
	rlRun "wait $STRACE_PID $NETLINK_PID" 0-255
	rlRun "COUNT_ENOBUFS=$(grep -w ENOBUFS dnsmasq.strace | wc -l)"
	rlRun "COUNT_EADDRNOTAVAIL=$(grep -w EADDRNOTAVAIL dnsmasq.strace | wc -l)"
	rlRun "COUNT_RTM_GETADDR=$(grep -w RTM_GETADDR dnsmasq.strace | wc -l)"
	rlRun "awk '$DNSMASQ_PID == \$3 || \$3 == \"Pid\" { print }' /proc/net/netlink" 0-255 "Show netlink info on process"
	if [ "$DEBUG" = y ] || [ "$DEBUG_FAIL" = y ] && ! rlGetTestState; then
		PS1="test-debug $PS1" bash -i
	fi
    rlPhaseEnd

    rlPhaseStartCleanup "#Cleanup $REPEAT"
	if [ "$STRACE_LOG" = y ]; then
		# It can be 40M big even after compression. Omit unless requested
		rlRun "gzip dnsmasq.strace"
		rlFileSubmit dnsmasq.strace*
	fi
	rlFileSubmit dnsmasq.sockets
	rlFileSubmit netlink.log
	rlFileSubmit /var/log/dnsmasq/test.log
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
	rlServiceRestore dnsmasq
	rlRun "rm -f /etc/dnsmasq.d/origin-upstream-dns.conf"
	rlRun "rlFileRestore"
    rlPhaseEnd
    # End repeats on first failure
    rlLog "End repeat $REPEAT"
    rlGetTestState || break
  done
rlJournalPrintText
rlJournalEnd
