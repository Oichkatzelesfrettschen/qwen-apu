#!/bin/sh
set -eu

# write-clangd-config.sh writes the editor configuration from a patched
# source tree's location and extracts the headers candidate patches add.
# These checks run it against a fixture tree and a fixture patch.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
failures=0
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

report() {
    printf '%s=%s\n' "$1" "$2"
    [ "$2" = ok ] || failures=$((failures + 1))
}

root=$work/root
mkdir -p "$root/remote" "$root/patches"
cp "$script_directory/write-clangd-config.sh" "$root/remote/"
source=$work/source
for directory in include ggml/include ggml/src common tools/server src vendor; do
    mkdir -p "$source/$directory"
done
: >"$source/CMakeLists.txt"
cat >"$root/patches/fixture.patch" <<'EOF'
diff --git a/tools/server/server-fixture.h b/tools/server/server-fixture.h
new file mode 100644
--- /dev/null
+++ b/tools/server/server-fixture.h
@@ -0,0 +1,3 @@
+#pragma once
+
+int fixture_value();
diff --git a/tools/server/server-context.cpp b/tools/server/server-context.cpp
--- a/tools/server/server-context.cpp
+++ b/tools/server/server-context.cpp
@@ -1,2 +1,3 @@
 int existing;
+int added;
 int other;
EOF

# A tree missing a llama.cpp directory is refused by name.
if "$root/remote/write-clangd-config.sh" --source "$work/absent" --root "$root" \
    >/dev/null 2>"$work/absent.err"; then
    report absent_source_refused fail
else
    grep -q 'lacks include' "$work/absent.err" && report absent_source_refused ok ||
        report absent_source_refused fail
fi

# --check prints the configuration and writes nothing.
"$root/remote/write-clangd-config.sh" --source "$source" --root "$root" --check >"$work/check.out"
if grep -q -- "-I$source/tools/server" "$work/check.out" && [ ! -e "$root/.clangd" ]; then
    report check_prints_without_writing ok
else
    report check_prints_without_writing fail
fi

# The write produces both configurations and extracts the added header only.
XDG_CONFIG_HOME=$work/xdg "$root/remote/write-clangd-config.sh" --source "$source" --root "$root" >"$work/write.out"
if grep -q "^headers_extracted=1$" "$work/write.out" &&
    [ -f "$root/.clangd-include/server-fixture.h" ] &&
    grep -q 'int fixture_value();' "$root/.clangd-include/server-fixture.h" &&
    [ ! -e "$root/.clangd-include/server-context.cpp" ] &&
    grep -q -- "-I$root/.clangd-include" "$root/.clangd" &&
    [ ! -e "$source/.clangd" ] &&
    grep -q "PathMatch: $source/" "$work/xdg/clangd/config.yaml" &&
    grep -q -- "-I$source/common" "$work/xdg/clangd/config.yaml" &&
    grep -q 'readability-isolate-declaration' "$root/.clangd"; then
    report configuration_and_headers_written ok
else
    report configuration_and_headers_written fail
    cat "$work/write.out" >&2
fi

# Usage errors exit 2.
if "$root/remote/write-clangd-config.sh" --bogus >/dev/null 2>&1; then
    report usage_refused fail
else
    [ "$?" -eq 2 ] && report usage_refused ok || report usage_refused fail
fi

if [ "$failures" -ne 0 ]; then
    printf 'write_clangd_config=failed failures=%s\n' "$failures"
    exit 1
fi
printf 'write_clangd_config=accepted\n'
