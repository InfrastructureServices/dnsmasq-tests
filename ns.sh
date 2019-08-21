#!/bin/sh
# vim: sts=4:
#
# Helper for running commands in namespace
#
# TODO: use bats!

CODEDIR="`(dirname -- "$0")`"
source $CODEDIR/settings.conf

ip netns exec "$NS" "$@"
