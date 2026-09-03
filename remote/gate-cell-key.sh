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
# gate_cell and of this reader itself: an edit to gate_shell_syntax or to
# gate_cell_named_paths changes what a cell's accepted record used to certify,
# and neither script is otherwise a file any cell names in its own spec.
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
gate_cell_cache_directory=${QWEN_GATE_CACHE_DIR:-$HOME/.cache/qwen-apu-gate}
gate_cell_sparse=${QWEN_GATE_SPARSE:-1}
gate_cell_directory_walk_limit=${QWEN_GATE_DIRECTORY_WALK_LIMIT:-64}
gate_cell_tool_digest=''
gate_cell_driver_digest=''
gate_cell_key_stream=''
gate_cell_run_count=0
gate_cell_reused_count=0

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
    gate_cell_run_count=0
    gate_cell_reused_count=0
    mkdir -p "$gate_cell_cache_directory/cells"
}

gate_cell_cleanup() {
    if [ -n "$gate_cell_key_stream" ]; then
        rm -f "$gate_cell_key_stream"
    fi
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

# Every repository path the text of one file names: a literal prefix under
# remote/, evidence/, or patches/, and the $script_directory/NAME form that
# resolves to remote/NAME for every script in this tree. A trailing dot comes
# from prose rather than a filename and is trimmed. A parent traversal is
# dropped, since `$script_directory/..` is how every script in this tree
# resolves the repository root and reads nothing by itself; the files it then
# reaches appear as their own tokens or leave the cell unbounded.
gate_cell_named_paths() {
    {
        grep -oE '(remote|evidence|patches)/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*' \
            "$gate_cell_root/$1" || true
        grep -oE '\$\{?script_directory\}?/[A-Za-z0-9_.-]+' \
            "$gate_cell_root/$1" |
            sed 's|^\${*script_directory}*/|remote/|' || true
        gate_cell_sibling_paths "$1"
    } | sed 's/[.]*$//' |
        grep -vE '(^|/)[.][.](/|$)' |
        grep -vE '/$' |
        LC_ALL=C sort -u
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
    if gate_cell_reads_are_unbounded "$seed"; then
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
        if gate_cell_reads_are_unbounded "$named_path"; then
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
# its spec.
gate_cell() {
    cell_name=$1
    cell_mode=$2
    cell_spec=$3
    cell_command=$4
    cell_always_runs=0
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
    rm -f "$cell_manifest"
    printf '%s\n' "$cell_key" >>"$gate_cell_key_stream"
    cell_record=$gate_cell_cache_directory/cells/$cell_key

    if [ "$gate_cell_sparse" = 1 ] && [ "$cell_always_runs" -eq 0 ] &&
        [ -f "$cell_record" ] &&
        grep -qx 'status=accepted' "$cell_record" &&
        grep -qx "tools=$gate_cell_tool_digest" "$cell_record" &&
        grep -qx "driver=$gate_cell_driver_digest" "$cell_record"; then
        gate_cell_reused_count=$((gate_cell_reused_count + 1))
        printf 'cell=reused key=%s name=%s\n' "$cell_key" "$cell_name"
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
    if eval "$cell_command"; then
        cell_record_temporary=$cell_record.$$
        {
            printf 'status=accepted\n'
            printf 'name=%s\n' "$cell_name"
            printf 'key=%s\n' "$cell_key"
            printf 'tools=%s\n' "$gate_cell_tool_digest"
            printf 'driver=%s\n' "$gate_cell_driver_digest"
            printf 'read_set=%s\n' "$cell_read_set_state"
        } >"$cell_record_temporary"
        mv "$cell_record_temporary" "$cell_record"
        return 0
    fi
    printf 'cell=rejected key=%s name=%s\n' "$cell_key" "$cell_name" >&2
    return 1
}

# The root binds every cell key in execution order, reused cells included, so
# two runs over one tree print one value.
gate_cell_summary() {
    printf 'gate=accepted cells_run=%s cells_reused=%s root=%s\n' \
        "$gate_cell_run_count" "$gate_cell_reused_count" \
        "$(sha256sum "$gate_cell_key_stream" | cut -d' ' -f1)"
}
