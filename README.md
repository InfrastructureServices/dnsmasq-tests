# dnsmasq test suite

Start block for dnsmasq testing. Not yet testing anything exceptional.

In future, it should contain set of repeatedly started test
to ensure dnsmasq is not broken.

It should contain automated tests for recent issues discovered.
Goal is to prevent regressions and move development faster without fear for breaking it whole down.
Dnsmasq is used in several products but have no automated tests.

Inspired by [NetworkManager-ci](https://github.com/NetworkManager/NetworkManager-ci),
suited to be used by [Fedora CI](https://fedoraproject.org) and Red Hat Enterprise Linux.
