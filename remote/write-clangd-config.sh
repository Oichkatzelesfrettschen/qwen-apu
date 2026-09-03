#!/bin/sh
set -eu

# Write the clangd configuration an editor reads for this repository's C and
# C++ files, and for a patched llama.cpp source tree beside it.
#
# The repository's own C sources (the telemetry broker, the Vulkan probes,
# the shader laboratory) compile against system headers alone, but the test
# fixtures that exercise a candidate server patch include headers the patch
# adds under tools/server, and every patched source tree compiles against
# llama.cpp's include, ggml/include, common, and tools/server directories.
# clangd resolves those only through a .clangd file at the root it serves, so
# this script writes one from the pinned source tree's location and extracts
# every header a candidate patch adds into .clangd-include, which is what lets
# a fixture compile in the editor exactly as remote/test-prefix-checkpoint-key.sh
# compiles it out of the patch. Both outputs carry local absolute paths, so
# .gitignore keeps them out of the tree and the script is the checked-in
# authority.
#
# CMake would produce compile_commands.json for a built tree, but
# build-llama-preset.sh binds its CMake flags into the build identity every
# calibration receipt records, so the editor configuration lives beside the
# tree rather than inside its build.

usage() {
    printf 'usage: %s [--source PATCHED_SOURCE] [--root REPOSITORY_ROOT] [--check]\n' "$0" >&2
    printf 'PATCHED_SOURCE defaults to $HOME/src/llama.cpp-qwen-apu, the tree prepare-llama-vulkan-source.sh writes\n' >&2
    printf '%s\n' '--check prints the configuration without writing it' >&2
    exit 2
}

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
patched_source=${HOME:?}/src/llama.cpp-qwen-apu
check_only=0
while [ "$#" -gt 0 ]; do
    case $1 in
        --source) [ "$#" -ge 2 ] || usage; patched_source=$2; shift 2 ;;
        --root) [ "$#" -ge 2 ] || usage; repository_root=$2; shift 2 ;;
        --check) check_only=1; shift ;;
        *) usage ;;
    esac
done
for required in include ggml/include common tools/server; do
    if [ ! -d "$patched_source/$required" ]; then
        printf 'the patched llama.cpp source lacks %s: %s\n' "$required" "$patched_source" >&2
        printf 'prepare it with remote/prepare-llama-vulkan-source.sh or name a tree with --source\n' >&2
        exit 1
    fi
done
patched_source=$(CDPATH='' cd -- "$patched_source" && pwd)
include_directory=$repository_root/.clangd-include

# Every header a candidate patch adds (a hunk whose old side is /dev/null)
# is extracted whole, so a fixture that includes it resolves in the editor.
extract_added_headers() {
    python3 - "$repository_root/patches" "$include_directory" <<'EOF'
import os
import sys

patches_directory, include_directory = sys.argv[1:3]
written = 0
for name in sorted(os.listdir(patches_directory)):
    if not name.endswith(".patch"):
        continue
    with open(os.path.join(patches_directory, name), encoding="utf-8") as handle:
        lines = handle.read().split("\n")
    index = 0
    while index < len(lines):
        if lines[index] == "--- /dev/null" and index + 1 < len(lines) and lines[index + 1].startswith("+++ b/"):
            target = lines[index + 1][len("+++ b/"):]
            index += 2
            if index < len(lines) and lines[index].startswith("@@"):
                index += 1
            body = []
            while index < len(lines) and (lines[index].startswith("+") or lines[index] == ""):
                if lines[index] == "":
                    break
                body.append(lines[index][1:])
                index += 1
            if target.endswith((".h", ".hpp")):
                destination = os.path.join(include_directory, os.path.basename(target))
                os.makedirs(include_directory, exist_ok=True)
                with open(destination, "w", encoding="utf-8") as out:
                    out.write("\n".join(body) + "\n")
                written += 1
            continue
        index += 1
print("headers_extracted=%d" % written)
EOF
}

configuration() {
    printf 'CompileFlags:\n'
    printf '  Add:\n'
    printf '    - -std=c++17\n'
    for directory in include ggml/include ggml/src common tools/server src vendor; do
        printf '    - -I%s/%s\n' "$patched_source" "$directory"
    done
    printf '    - -I%s\n' "$include_directory"
    printf '  CompilationDatabase: None\n'
    printf 'Diagnostics:\n'
    printf '  UnusedIncludes: None\n'
    printf '  ClangTidy:\n'
    printf '    Add: [readability-isolate-declaration]\n'
}

if [ "$check_only" = 1 ]; then
    configuration
    exit 0
fi
configuration >"$repository_root/.clangd"
extract_added_headers
printf 'clangd_config=written root=%s source=%s\n' "$repository_root" "$patched_source"
if [ -d "$patched_source/.git" ] || [ -f "$patched_source/CMakeLists.txt" ]; then
    # The same flags serve the patched tree itself, where the server and
    # ggml sources open from the tree rather than through a fixture.
    configuration >"$patched_source/.clangd"
    printf 'clangd_config=written root=%s\n' "$patched_source"
fi
