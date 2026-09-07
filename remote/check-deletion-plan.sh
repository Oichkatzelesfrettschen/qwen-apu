#!/bin/sh
set -eu

# The deletion plan a removal would execute, classified object by object
# before the first byte goes.
#
# `runtime-root.sh uninstall` and `purge` iterate the root and remove what
# they select. The confirm each takes proves an operator meant to run the
# command; it establishes nothing about the objects the command selected. A
# measurement that no longer exists anywhere else and a rollback bundle that
# is the only copy of the server it carries both sit inside that selection,
# and three copies of one artifact inside one root are removed by one
# invocation.
#
# This script enumerates the complete selection first and reads a decision
# record from every protected object in it. A plan holding one unreviewed,
# held, changed, locked, or malformed object refuses whole, so no sibling is
# removed while a protected object stands unresolved. Two object types carry
# that veto and they are different claims: a measurement acquisition is
# irreplaceable evidence, and a deployment bundle is an operational artifact
# whose protection comes from its serving and rollback roles. A directory is
# neither by default -- an object this script cannot classify refuses rather
# than reading an absent declaration as permission.
#
# Two identity checks answer two questions at two costs. The metadata
# fingerprint over `(type, relative path, size, mtime)` detects a changed
# population and a changed size cheaply, and it is a change indication rather
# than a content proof: `os.utime` restores a modification timestamp at
# nanosecond resolution, so a same-size rewrite with the original timestamp
# returned reproduces the fingerprint exactly while the payload digest moves.
# The payload manifest hashes the bytes and is required before a destructive
# disposal, where the cost is paid once against an acquisition an operator has
# already decided to lose.
#
# A named pipe blocks a reader forever, and six sit in the retained sweep as
# the `broker-control` FIFOs of two DPM authority runs. Both readers enumerate
# every node by type through `find -printf`, which opens nothing, and hash
# regular files alone; a socket, a FIFO, a device node, and a symbolic link
# are inventoried as type rows carrying no digest.
#
# usage: check-deletion-plan.sh plan ACTION
#        check-deletion-plan.sh verdict DIRECTORY CLASS ACTION PLAN_SHA256
#        check-deletion-plan.sh fingerprint DIRECTORY
#        check-deletion-plan.sh payload-manifest DIRECTORY
#   ACTION   uninstall | purge, the removal whose selection is classified
#   CLASS    acquisition | deployment, the protected object type
#   QWEN_HOME   the root, default .runtime beside remote/
#
# `plan` exits 0 where every selected object is admissible and 1 where any
# refuses, printing one row per object either way.

usage() {
    sed -n '/^# usage:/,/^# `plan` exits/p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
}

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

lock_helper=$script_directory/open-verified-lock-descriptor.py

control_directory_name=.acquisition
decision_record_name=decision.tsv
authorization_record_name=authorization.tsv
producer_lock_name=producer.lock

# The root's own control objects. They are declared rather than foreign, and
# the removal actions carry them past the plan: the lock is the exclusion the
# removal holds, and the journal names a path outside the root under purge.
root_control_names='.deletion.lock'

tab=$(printf '\t')

fail() {
    printf '%s\n' "$1" >&2
    exit 2
}

# One row per node, directories excluded. A directory's own timestamp moves
# when a control record is written beside it, so a fingerprint carrying it
# would be stale the instant the decision naming it is sealed; a changed
# population already appears as an added or removed node row.
node_rows() {
    node_directory=$1
    node_format=$2
    ( cd -- "$node_directory" && \
        find . -mindepth 1 -name "$control_directory_name" -prune -o \
            ! -type d -printf "$node_format" ) | LC_ALL=C sort
}

# `find -printf` and `sha256sum` both delimit by newline, so a path holding
# one would emit a row the reader misparses. The node count taken by the same
# enumeration bounds that: a listing whose row count differs from the node
# count carries a path this reader cannot represent, and the caller refuses
# rather than digesting a misparsed listing.
counted_node_total() {
    ( cd -- "$1" && \
        find . -mindepth 1 -name "$control_directory_name" -prune -o \
            ! -type d -printf 'x\n' ) | wc -l | tr -d ' '
}

fingerprint_of() {
    fingerprint_directory=$1
    fingerprint_rows=$(node_rows "$fingerprint_directory" '%y\t%P\t%s\t%T@\n')
    fingerprint_expected=$(counted_node_total "$fingerprint_directory")
    fingerprint_emitted=$(printf '%s' "$fingerprint_rows" | grep -c '' || true)
    [ -n "$fingerprint_rows" ] || fingerprint_emitted=0
    if [ "$fingerprint_emitted" != "$fingerprint_expected" ]; then
        printf 'unrepresentable-path\n'
        return 0
    fi
    printf '%s\n' "$fingerprint_rows" | sha256sum | cut -d ' ' -f 1
}

