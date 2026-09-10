# shellcheck shell=sh
# Content identity for one quality-gate cell, sourced by the gate and by its
# own test.
#
# A cell is one gate invocation: a lint walk, a syntax walk, or a test script.
# Its key is the SHA-256 of a manifest carrying the cell name, the command line
# the gate would run, the identity of every tool the gate can invoke, the
# identity of the driver script and this reader, the read-set state
# (`bounded`, `unbounded`, or `universal`), and the SHA-256 of every file the
# cell reads, so a cell whose key names an accepted record has already run
# over exactly these bytes and is reported and skipped.
#
# The read set is derived statically from the text of the scripts a cell names,
# which bounds it from above rather than exactly. Every ambiguity resolves
# toward running the cell: a false reuse is a hole in the gate and a false run
# costs seconds. A token naming a directory is walked whole while that directory
# holds at most gate_cell_directory_walk_limit files, which covers a retained
# replay corpus and a fixture directory a test reads entry by entry; a larger
# directory marks the cell unbounded instead, since a bare `evidence/` token
# would otherwise hash 43 MiB of retained measurement once per cell. A path a
# script names and the tree lacks enters the manifest as `absent`, so the key
# moves when that file appears.
#
# A bare Python `import NAME` or `from NAME import ...` and a literal
# `NAME.py`/`NAME.sh`/`NAME.mjs` token both name code the file may load at
# run time, and several servers in this tree reach a sibling directory through
# `sys.path.insert` rather than their own: image-mcp/server.py loads
# image_protocol.py from remote/ and image_grant.py from remote/web-mcp/, and
# a test that spawns a script by path names it as a string literal the way
# image-mcp/test-image-mcp.py names remote/web-mcp/authorize-broker.py. A code
# token is therefore resolved against the reading file's own directory and
# against every directory gate_cell_module_search_directories reports, and
# every directory that resolves it enters the read set, so an ambiguous name
# is read wherever it could load from rather than guessed once. A data or
# prose token (.tsv, .json, .ini, .md, .txt, .patch, .html, .png) resolves
# beside the reading file alone, since this tree's own text documents unrelated
# evidence paths in prose and a directory-wide search over those extensions
# would pull a README's citations into every cell that names it.
#
# Every cell's key also carries the identity of the driver that invokes
# gate_cell and of this reader itself. A bounded cell whose command lives in a
# separate file can reuse an older accepted record across a driver or reader
# edit only when the current reader reconstructs the old key from the current
# command, tools, mode, read-set class, and input hashes. A match proves that
# the driver digest is the only manifest field that moved. A cell that executes
# a function defined by the driver requests `exact-driver` scope instead, so an
# edit to gate_shell_syntax or another driver-owned function reruns that cell.
#
# GATE_CELL_ROOT is the tree paths resolve against and defaults to the
# repository root, which is what lets the test drive the derivation over a
# fixture tree. GATE_CELL_DRIVER_PATH is the driver's own absolute path,
# resolved the way script_directory already is -- before any `cd` the driver
# makes -- because $0 read fresh inside gate_cell_init would resolve against
# whatever directory the driver has since changed into rather than the one it
# started in.

gate_cell_root=${GATE_CELL_ROOT:-}
gate_cell_driver_path=${GATE_CELL_DRIVER_PATH:-}
# The cache root follows the runtime root. A driver that sourced qwen-home.sh
# already holds the value; a fixture driver that did not resolves it through
# the command form beside itself.
if [ -z "${qwen_home_gate_cache:-}" ]; then
    for gate_cell_resolver_directory in "${script_directory:-}" "${gate_cell_driver_path%/*}"; do
        [ -n "$gate_cell_resolver_directory" ] || continue
        [ -x "$gate_cell_resolver_directory/qwen-home.sh" ] || continue
        qwen_home_gate_cache=$("$gate_cell_resolver_directory/qwen-home.sh" print qwen_home_gate_cache)
        break
    done
fi
gate_cell_cache_directory=${QWEN_GATE_CACHE_DIR:-${qwen_home_gate_cache:-}}
gate_cell_sparse=${QWEN_GATE_SPARSE:-1}
gate_cell_directory_walk_limit=${QWEN_GATE_DIRECTORY_WALK_LIMIT:-64}
gate_cell_tool_digest=''
gate_cell_driver_digest=''
gate_cell_key_stream=''
gate_cell_record_index=''
gate_cell_run_count=0
gate_cell_reused_count=0

# Where a gate run spends its time, read from the boundaries the run already
# crosses rather than from a sampler beside it. Two phases are separable here:
# deriving a cell's read set and hashing it into a key, and executing the cell's
# own command. An accepted record carries the execution it measured, so a later
# reuse reports the cost it avoided instead of leaving that unquantified.
#
# `date +%s%N` reads CLOCK_REALTIME, so a backward step during a run would
# produce a negative interval; a negative interval is recorded as `-` rather
# than as a number, and no run is expected to span a step. Each boundary is one
# fork of about two milliseconds, which is stated here because the key phase it
# brackets is itself milliseconds: the phase separates hashing from execution
# at that resolution rather than resolving hashing to the microsecond.
gate_cell_timing=${QWEN_GATE_TIMING:-1}
gate_cell_key_ns_total=0
gate_cell_run_ns_total=0
gate_cell_avoided_ns_total=0
gate_cell_now_ns() {
    if [ "$gate_cell_timing" = 1 ]; then
        date +%s%N
    else
        printf '0\n'
    fi
}
# A negative or unreadable interval states nothing, so it is reported as `-`
# rather than folded into a total that would then be wrong by that much.
gate_cell_interval_ns() {
    if [ "$gate_cell_timing" != 1 ] || [ -z "$1" ] || [ -z "$2" ]; then
        printf -- '-\n'
        return 0
    fi
    gate_cell_interval=$(( $2 - $1 ))
    if [ "$gate_cell_interval" -lt 0 ]; then
        printf -- '-\n'
        return 0
    fi
    printf '%s\n' "$gate_cell_interval"
}
gate_cell_add_ns() {
    case $2 in
        '' | -) printf '%s\n' "$1" ;;
        *) printf '%s\n' "$(( $1 + $2 ))" ;;
    esac
}

