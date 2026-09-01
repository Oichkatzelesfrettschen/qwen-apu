#!/bin/sh
set -eu

# Bind the checkpoint policy to the build that will execute it, immediately
# before llama-server replaces this process.
#
# A positive --ctx-checkpoints count is executable only by a server whose build
# placed checkpoints at natural batch boundaries. The pinned commit force-breaks
# the prompt fill loop `4 + n_ubatch` and `4` tokens from the end whenever
# checkpoints are armed, which moves the 0.8B's first-turn token at zero-based
# index 25, so a ledger edit that outran its binary would serve a perturbed
# first turn under a count the ledger admits. build-llama-preset.sh earns the
# declaration from the patch digest, the compiled source digest, and the absence
# of the forced partition, and this guard is what makes the declaration binding.
#
# The guard runs on both serving paths. On a router launch it precedes
# qwen-router-exec-guard.sh, which then rechecks the policy authorities; on the
# single-model path it precedes llama-server directly. It runs after
# radv-low-priority-env.sh has configured the final environment, so a symlink
# repointed or a manifest rewritten between policy assembly and exec is caught
# here rather than in a serving difference nobody attributes.
#
# The executable is resolved through its symlinks before the manifest is read,
# because build-appliance-current is a symlink and the manifest belongs to the
# build directory it resolves into. Requiring the manifest's own digest to equal
# the one the capacity policy measured closes the remaining window: a manifest
# rewritten to declare natural-boundary-v1 over an unrepaired binary changes the
# digest the policy recorded.

if [ "$#" -lt 4 ]; then
    printf 'usage: %s SERVER MANIFEST_SHA256 REQUIRED_SEMANTICS COMMAND [ARG ...]\n' \
        "$0" >&2
    printf '  REQUIRED_SEMANTICS is `-` where no positive checkpoint count is armed\n' >&2
    exit 2
fi

server_path=$1
shift
manifest_sha256=$1
shift
required_semantics=$1
shift

resolved_server=$(readlink -f -- "$server_path") || {
    printf 'selected llama-server cannot be resolved: %s\n' "$server_path" >&2
    exit 1
}
if [ ! -x "$resolved_server" ]; then
    printf 'selected llama-server is not executable: %s\n' "$resolved_server" >&2
    exit 1
fi

# A build directory holds bin/llama-server beside artifact-manifest.tsv, and a
# test fixture holds the manifest beside the executable itself. Both shapes
# resolve here so the guard reads one manifest either way.
#
# qwen-capacity-policy.sh performs the same two-step search to measure the
# digest this guard compares against, so the two orders are one decision made
# twice: a change here that resolved a different file would compare a digest
# taken from another manifest, and the refusal would name a drift that never
# happened.
server_directory=$(dirname -- "$resolved_server")
manifest_path=''
for candidate_manifest in "$server_directory/artifact-manifest.tsv" \
    "$server_directory/../artifact-manifest.tsv"; do
    if [ -r "$candidate_manifest" ]; then
        manifest_path=$candidate_manifest
        break
    fi
done

if [ "$required_semantics" = - ]; then
    # No positive count is armed, so an older checkpoint implementation serves
    # and a build predating the declaration launches unchanged.
    printf 'build_guard=accepted checkpoint_requirement=none server=%s\n' \
        "$resolved_server"
    exec "$@"
fi

if [ -z "$manifest_path" ]; then
    printf 'selected llama-server carries no artifact manifest: %s\n' \
        "$resolved_server" >&2
    printf 'a positive context checkpoint count requires %s\n' \
        "$required_semantics" >&2
    exit 1
fi

if [ "$manifest_sha256" != - ]; then
    measured_manifest_sha256=$(sha256sum -- "$manifest_path" | cut -d ' ' -f 1)
    if [ "$measured_manifest_sha256" != "$manifest_sha256" ]; then
        printf 'artifact manifest identity changed: expected %s, measured %s\n' \
            "$manifest_sha256" "$measured_manifest_sha256" >&2
        exit 1
    fi
fi

# The manifest states one executable row per object it owns, so an executable
# named twice or not at all leaves the digest comparison undefined rather than
# failing it.
server_name=$(basename -- "$resolved_server")
executable_rows=$(awk -F'\t' -v object="$server_name" '
    $1 == "executable" && $2 == object && NF == 4 { count++ }
    END { print count + 0 }
' "$manifest_path")
if [ "$executable_rows" -ne 1 ]; then
    printf 'artifact manifest holds %s executable rows for %s, requires exactly one\n' \
        "$executable_rows" "$server_name" >&2
    exit 1
fi

expected_bytes=$(awk -F'\t' -v object="$server_name" '
    $1 == "executable" && $2 == object && NF == 4 { print $3; exit }
' "$manifest_path")
expected_digest=$(awk -F'\t' -v object="$server_name" '
    $1 == "executable" && $2 == object && NF == 4 { print $4; exit }
' "$manifest_path")
measured_bytes=$(stat -c %s -- "$resolved_server")
measured_digest=$(sha256sum -- "$resolved_server" | cut -d ' ' -f 1)
if [ "$measured_bytes" != "$expected_bytes" ] ||
    [ "$measured_digest" != "$expected_digest" ]; then
    printf 'selected llama-server does not match its manifest row: %s\n' \
        "$resolved_server" >&2
    printf 'manifest states %s bytes %s, measured %s bytes %s\n' \
        "$expected_bytes" "$expected_digest" "$measured_bytes" "$measured_digest" >&2
    exit 1
fi

semantics_rows=$(awk -F'\t' '
    $1 == "checkpoint_semantics" { count++ }
    END { print count + 0 }
' "$manifest_path")
if [ "$semantics_rows" -ne 1 ]; then
    printf 'artifact manifest holds %s checkpoint_semantics rows, requires exactly one: %s\n' \
        "$semantics_rows" "$manifest_path" >&2
    exit 1
fi
declared_semantics=$(awk -F'\t' '
    $1 == "checkpoint_semantics" { print $2; exit }
' "$manifest_path")
if [ "$declared_semantics" != "$required_semantics" ]; then
    printf 'the selected llama-server declares checkpoint_semantics=%s: %s\n' \
        "$declared_semantics" "$resolved_server" >&2
    printf 'a positive context checkpoint count requires %s\n' \
        "$required_semantics" >&2
    exit 1
fi

printf 'build_guard=accepted checkpoint_semantics=%s server=%s manifest=%s\n' \
    "$declared_semantics" "$resolved_server" "$manifest_path"

exec "$@"
