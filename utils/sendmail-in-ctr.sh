#!/bin/sh
# Proxy to sendmail inside smtp container
CTR_NAME=smtp-proxy
exec ${CTR_EXEC_CMD:-podman exec} -i -e EMAIL "$CTR_NAME" sendmail "$@"
