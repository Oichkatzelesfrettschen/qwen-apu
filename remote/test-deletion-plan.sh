#!/bin/sh
set -eu

# The deletion-plan preflight against a fixture root.
#
# Every arm builds a runtime root in a temporary directory, seeds one object
# population under it, and reads what `runtime-root.sh uninstall` or `purge`
# does. The refusal arms assert two things together: the command exits
# non-zero, and an unrelated sibling seeded beside the protected object is
# still there afterwards, since a preflight that refuses after removing three
# of five entries protects nothing.
#
# The enumeration arm is the one that decides whether this mechanism works at
# all. An acquisition carrying no control directory anywhere is what the
# retained sweep is, so the fixture for that row seeds no declaration and
# requires the refusal to come from the plan enumerating the children of a
# protected layout directory rather than from finding a record to read.
#
# usage: test-deletion-plan.sh

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d "${TMPDIR:-/tmp}/test-deletion-plan.XXXXXX")
trap 'chmod -R u+rwX "$work" 2>/dev/null || true; rm -rf -- "$work"' EXIT HUP INT TERM

failures=0
report() {
    if [ "$2" = ok ]; then
        printf 'ok %s\n' "$1"
    else
        printf 'FAIL %s: %s\n' "$1" "$2"
        failures=$((failures + 1))
    fi
}

# A fixture tree carries no .git at all, so runtime-root.sh reads it as
# neither a production checkout nor a linked worktree and uninstall needs no
# confirm. The fixture copies the scripts the actions reach rather than
# pointing at this checkout, so an arm cannot resolve the primary root.
new_tree() {
    tree=$1
    mkdir -p "$tree/remote"
    for helper in qwen-home.sh runtime-root.sh check-deletion-plan.sh \
        open-verified-lock-descriptor.py; do
        cp "$script_directory/$helper" "$tree/remote/$helper"
    done
    chmod +x "$tree/remote/runtime-root.sh" "$tree/remote/check-deletion-plan.sh" \
        "$tree/remote/qwen-home.sh" "$tree/remote/open-verified-lock-descriptor.py"
}

# One root laid out by the script itself, plus a sibling under `cache` whose
# survival is what every refusal arm reads.
new_root() {
    arm=$1
    tree=$work/$arm
    new_tree "$tree"
    root=$tree/root
    QWEN_HOME=$root "$tree/remote/runtime-root.sh" init >/dev/null
    mkdir -p "$root/cache/sibling"
    printf 'reconstructible\n' >"$root/cache/sibling/marker.txt"
}

run_uninstall() {
    ( cd "$tree" && QWEN_HOME=$root QWEN_DELETION_JOURNAL=$tree/journal.tsv \
        "$tree/remote/runtime-root.sh" uninstall ) >"$tree/out.log" 2>&1
}

sibling_survives() {
    [ -f "$root/cache/sibling/marker.txt" ]
}

plan_identity() {
    ( cd "$tree" && QWEN_HOME=$root "$tree/remote/check-deletion-plan.sh" plan "$1" \
        2>/dev/null || true ) | sed -n 's/.*plan_sha256=\([0-9a-f]*\).*/\1/p' | head -n 1
}

seal_decision() {
    seal_directory=$1
    seal_decision_value=$2
    seal_reason=$3
    mkdir -p "$seal_directory/.acquisition"
    seal_fingerprint=$( cd "$tree" && "$tree/remote/check-deletion-plan.sh" \
        fingerprint "$seal_directory" )
    seal_manifest=$( cd "$tree" && "$tree/remote/check-deletion-plan.sh" \
        payload-manifest "$seal_directory" )
    {
        printf 'acquisition_id\t%s\n' "${seal_directory##*/}"
        printf 'metadata_fingerprint\t%s\n' "$seal_fingerprint"
        printf 'payload_manifest\t%s\n' "$seal_manifest"
        printf 'decision\t%s\n' "$seal_decision_value"
        printf 'reason\t%s\n' "$seal_reason"
        printf 'retained_destination\t-\n'
        printf 'retained_digest\t-\n'
        printf 'authorization\tauthorization.tsv\n'
    } >"$seal_directory/.acquisition/decision.tsv"
    : >"$seal_directory/.acquisition/producer.lock"
    chmod 600 "$seal_directory/.acquisition/producer.lock"
}

