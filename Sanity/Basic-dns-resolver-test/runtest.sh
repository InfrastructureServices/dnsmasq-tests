#!/bin/bash
# vim: dict+=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/dnsmasq/Sanity/Basic-dns-resolver-test
#   Description: Basic test for the dnsmasq dns resolver
#   Author: Daniel Rusek <drusek@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2018 Red Hat, Inc.
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
. /usr/bin/rhts-environment.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGE="dnsmasq"
TEST_NOREC=

dig_noerror()
{
	rlRun -s "dig @localhost $@"
	rlAssertGrep 'status: NOERROR' $rlRun_LOG
	rlAssertNotGrep 'ANSWER: 0' $rlRun_LOG
	rm -f "$rlRun_LOG"
}

make_servers()
{
	awk '$1 == "nameserver" { print "server="$2 }' /etc/resolv.conf
}

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm $PACKAGE
        #rlRun "mv /etc/dnsmasq.conf /tmp/"
	rlFileBackup --clean /etc/dnsmasq.d/{dns,servers}.conf /etc/dnsmasq.d/dns/hosts-list
	rlRun "mkdir -p /etc/dnsmasq.d/dns" 0-255
	rlRun "install hosts-list /etc/dnsmasq.d/dns"
	rlRun "install dns.conf /etc/dnsmasq.d"
	rlRun "make_servers > /etc/dnsmasq.d/servers.conf"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
        rlRun "rlServiceStop dnsmasq"
        rlRun "rlServiceStart dnsmasq"
	if ! rlIsRHEL 8 || rlIsRHEL >=8.2; then
		TEST_NOREC=y
	fi
    rlPhaseEnd

    rlPhaseStartTest "Basic DNS tests"
        dig_noerror redhat.com

	for HOST in gateway.lan.test server.lan.test ipv4-only.lan.test both.lan.test
	do
		[ "$TEST_NOREC" = y ] && dig_noerror "+norec -t A -q $HOST"
		dig_noerror "-t A -q $HOST"
	done

	for HOST in ipv6-only.lan.test both.lan.test
	do
		[ "$TEST_NOREC" = y ] && dig_noerror "+norec -t AAAA -q $HOST"
		dig_noerror "-t AAAA -q $HOST"
	done

	if  true; then
	for IP in fd1d:b670:1cc:8897::1 fd1d:b670:1cc:8897::4 192.168.0.3 192.168.0.4
	do
		[ "$TEST_NOREC" = y ] && dig_noerror "+norec -x $IP"
		dig_noerror "-x $IP"
	done
	fi

	rlRun -s "dig @localhost nx.test"
	rlAssertGrep 'status: NXDOMAIN' $rlRun_LOG
	rlAssertGrep 'ANSWER: 0' $rlRun_LOG
	rm -f "$rlRun_LOG"
    rlPhaseEnd

    rlPhaseStartTest "Additional DNS tests"
	dig_noerror "-t TXT -q txt.lan.test"
	dig_noerror "-t SRV -q _xmpp-server._tcp.lan.test"
	dig_noerror "-t MX -q mail.test"
	dig_noerror "-t A -q cname.lan.test"

	[ "$DEBUG" = y ] && PS1="test-debug $PS1" bash -i
    rlPhaseEnd

    rlPhaseStartCleanup
	rlFileRestore
        rlRun "rlServiceStop dnsmasq"
        rlRun "rm -rf /etc/dnsmasq.d/{dns.conf,dns/hosts-list}"
        rlRun "rlServiceRestore dnsmasq"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