# The browser a cell drives, resolved the way repository-quality-gates.sh
# resolves it, so the key names the executable the run would use rather than the
# literal command string.
gate_cell_chromium=${QWEN_CHROMIUM:-chromium}

# One line per tool: its name, the path the run resolves it to, and the first
# line of its version report. A tool the run cannot resolve reads absent, which
# keeps the key moving when it appears.
gate_cell_tool_report() {
    gate_cell_tool_name=${2:-$1}
    gate_cell_tool_path=$(command -v "$1" 2>/dev/null || true)
    if [ -z "$gate_cell_tool_path" ]; then
        printf '%s\tabsent\tabsent\n' "$gate_cell_tool_name"
        return 0
    fi
    printf '%s\t%s\t%s\n' "$gate_cell_tool_name" "$gate_cell_tool_path" \
        "$("$gate_cell_tool_path" --version 2>&1 | head -n 1 || true)"
}

# Every executable whose output decides a cell's verdict independently of the
# repository bytes, which is the command set repository-quality-gates.sh
# requires before it runs a cell. A new shellcheck, ruff, mypy, node, browser,
# shell, or compiler grades the same file differently, so each identity enters
# every key and every record. `sh` is tracked beside `bash` because the gate
# runs most cells by executing a `#!/bin/sh` script directly or by naming
# `sh script` in its command, so whatever `sh` resolves to on this host --
# dash on a Debian-family appliance, bash itself here -- decides the
# interpretation the gate reused as much as bash decides gate_shell_syntax's
# own bash branch.
gate_cell_tool_versions() {
    for gate_cell_tool in shellcheck ruff python3 cc c++ bash sh node mypy \
        git curl flock ps sha256sum; do
        gate_cell_tool_report "$gate_cell_tool"
    done
    gate_cell_tool_report "$gate_cell_chromium" chromium
}

# The SHA-256 of one path plus its mode bits, or `absent absent` for a path the
# tree lacks. Unlike gate_cell_hash_line this takes a path as given -- absolute
# or relative to the caller's own working directory -- rather than one resolved
# against gate_cell_root, because the driver and reader identities below are
# named by $0 and by this file's own location beside it, not by a token a cell
# spec names.
gate_cell_identity_line() {
    if [ -f "$1" ]; then
        printf '%s %s %s\n' "$(sha256sum "$1" | cut -d' ' -f1)" \
            "$(stat -c '%a' "$1")" "$2"
    else
        printf 'absent absent %s\n' "$2"
    fi
}

gate_cell_init() {
    if [ -z "$gate_cell_root" ]; then
        printf 'gate_cell_root is unset\n' >&2
        return 2
    fi
    if [ -z "$gate_cell_cache_directory" ]; then
        printf 'gate cache root is unresolved: source qwen-home.sh ahead of gate-cell-key.sh or export GATE_CELL_DRIVER_PATH beside it\n' >&2
        return 2
    fi
    if [ -z "$gate_cell_driver_path" ]; then
        printf 'gate_cell_driver_path is unset\n' >&2
        return 2
    fi
    # A wrong GATE_CELL_DRIVER_PATH would otherwise key every cell on
    # `absent` silently and still reuse from run to run, which defeats the
    # binding through a typo rather than through an edit. Both the driver and
    # the reader beside it are required to exist before any cell runs.
    if [ ! -f "$gate_cell_driver_path" ]; then
        printf 'gate_cell_driver_path names no file: %s\n' \
            "$gate_cell_driver_path" >&2
        return 2
    fi
    gate_cell_reader_path=$(dirname -- "$gate_cell_driver_path")/gate-cell-key.sh
    if [ ! -f "$gate_cell_reader_path" ]; then
        printf 'gate-cell-key.sh is absent beside the driver: %s\n' \
            "$gate_cell_reader_path" >&2
        return 2
    fi
    gate_cell_tool_digest=$(gate_cell_tool_versions | sha256sum | cut -d' ' -f1)
    # This reader always sits beside its driver -- both live in remote/ for
    # the gate and both live under the fixture root's own remote/ for the
    # test -- so the driver's own directory is where the reader's copy is read
    # back from.
    gate_cell_driver_digest=$(
        {
            gate_cell_identity_line "$gate_cell_driver_path" driver
            gate_cell_identity_line "$gate_cell_reader_path" reader
        } | sha256sum | cut -d' ' -f1
    )
    gate_cell_key_stream=$(mktemp)
    gate_cell_record_index=$(mktemp)
    gate_cell_run_count=0
    gate_cell_reused_count=0
    mkdir -p "$gate_cell_cache_directory/cells"
    for indexed_record in "$gate_cell_cache_directory"/cells/*; do
        [ -f "$indexed_record" ] || continue
        indexed_name=$(gate_cell_record_field "$indexed_record" name || true)
        [ -n "$indexed_name" ] || continue
        case $indexed_name in
            *[!A-Za-z0-9_.-]*) continue ;;
        esac
        printf '%s\t%s\n' "$indexed_name" "$indexed_record" \
            >>"$gate_cell_record_index"
    done
}

gate_cell_cleanup() {
    if [ -n "$gate_cell_key_stream" ]; then
        rm -f "$gate_cell_key_stream"
    fi
    if [ -n "$gate_cell_record_index" ]; then
        rm -f "$gate_cell_record_index"
    fi
}

# Read one unique field from an accepted-record candidate. A malformed or
# duplicated field prints nothing, which makes the candidate ineligible for
# reuse rather than asking callers to distinguish malformed from absent.
gate_cell_record_field() {
    record_field_count=$(awk -F= -v field="$2" '$1 == field { count++ } END { print count + 0 }' "$1")
    [ "$record_field_count" -eq 1 ] || return 1
    awk -F= -v field="$2" '$1 == field { sub(/^[^=]*=/, ""); print; exit }' "$1"
}

gate_cell_is_sha256() {
    [ "${#1}" -eq 64 ] || return 1
    case $1 in
        *[!0-9a-f]*) return 1 ;;
    esac
    return 0
}

# Require every record field that binds the reuse decision. The filename and
# recorded key must agree, so a truncated copy or a record moved under another
# key cannot stand in for an accepted cell.
gate_cell_record_is_accepted() {
    accepted_record=$1
    accepted_key=$2
    accepted_name=$3
    accepted_driver=$4
    accepted_read_set=$5
    [ -f "$accepted_record" ] || return 1
    [ "$(basename -- "$accepted_record")" = "$accepted_key" ] || return 1
    [ "$(gate_cell_record_field "$accepted_record" status || true)" = accepted ] || return 1
    [ "$(gate_cell_record_field "$accepted_record" name || true)" = "$accepted_name" ] || return 1
    [ "$(gate_cell_record_field "$accepted_record" key || true)" = "$accepted_key" ] || return 1
    [ "$(gate_cell_record_field "$accepted_record" tools || true)" = "$gate_cell_tool_digest" ] || return 1
    [ "$(gate_cell_record_field "$accepted_record" driver || true)" = "$accepted_driver" ] || return 1
    [ "$(gate_cell_record_field "$accepted_record" read_set || true)" = "$accepted_read_set" ] || return 1
    accepted_run_ns=$(gate_cell_record_field "$accepted_record" run_ns || true)
    case $accepted_run_ns in
        '' | *[!0-9]*) return 1 ;;
    esac
    return 0
}

# Find an accepted record whose old key the current manifest reproduces after
# substituting only that record's driver digest. SHA-256 equality proves every
# other manifest field remains identical. Only caller-declared
# `driver-independent` cells use this path.
gate_cell_compatible_driver_record() {
    compatible_manifest=$1
    compatible_name=$2
    compatible_read_set=$3
    compatible_tab=$(printf '\t')
    while IFS="$compatible_tab" read -r indexed_name compatible_record; do
        [ "$indexed_name" = "$compatible_name" ] || continue
        [ -f "$compatible_record" ] || continue
        compatible_driver=$(gate_cell_record_field "$compatible_record" driver || true)
        gate_cell_is_sha256 "$compatible_driver" || continue
        [ "$compatible_driver" != "$gate_cell_driver_digest" ] || continue
        compatible_key=$(basename -- "$compatible_record")
        gate_cell_is_sha256 "$compatible_key" || continue
        reconstructed_key=$(
            sed "s/^driver=.*/driver=$compatible_driver/" "$compatible_manifest" |
                sha256sum | cut -d' ' -f1
        )
        [ "$reconstructed_key" = "$compatible_key" ] || continue
        if gate_cell_record_is_accepted "$compatible_record" "$compatible_key" \
            "$compatible_name" "$compatible_driver" "$compatible_read_set"; then
            printf '%s\n' "$compatible_record"
            return 0
        fi
    done <"$gate_cell_record_index"
    return 1
}

