#!/bin/sh
set -eu

# The deployment receipt over fixtures: it reads a verified runtime tree, a
# real activated bundle, a model registry, and a session status line, and
# writes one row per claim with the file each was read from, closing on a
# receipt_sha256 over the rows above it. Every refusal path -- an unsynced
# runtime tree, a divergent one, no active deployment -- is exercised too,
# since the script's whole point is refusing to name an identity it has not
# confirmed.

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
writer=$script_directory/write-deployment-receipt.sh
builder=$script_directory/build-deployment-bundle.sh
activator=$script_directory/activate-deployment-bundle.sh
work_directory=$(mktemp -d)
trap 'rm -rf "$work_directory"' EXIT HUP INT TERM

checks=0
report() {
    checks=$((checks + 1))
    printf 'check_%02d %s=%s\n' "$checks" "$1" "$2"
}

# ---- a self-consistent runtime tree fixture, in the shape
# test-check-runtime-tree.sh already builds one in ----------------------------
tree=$work_directory/tree
mkdir -p "$tree/remote" "$tree/patches"
printf 'echo serving\n' >"$tree/remote/serve.sh"
chmod 755 "$tree/remote/serve.sh"
printf 'patch body\n' >"$tree/patches/repair.patch"
chmod 644 "$tree/patches/repair.patch"

write_tree_manifest() {
    manifest_head=$1
    payload_rows=$work_directory/payload-rows
    (
        cd "$tree"
        find remote patches -type f | LC_ALL=C sort | while IFS= read -r file; do
            mode_class=-
            [ -x "$file" ] && mode_class=x
            printf '%s\t%s\t%s\n' "$file" "$(sha256sum "$file" | cut -d ' ' -f 1)" \
                "$mode_class"
        done
    ) >"$payload_rows"
    remote_digest=$(grep '^remote/' "$payload_rows" | sha256sum | cut -d ' ' -f 1)
    patches_digest=$(grep '^patches/' "$payload_rows" | sha256sum | cut -d ' ' -f 1)
    {
        printf 'git_head\t%s\n' "$manifest_head"
        printf 'remote_payload_tree_sha256\t%s\n' "$remote_digest"
        printf 'patches_payload_tree_sha256\t%s\n' "$patches_digest"
        cat "$payload_rows"
    } >"$tree/runtime-tree-manifest.tsv"
}
write_tree_manifest deadbeefcafef00d1234567890abcdef12345678

# ---- an activated bundle -----------------------------------------------------
QWEN_MODEL_REGISTRY=$work_directory/models.tsv
export QWEN_MODEL_REGISTRY
printf 'qwen-2b\tfast-text\tqwen-2b.gguf\n' >"$QWEN_MODEL_REGISTRY"
model_root=$work_directory/models
mkdir -p "$model_root"

server=$work_directory/llama-server
printf '#!/bin/sh\nexit 0\n' >"$server"
chmod 755 "$server"
manifest=$work_directory/artifact-manifest.tsv
{
    printf 'checkpoint_semantics\tnatural-boundary-v1\n'
    printf 'candidate_series\tpatches/llama-server-prefix-checkpoint.patch\n'
    printf 'candidate_series_sha256\t%s\n' \
        "$(printf 'candidate-fixture' | sha256sum | cut -d ' ' -f 1)"
    printf 'executable\tllama-server\t%s\t%s\n' \
        "$(wc -c <"$server" | tr -d ' ')" "$(sha256sum "$server" | cut -d ' ' -f 1)"
} >"$manifest"
ledger=$work_directory/ledger.tsv
printf 'qwen-2b\t0\t-\n' >"$ledger"
router_preset=$work_directory/router-presets.ini
printf '[qwen-2b]\nLLAMA_ARG_MODEL = %s/qwen-2b.gguf\nLLAMA_ARG_CTX_CHECKPOINTS = 0\n' \
    "$model_root" >"$router_preset"

deployment_root=$work_directory/deployments
mkdir -p "$deployment_root"
QWEN_BUNDLE_ROUTER_PRESETS=$router_preset \
    "$builder" receipt-fixture "$server" "$manifest" "$ledger" "$deployment_root" \
    >/dev/null
"$activator" receipt-fixture "$deployment_root" >/dev/null
report bundle_activated accepted

# ---- a running-session status line -------------------------------------------
state_directory=$work_directory/state
mkdir -p "$state_directory"
printf 'state=running server_pid=1 profile=low-async lan_exposure=1 lan_address=192.0.2.10 lan_name=qwen-laptop.local lan_open=1\n' \
    >"$state_directory/session.status"

run_writer() {
    output=$work_directory/receipt.tsv
    rm -f "$output"
    QWEN_RECEIPT_RUNTIME_TREE_ROOT=$tree \
    QWEN_RECEIPT_MODEL_REGISTRY=$QWEN_MODEL_REGISTRY \
    QWEN_RECEIPT_STATE_DIRECTORY=$state_directory \
        "$writer" "$deployment_root" "$output"
}

if ! run_writer >"$work_directory/writer.stdout" 2>"$work_directory/writer.stderr"; then
    cat "$work_directory/writer.stderr" >&2
    printf 'the receipt writer failed against a verified fixture\n' >&2
    exit 1
fi
report receipt_written accepted

receipt=$work_directory/receipt.tsv
field() {
    awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$receipt"
}

