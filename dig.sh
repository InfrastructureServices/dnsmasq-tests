#!/bin/bash
#
# Small wrapper around dig. Checks also desired status in reply
#
declare -a OPTS

CHECK_STATUS=
OK_STATUS=
DIG=dig

for P in "$@"
do
	# filter out local parameters from dig parameters
	case "$P" in
		-S=*|--status=*)
			CHECK_STATUS="${P#-*=}"
			;;
		*)
			OPTS+=( "$P" )
			;;
	esac
done

TMPFILE="$(mktemp --tmpdir dig-XXXXXX.log)"
$DIG "${OPTS[@]}" > "$TMPFILE"
R=$?
cat "$TMPFILE"

if [ "$R" -eq 0 ] && [ -n "$CHECK_STATUS" ]
then
	if ! grep -qi "^;.* status: $CHECK_STATUS[ ,]" "$TMPFILE"
	then
		echo "Status do not match $CHECK_STATUS"
		rm -f "$TMPFILE"
		exit 2
	fi
fi

rm -f "$TMPFILE"

exit $R