# One manifest line per path carrying its content digest and its mode bits,
# with `absent` standing for a named path the tree lacks so the key moves when
# the file appears. The gate runs several cells by invoking a script directly,
# where a cleared execute bit decides whether the command reaches an
# interpreter at all and a narrowed mode (0755 to 0700) never changes whether
# it runs there but is still part of what the tree states about the file, so
# the full permission bits move the key rather than a coarse exec/plain class.
gate_cell_hash_line() {
    if [ -f "$gate_cell_root/$1" ]; then
        printf '%s %s %s\n' \
            "$(sha256sum "$gate_cell_root/$1" | cut -d' ' -f1)" \
            "$(stat -c '%a' "$gate_cell_root/$1")" "$1"
    else
        printf 'absent absent %s\n' "$1"
    fi
}

# Only a text file is read for the paths it names. A PNG fixture or another
# binary member of a read set reaches grep as bytes, where a chance match makes
# GNU grep report the file rather than the match and puts an absolute path into
# the manifest, which is what would make one tree's key differ from a copy of
# it. A path with no extension at all is read as text where the tree marks it
# executable, since every extensionless member of this tree is a script that
# relies on its shebang rather than a suffix, and a non-executable extensionless
# path stays outside the text class the way a binary fixture does.
gate_cell_is_text_path() {
    case $1 in
        *.sh | *.py | *.mjs | *.js | *.tsv | *.json | *.ini | *.md | *.txt | \
            *.patch | *.html | *.css | *.c | *.h | *.cpp | *.conf | *.yml | \
            *.yaml) return 0 ;;
    esac
    case $(basename -- "$1") in
        *.*) return 1 ;;
    esac
    [ -x "$gate_cell_root/$1" ]
}

# A construction whose target this reader cannot name: a path composed from a
# variable, or an enumeration of the tree itself.
gate_cell_reads_are_unbounded() {
    for unbounded_pattern in \
        'git( -c [^ ]+)* ls-files' \
        '(remote|evidence|patches)/["'"'"']?\$' \
        '\$\{?script_directory\}?/["'"'"']?\$' \
        'find +("?\$repository_root|remote|evidence|patches)'; do
        if grep -qE "$unbounded_pattern" "$gate_cell_root/$1"; then
            return 0
        fi
    done
    return 1
}

# Extensions resolved across every module search directory, because the code
# they name may load from a directory other than the reading file's own: a
# Python import reached through sys.path.insert, or a script path another
# script names as a string literal to spawn or exec it.
gate_cell_code_extension_pattern='py|sh|mjs'

# Extensions resolved only beside the reading file. A .md, .tsv, .json, .ini,
# .txt, .patch, .html, or .png token in this tree's own prose commonly cites an
# unrelated evidence path for documentation, and searching every module
# directory for those extensions would pull each such citation into every cell
# whose spec reaches the citing file.
gate_cell_data_extension_pattern='tsv|json|ini|md|txt|patch|html|png'

# Every first-level directory under remote/ that holds at least one .py file,
# plus remote/ itself. web-mcp/, image-mcp/, and remote/ are the three
# directories this tree's servers and tests reach each other's modules from, and
# a directory added later joins the search the same way once it holds a module,
# so the set does not need a per-directory edit when one is added.
gate_cell_module_search_directories() {
    printf 'remote\n'
    find "$gate_cell_root/remote" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null |
        LC_ALL=C sort |
        while IFS= read -r module_search_candidate; do
            if find "$module_search_candidate" -maxdepth 1 -name '*.py' \
                -print -quit 2>/dev/null | grep -q .; then
                printf '%s\n' "${module_search_candidate#"$gate_cell_root"/}"
            fi
        done
}