seal_authorization() {
    authorize_directory=$1
    authorize_action=$2
    authorize_plan=$3
    authorize_manifest=$( cd "$tree" && "$tree/remote/check-deletion-plan.sh" \
        payload-manifest "$authorize_directory" )
    {
        printf 'acquisition_id\t%s\n' "${authorize_directory##*/}"
        printf 'payload_manifest\t%s\n' "$authorize_manifest"
        printf 'action\t%s\n' "$authorize_action"
        printf 'plan_sha256\t%s\n' "$authorize_plan"
        printf 'authorized_by\toperator\n'
        printf 'authorized_at\t2026-09-07T00:00:00Z\n'
    } >"$authorize_directory/.acquisition/authorization.tsv"
}

# ---- an acquisition carrying no declaration anywhere refuses the plan ----
new_root unreviewed
mkdir -p "$root/results/home-sweep-20260906/logs"
printf 'decode 9.46 tok/s\n' >"$root/results/home-sweep-20260906/logs/arm.log"
if run_uninstall; then
    report unreviewed_acquisition_refuses accepted
else
    report unreviewed_acquisition_refuses ok
fi
sibling_survives && report unreviewed_refusal_precedes_removal ok \
    || report unreviewed_refusal_precedes_removal "sibling removed"
[ -f "$root/results/home-sweep-20260906/logs/arm.log" ] \
    && report unreviewed_acquisition_untouched ok \
    || report unreviewed_acquisition_untouched removed
grep -q 'unreviewed' "$tree/out.log" && report unreviewed_names_its_reason ok \
    || report unreviewed_names_its_reason "$(cat "$tree/out.log")"

# ---- a hold stands against the root confirmation ----
new_root held
mkdir -p "$root/results/representation-arm"
printf 'raw arm\n' >"$root/results/representation-arm/run.log"
seal_decision "$root/results/representation-arm" hold -
if ( cd "$tree" && QWEN_HOME=$root QWEN_RUNTIME_ROOT_CONFIRM=$root \
    QWEN_DELETION_JOURNAL=$tree/journal.tsv \
    "$tree/remote/runtime-root.sh" uninstall ) >"$tree/out.log" 2>&1; then
    report hold_survives_root_confirmation accepted
else
    report hold_survives_root_confirmation ok
fi
grep -q "$(printf 'refuse\theld')" "$tree/out.log" && report hold_names_its_reason ok \
    || report hold_names_its_reason "$(cat "$tree/out.log")"
sibling_survives && report hold_refusal_precedes_removal ok \
    || report hold_refusal_precedes_removal "sibling removed"

# ---- a changed payload invalidates the decision that named it ----
new_root changed
mkdir -p "$root/results/universal-sweep"
printf 'slot 4\n' >"$root/results/universal-sweep/arm.log"
seal_decision "$root/results/universal-sweep" dispose intentional-discard
printf 'slot 4 edited\n' >"$root/results/universal-sweep/arm.log"
if run_uninstall; then
    report changed_fingerprint_refuses accepted
else
    report changed_fingerprint_refuses ok
fi
grep -q 'changed-since-review' "$tree/out.log" && report changed_names_its_reason ok \
    || report changed_names_its_reason "$(cat "$tree/out.log")"

# ---- a same-size rewrite with the timestamp returned moves the payload
#      digest while the metadata fingerprint holds still ----
new_root metadata_is_not_content
mkdir -p "$root/results/timestamped"
printf 'aaaaaaaaaaaaaaaaaaaa\n' >"$root/results/timestamped/value.txt"
before_fingerprint=$( cd "$tree" && "$tree/remote/check-deletion-plan.sh" \
    fingerprint "$root/results/timestamped" )
before_manifest=$( cd "$tree" && "$tree/remote/check-deletion-plan.sh" \
    payload-manifest "$root/results/timestamped" )
python3 - "$root/results/timestamped/value.txt" <<'PY'
import os, sys
path = sys.argv[1]
status = os.stat(path)
with open(path, "w") as handle:
    handle.write("bbbbbbbbbbbbbbbbbbbb\n")
os.utime(path, ns=(status.st_atime_ns, status.st_mtime_ns))
PY
after_fingerprint=$( cd "$tree" && "$tree/remote/check-deletion-plan.sh" \
    fingerprint "$root/results/timestamped" )
after_manifest=$( cd "$tree" && "$tree/remote/check-deletion-plan.sh" \
    payload-manifest "$root/results/timestamped" )
