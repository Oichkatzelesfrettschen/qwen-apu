#!/bin/sh
set -eu

# The tier tree decides what the model picker offers, so a defect here exposes a
# checkpoint the evidence says to keep out of reach rather than producing a
# visible error. Every check below runs against a fabricated model root so it
# needs no weights and no device.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
registry=$script_directory/models.tsv
quarantine=$script_directory/quarantine.tsv
builder=$script_directory/build-router-presets.sh
reader=$script_directory/model-registry.sh
failures=0

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = accepted ] || failures=$((failures + 1))
}

# A fabricated model root carrying an empty file at every registry path. The
# builder tests for a regular file rather than reading it, so an empty file
# exercises the whole reconciliation without a single weight on disk.
model_root=$work/models
awk -F'\t' '!/^#/ && NF { print $3 }' "$registry" | while read -r model_file; do
    mkdir -p "$model_root/$(dirname -- "$model_file")"
    : >"$model_root/$model_file"
done

presets=$work/router-presets.ini
build() {
    QWEN_MODEL_ROOT=$model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine \
    QWEN_QUARANTINE_REASONS=$repository_root/evidence/quarantine \
        "$builder" "$presets"
}

if build >"$work/build.log" 2>"$work/build.err"; then
    report reconciliation accepted
else
    report reconciliation rejected
    cat "$work/build.err" >&2
fi

section_ids=$(awk -F'[][]' '/^\[/ { print $2 }' "$presets")

# Every tier value in the registry must be one the readers handle. A sixth tier
# reaches the builder as an unclaimed row rather than as an error.
tier_vocabulary=0
for tier in $(awk -F'\t' '!/^#/ && NF { print $15 }' "$registry" | sort -u); do
    "$reader" validate-tier "$tier" ||
        { printf 'tier outside the vocabulary: %s\n' "$tier" >&2
          tier_vocabulary=$((tier_vocabulary + 1)); }
done
if [ "$tier_vocabulary" -eq 0 ]; then
    report tier_vocabulary accepted
else
    report tier_vocabulary rejected
fi

# A quarantined subject reaching production/ or candidates/ is the failure the
# tier tree exists to prevent, and it is checked against the link tree rather
# than against the registry, because the link is what the router scans.
quarantine_leak=0
for subject in $("$reader" quarantine-subjects); do
    model_file=$("$reader" id "$subject" model_file)
    model_directory=$(basename -- "$(dirname -- "$model_file")")
    for open_tier in production candidates; do
        if [ -e "$model_root/$open_tier/$model_directory" ]; then
            printf 'quarantined subject %s is linked into %s\n' \
                "$subject" "$open_tier" >&2
            quarantine_leak=$((quarantine_leak + 1))
        fi
    done
    case " $section_ids " in
        *" $subject "*)
            printf 'quarantined subject %s carries a preset section\n' \
                "$subject" >&2
            quarantine_leak=$((quarantine_leak + 1))
            ;;
    esac
done
if [ "$quarantine_leak" -eq 0 ]; then
    report quarantine_excluded accepted
else
    report quarantine_excluded rejected
fi