# A bare filename a script names, resolved against the script's own directory
# and, for a code extension, against every module search directory too.
# `os.path.join(os.path.dirname(os.path.abspath(__file__)), "run-quality-suite.py")`
# is how every Python test in this tree reaches the module it exercises, and the
# joined name carries no repository prefix for the literal reader to match. A
# module reached by `import NAME` spells no filename at all, which is how
# authorize-broker.py reaches image_grant.py, so a bare import name resolves to
# a sibling NAME.py as well. A name that resolves to no file in any searched
# directory is a fixture the test writes under its own temporary directory.
gate_cell_sibling_paths() {
    sibling_directory=$(dirname "$1")
    sibling_search_directories=$(gate_cell_module_search_directories)
    {
        grep -oE "[A-Za-z0-9][A-Za-z0-9_.-]*[.]($gate_cell_code_extension_pattern)" \
            "$gate_cell_root/$1" || true
        grep -oE '^[[:space:]]*(import|from)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
            "$gate_cell_root/$1" | awk '{ printf "%s.py\n", $NF }' || true
    } | LC_ALL=C sort -u |
        while read -r sibling_name; do
            for candidate_directory in "$sibling_directory" \
                $sibling_search_directories; do
                if [ -f "$gate_cell_root/$candidate_directory/$sibling_name" ]; then
                    printf '%s/%s\n' "$candidate_directory" "$sibling_name"
                fi
            done
        done | LC_ALL=C sort -u
    grep -oE "[A-Za-z0-9][A-Za-z0-9_.-]*[.]($gate_cell_data_extension_pattern)" \
        "$gate_cell_root/$1" 2>/dev/null | LC_ALL=C sort -u |
        while read -r data_sibling_name; do
            if [ -f "$gate_cell_root/$sibling_directory/$data_sibling_name" ]; then
                printf '%s/%s\n' "$sibling_directory" "$data_sibling_name"
            fi
        done
}

# The literal remote/evidence/patches and $script_directory paths one file's
# text spells directly, ahead of what sibling and bare-name resolution add.
# Factored out because gate_cell_named_directories below needs the same
# tokens' directories, not only the paths themselves.
gate_cell_literal_named_path_tokens() {
    grep -oE '(remote|evidence|patches)/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*' \
        "$gate_cell_root/$1" || true
    grep -oE '\$\{?script_directory\}?/[A-Za-z0-9_.-]+' \
        "$gate_cell_root/$1" |
        sed 's|^\${*script_directory}*/|remote/|' || true
}

# Every repository path the text of one file names: a literal prefix under
# remote/, evidence/, or patches/, the $script_directory/NAME form that
# resolves to remote/NAME for every script in this tree, a sibling reached by
# filename or module name, and a bare extensionless name resolved to an
# executable file below. A trailing dot comes from prose rather than a
# filename and is trimmed. A parent traversal is dropped, since
# `$script_directory/..` is how every script in this tree resolves the
# repository root and reads nothing by itself; the files it then reaches
# appear as their own tokens or leave the cell unbounded.
gate_cell_named_paths() {
    {
        gate_cell_literal_named_path_tokens "$1"
        gate_cell_sibling_paths "$1"
        gate_cell_bare_name_paths "$1"
    } | sed 's/[.]*$//' |
        grep -vE '(^|/)[.][.](/|$)' |
        grep -vE '/$' |
        LC_ALL=C sort -u
}

# Every directory a bare extensionless token below resolves against: the
# reading file's own directory, every module search directory, the directory
# of every literal remote/evidence/patches or $script_directory path the same
# file's text already names, and one further hop through a bare token that is
# itself a directory rather than a leaf -- the "helpers" in a join of
# DELTA_DIRECTORY with that bare name -- resolved against the base set alone.
# A directory a script reaches only by composing two of its own DIRECTORY
# constants (HELPERS_DIRECTORY built from a join of the script's own directory
# with "helpers", holding no .py module of its own) would otherwise never
# enter this list, and a bare leaf named against HELPERS_DIRECTORY next to it
# would read unresolved on that account alone rather than on an actual
# missing file. The module search directories still cover the common case --
# a sibling directory that already holds a .py module -- without the second
# grep pass this hop adds; both stay, since one costs nothing the other
# already pays for.
gate_cell_named_directories() {
    named_directory_base=$(
        {
            dirname "$1"
            gate_cell_module_search_directories
            gate_cell_literal_named_path_tokens "$1" | sed 's/[.]*$//' |
                while read -r literal_named_path; do
                    dirname "$literal_named_path"
                done
        } | LC_ALL=C sort -u
    )
    {
        printf '%s\n' "$named_directory_base"
        gate_cell_bare_name_tokens "$1" |
            while read -r bare_directory_candidate; do
                [ -n "$bare_directory_candidate" ] || continue
                for named_directory_candidate in $named_directory_base; do
                    if [ -d "$gate_cell_root/$named_directory_candidate/$bare_directory_candidate" ]; then
                        printf '%s/%s\n' "$named_directory_candidate" \
                            "$bare_directory_candidate"
                    fi
                done
            done
    } | LC_ALL=C sort -u
}

# A file's text with every full-line comment removed -- a line whose first
# non-blank character is `#`, the shape every comment in this tree's own
# shell and Python takes. The two token readers below scan this rather than
# the raw file, since an unfiltered scan reads a worked example in a comment
# or docstring the same as a live construction: a line documenting
# `os.path.join(HELPERS_DIRECTORY, "missing-helper")` as prose would
# otherwise mark the cell unbounded on a reference nothing at run time ever
# names. A trailing `# comment` sharing a code line survives this filter,
# the same asymmetry `gate_cell_reads_are_unbounded` already carries against
# a mid-line construction.
gate_cell_strip_comment_lines() {
    grep -v '^[[:space:]]*#' "$gate_cell_root/$1" 2>/dev/null || true
}