[ "$before_fingerprint" = "$after_fingerprint" ] \
    && report metadata_fingerprint_misses_the_rewrite ok \
    || report metadata_fingerprint_misses_the_rewrite "fingerprint moved"
[ "$before_manifest" != "$after_manifest" ] \
    && report payload_manifest_catches_the_rewrite ok \
    || report payload_manifest_catches_the_rewrite "manifest held still"
seal_decision "$root/results/timestamped" dispose intentional-discard
python3 - "$root/results/timestamped/value.txt" <<'PY'
import os, sys
path = sys.argv[1]
status = os.stat(path)
with open(path, "w") as handle:
    handle.write("cccccccccccccccccccc\n")
os.utime(path, ns=(status.st_atime_ns, status.st_mtime_ns))
PY
if run_uninstall; then
    report payload_change_refuses_the_stale_decision accepted
else
    report payload_change_refuses_the_stale_decision ok
fi
grep -q 'payload-changed' "$tree/out.log" \
    && report payload_change_names_its_reason ok \
    || report payload_change_names_its_reason "$(cat "$tree/out.log")"

# ---- each mechanism refuses alone, with every other proof complete ----
#
# An arm whose object also lacks an authorization refuses for that reason
# whatever the mechanism under test does, so these three carry a complete
# proof and withdraw exactly one thing. A `touch` moves the modification
# timestamp and leaves the bytes, which is the one change the fingerprint sees
# and the payload manifest does not.
new_root isolated_fingerprint
mkdir -p "$root/results/only-the-fingerprint"
printf 'x\n' >"$root/results/only-the-fingerprint/a.log"
seal_decision "$root/results/only-the-fingerprint" dispose intentional-discard
seal_authorization "$root/results/only-the-fingerprint" uninstall "$(plan_identity uninstall)"
touch "$root/results/only-the-fingerprint/a.log"
if run_uninstall; then
    report timestamp_alone_refuses accepted
else
    report timestamp_alone_refuses ok
fi
grep -q 'changed-since-review' "$tree/out.log" && report timestamp_alone_names_its_reason ok \
    || report timestamp_alone_names_its_reason "$(cat "$tree/out.log")"

new_root isolated_lock
mkdir -p "$root/results/only-the-lock"
printf 'x\n' >"$root/results/only-the-lock/a.log"
seal_decision "$root/results/only-the-lock" dispose intentional-discard
seal_authorization "$root/results/only-the-lock" uninstall "$(plan_identity uninstall)"
rm -f "$root/results/only-the-lock/.acquisition/producer.lock"
if run_uninstall; then
    report absent_lock_alone_refuses accepted
else
    report absent_lock_alone_refuses ok
fi

new_root isolated_duplicate
mkdir -p "$root/results/only-the-reason"
printf 'x\n' >"$root/results/only-the-reason/a.log"
seal_decision "$root/results/only-the-reason" dispose verified-copy-retained
seal_authorization "$root/results/only-the-reason" uninstall "$(plan_identity uninstall)"
if run_uninstall; then
    report duplicate_reason_alone_refuses accepted
else
    report duplicate_reason_alone_refuses ok
fi

# ---- a malformed decision refuses, and so does a conflicting one ----
new_root malformed
mkdir -p "$root/results/malformed-record"
printf 'x\n' >"$root/results/malformed-record/a.log"
seal_decision "$root/results/malformed-record" dispose intentional-discard
printf 'decision\thold\n' >>"$root/results/malformed-record/.acquisition/decision.tsv"
if run_uninstall; then report conflicting_decision_refuses accepted; else report conflicting_decision_refuses ok; fi
grep -q 'malformed-decision' "$tree/out.log" && report conflicting_names_its_reason ok \
    || report conflicting_names_its_reason "$(cat "$tree/out.log")"

new_root unknown_key
mkdir -p "$root/results/unknown-key"
printf 'x\n' >"$root/results/unknown-key/a.log"
seal_decision "$root/results/unknown-key" dispose intentional-discard
printf 'force\tyes\n' >>"$root/results/unknown-key/.acquisition/decision.tsv"
if run_uninstall; then report unknown_key_refuses accepted; else report unknown_key_refuses ok; fi

# ---- an acquisition identity that names another object refuses ----
new_root identity
mkdir -p "$root/results/named-one"
printf 'x\n' >"$root/results/named-one/a.log"
seal_decision "$root/results/named-one" dispose intentional-discard
sed 's/^acquisition_id\t.*/acquisition_id\tnamed-two/' \
    "$root/results/named-one/.acquisition/decision.tsv" >"$work/identity.tsv"
