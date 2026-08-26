#!/bin/sh
set -eu

# Run a privileged command on the terminal that holds the sudo credential.
#
# sudo binds its timestamp to the tty that authenticated it, so a command
# arriving over SSH lands on a fresh pseudo-terminal and finds no credential no
# matter how recently the user authenticated elsewhere. This relay sends the
# command into the shared admin window instead, where the credential lives.
#
# The password is typed by the user directly into that window and reaches this
# script through no path at all: the relay sends `sudo -v` and returns, and the
# command output travels through a file rather than through `capture-pane`, so
# the pane's contents, including the asterisks `pwfeedback` echoes, stay out of
# the transcript.

tmux_socket=${QWEN_ADMIN_TMUX_SOCKET:-default}
tmux_session=${QWEN_ADMIN_TMUX_SESSION:-qwen-admin}
tmux_window=${QWEN_ADMIN_TMUX_WINDOW:-admin}
target=$tmux_session:$tmux_window
relay_directory=${QWEN_ADMIN_RELAY_DIRECTORY:-"${HOME:?}/.qwen-admin-relay"}
wait_seconds=${QWEN_ADMIN_WAIT_SECONDS:-900}

usage() {
    printf 'usage: %s auth | check | run COMMAND [ARG ...]\n' "$0" >&2
    printf '  auth   send `sudo -v` to the admin window for the user to answer\n' >&2
    printf '  check  report whether the credential is currently live\n' >&2
    printf '  run    execute COMMAND on the credentialed terminal\n' >&2
    exit 2
}

[ "$#" -ge 1 ] || usage
action=$1
shift

if ! tmux -L "$tmux_socket" has-session -t "$tmux_session" 2>/dev/null; then
    printf 'admin session is absent: socket=%s session=%s\n' \
        "$tmux_socket" "$tmux_session" >&2
    exit 1
fi
if ! tmux -L "$tmux_socket" list-windows -t "$tmux_session" -F '#{window_name}' |
        grep -Fxq "$tmux_window"; then
    printf 'admin window is absent: %s\n' "$target" >&2
    exit 1
fi
if [ "$(tmux -L "$tmux_socket" display-message -p -t "$target" '#{pane_dead}')" = 1 ]; then
    printf 'admin window holds a dead pane: %s\n' "$target" >&2
    exit 1
fi

umask 077
mkdir -p "$relay_directory"

# Send one shell line and wait for the return code file it writes last. The
# command itself lives in a file, so no quoting of the caller's arguments has to
# survive send-keys.
relay() {
    relay_script=$relay_directory/command.sh
    relay_output=$relay_directory/output
    relay_status=$relay_directory/status
    rm -f "$relay_output" "$relay_status"
    cat >"$relay_script"
    tmux -L "$tmux_socket" send-keys -t "$target" \
        "sh '$relay_script' >'$relay_output' 2>&1; printf '%s' \$? >'$relay_status'" Enter

    waited=0
    while [ ! -s "$relay_status" ]; do
        if [ "$waited" -ge "$((wait_seconds * 10))" ]; then
            printf 'relayed command did not finish within %s seconds\n' \
                "$wait_seconds" >&2
            [ -s "$relay_output" ] && cat "$relay_output" >&2
            return 1
        fi
        waited=$((waited + 1))
        sleep 0.1
    done
    [ -f "$relay_output" ] && cat "$relay_output"
    return "$(cat "$relay_status")"
}

case $action in
    check)
        [ "$#" -eq 0 ] || usage
        if printf 'sudo -n true\n' | relay >/dev/null 2>&1; then
            printf 'sudo_credential=live target=%s\n' "$target"
        else
            printf 'sudo_credential=absent target=%s\n' "$target"
            exit 1
        fi
        ;;
    auth)
        [ "$#" -eq 0 ] || usage
        # `sudo -v` prompts on the pane. The user answers it there; this script
        # returns at once rather than waiting, so it never sits on the prompt.
        tmux -L "$tmux_socket" send-keys -t "$target" 'sudo -v' Enter
        printf 'password_prompt=sent target=%s\n' "$target"
        printf 'answer it in that window, then re-run: %s check\n' "$0"
        ;;
    run)
        [ "$#" -ge 1 ] || usage
        if ! printf 'sudo -n true\n' | relay >/dev/null 2>&1; then
            printf 'sudo credential is absent on %s; run `%s auth` first\n' \
                "$target" "$0" >&2
            exit 1
        fi
        for argument in "$@"; do
            printf '%s\n' "$argument"
        done | {
            printf '#!/bin/sh\nset -eu\n'
            first=1
            while IFS= read -r argument; do
                if [ "$first" -eq 1 ]; then
                    first=0
                    printf '%s' "$argument"
                else
                    printf " '%s'" "$(printf '%s' "$argument" | sed "s/'/'\\\\''/g")"
                fi
            done
            printf '\n'
        } | relay
        ;;
    *)
        usage
        ;;
esac