# A bare, extensionless name a script composes with a directory it already
# holds rather than spelling as a literal repository path: the last argument
# of a Python call joining some first argument with further path components,
# with no `.` in the last argument, so joining HELPERS_DIRECTORY with the bare
# name `cross-helper` yields that bare name while joining it with
# `cross-helper.sh` stays with the code- and data-extension matches above.
# The first argument is unconstrained here, because widening this discovery
# scan costs at most a bounded set of extra stat(2) calls in
# gate_cell_bare_name_paths below, which silently skips a candidate that
# resolves to nothing rather than adding it or moving the cell to unbounded --
# over-inclusion at this stage cannot cause a false reuse.
gate_cell_bare_name_tokens() {
    gate_cell_strip_comment_lines "$1" |
        grep -oE 'os\.path\.join\([^()]*\)' |
        grep -oE "['\"][A-Za-z0-9_][A-Za-z0-9_-]*['\"][[:space:]]*\\)\$" |
        sed "s/^['\"]//; s/['\"][[:space:]]*)\$//" |
        LC_ALL=C sort -u
}

# The subset of gate_cell_bare_name_tokens whose call's own first argument
# follows this tree's naming convention for a directory a script resolves at
# run time -- HELPERS_DIRECTORY, SERVICE_DIRECTORY, BROKER_DIRECTORY,
# TEST_DIRECTORY, and every other ALL_CAPS name ending `DIRECTORY` this tree's
# scripts already assign from
# `os.path.dirname(os.path.abspath(__file__))` or a join of one such name.
# Only this subset can move a cell to unbounded, in
# gate_cell_bare_names_are_unresolved below: an os.path.join call in this tree
# whose first argument is a lowercase local or attribute -- state_directory,
# args.drm_device, self.workspace.name -- composes a state, fixture, or sysfs
# path rather than a helper reference, and treating an unresolved token there
# as unbounded would mark cells unrelated to any code reference unbounded on
# a sysfs leaf name or a fixture key that names no file at all. Prints
# `VARIABLE NAME` pairs rather than the bare name alone, since
# gate_cell_bare_names_are_unresolved judges each pair against the one
# directory VARIABLE itself resolves to rather than against every candidate
# directory in the file: an unrelated executable sharing NAME's spelling in
# some other directory must not stand in for a reference this reader cannot
# actually place.
gate_cell_bare_name_unbounded_tokens() {
    gate_cell_strip_comment_lines "$1" |
        grep -oE 'os\.path\.join\([A-Z][A-Z0-9_]*DIRECTORY[[:space:]]*,[^()]*\)' |
        while read -r bare_unbounded_call; do
            bare_unbounded_variable=$(printf '%s\n' "$bare_unbounded_call" |
                sed -E 's/^os\.path\.join\(([A-Z][A-Z0-9_]*DIRECTORY).*/\1/')
            bare_unbounded_name=$(printf '%s\n' "$bare_unbounded_call" |
                grep -oE "['\"][A-Za-z0-9_][A-Za-z0-9_-]*['\"][[:space:]]*\\)\$" |
                sed "s/^['\"]//; s/['\"][[:space:]]*)\$//")
            [ -n "$bare_unbounded_name" ] || continue
            printf '%s %s\n' "$bare_unbounded_variable" "$bare_unbounded_name"
        done | LC_ALL=C sort -u
}

# The single directory a DIRECTORY-suffixed Python constant resolves to,
# printed as one `NAME DIRECTORY` line per constant this reader can trace.
# `NAME = os.path.dirname(os.path.abspath(__file__))` resolves to the reading
# file's own directory, the assignment DELTA_DIRECTORY and ZETA_DIRECTORY both
# take in this tree's fixtures; `NAME = os.path.join(OTHER, "bare")` resolves
# to OTHER's own directory joined with that bare name, once OTHER is itself
# resolved and that joined path exists as a directory -- the chain
# HELPERS_DIRECTORY takes from DELTA_DIRECTORY; `NAME = os.path.dirname(OTHER)`
# resolves to the parent of OTHER's own directory, once OTHER is itself
# resolved -- the chain `remote/image-mcp/server.py` takes from its own
# SERVER_DIRECTORY up to REMOTE_DIRECTORY. Both indirect forms are applied
# across a bounded number of rounds so a multi-hop chain resolves regardless
# of the order its assignments appear in the file. A constant this reader
# cannot trace to exactly one directory this way -- reassigned, built from a
# fourth construction, or chained deeper than the round count -- is absent
# from the map, and gate_cell_bare_names_are_unresolved treats absence the
# same as an unresolved file: a reference this reader cannot place is a
# spawn target it cannot bound, not one it may bind to an unrelated
# same-named executable found by searching every candidate directory.
gate_cell_directory_variable_map() {
    directory_variable_map_file=$(mktemp)
    directory_variable_map_own_directory=$(dirname "$1")
    directory_variable_map_stripped=$(gate_cell_strip_comment_lines "$1")
    printf '%s\n' "$directory_variable_map_stripped" |
        grep -oE '^[A-Z][A-Z0-9_]*DIRECTORY[[:space:]]*=[[:space:]]*os\.path\.dirname\(os\.path\.abspath\(__file__\)\)' |
        sed -E 's/^([A-Z][A-Z0-9_]*DIRECTORY).*/\1/' |
        while read -r directory_variable_map_direct_name; do
            printf '%s %s\n' "$directory_variable_map_direct_name" \
                "$directory_variable_map_own_directory"
        done >"$directory_variable_map_file"
    directory_variable_map_round=0
    while [ "$directory_variable_map_round" -lt 4 ]; do
        printf '%s\n' "$directory_variable_map_stripped" |
            grep -oE '^[A-Z][A-Z0-9_]*DIRECTORY[[:space:]]*=[[:space:]]*os\.path\.join\([A-Z][A-Z0-9_]*DIRECTORY[[:space:]]*,[[:space:]]*["'"'"'][A-Za-z0-9_-]+["'"'"']\)' |
            while read -r directory_variable_map_join_assignment; do
                directory_variable_map_lhs=$(printf '%s\n' \
                    "$directory_variable_map_join_assignment" |
                    sed -E 's/^([A-Z][A-Z0-9_]*DIRECTORY).*/\1/')
                if grep -q "^$directory_variable_map_lhs " \
                    "$directory_variable_map_file" 2>/dev/null; then
                    continue
                fi
                directory_variable_map_rhs_variable=$(printf '%s\n' \
                    "$directory_variable_map_join_assignment" |
                    sed -E 's/.*os\.path\.join\(([A-Z][A-Z0-9_]*DIRECTORY).*/\1/')
                directory_variable_map_rhs_name=$(printf '%s\n' \
                    "$directory_variable_map_join_assignment" |
                    grep -oE "['\"][A-Za-z0-9_-]+['\"]\\)\$" |
                    sed "s/^['\"]//; s/['\"])\$//")
                directory_variable_map_rhs_directory=$(awk \
                    -v name="$directory_variable_map_rhs_variable" \
                    '$1 == name { print $2; exit }' \
                    "$directory_variable_map_file")
                if [ -n "$directory_variable_map_rhs_directory" ] &&
                    [ -d "$gate_cell_root/$directory_variable_map_rhs_directory/$directory_variable_map_rhs_name" ]; then
                    printf '%s %s/%s\n' "$directory_variable_map_lhs" \
                        "$directory_variable_map_rhs_directory" \
                        "$directory_variable_map_rhs_name" \
                        >>"$directory_variable_map_file"
                fi
            done
        printf '%s\n' "$directory_variable_map_stripped" |
            grep -oE '^[A-Z][A-Z0-9_]*DIRECTORY[[:space:]]*=[[:space:]]*os\.path\.dirname\([A-Z][A-Z0-9_]*DIRECTORY\)' |
            while read -r directory_variable_map_dirname_assignment; do
                directory_variable_map_lhs=$(printf '%s\n' \
                    "$directory_variable_map_dirname_assignment" |
                    sed -E 's/^([A-Z][A-Z0-9_]*DIRECTORY).*/\1/')
                if grep -q "^$directory_variable_map_lhs " \
                    "$directory_variable_map_file" 2>/dev/null; then
                    continue
                fi
                directory_variable_map_rhs_variable=$(printf '%s\n' \
                    "$directory_variable_map_dirname_assignment" |
                    sed -E 's/.*os\.path\.dirname\(([A-Z][A-Z0-9_]*DIRECTORY)\).*/\1/')
                directory_variable_map_rhs_directory=$(awk \
                    -v name="$directory_variable_map_rhs_variable" \
                    '$1 == name { print $2; exit }' \
                    "$directory_variable_map_file")
                if [ -n "$directory_variable_map_rhs_directory" ]; then
                    printf '%s %s\n' "$directory_variable_map_lhs" \
                        "$(dirname "$directory_variable_map_rhs_directory")" \
                        >>"$directory_variable_map_file"
                fi
            done
        directory_variable_map_round=$((directory_variable_map_round + 1))
    done
    LC_ALL=C sort -u "$directory_variable_map_file"
    rm -f "$directory_variable_map_file"
}