# One checkpoint directory in two tiers means one of the two claims is stale,
# and the picker would show whichever the router scanned first.
duplicate_tier=$(
    for open_tier in production candidates quarantine; do
        [ -d "$model_root/$open_tier" ] || continue
        for entry in "$model_root/$open_tier"/*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            basename -- "$entry"
        done
    done | sort | uniq -d
)
if [ -z "$duplicate_tier" ]; then
    report single_tier accepted
else
    report single_tier rejected
    printf 'checkpoint appears in more than one tier: %s\n' "$duplicate_tier" >&2
fi

# A quarantine without a reason record is an unexplained exclusion, and a reason
# record naming evidence that is absent is an unsupported one.
reason_failures=0
for reason_id in $(awk -F'\t' '!/^#/ && NF { print $1 }' "$quarantine"); do
    reason_record=$repository_root/evidence/quarantine/$reason_id.md
    if [ ! -r "$reason_record" ]; then
        printf 'quarantine %s carries no reason record\n' "$reason_id" >&2
        reason_failures=$((reason_failures + 1))
    fi
done
for subject in $("$reader" quarantine-subjects); do
    model_file=$("$reader" id "$subject" model_file)
    model_directory=$(basename -- "$(dirname -- "$model_file")")
    if [ ! -L "$model_root/quarantine/$model_directory" ]; then
        printf 'quarantined subject %s is not linked into quarantine/\n' \
            "$subject" >&2
        reason_failures=$((reason_failures + 1))
    fi
    if [ ! -r "$model_root/quarantine-reasons/$subject.md" ]; then
        printf 'quarantine link for %s has no deployed reason record\n' \
            "$subject" >&2
        reason_failures=$((reason_failures + 1))
    fi
done
if [ "$reason_failures" -eq 0 ]; then
    report quarantine_reasons accepted
else
    report quarantine_reasons rejected
fi

# Both evidence pointers of every quarantine row resolve inside the tree, so a
# quarantine is never carried by prose that names a file nobody retained. The
# check is unconditional on both machines: the appliance is where a quarantine
# is enforced, and a reason record there that cites a measurement that host
# cannot show is the same defect as one in the repository.
evidence_failures=0
while IFS='	' read -r quarantine_id _scope _subject _class _depth _batch \
    _ubatch _ctk _ctv _fa first_evidence latest_evidence _record; do
    case $quarantine_id in '#'* | '') continue ;; esac
    for evidence_path in "$first_evidence" "$latest_evidence"; do
        [ "$evidence_path" = - ] && continue
        if [ ! -r "$repository_root/$evidence_path" ]; then
            printf 'quarantine %s names absent evidence: %s\n' \
                "$quarantine_id" "$evidence_path" >&2
            evidence_failures=$((evidence_failures + 1))
        fi
    done
done <"$quarantine"
if [ "$evidence_failures" -eq 0 ]; then
    report evidence_paths accepted
else
    report evidence_paths rejected
fi

# llama-server refuses a preset key it does not recognise and fails the whole
# router at startup, so an invented name reaches the appliance as a dead service
# rather than as an ignored line. The vocabulary is the set_env() names in
# common/arg.cpp at the pinned build; LLAMA_ARG_BATCH_SIZE is not among them and
# LLAMA_ARG_BATCH is, which is the failure this check exists for.
preset_key_failures=0
for preset_key in $(sed -n 's/^\(LLAMA_ARG_[A-Z_]*\) *=.*/\1/p' "$presets" |
    sort -u); do
    case $preset_key in
        LLAMA_ARG_MODEL | LLAMA_ARG_ALIAS | LLAMA_ARG_TAGS | \
        LLAMA_ARG_CTX_SIZE | LLAMA_ARG_CACHE_TYPE_K | LLAMA_ARG_CACHE_TYPE_V | \
        LLAMA_ARG_FLASH_ATTN | LLAMA_ARG_BATCH | LLAMA_ARG_UBATCH | \
        LLAMA_ARG_MMPROJ) ;;
        *)
            printf 'preset key is outside the llama-server vocabulary: %s\n' \
                "$preset_key" >&2
            preset_key_failures=$((preset_key_failures + 1))
            ;;
    esac
done
if [ "$preset_key_failures" -eq 0 ]; then
    report preset_key_vocabulary accepted
else
    report preset_key_vocabulary rejected
fi

