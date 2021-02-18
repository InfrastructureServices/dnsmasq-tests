#!/bin/sh
#
# Script repeatedly logging stats from netlink

PID=$1

if ! ps u "$PID"; then
	echo "Requires PID parameter" 2>&1
	exit 1
fi
TIME=$(date '+%s')
printf "%10s: %10s %10s %4s\n" $TIME Drops Rmem Dump
while awk "\$3 == ${PID} { printf \"%10s: %10s %10s %04s\n\", ${TIME}, \$9, \$5, \$7; }" /proc/net/netlink
do
	sleep 1
	TIME=$(date '+%s')
done
