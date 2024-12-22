#!/bin/sh
set -eu

if [ ! -f /etc/dma/dma.conf ]; then
	{
		echo "# config automatically generated from DMA_* env vars"
		echo
		printenv \
			| grep ^DMA_ \
			| sed -E 's/^DMA_//; /^[^=]*=(false)?$/d; s/^([^=]*)=true$/\1/; s/^([^=]*)=/\1 /'
	} > /etc/dma/dma.conf
	# verify config
	dma 2>&1 | grep -v 'no recipients$' >&2 && {
		echo
		echo "Generated config:"
		echo
		nl -b a -s ': ' -w 2 /etc/dma/dma.conf
		exit 1
	} >&2
fi

if [ "$1" = "msmtpd" ]; then
	shift
	set -- tini -- msmtpd \
		--interface 0.0.0.0 \
		--log /dev/stdout \
		--command 'dma -f %F --' \
		"$@"
	# TODO: handle flushing the queue every 15 mins?
fi

exec "$@"