mv "$work/identity.tsv" "$root/results/named-one/.acquisition/decision.tsv"
if run_uninstall; then report identity_mismatch_refuses accepted; else report identity_mismatch_refuses ok; fi
grep -q 'identity-mismatch' "$tree/out.log" && report identity_names_its_reason ok \
    || report identity_names_its_reason "$(cat "$tree/out.log")"

# ---- an absent producer lock reads as unmanaged rather than idle ----
new_root unmanaged
mkdir -p "$root/results/legacy-acquisition"
printf 'x\n' >"$root/results/legacy-acquisition/a.log"
seal_decision "$root/results/legacy-acquisition" dispose intentional-discard
rm -f "$root/results/legacy-acquisition/.acquisition/producer.lock"
if run_uninstall; then report absent_lock_refuses accepted; else report absent_lock_refuses ok; fi
grep -q 'unmanaged-activity' "$tree/out.log" && report absent_lock_names_unmanaged ok \
    || report absent_lock_names_unmanaged "$(cat "$tree/out.log")"

# ---- a producer holding its own lock refuses ----
new_root producer_active
mkdir -p "$root/results/running-acquisition"
printf 'x\n' >"$root/results/running-acquisition/a.log"
seal_decision "$root/results/running-acquisition" dispose intentional-discard
lock_leaf=$root/results/running-acquisition/.acquisition/producer.lock
flock -x "$lock_leaf" sh -c 'sleep 30' &
producer_pid=$!
producer_settled=0
while [ "$producer_settled" -lt 50 ]; do
    if ! flock -n -x "$lock_leaf" true 2>/dev/null; then break; fi
    producer_settled=$((producer_settled + 1))
done
if run_uninstall; then report held_lock_refuses accepted; else report held_lock_refuses ok; fi
grep -q 'producer-active' "$tree/out.log" && report held_lock_names_producer ok \
    || report held_lock_names_producer "$(cat "$tree/out.log")"
kill "$producer_pid" 2>/dev/null || true
wait "$producer_pid" 2>/dev/null || true

# ---- a FIFO is inventoried by type and never opened ----
new_root special_nodes
mkdir -p "$root/results/dpm-authority"
printf 'x\n' >"$root/results/dpm-authority/a.log"
mkfifo "$root/results/dpm-authority/broker-control"
ln -s a.log "$root/results/dpm-authority/alias.log"
fifo_fingerprint=$( cd "$tree" && timeout 30 "$tree/remote/check-deletion-plan.sh" \
    fingerprint "$root/results/dpm-authority" ) \
    && report fifo_fingerprint_terminates ok || report fifo_fingerprint_terminates blocked
fifo_manifest=$( cd "$tree" && timeout 30 "$tree/remote/check-deletion-plan.sh" \
    payload-manifest "$root/results/dpm-authority" ) \
    && report fifo_manifest_terminates ok || report fifo_manifest_terminates blocked
case $fifo_fingerprint in
    [0-9a-f]*) report fifo_fingerprint_is_a_digest ok ;;
    *) report fifo_fingerprint_is_a_digest "$fifo_fingerprint" ;;
esac
case $fifo_manifest in
    [0-9a-f]*) report fifo_manifest_is_a_digest ok ;;
    *) report fifo_manifest_is_a_digest "$fifo_manifest" ;;
esac

# ---- a nested declaration refuses the object that contains it ----
new_root nested
mkdir -p "$root/results/outer/inner"
printf 'x\n' >"$root/results/outer/inner/a.log"
seal_decision "$root/results/outer" dispose intentional-discard
mkdir -p "$root/results/outer/inner/.acquisition"
printf 'acquisition_id\tinner\n' >"$root/results/outer/inner/.acquisition/decision.tsv"
if run_uninstall; then report nested_declaration_refuses accepted; else report nested_declaration_refuses ok; fi
grep -q 'nested-declaration' "$tree/out.log" && report nested_names_its_reason ok \
    || report nested_names_its_reason "$(cat "$tree/out.log")"