# Every gate_cell_bare_name_tokens candidate that resolves to an existing
# executable regular file, printed as `DIRECTORY/NAME` once per candidate
# directory gate_cell_named_directories reports that carries a match --
# every match rather than the first, the same way gate_cell_sibling_paths
# resolves an ambiguous filename, since a static reader cannot tell which
# directory the Python variable names at run time and recording only one
# would leave the cell's key unmoved by an edit to the helper the variable
# actually resolves to. A candidate that resolves to a directory or to
# nothing is skipped silently here -- discovery only adds what it can name --
# and the unresolved case is judged separately, and only for the narrower
# DIRECTORY-suffixed subset, by gate_cell_bare_names_are_unresolved.
gate_cell_bare_name_paths() {
    bare_name_directories=$(gate_cell_named_directories "$1")
    gate_cell_bare_name_tokens "$1" |
        while read -r bare_candidate; do
            [ -n "$bare_candidate" ] || continue
            for candidate_directory in $bare_name_directories; do
                if [ -f "$gate_cell_root/$candidate_directory/$bare_candidate" ] &&
                    [ -x "$gate_cell_root/$candidate_directory/$bare_candidate" ]; then
                    printf '%s/%s\n' "$candidate_directory" "$bare_candidate"
                fi
            done
        done
}

# True where a DIRECTORY-suffixed bare name token in this file resolved to
# neither an existing executable file nor an existing directory in the one
# directory gate_cell_directory_variable_map traces its own call's first
# argument to, which gate_cell_expand_seed reads the same way it reads
# gate_cell_reads_are_unbounded: the reader found a reference it cannot name,
# so the cell always runs rather than reusing a key that never counted the
# bytes behind it. A variable this reader cannot trace to a single directory
# is judged the same way -- unresolved -- rather than searched for across
# every candidate directory in the file, since a same-named executable
# elsewhere is a coincidence this reader must not bind the reference to: doing
# so would let the cell stay bounded on an unrelated file's identity while the
# reference's actual, still-absent target moves the key on no run at all.
# Clearing the execute bit on a resolved helper falls into this same
# unresolved case -- the file exists but fails the `-x` test -- so the whole
# cell moves to unbounded rather than simply missing the mode change, which is
# the safe direction for a change this reader cannot otherwise represent as a
# moved key.
gate_cell_bare_names_are_unresolved() {
    bare_directory_variable_map=$(gate_cell_directory_variable_map "$1")
    gate_cell_bare_name_unbounded_tokens "$1" |
        while read -r bare_variable bare_candidate; do
            [ -n "$bare_candidate" ] || continue
            bare_candidate_directory=$(printf '%s\n' "$bare_directory_variable_map" |
                awk -v name="$bare_variable" '$1 == name { print $2; exit }')
            if [ -z "$bare_candidate_directory" ]; then
                printf 'unresolved\n'
                continue
            fi
            if [ -f "$gate_cell_root/$bare_candidate_directory/$bare_candidate" ] &&
                [ -x "$gate_cell_root/$bare_candidate_directory/$bare_candidate" ]; then
                continue
            fi
            if [ -d "$gate_cell_root/$bare_candidate_directory/$bare_candidate" ]; then
                continue
            fi
            printf 'unresolved\n'
        done | grep -qx unresolved
}