# The content manifest: every node by type, regular files by digest. Nothing
# outside a regular file is opened.
payload_manifest_of() {
    manifest_directory=$1
    manifest_special=$(node_rows "$manifest_directory" '%y\t%P\t-\n' | grep -v "^f$tab" || true)
    # The digest pass runs inside the acquisition, so `sha256sum` resolves the
    # relative paths `find` emitted rather than the caller's own directory.
    manifest_regular=$( cd -- "$manifest_directory" && \
        find . -mindepth 1 -name "$control_directory_name" -prune -o \
            -type f -print0 | xargs -0 -r sha256sum -- | \
        awk -F'  ' '{ digest = $1; path = substr($0, index($0, "  ") + 2); sub(/^\.\//, "", path); printf "f\t%s\t%s\n", path, digest }' | \
        LC_ALL=C sort)
    manifest_rows=$(printf '%s\n%s\n' "$manifest_special" "$manifest_regular" | grep -v '^$' | LC_ALL=C sort || true)
    manifest_expected=$(counted_node_total "$manifest_directory")
    manifest_emitted=$(printf '%s' "$manifest_rows" | grep -c '' || true)
    [ -n "$manifest_rows" ] || manifest_emitted=0
    if [ "$manifest_emitted" != "$manifest_expected" ]; then
        printf 'unrepresentable-path\n'
        return 0
    fi
    printf '%s\n' "$manifest_rows" | sha256sum | cut -d ' ' -f 1
}

# One value out of a two-column record, refusing a repeated key rather than
# taking the first or the last: two rows naming one key are two claims and
# the record states which is authoritative nowhere.
record_value() {
    record_path=$1
    record_key=$2
    record_hits=$(awk -F'\t' -v key="$record_key" '$1 == key { print NR }' "$record_path" | wc -l | tr -d ' ')
    if [ "$record_hits" -gt 1 ]; then
        printf 'duplicate-key\n'
        return 0
    fi
    awk -F'\t' -v key="$record_key" '$1 == key { print $2 }' "$record_path"
}

decision_keys='acquisition_id metadata_fingerprint payload_manifest decision reason retained_destination retained_digest authorization'
authorization_keys='acquisition_id payload_manifest action plan_sha256 authorized_by authorized_at'

# A record is read as a whole: an unknown key means the writer stated
# something this reader ignores, which is the shape a permissive parser turns
# into a silent grant.
record_keys_closed() {
    closed_record=$1
    closed_keys=$2
    # shellcheck disable=SC2034  # the value field splits the key off the row
    while IFS="$tab" read -r closed_key closed_value; do
        [ -n "$closed_key" ] || continue
        case $closed_key in \#*) continue ;; esac
        case " $closed_keys " in
            *" $closed_key "*) ;;
            *) return 1 ;;
        esac
    done <"$closed_record"
    return 0
}

# `flock` is advisory: a free lock proves that no cooperating writer holds
# this leaf, and it proves nothing about a writer that never took it. An
# absent leaf is therefore `unmanaged` rather than `idle`, which is what every
# acquisition predating the protocol reads as, and both refuse a disposal.
producer_lock_state() {
    lock_path=$1/$control_directory_name/$producer_lock_name
    if [ ! -e "$lock_path" ] && [ ! -L "$lock_path" ]; then
        printf 'unmanaged\n'
        return 0
    fi
    if ! "$lock_helper" open "$lock_path" 7 true >/dev/null 2>&1; then
        printf 'malformed\n'
        return 0
    fi
    if "$lock_helper" open "$lock_path" 7 sh -c 'flock -n -x 7' >/dev/null 2>&1; then
        printf 'free\n'
    else
        printf 'held\n'
    fi
}

