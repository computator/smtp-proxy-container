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

write_dma_conf

case "$1" in
	dma|mailq|msmtpd|newaliases|sendmail) verify_dma_conf ;;
esac

if [ "$1" = "msmtpd" ] || [ "${1#-}" != "$1" ]; then
	[ "${1#-}" != "$1" ] || shift
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