# Every file under a directory a script names, while the directory stays inside
# the walk limit. A larger directory returns 3 and leaves the cell unbounded.
gate_cell_walk_directory() {
    if [ "$(find "$gate_cell_root/$1" -type f -print | wc -l)" -gt \
        "$gate_cell_directory_walk_limit" ]; then
        return 3
    fi
    find "$gate_cell_root/$1" -type f -print | sed "s|^$gate_cell_root/||"
}

# Expand one seed into itself plus the paths it names plus the paths those name,
# which is the one level of indirection the derivation claims. Prints the
# expansion; returns 3 where a construction or an evidence/ directory leaves the
# read set unbounded.
gate_cell_expand_seed() {
    seed=$1
    if [ ! -f "$gate_cell_root/$seed" ]; then
        printf '%s\n' "$seed"
        return 0
    fi
    printf '%s\n' "$seed"
    if ! gate_cell_is_text_path "$seed"; then
        return 0
    fi
    if gate_cell_reads_are_unbounded "$seed" ||
        gate_cell_bare_names_are_unresolved "$seed"; then
        return 3
    fi
    for named_path in $(gate_cell_named_paths "$seed"); do
        if [ -d "$gate_cell_root/$named_path" ]; then
            gate_cell_walk_directory "$named_path" || return 3
            continue
        fi
        printf '%s\n' "$named_path"
        if [ ! -f "$gate_cell_root/$named_path" ] ||
            ! gate_cell_is_text_path "$named_path"; then
            continue
        fi
        if gate_cell_reads_are_unbounded "$named_path" ||
            gate_cell_bare_names_are_unresolved "$named_path"; then
            return 3
        fi
        for second_level_path in $(gate_cell_named_paths "$named_path"); do
            if [ -d "$gate_cell_root/$second_level_path" ]; then
                gate_cell_walk_directory "$second_level_path" || return 3
                continue
            fi
            printf '%s\n' "$second_level_path"
        done
    done
    return 0
}

# The sorted read set of a seed list, or exit 3 where any seed is unbounded.
gate_cell_read_set() {
    read_set_file=$(mktemp)
    read_set_status=0
    for seed in $1; do
        if ! gate_cell_expand_seed "$seed" >>"$read_set_file"; then
            read_set_status=3
            break
        fi
    done
    if [ "$read_set_status" -eq 0 ]; then
        LC_ALL=C sort -u "$read_set_file"
    fi
    rm -f "$read_set_file"
    return "$read_set_status"
}