# One object's verdict. `class` selects which decisions are admissible: an
# acquisition is disposed of on evidence grounds and a deployment is retired
# on operational grounds, and both refuse by default.
object_verdict() {
    verdict_directory=$1
    verdict_class=$2
    verdict_action=$3
    verdict_plan=$4

    if [ -L "$verdict_directory" ]; then
        printf 'refuse\tsymlinked-object\n'
        return 0
    fi
    if [ ! -d "$verdict_directory" ]; then
        printf 'refuse\tunknown-node-type\n'
        return 0
    fi

    verdict_control=$verdict_directory/$control_directory_name
    if [ -L "$verdict_control" ]; then
        printf 'refuse\tsymlinked-control\n'
        return 0
    fi
    if [ ! -d "$verdict_control" ]; then
        printf 'refuse\tunreviewed\n'
        return 0
    fi

    # A control directory below the object root is a second declaration over
    # bytes this object's own manifest already covers, and the two cannot
    # both be authoritative. The plan enumerates one object per child of a
    # selected layout directory, so a deeper declaration is a conflict rather
    # than a nested object with a decision of its own.
    verdict_nested=$(find "$verdict_directory" -mindepth 2 -type d \
        -name "$control_directory_name" -print 2>/dev/null | head -n 1)
    if [ -n "$verdict_nested" ]; then
        printf 'refuse\tnested-declaration\n'
        return 0
    fi

    verdict_record=$verdict_control/$decision_record_name
    if [ ! -f "$verdict_record" ] || [ ! -r "$verdict_record" ]; then
        printf 'refuse\tunreviewed\n'
        return 0
    fi
    if ! record_keys_closed "$verdict_record" "$decision_keys"; then
        printf 'refuse\tmalformed-decision\n'
        return 0
    fi
    for verdict_key in $decision_keys; do
        verdict_value=$(record_value "$verdict_record" "$verdict_key")
        if [ "$verdict_value" = duplicate-key ] || [ -z "$verdict_value" ]; then
            printf 'refuse\tmalformed-decision\n'
            return 0
        fi
    done

    verdict_identity=$(record_value "$verdict_record" acquisition_id)
    if [ "$verdict_identity" != "${verdict_directory##*/}" ]; then
        printf 'refuse\tidentity-mismatch\n'
        return 0
    fi

    verdict_lock=$(producer_lock_state "$verdict_directory")
    case $verdict_lock in
        held) printf 'refuse\tproducer-active\n'; return 0 ;;
        malformed) printf 'refuse\tmalformed-lock\n'; return 0 ;;
        unmanaged) printf 'refuse\tunmanaged-activity\n'; return 0 ;;
    esac

    verdict_fingerprint=$(fingerprint_of "$verdict_directory")
    if [ "$verdict_fingerprint" = unrepresentable-path ]; then
        printf 'refuse\tunrepresentable-path\n'
        return 0
    fi
    if [ "$verdict_fingerprint" != "$(record_value "$verdict_record" metadata_fingerprint)" ]; then
        printf 'refuse\tchanged-since-review\n'
        return 0
    fi

    verdict_decision=$(record_value "$verdict_record" decision)
    case $verdict_decision in
        hold) printf 'refuse\theld\n'; return 0 ;;
        retain) printf 'refuse\tretained\n'; return 0 ;;
        dispose) ;;
        *) printf 'refuse\tmalformed-decision\n'; return 0 ;;
    esac

    verdict_reason=$(record_value "$verdict_record" reason)
    case $verdict_class:$verdict_reason in
        acquisition:verified-copy-retained)
            # Permitting this disposal asserts that another copy is
            # recoverable and outside this same plan. Verifying that
            # destination is the act evidence disposition owns, and a
            # duplicate-based removal against an unverified destination is
            # the intentional discard it was not declared to be.
            printf 'refuse\tdestination-unverified\n'
            return 0
            ;;
        acquisition:intentional-discard) ;;
        deployment:retired-and-replaced) ;;
        *) printf 'refuse\tmalformed-decision\n'; return 0 ;;
    esac

    verdict_manifest_claim=$(record_value "$verdict_record" payload_manifest)
    case $verdict_manifest_claim in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) ;;
        *) printf 'refuse\tpayload-manifest-absent\n'; return 0 ;;
    esac
    verdict_manifest=$(payload_manifest_of "$verdict_directory")
    if [ "$verdict_manifest" = unrepresentable-path ]; then
        printf 'refuse\tunrepresentable-path\n'
        return 0
    fi
    if [ "$verdict_manifest" != "$verdict_manifest_claim" ]; then
        printf 'refuse\tpayload-changed\n'
        return 0
    fi

    verdict_authorization=$verdict_control/$authorization_record_name
    if [ "$(record_value "$verdict_record" authorization)" != "$authorization_record_name" ]; then
        printf 'refuse\tauthorization-unnamed\n'
        return 0
    fi
    if [ ! -f "$verdict_authorization" ] || [ ! -r "$verdict_authorization" ]; then
        printf 'refuse\tauthorization-absent\n'
        return 0
    fi
    if ! record_keys_closed "$verdict_authorization" "$authorization_keys"; then
        printf 'refuse\tmalformed-authorization\n'
        return 0
    fi
    for verdict_key in $authorization_keys; do
        verdict_value=$(record_value "$verdict_authorization" "$verdict_key")
        if [ "$verdict_value" = duplicate-key ] || [ -z "$verdict_value" ]; then
            printf 'refuse\tmalformed-authorization\n'
            return 0
        fi
    done
    # The authorization names one acquisition, one payload, one action, and
    # one plan. An arbitrary nonempty string authorizes nothing: a record
    # carried to a second acquisition, reused after the payload moved, or
    # replayed against a different removal fails one of the four.
    [ "$(record_value "$verdict_authorization" acquisition_id)" = "$verdict_identity" ] || {
        printf 'refuse\tauthorization-mismatch\n'; return 0; }
    [ "$(record_value "$verdict_authorization" payload_manifest)" = "$verdict_manifest" ] || {
        printf 'refuse\tauthorization-stale\n'; return 0; }
    [ "$(record_value "$verdict_authorization" action)" = "$verdict_action" ] || {
        printf 'refuse\tauthorization-mismatch\n'; return 0; }
    [ "$(record_value "$verdict_authorization" plan_sha256)" = "$verdict_plan" ] || {
        printf 'refuse\tauthorization-stale\n'; return 0; }

    printf 'admit\t%s\n' "$verdict_reason"
}

