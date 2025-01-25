#!/bin/sh
# Proxy to s-nail mail/mailx inside smtp container
: ${CTR_NAME:=smtp-proxy}
SELF_NAME=mail-in-ctr

SHORT_OPTS='dEhntvVa:b:c:q:r:s:T:'
LONG_OPTS='debug,discard-empty-messages,help,template,verbose,version'$(\
         )',attach:,bcc:,cc:,quote-file:,from-address:,subject:,target:'

arg_quot () {
	# test'asdf"blah -> 'test'\''asdf"blah'
	printf '%s' "$@" | sed "s/'/'\\\\''/g; s/.*/'&'/"
}

if [ "$(getopt -T > /dev/null; echo $?)" -eq 4 ]; then
	# sed is to strip the extra -- param
	orig_opts=$(getopt -- '' -- "$@" | sed 's/^ *-- *//')
	# convert -. and --end-options to --
	eval set -- "$(echo "$orig_opts" | sed -E "s/' *(-\.|--end-options) *'/--/")"
	opts=$(getopt -n $SELF_NAME -l "$LONG_OPTS" -- "$SHORT_OPTS" "$@") || exit
	eval set -- "$opts"
	out_opts=
	while true; do
		case "$1" in
			# safe flags
			-d|--debug|\
			-E|--discard-empty-messages|\
			-n|\
			-t|--template|\
			-v|--verbose|\
			-V|--version)
				out_opts="$out_opts $1"
				shift
				;;

			# safe params
			-b|--bcc|\
			-c|--cc|\
			-r|--from-address|\
			-s|--subject|\
			-T|--target)
				out_opts="$out_opts $1 $(arg_quot "$2")"
				shift 2
				;;

			# special
			-a|--attach)
				echo "ERROR: $SELF_NAME: attachments are unsupported" >&2
				exit 1
				;;
			-h|--help)
				out_opts='--help'
				break
				;;
			-q|--quote-file)
				if [ "$2" != '-' ]; then
					echo "ERROR: $SELF_NAME: only '-' for stdin is supported with '$1'" >&2
					exit 1
				fi
				out_opts="$out_opts -q -"
				shift 2
				;;

			# end of options
			--) shift; break;;

			*)
				echo "ERROR: $SELF_NAME: unhandled paramater '$1'" >&2
				exit 1
				;;
		esac
	done
	if [ "$out_opts" = '--help' ]; then
		eval set -- --help
	else
		out_opts=${out_opts# }
		eval set -- "$out_opts" -. '"$@"'
	fi
else
	echo "WARNING: $SELF_NAME: falling back to insecure parameter passing because this getopt is unsupported" >&2
fi

exec ${CTR_EXEC_CMD:-podman exec} -i "$CTR_NAME" mail "$@"
