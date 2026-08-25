#!/bin/sh
set -eu

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
    printf 'usage: %s SSH_TARGET [LOCAL_PORT [REMOTE_PORT]]\n' "$0" >&2
    exit 2
fi

ssh_target=$1
local_port=${2:-8080}
remote_port=${3:-8080}

case $local_port:$remote_port in
    *[!0-9:]* | :* | *:)
        printf 'ports must be integers from 1024 through 65535\n' >&2
        exit 2
        ;;
esac
if [ "$local_port" -lt 1024 ] || [ "$local_port" -gt 65535 ] || \
   [ "$remote_port" -lt 1024 ] || [ "$remote_port" -gt 65535 ]; then
    printf 'ports must be integers from 1024 through 65535\n' >&2
    exit 2
fi

printf 'Open http://127.0.0.1:%s after the tunnel reports no error.\n' "$local_port"
# Both tunnel endpoints bind loopback. The laptop exposes no unauthenticated
# llama.cpp listener to its LAN, and the browser remains on the client machine
# rather than competing with Raven2 for shared DDR4 or graphics scheduling.
exec ssh -N -T \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -L "127.0.0.1:$local_port:127.0.0.1:$remote_port" \
    "$ssh_target"