# The selection each action would remove, one row per object, as
# `class<TAB>path`. `uninstall` keeps state and models and `purge` keeps
# nothing, so the two actions select two sets and the plan identity differs
# between them for the same root.
#
# A layout directory holding protected objects expands into its children:
# `results` and `deployments` always, and `models` under purge, where the
# registry proves a pinned digest for the rows it names and proves nothing
# about a derived artifact or a synthetic corpus beside them.
# The root-level entries an action selects. The plan expands them into objects
# and the removal reads the root-level rows back out of the plan report, so
# the classification and the removal share one enumeration rather than taking
# two readings of the root at two times.
root_entries_of() {
    entries_action=$1
    for root_entry in "$qwen_home"/* "$qwen_home"/.[!.]*; do
        [ -e "$root_entry" ] || [ -L "$root_entry" ] || continue
        root_entry_name=${root_entry##*/}
        case $root_entry_name in
            .gitkeep) continue ;;
            state | models)
                [ "$entries_action" = purge ] || continue
                ;;
        esac
        printf '%s\n' "$root_entry"
    done | LC_ALL=C sort
}

plan_rows() {
    plan_action=$1
    root_entries_of "$plan_action" | while IFS= read -r plan_entry; do
        plan_name=${plan_entry##*/}
        # The root's own control objects stay out of the selection. The
        # removal creates its exclusion leaf before it classifies anything, so
        # a plan counting that leaf would answer one identity to the operator
        # reading it and another to the removal holding it, and every
        # authorization written against the first would refuse as stale.
        case " $root_control_names " in
            *" $plan_name "*) continue ;;
        esac
        case $plan_name in
            manifest.tsv | .qwen-runtime-root)
                printf 'declared\t%s\n' "$plan_entry"
                ;;
            results | models)
                plan_expand "$plan_entry" acquisition
                ;;
            deployments)
                plan_expand "$plan_entry" deployment
                ;;
            state)
                printf 'transient-state\t%s\n' "$plan_entry"
                ;;
            bin | opt | cache | tmp)
                printf 'reconstructible\t%s\n' "$plan_entry"
                ;;
            *)
                printf 'unknown\t%s\n' "$plan_entry"
                ;;
        esac
    done
}

# Every child of a protected layout directory is one object of that class,
# enumerated from the directory rather than from the presence of a control
# record. An object carrying no declaration is the case this preflight
# exists for, so it must appear in the plan to be refused.
plan_expand() {
    expand_directory=$1
    expand_class=$2
    printf 'container\t%s\n' "$expand_directory"
    for expand_entry in "$expand_directory"/* "$expand_directory"/.[!.]*; do
        [ -e "$expand_entry" ] || [ -L "$expand_entry" ] || continue
        expand_name=${expand_entry##*/}
        case $expand_name in .gitkeep) continue ;; esac
        if [ -L "$expand_entry" ]; then
            printf 'link\t%s\n' "$expand_entry"
            continue
        fi
        printf '%s\t%s\n' "$expand_class" "$expand_entry"
    done
}