# ---- a duplicate-based disposal refuses while the destination is unverified ----
new_root duplicate
mkdir -p "$root/results/second-copy"
printf 'x\n' >"$root/results/second-copy/a.log"
seal_decision "$root/results/second-copy" dispose verified-copy-retained
if run_uninstall; then report duplicate_disposal_refuses accepted; else report duplicate_disposal_refuses ok; fi
grep -q 'destination-unverified' "$tree/out.log" && report duplicate_names_its_reason ok \
    || report duplicate_names_its_reason "$(cat "$tree/out.log")"

# ---- a blank, mismatched, or replayed authorization refuses ----
new_root authorization
mkdir -p "$root/results/discardable"
printf 'x\n' >"$root/results/discardable/a.log"
seal_decision "$root/results/discardable" dispose intentional-discard
if run_uninstall; then report absent_authorization_refuses accepted; else report absent_authorization_refuses ok; fi
grep -q 'authorization-absent' "$tree/out.log" && report absent_authorization_names_it ok \
    || report absent_authorization_names_it "$(cat "$tree/out.log")"
seal_authorization "$root/results/discardable" uninstall \
    0000000000000000000000000000000000000000000000000000000000000000
if run_uninstall; then report replayed_authorization_refuses accepted; else report replayed_authorization_refuses ok; fi
grep -q 'authorization-stale' "$tree/out.log" && report replayed_authorization_names_it ok \
    || report replayed_authorization_names_it "$(cat "$tree/out.log")"
seal_authorization "$root/results/discardable" purge "$(plan_identity uninstall)"
if run_uninstall; then report wrong_action_authorization_refuses accepted; else report wrong_action_authorization_refuses ok; fi

# ---- a complete proof removes exactly the accepted set ----
new_root admitted
mkdir -p "$root/results/discardable-fixture"
printf 'x\n' >"$root/results/discardable-fixture/a.log"
seal_decision "$root/results/discardable-fixture" dispose intentional-discard
seal_authorization "$root/results/discardable-fixture" uninstall "$(plan_identity uninstall)"
if run_uninstall; then
    report complete_proof_admits ok
else
    report complete_proof_admits "$(cat "$tree/out.log")"
fi
[ -d "$root/results" ] && report admitted_removal_leaves_no_results removed \
    || report admitted_removal_leaves_no_results ok
[ -d "$root/state" ] && report admitted_uninstall_keeps_state ok \
    || report admitted_uninstall_keeps_state removed
grep -q "$(printf 'journal\tcomplete')" "$tree/journal.tsv" \
    && report journal_records_completion ok || report journal_records_completion "$(cat "$tree/journal.tsv")"
grep -q "removed.*results" "$tree/journal.tsv" \
    && report journal_names_each_removal ok || report journal_names_each_removal "$(cat "$tree/journal.tsv")"
# The removal iterates the root-level rows of the plan report rather than
# taking its own reading of the root. The exclusion leaf is the one root entry
# the plan leaves out, so a loop re-reading the root would remove it and a loop
# reading the plan cannot: its survival is what separates the two.
[ -f "$root/.deletion.lock" ] && report removal_iterates_the_classified_set ok \
    || report removal_iterates_the_classified_set "$(ls -A "$root")"

# ---- a held sibling refuses the plan the disposable object was proven for ----
new_root mixed
mkdir -p "$root/results/disposable" "$root/results/held-beside-it"
printf 'x\n' >"$root/results/disposable/a.log"
printf 'y\n' >"$root/results/held-beside-it/b.log"
seal_decision "$root/results/disposable" dispose intentional-discard
seal_decision "$root/results/held-beside-it" hold -
seal_authorization "$root/results/disposable" uninstall "$(plan_identity uninstall)"
if run_uninstall; then report held_sibling_refuses_the_whole_plan accepted; else report held_sibling_refuses_the_whole_plan ok; fi
[ -f "$root/results/disposable/a.log" ] && report proven_object_untouched_while_sibling_holds ok \
    || report proven_object_untouched_while_sibling_holds removed

# ---- a deployment bundle refuses whether or not a role link names it ----
new_root deployments
mkdir -p "$root/deployments/emergency-rollback-bundle"
printf 'server\n' >"$root/deployments/emergency-rollback-bundle/server"
if run_uninstall; then report unreferenced_deployment_refuses accepted; else report unreferenced_deployment_refuses ok; fi
grep -q "$(printf 'deployment\trefuse')" "$tree/out.log" \
    && report deployment_refusal_is_typed ok || report deployment_refusal_is_typed "$(cat "$tree/out.log")"

