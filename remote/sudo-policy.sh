#!/bin/sh
set -eu

# The one persistent root-owned object, reproducible from its source.
#
# runtime/sudoers/90-qwen-agent is the checked-in policy: a global sudo
# timestamp with a bounded timeout, so one `sudo -v` in the operator's
# session covers the SSH commands that administer the appliance and the
# password reaches no command line, script, or log. `install` copies it to
# /etc/sudoers.d/90-qwen-agent at mode 0440 owned by root after visudo
# accepts it; `verify` requires the installed file to hash to the source and
# to carry that mode and owner; `uninstall` removes it. Every other
# privileged write in this tree is transactional -- a DPM level, a boost
# state, a KSM run state, an SMU budget -- snapshotted, written, measured,
# restored, and proven restored, so this file is the whole of what root
# keeps between launches.
#
# usage: sudo-policy.sh install|verify|uninstall
#   QWEN_SUDO_POLICY_TARGET   the installed path (fixtures), default
#                             /etc/sudoers.d/90-qwen-agent
#   QWEN_SUDO_POLICY_PRIVILEGE the command prefix that writes there
#                             (fixtures), default `sudo -n`

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

[ "$#" -eq 1 ] || { printf 'usage: %s install|verify|uninstall\n' "$0" >&2; exit 2; }
action=$1
source_file=$qwen_tree_root/runtime/sudoers/90-qwen-agent
target_file=${QWEN_SUDO_POLICY_TARGET:-/etc/sudoers.d/90-qwen-agent}
privilege=${QWEN_SUDO_POLICY_PRIVILEGE:-sudo -n}
[ -r "$source_file" ] || { printf 'policy source unreadable: %s\n' "$source_file" >&2; exit 2; }
source_sha256=$(sha256sum "$source_file" | cut -d ' ' -f 1)

installed_sha256() {
    $privilege sha256sum "$target_file" 2>/dev/null | cut -d ' ' -f 1
}

case $action in
    install)
        if command -v visudo >/dev/null 2>&1; then
            visudo -cf "$source_file" >/dev/null
        fi
        $privilege install -o root -g root -m 0440 "$source_file" "$target_file"
        printf 'sudo_policy=installed target=%s sha256=%s\n' "$target_file" "$source_sha256"
        ;;
    verify)
        observed=$(installed_sha256 || true)
        if [ -z "$observed" ]; then
            printf 'sudo policy absent or unreadable at %s (run make install-sudo-policy)\n' "$target_file" >&2
            exit 1
        fi
        if [ "$observed" != "$source_sha256" ]; then
            printf 'sudo policy at %s hashes to %s where the source hashes to %s\n' \
                "$target_file" "$observed" "$source_sha256" >&2
            exit 1
        fi
        mode_owner=$($privilege stat -c '%a %U' "$target_file")
        case $mode_owner in
            '440 root') ;;
            *)
                printf 'sudo policy at %s reads mode/owner %s where 440 root is required\n' \
                    "$target_file" "$mode_owner" >&2
                exit 1
                ;;
        esac
        printf 'sudo_policy=verified target=%s sha256=%s\n' "$target_file" "$source_sha256"
        ;;
    uninstall)
        $privilege rm -f "$target_file"
        printf 'sudo_policy=removed target=%s\n' "$target_file"
        ;;
    *) printf 'usage: %s install|verify|uninstall\n' "$0" >&2; exit 2 ;;
esac