# Every section carries all six per-checkpoint keys. The router argv omits them
# so the preset decides, and a key absent from a section falls through to the
# llama.cpp defaults, where batch 2048 and ubatch 512 is the quarantined
# geometry. An incomplete section is therefore how a quarantined tuple would
# reach a child without any row asking for it.
section_completeness=0
for section in $section_ids; do
    for required_key in LLAMA_ARG_CTX_SIZE LLAMA_ARG_CACHE_TYPE_K \
        LLAMA_ARG_CACHE_TYPE_V LLAMA_ARG_FLASH_ATTN LLAMA_ARG_BATCH \
        LLAMA_ARG_UBATCH; do
        if ! awk -F'[][]' -v want="$section" -v key="$required_key" '
            /^\[/ { in_section = ($2 == want); next }
            in_section && index($0, key) == 1 { found = 1 }
            END { exit found ? 0 : 1 }' "$presets"; then
            printf 'preset section %s omits %s\n' "$section" "$required_key" >&2
            section_completeness=$((section_completeness + 1))
        fi
    done
done
if [ "$section_completeness" -eq 0 ]; then
    report section_completeness accepted
else
    report section_completeness rejected
fi

# A profile quarantine removes one tuple, so the check is against the geometry
# each section serves at rather than against the section's presence. The preset
# carries batch and ubatch explicitly for exactly this reason.
profile_leak=0
while IFS='	' read -r subject depth batch ubatch _cache_k _cache_v _flash; do
    [ -n "$subject" ] || continue
    section_ctx=$(awk -F'[][]' -v want="$subject" '
        /^\[/ { in_section = ($2 == want); next }
        in_section && /^LLAMA_ARG_CTX_SIZE/ { print $0 }' "$presets" |
        sed 's/.*= *//')
    section_batch=$(awk -F'[][]' -v want="$subject" '
        /^\[/ { in_section = ($2 == want); next }
        in_section && /^LLAMA_ARG_BATCH/ { print $0 }' "$presets" |
        sed 's/.*= *//')
    section_ubatch=$(awk -F'[][]' -v want="$subject" '
        /^\[/ { in_section = ($2 == want); next }
        in_section && /^LLAMA_ARG_UBATCH/ { print $0 }' "$presets" |
        sed 's/.*= *//')
    [ -n "$section_batch" ] || continue
    if [ "$section_ctx" = "$depth" ] && [ "$section_batch" = "$batch" ] &&
        [ "$section_ubatch" = "$ubatch" ]; then
        printf 'preset %s serves the quarantined tuple %s/%s/%s\n' \
            "$subject" "$depth" "$batch" "$ubatch" >&2
        profile_leak=$((profile_leak + 1))
    fi
done <<PROFILES
$("$reader" quarantine-profiles)
PROFILES
if [ "$profile_leak" -eq 0 ]; then
    report quarantine_profiles accepted
else
    report quarantine_profiles rejected
fi

# Reconciliation removes symlinks and must refuse a real directory, because
# emptying one would delete a checkpoint and skipping one would leave it in a
# tier no row claims.
mkdir -p "$model_root/production/hand-placed"
set +e
build >"$work/refuse.log" 2>"$work/refuse.err"
refuse_status=$?
set -e
rmdir "$model_root/production/hand-placed"
if [ "$refuse_status" -ne 0 ] &&
    grep -q 'real entry where a symlink belongs' "$work/refuse.err"; then
    report real_directory_refused accepted
else
    report real_directory_refused rejected
fi

# The research override is the only path that names a quarantined checkpoint,
# and the policy forces the listener to loopback while it is set.
build_override=$(QWEN_MODEL_ROOT=$model_root \
    QWEN_QUARANTINE_REGISTRY=$quarantine \
    QWEN_QUARANTINE_REASONS=$repository_root/evidence/quarantine \
    QWEN_ROUTER_INCLUDE_QUARANTINE=1 "$builder" "$presets" 2>&1)
if printf '%s' "$build_override" | grep -q 'quarantine_override=on' &&
    awk -F'[][]' '/^\[/ { print $2 }' "$presets" | grep -qx nanbeige42-3b; then
    report quarantine_override accepted
else
    report quarantine_override rejected
fi

if [ "$failures" -eq 0 ]; then
    printf 'model_tiers=accepted\n'
    exit 0
fi
printf 'model_tiers=rejected failures=%s\n' "$failures" >&2
exit 1