new_root active_deployment
mkdir -p "$root/deployments/serving-bundle"
printf 'server\n' >"$root/deployments/serving-bundle/server"
ln -s serving-bundle "$root/deployments/deployment-current"
if run_uninstall; then report active_deployment_refuses accepted; else report active_deployment_refuses ok; fi
grep -q 'serving-role-current' "$tree/out.log" && report active_deployment_names_its_role ok \
    || report active_deployment_names_its_role "$(cat "$tree/out.log")"

# ---- an unclassified root entry refuses rather than reading as disposable ----
new_root unclassified
printf 'who wrote this\n' >"$root/stray-file"
if run_uninstall; then report unclassified_entry_refuses accepted; else report unclassified_entry_refuses ok; fi
grep -q 'unclassified-entry' "$tree/out.log" && report unclassified_names_its_reason ok \
    || report unclassified_names_its_reason "$(cat "$tree/out.log")"

# ---- purge selects models, and an undeclared checkpoint tree refuses ----
new_root purge_models
mkdir -p "$root/models/qwen-test-models"
printf 'gguf\n' >"$root/models/qwen-test-models/model.gguf"
if ( cd "$tree" && QWEN_HOME=$root QWEN_RUNTIME_ROOT_CONFIRM=$root \
    QWEN_DELETION_JOURNAL=$tree/journal.tsv \
    "$tree/remote/runtime-root.sh" purge ) >"$tree/out.log" 2>&1; then
    report purge_selects_models accepted
else
    report purge_selects_models ok
fi
[ -f "$root/models/qwen-test-models/model.gguf" ] && report purge_refusal_precedes_removal ok \
    || report purge_refusal_precedes_removal removed
if ( cd "$tree" && QWEN_HOME=$root QWEN_RUNTIME_ROOT_CONFIRM=$root \
    "$tree/remote/runtime-root.sh" uninstall ) >"$tree/uninstall.log" 2>&1; then
    report uninstall_leaves_models_unselected ok
else
    report uninstall_leaves_models_unselected "$(cat "$tree/uninstall.log")"
fi

# ---- purge refuses a journal it would destroy, and one it was never given ----
new_root purge_journal
if ( cd "$tree" && QWEN_HOME=$root QWEN_RUNTIME_ROOT_CONFIRM=$root \
    "$tree/remote/runtime-root.sh" purge ) >"$tree/out.log" 2>&1; then
    report purge_requires_a_journal accepted
else
    report purge_requires_a_journal ok
fi
if ( cd "$tree" && QWEN_HOME=$root QWEN_RUNTIME_ROOT_CONFIRM=$root \
    QWEN_DELETION_JOURNAL=$root/state/journal.tsv \
    "$tree/remote/runtime-root.sh" purge ) >"$tree/out.log" 2>&1; then
    report purge_refuses_a_journal_inside_the_root accepted
else
    report purge_refuses_a_journal_inside_the_root ok
fi
[ -d "$root/cache" ] && report refused_purge_touches_nothing ok \
    || report refused_purge_touches_nothing removed

# ---- the plan identity separates the two actions over one root ----
new_root plan_identity
mkdir -p "$root/results/one"
printf 'x\n' >"$root/results/one/a.log"
uninstall_plan=$(plan_identity uninstall)
purge_plan=$(plan_identity purge)
[ -n "$uninstall_plan" ] && [ "$uninstall_plan" != "$purge_plan" ] \
    && report plan_identity_separates_the_actions ok \
    || report plan_identity_separates_the_actions "$uninstall_plan vs $purge_plan"
seal_decision "$root/results/one" hold -
[ "$(plan_identity uninstall)" = "$uninstall_plan" ] \
    && report sealing_a_decision_holds_the_plan_identity ok \
    || report sealing_a_decision_holds_the_plan_identity moved
# The removal opens its exclusion leaf under the root before it classifies
# anything. An identity that counted that leaf would answer one value to the
# operator writing an authorization and another to the removal reading it.
: >"$root/.deletion.lock"
chmod 600 "$root/.deletion.lock"
[ "$(plan_identity uninstall)" = "$uninstall_plan" ] \
    && report exclusion_leaf_holds_the_plan_identity ok \
    || report exclusion_leaf_holds_the_plan_identity moved

if [ "$failures" -ne 0 ]; then
    printf 'test-deletion-plan: %s check(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'test-deletion-plan: all checks passed\n'