# Run one cell, or report and skip it where an accepted record already carries
# its key. MODE is `derive` for a read set closed over SPEC, `files` for a walk
# whose members SPEC already names, `unbounded` for a cell whose reads this
# reader cannot bound, and `universal` for a cell the gate always runs because
# it reads the whole tree. Every mode records its read-set state -- `bounded`,
# `unbounded`, or `universal` -- as its own manifest and record line, so a
# reader of an accepted record sees why a cell always runs without recomputing
# its spec. DRIVER_SCOPE defaults to `driver-independent`; `exact-driver`
# applies where CELL_COMMAND invokes a function whose implementation lives in
# the driver rather than in CELL_SPEC's hashed files.
gate_cell() {
    if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
        printf 'gate_cell requires four or five arguments\n' >&2
        return 2
    fi
    cell_name=$1
    cell_mode=$2
    cell_spec=$3
    cell_command=$4
    cell_driver_scope=${5:-driver-independent}
    if [ "$#" -eq 4 ]; then
        case $cell_command in
            gate_*)
                printf 'driver-owned command requires exact-driver scope: %s\n' \
                    "$cell_command" >&2
                return 2
                ;;
        esac
    fi
    case $cell_driver_scope in
        driver-independent | exact-driver) ;;
        *)
            printf 'unknown gate cell driver scope: %s\n' "$cell_driver_scope" >&2
            return 2
            ;;
    esac
    cell_always_runs=0
    cell_key_begin_ns=$(gate_cell_now_ns)
    cell_manifest=$(mktemp)

    {
        printf 'cell=%s\n' "$cell_name"
        printf 'command=%s\n' "$cell_command"
        printf 'tools=%s\n' "$gate_cell_tool_digest"
        printf 'driver=%s\n' "$gate_cell_driver_digest"
        printf 'mode=%s\n' "$cell_mode"
    } >"$cell_manifest"

    case $cell_mode in
        files)
            cell_read_set_state=bounded
            printf 'read_set=%s\n' "$cell_read_set_state" >>"$cell_manifest"
            for cell_path in $cell_spec; do
                gate_cell_hash_line "$cell_path"
            done | LC_ALL=C sort >>"$cell_manifest"
            ;;
        derive)
            if cell_read_set=$(gate_cell_read_set "$cell_spec"); then
                cell_read_set_state=bounded
                printf 'read_set=%s\n' "$cell_read_set_state" >>"$cell_manifest"
                for cell_path in $cell_read_set; do
                    gate_cell_hash_line "$cell_path"
                done >>"$cell_manifest"
            else
                cell_always_runs=1
                cell_read_set_state=unbounded
                printf 'read_set=%s\n' "$cell_read_set_state" >>"$cell_manifest"
                for cell_path in $cell_spec; do
                    gate_cell_hash_line "$cell_path"
                done >>"$cell_manifest"
            fi
            ;;
        unbounded)
            cell_always_runs=1
            cell_read_set_state=unbounded
            printf 'read_set=%s\n' "$cell_read_set_state" >>"$cell_manifest"
            for cell_path in $cell_spec; do
                gate_cell_hash_line "$cell_path"
            done >>"$cell_manifest"
            ;;
        universal)
            cell_always_runs=1
            cell_read_set_state=universal
            printf 'read_set=%s\n' "$cell_read_set_state" >>"$cell_manifest"
            for cell_path in $cell_spec; do
                gate_cell_hash_line "$cell_path"
            done >>"$cell_manifest"
            ;;
        *)
            printf 'unknown gate cell mode: %s\n' "$cell_mode" >&2
            rm -f "$cell_manifest"
            return 2
            ;;
    esac

    cell_key=$(sha256sum "$cell_manifest" | cut -d' ' -f1)
    printf '%s\n' "$cell_key" >>"$gate_cell_key_stream"
    cell_record=$gate_cell_cache_directory/cells/$cell_key
    # The key phase ends here: everything above derived the read set and hashed
    # it, and everything below is the reuse decision and the cell's own command.
    cell_key_ns=$(gate_cell_interval_ns "$cell_key_begin_ns" "$(gate_cell_now_ns)")
    gate_cell_key_ns_total=$(gate_cell_add_ns "$gate_cell_key_ns_total" "$cell_key_ns")

    compatible_record=''
    if [ "$gate_cell_sparse" = 1 ] && [ "$cell_always_runs" -eq 0 ]; then
        if gate_cell_record_is_accepted "$cell_record" "$cell_key" \
            "$cell_name" "$gate_cell_driver_digest" "$cell_read_set_state"; then
            compatible_record=$cell_record
        elif [ "$cell_driver_scope" = driver-independent ]; then
            compatible_record=$(gate_cell_compatible_driver_record \
                "$cell_manifest" "$cell_name" "$cell_read_set_state" || true)
        fi
    fi
    rm -f "$cell_manifest"

    if [ -n "$compatible_record" ]; then
        gate_cell_reused_count=$((gate_cell_reused_count + 1))
        # The record carries what this cell cost when it last ran, so a reuse
        # states the execution it avoided rather than leaving the saving as an
        # unmeasured claim. A record written before that field reads `-`.
        cell_avoided_ns=$(gate_cell_record_field "$compatible_record" run_ns)
        gate_cell_avoided_ns_total=$(gate_cell_add_ns \
            "$gate_cell_avoided_ns_total" "${cell_avoided_ns:--}")
        if [ "$compatible_record" != "$cell_record" ]; then
            compatible_key=$(basename -- "$compatible_record")
            cell_record_temporary=$cell_record.$$
            {
                printf 'status=accepted\n'
                printf 'name=%s\n' "$cell_name"
                printf 'key=%s\n' "$cell_key"
                printf 'tools=%s\n' "$gate_cell_tool_digest"
                printf 'driver=%s\n' "$gate_cell_driver_digest"
                printf 'read_set=%s\n' "$cell_read_set_state"
                printf 'key_ns=%s\n' "$cell_key_ns"
                printf 'run_ns=%s\n' "$cell_avoided_ns"
            } >"$cell_record_temporary"
            mv "$cell_record_temporary" "$cell_record"
            printf 'cell=compatible-driver key=%s previous_key=%s name=%s\n' \
                "$cell_key" "$compatible_key" "$cell_name"
        fi
        # The decision line keeps the shape its readers already match, and the
        # timing is a line of its own beside it.
        printf 'cell=reused key=%s name=%s\n' "$cell_key" "$cell_name"
        [ "$gate_cell_timing" = 1 ] &&
            printf 'cell=timing key=%s name=%s decision=reused key_ns=%s avoided_ns=%s\n' \
                "$cell_key" "$cell_name" "$cell_key_ns" "${cell_avoided_ns:--}"
        return 0
    fi

    gate_cell_run_count=$((gate_cell_run_count + 1))
    if [ "$cell_always_runs" -eq 1 ]; then
        printf 'cell=run key=%s name=%s read_set=%s\n' \
            "$cell_key" "$cell_name" "$cell_read_set_state"
    else
        printf 'cell=run key=%s name=%s\n' "$cell_key" "$cell_name"
    fi
    # A failing cell writes nothing, so the next run measures it again. The
    # status is captured rather than left to errexit, which is disabled inside a
    # function whose return value is tested.
    cell_run_begin_ns=$(gate_cell_now_ns)
    if eval "$cell_command"; then
        cell_run_ns=$(gate_cell_interval_ns "$cell_run_begin_ns" \
            "$(gate_cell_now_ns)")
        gate_cell_run_ns_total=$(gate_cell_add_ns "$gate_cell_run_ns_total" \
            "$cell_run_ns")
        cell_record_temporary=$cell_record.$$
        {
            printf 'status=accepted\n'
            printf 'name=%s\n' "$cell_name"
            printf 'key=%s\n' "$cell_key"
            printf 'tools=%s\n' "$gate_cell_tool_digest"
            printf 'driver=%s\n' "$gate_cell_driver_digest"
            printf 'read_set=%s\n' "$cell_read_set_state"
            printf 'key_ns=%s\n' "$cell_key_ns"
            printf 'run_ns=%s\n' "$cell_run_ns"
        } >"$cell_record_temporary"
        mv "$cell_record_temporary" "$cell_record"
        [ "$gate_cell_timing" = 1 ] &&
            printf 'cell=timing key=%s name=%s decision=run key_ns=%s run_ns=%s\n' \
                "$cell_key" "$cell_name" "$cell_key_ns" "$cell_run_ns"
        return 0
    fi
    cell_run_ns=$(gate_cell_interval_ns "$cell_run_begin_ns" \
        "$(gate_cell_now_ns)")
    printf 'cell=rejected key=%s name=%s\n' "$cell_key" "$cell_name" >&2
    [ "$gate_cell_timing" = 1 ] &&
        printf 'cell=timing key=%s name=%s decision=rejected key_ns=%s run_ns=%s\n' \
            "$cell_key" "$cell_name" "$cell_key_ns" "$cell_run_ns" >&2
    return 1
}

# The root binds every cell key in execution order, reused cells included, so
# two runs over one tree print one value.
gate_cell_summary() {
    printf 'gate=accepted cells_run=%s cells_reused=%s root=%s\n' \
        "$gate_cell_run_count" "$gate_cell_reused_count" \
        "$(sha256sum "$gate_cell_key_stream" | cut -d' ' -f1)"
    [ "$gate_cell_timing" = 1 ] || return 0
    # Three totals, each summed from the per-cell lines above rather than from a
    # second clock: deriving and hashing every cell's read set, executing the
    # cells that ran, and the execution the reused cells avoided. The third is
    # what each record measured when it last ran, so it states the saving under
    # the machine state of that run rather than predicting this one.
    printf 'gate_timing key_ns=%s run_ns=%s avoided_ns=%s clock=CLOCK_REALTIME boundaries_per_cell=3\n' \
        "$gate_cell_key_ns_total" "$gate_cell_run_ns_total" \
        "$gate_cell_avoided_ns_total"
}
