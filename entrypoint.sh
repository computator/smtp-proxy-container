#!/bin/sh
set -eu

write_dma_conf () {
	[ -f /etc/dma/dma.conf ] && return

	{
		echo "# config automatically generated from DMA_* env vars"
		echo
		printenv \
			| grep ^DMA_ \
			| sed -E 's/^DMA_//; /^[^=]*=(false)?$/d; s/^([^=]*)=true$/\1/; s/^([^=]*)=/\1 /'
	} > /etc/dma/dma.conf
}

verify_dma_conf () {
	dma 2>&1 | grep -v 'no recipients$' >&2 && {
		echo
		echo "Generated config:"
		echo
		nl -b a -s ': ' -w 2 /etc/dma/dma.conf
		exit 1
	} >&2 || true
}

write_dma_auth () {
	grep -Evq '^\s*(#|$)' /etc/dma/auth.conf && return

	if [ -n "${AUTH_CONTENTS:+1}" ]; then
		printenv AUTH_CONTENTS > /etc/dma/auth.conf
	elif [ -n "${AUTH_PASS:+1}${AUTH_PASS_FILE:+1}" ]; then
		{
			printf '%s|%s:' "${AUTH_USER:?}" "${AUTH_HOST:-$DMA_SMARTHOST}"
			if [ -n "${AUTH_PASS_FILE-}" ]; then
				{
					cat "$AUTH_PASS_FILE"
					# make sure there's a newline
					echo
				} | head -n 1
			else
				printenv AUTH_PASS
			fi
		} > /etc/dma/auth.conf
	else
		return 0
	fi
}

setup_utils () {
	test -d /utils-export || return 0
	echo "Setting up /utils-export/"
	cp -Rpv /utils/* /utils-export/
}

: \
	${DMA_SMARTHOST=${SMARTHOST-}} \
	${DMA_PORT=${SMARTHOST_PORT-}} \
	${DMA_AUTHPATH="/etc/dma/auth.conf"}
export DMA_SMARTHOST DMA_PORT DMA_AUTHPATH

# set default command
[ "${1#-}" = "$1" ] || set -- msmtpd "$@"

[ "$1" = "msmtpd" ] && setup_utils

write_dma_conf
case "$1" in
	dma|mailq|msmtpd|newaliases|sendmail) verify_dma_conf ;;
esac

write_dma_auth

if [ "$1" = "msmtpd" ]; then
	shift
	set -- tini -- msmtpd \
		--interface 0.0.0.0 \
		--log /dev/stdout \
		--command 'dma -f %F --' \
		"$@"

	# start syslogd to handle dma logging
	test -s /dev/log || ( syslogd -nSO - & )

	# flush the queue every 15 mins
	( sh -c 'while sleep 15m; do dma -q1; done' & )

	echo "Starting msmtpd..."
fi

exec "$@"
