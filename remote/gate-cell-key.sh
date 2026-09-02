# shellcheck shell=sh
# Content identity for one quality-gate cell, sourced by the gate and by its
# own test.
#
# A cell is one gate invocation: a lint walk, a syntax walk, or a test script.
# Its key is the SHA-256 of a manifest carrying the cell name, the command line
# the gate would run, the versions of the tools in force, and the SHA-256 of
# every file the cell reads, so a cell whose key names an accepted record has
# already run over exactly these bytes and is reported and skipped.
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
# GATE_CELL_ROOT is the tree paths resolve against and defaults to the
# repository root, which is what lets the test drive the derivation over a
# fixture tree.

gate_cell_root=${GATE_CELL_ROOT:-}
gate_cell_cache_directory=${QWEN_GATE_CACHE_DIR:-$HOME/.cache/qwen-apu-gate}
gate_cell_sparse=${QWEN_GATE_SPARSE:-1}
gate_cell_directory_walk_limit=${QWEN_GATE_DIRECTORY_WALK_LIMIT:-64}
gate_cell_tool_digest=''
gate_cell_key_stream=''
gate_cell_run_count=0
gate_cell_reused_count=0

# The four tools whose output decides a cell's verdict independently of the
# repository bytes. A new shellcheck, ruff, python3, or cc grades the same file
# differently, so its version enters every key and every record.
gate_cell_tool_versions() {
    shellcheck --version 2>/dev/null || printf 'shellcheck=absent\n'
    ruff --version 2>/dev/null || printf 'ruff=absent\n'
    python3 --version 2>&1 || printf 'python3=absent\n'
    cc --version 2>/dev/null | head -n 1 || printf 'cc=absent\n'
}

gate_cell_init() {
    if [ -z "$gate_cell_root" ]; then
        printf 'gate_cell_root is unset\n' >&2
        return 2
    fi
    gate_cell_tool_digest=$(gate_cell_tool_versions | sha256sum | cut -d' ' -f1)
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

# One manifest line per path, with `absent` standing for a named path the tree
# lacks so the key moves when the file appears.
gate_cell_hash_line() {
    if [ -f "$gate_cell_root/$1" ]; then
        printf '%s %s\n' \
            "$(sha256sum "$gate_cell_root/$1" | cut -d' ' -f1)" "$1"
    else
        printf 'absent %s\n' "$1"
    fi
}

# Only a text file is read for the paths it names. A PNG fixture or another
# binary member of a read set reaches grep as bytes, where a chance match makes
# GNU grep report the file rather than the match and puts an absolute path into
# the manifest, which is what would make one tree's key differ from a copy of it.
gate_cell_is_text_path() {
    case $1 in
        *.sh | *.py | *.mjs | *.js | *.tsv | *.json | *.ini | *.md | *.txt | \
            *.patch | *.html | *.css | *.c | *.h | *.cpp | *.conf | *.yml | \
            *.yaml) return 0 ;;
    esac
    return 1
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

# A bare filename a script names, resolved against the script's own directory.
# `os.path.join(os.path.dirname(os.path.abspath(__file__)), "run-quality-suite.py")`
# is how every Python test in this tree reaches the module it exercises, and the
# joined name carries no repository prefix for the literal reader to match. A
# name that resolves to a sibling file enters the read set; a name that resolves
# nowhere is a fixture the test writes under its own temporary directory.
gate_cell_sibling_paths() {
    sibling_directory=$(dirname "$1")
    grep -oE '[A-Za-z0-9][A-Za-z0-9_.-]*[.](py|sh|mjs|tsv|json|ini|md|txt|patch|html|png)' \
        "$gate_cell_root/$1" | LC_ALL=C sort -u |
        while read -r sibling_name; do
            if [ -f "$gate_cell_root/$sibling_directory/$sibling_name" ]; then
                printf '%s/%s\n' "$sibling_directory" "$sibling_name"
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
# it reads the whole tree.
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
        printf 'mode=%s\n' "$cell_mode"
    } >"$cell_manifest"

    case $cell_mode in
        files)
            for cell_path in $cell_spec; do
                gate_cell_hash_line "$cell_path"
            done | LC_ALL=C sort >>"$cell_manifest"
            ;;
        derive)
            if cell_read_set=$(gate_cell_read_set "$cell_spec"); then
                for cell_path in $cell_read_set; do
                    gate_cell_hash_line "$cell_path"
                done >>"$cell_manifest"
            else
                cell_always_runs=1
                printf 'read_set=unbounded\n' >>"$cell_manifest"
                for cell_path in $cell_spec; do
                    gate_cell_hash_line "$cell_path"
                done >>"$cell_manifest"
            fi
            ;;
        unbounded)
            cell_always_runs=1
            printf 'read_set=unbounded\n' >>"$cell_manifest"
            for cell_path in $cell_spec; do
                gate_cell_hash_line "$cell_path"
            done >>"$cell_manifest"
            ;;
        universal)
            cell_always_runs=1
            printf 'read_set=universal\n' >>"$cell_manifest"
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
        grep -qx "tools=$gate_cell_tool_digest" "$cell_record"; then
        gate_cell_reused_count=$((gate_cell_reused_count + 1))
        printf 'cell=reused key=%s name=%s\n' "$cell_key" "$cell_name"
        return 0
    fi

    gate_cell_run_count=$((gate_cell_run_count + 1))
    if [ "$cell_always_runs" -eq 1 ]; then
        printf 'cell=run key=%s name=%s read_set=unbounded\n' \
            "$cell_key" "$cell_name"
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