# A deployment reachable from a role link is refused for a stronger reason
# than an unreferenced one, and the unreferenced one is refused all the same.
# Reachability states which bundle serves now and which rolls back; it states
# nothing about whether a bundle nobody references is the only copy of the
# server it carries.
deployment_role_of() {
    role_path=$1
    for role in current previous; do
        role_target=$(readlink -f "$qwen_home_deployments/deployment-$role" 2>/dev/null || true)
        [ -n "$role_target" ] || continue
        [ "$role_target" = "$(readlink -f "$role_path")" ] || continue
        printf '%s\n' "$role"
        return 0
    done
    # `printf '-\n'` reads its first argument as an option, so the value goes
    # through a format that takes it as data.
    printf '%s\n' -
}

[ "$#" -ge 1 ] || usage
action=$1
shift

case $action in
    fingerprint)
        [ "$#" -eq 1 ] || usage
        [ -d "$1" ] || fail "not a directory: $1"
        fingerprint_of "$1"
        ;;
    payload-manifest)
        [ "$#" -eq 1 ] || usage
        [ -d "$1" ] || fail "not a directory: $1"
        payload_manifest_of "$1"
        ;;
    verdict)
        [ "$#" -eq 4 ] || usage
        object_verdict "$1" "$2" "$3" "$4"
        ;;
    plan)
        [ "$#" -eq 1 ] || usage
        plan_action=$1
        case $plan_action in uninstall | purge) ;; *) usage ;; esac
        qwen_home_require_binding || exit 2
        [ -d "$qwen_home" ] || fail "runtime root absent: $qwen_home"

        plan_selection=$(plan_rows "$plan_action" | LC_ALL=C sort)
        # The plan identity is the digest of the selected set alone, so it
        # moves when the selection moves and holds still while a decision or
        # an authorization is written inside an excluded control directory.
        # An authorization can therefore name the plan it was written for.
        plan_identity=$(printf '%s\n' "$plan_selection" | sha256sum | cut -d ' ' -f 1)
        printf 'plan_action=%s plan_root=%s plan_sha256=%s\n' \
            "$plan_action" "$qwen_home" "$plan_identity"

        plan_report=$(mktemp "${TMPDIR:-/tmp}/deletion-plan.XXXXXX")
        trap 'rm -f "$plan_report"' EXIT HUP INT TERM
        printf 'class\tverdict\treason\tpath\n'
        printf '%s\n' "$plan_selection" | while IFS="$tab" read -r plan_class plan_path; do
            [ -n "$plan_class" ] || continue
            case $plan_class in
                acquisition | deployment)
                    plan_verdict=$(object_verdict "$plan_path" "$plan_class" \
                        "$plan_action" "$plan_identity")
                    plan_detail=${plan_verdict#*"$tab"}
                    plan_state=${plan_verdict%%"$tab"*}
                    if [ "$plan_class" = deployment ]; then
                        plan_role=$(deployment_role_of "$plan_path")
                        case $plan_role in
                            current | previous)
                                plan_state=refuse
                                plan_detail=serving-role-$plan_role
                                ;;
                        esac
                    fi
                    printf '%s\t%s\t%s\t%s\n' "$plan_class" "$plan_state" \
                        "$plan_detail" "$plan_path"
                    ;;
                unknown)
                    printf '%s\trefuse\tunclassified-entry\t%s\n' "$plan_class" "$plan_path"
                    ;;
                *)
                    printf '%s\tadmit\t-\t%s\n' "$plan_class" "$plan_path"
                    ;;
            esac
        done >"$plan_report"
        cat "$plan_report"
        plan_refusals=$(awk -F'\t' '$2 == "refuse"' "$plan_report" | wc -l | tr -d ' ')
        plan_objects=$(awk -F'\t' '$1 == "acquisition" || $1 == "deployment"' \
            "$plan_report" | wc -l | tr -d ' ')
        if [ "$plan_refusals" -ne 0 ]; then
            printf 'deletion_plan=refused protected_objects=%s refusals=%s plan_sha256=%s\n' \
                "$plan_objects" "$plan_refusals" "$plan_identity"
            printf '%s selects %s object(s) it cannot prove disposable; nothing was removed\n' \
                "$plan_action" "$plan_refusals" >&2
            exit 1
        fi
        printf 'deletion_plan=admitted protected_objects=%s refusals=0 plan_sha256=%s\n' \
            "$plan_objects" "$plan_identity"
        ;;
    *) usage ;;
esac
