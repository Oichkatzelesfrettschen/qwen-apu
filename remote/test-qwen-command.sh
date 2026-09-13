#!/bin/sh
# The operator's command: which argv it builds, and what it refuses.
#
# The claim under test is that `qwen VERB` reaches `qwen-apu appliance VERB`
# through the environment under the runtime root rather than through any path
# this file carries, so the interpreter is recorded by a stand-in and compared
# against the argv the appliance expects. The second claim is the refusal: a root
# whose environment holds no interpreter names PYTHON and the command that builds
# one, because an interpreter that cannot import the package fails one call later
# with a worse message.
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
command_under_test=$script_directory/qwen
tree_root=$(CDPATH='' cd -- "$script_directory/.." && pwd -P)
work_directory=$(mktemp -d)
trap 'rm -rf -- "$work_directory"' EXIT HUP INT TERM
failures=0
report() {
    if [ "$2" = ok ]; then
        printf 'ok %s\n' "$1"
    else
        printf 'FAIL %s: %s\n' "$1" "$2"
        failures=$((failures + 1))
    fi
}

# ---- the argv the appliance receives, recorded by a stand-in interpreter ----
recording_home=$work_directory/recording
mkdir -p "$recording_home/venv/bin"
argv_record=$work_directory/argv.txt
cat >"$recording_home/venv/bin/python" <<RECORDER
#!/bin/sh
printf '%s\n' "\$*" >"$argv_record"
RECORDER
chmod 755 "$recording_home/venv/bin/python"

QWEN_HOME=$recording_home "$command_under_test" up --local
recorded=$(cat "$argv_record")
[ "$recorded" = "-m qwen_apu appliance up --local" ] &&
    report verb_reaches_the_appliance ok || report verb_reaches_the_appliance "$recorded"

QWEN_HOME=$recording_home "$command_under_test" down
recorded=$(cat "$argv_record")
[ "$recorded" = "-m qwen_apu appliance down" ] &&
    report down_reaches_the_appliance ok || report down_reaches_the_appliance "$recorded"

# ---- the checkout travels to the child, so the package resolves one tree ----
cat >"$recording_home/venv/bin/python" <<RECORDER
#!/bin/sh
printf '%s\n' "\$QWEN_TREE_ROOT" >"$argv_record"
RECORDER
chmod 755 "$recording_home/venv/bin/python"
QWEN_HOME=$recording_home "$command_under_test" status
recorded=$(cat "$argv_record")
[ "$recorded" = "$tree_root" ] && report tree_root_reaches_the_child ok ||
    report tree_root_reaches_the_child "$recorded"

# ---- an environment with no interpreter refuses and names PYTHON ----
empty_home=$work_directory/empty
mkdir -p "$empty_home"
refusal_output=$work_directory/refusal.txt
if QWEN_HOME=$empty_home PYTHON=/stand-in/python3 "$command_under_test" up \
    >/dev/null 2>"$refusal_output"; then
    report absent_environment_refused accepted
else
    if grep -q '/stand-in/python3 bootstrap.py' "$refusal_output"; then
        report absent_environment_refused ok
    else
        report absent_environment_refused "$(cat "$refusal_output")"
    fi
fi

# ---- the verb set is closed, and the usage block is the refusal ----
if QWEN_HOME=$recording_home "$command_under_test" sideways >/dev/null 2>&1; then
    report unknown_verb_refused accepted
else
    status=$?
    [ "$status" = 2 ] && report unknown_verb_refused ok || report unknown_verb_refused "$status"
fi
if QWEN_HOME=$recording_home "$command_under_test" >/dev/null 2>&1; then
    report no_argument_refused accepted
else
    status=$?
    [ "$status" = 2 ] && report no_argument_refused ok || report no_argument_refused "$status"
fi
if QWEN_HOME=$recording_home "$command_under_test" --help >/dev/null 2>&1; then
    report help_is_not_an_error ok
else
    report help_is_not_an_error "$?"
fi

# ---- this file names no interpreter of its own ----
if grep -nE '^[^#]*(/usr/bin/python|python3\.[0-9]+|venv/bin/qwen)' "$command_under_test" >/dev/null; then
    report no_installed_interpreter_named "$(grep -nE '^[^#]*(/usr/bin/python|python3\.[0-9]+)' "$command_under_test")"
else
    report no_installed_interpreter_named ok
fi

[ "$failures" = 0 ] || exit 1
printf 'qwen_command=accepted\n'