if [ "$(field main_commit)" = deadbeefcafef00d1234567890abcdef12345678 ]; then
    report main_commit_field accepted
else
    printf 'main_commit field did not read the manifest git_head\n' >&2
    exit 1
fi
if [ "$(field tool_prefix_identity)" = \
    "patches/llama-server-prefix-checkpoint.patch:$(printf 'candidate-fixture' | sha256sum | cut -d ' ' -f 1)" ]; then
    report tool_prefix_identity_field accepted
else
    printf 'tool_prefix_identity field did not join the candidate series rows\n' >&2
    exit 1
fi
case $(field open_lan_policy_identity) in
    'lan_exposure=1 lan_address=192.0.2.10 lan_name=qwen-laptop.local lan_open=1')
        report open_lan_policy_identity_field accepted ;;
    *)
        printf 'open_lan_policy_identity field did not read the session boundary line\n' >&2
        exit 1
        ;;
esac
if [ "$(field server_digest)" = "$(sha256sum "$server" | cut -d ' ' -f 1)" ]; then
    report server_digest_field accepted
else
    printf 'server_digest field did not match the bundled server\n' >&2
    exit 1
fi
if [ "$(field model_ledger_digest)" = "$(sha256sum "$QWEN_MODEL_REGISTRY" | cut -d ' ' -f 1)" ]; then
    report model_ledger_digest_field accepted
else
    printf 'model_ledger_digest field did not match the registry file\n' >&2
    exit 1
fi

# The closing row is a digest over every row above it, recomputed here the
# same way the writer computed it: strip the closing row itself and hash what
# remains.
recomputed=$(grep -v '^receipt_sha256	' "$receipt" | sha256sum | cut -d ' ' -f 1)
if [ "$(field receipt_sha256)" = "$recomputed" ]; then
    report receipt_sha256_reproducible accepted
else
    printf 'receipt_sha256 does not reproduce from the rows it covers\n' >&2
    exit 1
fi

# ---- refusal: no active deployment --------------------------------------------
empty_root=$work_directory/empty-deployments
mkdir -p "$empty_root"
if QWEN_RECEIPT_RUNTIME_TREE_ROOT=$tree \
    "$writer" "$empty_root" "$work_directory/refused.tsv" \
    >/dev/null 2>"$work_directory/no-deployment.stderr"; then
    printf 'a deployment root with no active bundle escaped refusal\n' >&2
    exit 1
fi
report no_active_deployment_refused accepted

# ---- refusal: a runtime tree diverged from its own manifest -------------------
printf 'echo tampered\n' >"$tree/remote/serve.sh"
if QWEN_RECEIPT_RUNTIME_TREE_ROOT=$tree \
    QWEN_RECEIPT_MODEL_REGISTRY=$QWEN_MODEL_REGISTRY \
    QWEN_RECEIPT_STATE_DIRECTORY=$state_directory \
    "$writer" "$deployment_root" "$work_directory/refused.tsv" \
    >/dev/null 2>"$work_directory/divergent.stderr"; then
    printf 'a divergent runtime tree escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'failed verification' "$work_directory/divergent.stderr"; then
    printf 'the divergent-tree refusal lost its reason\n' >&2
    exit 1
fi
report divergent_runtime_tree_refused accepted
write_tree_manifest deadbeefcafef00d1234567890abcdef12345678

# ---- absent session leaves an explicit field rather than refusing ------------
run_writer >/dev/null 2>&1
no_session_root=$work_directory/no-session-state
if QWEN_RECEIPT_RUNTIME_TREE_ROOT=$tree \
    QWEN_RECEIPT_MODEL_REGISTRY=$QWEN_MODEL_REGISTRY \
    QWEN_RECEIPT_STATE_DIRECTORY=$no_session_root \
    "$writer" "$deployment_root" "$work_directory/no-session.tsv" >/dev/null; then
    if [ "$(awk -F'\t' '$1 == "open_lan_policy_identity" { print $2; exit }' \
        "$work_directory/no-session.tsv")" = no-running-session ]; then
        report absent_session_recorded accepted
    else
        printf 'an absent session did not record no-running-session\n' >&2
        exit 1
    fi
else
    printf 'an absent session state directory refused the whole receipt\n' >&2
    exit 1
fi

# ---- refusal: a dirty sync names no commit a git tag can point at ------------
write_tree_manifest deadbeefcafef00d1234567890abcdef12345678-dirty
if QWEN_RECEIPT_RUNTIME_TREE_ROOT=$tree \
    QWEN_RECEIPT_MODEL_REGISTRY=$QWEN_MODEL_REGISTRY \
    QWEN_RECEIPT_STATE_DIRECTORY=$state_directory \
    "$writer" "$deployment_root" "$work_directory/dirty.tsv" \
    >/dev/null 2>"$work_directory/dirty.stderr"; then
    printf 'a dirty-synced runtime tree escaped refusal\n' >&2
    exit 1
fi
if ! grep -q 'dirty working tree' "$work_directory/dirty.stderr"; then
    printf 'the dirty-sync refusal lost its reason\n' >&2
    exit 1
fi
report dirty_sync_refused accepted
write_tree_manifest deadbeefcafef00d1234567890abcdef12345678

printf 'test-write-deployment-receipt: %d checks passed\n' "$checks"
