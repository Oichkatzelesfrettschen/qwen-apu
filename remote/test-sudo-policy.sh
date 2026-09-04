#!/bin/sh
# sudo-policy.sh against a scratch target with the privilege prefix replaced
# by a stand-in that records what it was asked to run: install copies the
# checked-in source at mode 0440, verify passes on that copy and fails on an
# edited one or a wrong mode, and uninstall removes it.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tool=$script_directory/sudo-policy.sh
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
failures=0
report() {
    if [ "$2" = ok ]; then printf 'ok %s\n' "$1"; else printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); fi
}
export QWEN_SUDO_POLICY_TARGET=$work/etc/90-qwen-agent
mkdir -p "$work/etc"
# The stand-in handles each verb the tool asks the privilege for.
cat >"$work/privilege" <<'EOF'
#!/bin/sh
case $1 in
    install) install -m 0440 "$8" "$9" ;;
    stat) printf '440 root\n' ;;
    *) exec "$@" ;;
esac
EOF
chmod +x "$work/privilege"
export QWEN_SUDO_POLICY_PRIVILEGE=$work/privilege
source_file=$script_directory/../runtime/sudoers/90-qwen-agent

"$tool" install >"$work/install.log"
[ -f "$QWEN_SUDO_POLICY_TARGET" ] && cmp -s "$QWEN_SUDO_POLICY_TARGET" "$source_file" \
    && report install_copies_source ok || report install_copies_source "$(cat "$work/install.log")"
[ "$(stat -c %a "$QWEN_SUDO_POLICY_TARGET")" = 440 ] && report install_sets_mode ok || report install_sets_mode "$(stat -c %a "$QWEN_SUDO_POLICY_TARGET")"

"$tool" verify >"$work/verify.log" && grep -q '^sudo_policy=verified' "$work/verify.log" \
    && report verify_passes_on_copy ok || report verify_passes_on_copy "$(cat "$work/verify.log")"

chmod u+w "$QWEN_SUDO_POLICY_TARGET"; printf '\nDefaults !authenticate\n' >>"$QWEN_SUDO_POLICY_TARGET"
if "$tool" verify >"$work/edited.log" 2>&1; then report verify_fails_on_edit accepted; else
    grep -q 'hashes to' "$work/edited.log" && report verify_fails_on_edit ok || report verify_fails_on_edit "$(cat "$work/edited.log")"
fi

printf '#!/bin/sh\ncase $1 in install) install -m 0440 "$8" "$9" ;; stat) printf "644 root\\n" ;; *) exec "$@" ;; esac\n' >"$work/privilege"
"$tool" install >/dev/null
if "$tool" verify >"$work/mode.log" 2>&1; then report verify_fails_on_mode accepted; else
    grep -q '440 root is required' "$work/mode.log" && report verify_fails_on_mode ok || report verify_fails_on_mode "$(cat "$work/mode.log")"
fi

printf '#!/bin/sh\ncase $1 in install) install -m 0440 "$8" "$9" ;; stat) printf "440 root\\n" ;; *) exec "$@" ;; esac\n' >"$work/privilege"
"$tool" uninstall >/dev/null
[ ! -e "$QWEN_SUDO_POLICY_TARGET" ] && report uninstall_removes ok || report uninstall_removes present
if "$tool" verify >"$work/absent.log" 2>&1; then report verify_fails_when_absent accepted; else report verify_fails_when_absent ok; fi

if [ "$failures" -ne 0 ]; then printf '%s failure(s)\n' "$failures"; exit 1; fi
printf 'test-sudo-policy: all checks passed\n'
