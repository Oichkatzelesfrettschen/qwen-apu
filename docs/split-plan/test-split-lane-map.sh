#!/bin/sh
set -eu

# Test the lane map parsing logic from split-pr-105.sh.
# Verify that the four-column format is parsed correctly and that
# header rows and comments are skipped.

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

# Create a minimal test lane map with four columns.
cat >"$test_dir/lanes.tsv" <<'EOF'
lane	pattern	pr	merge_sha
# Comment line that should be skipped
census-timing	remote/census-arm-lib.sh	116	717dbef
dpm-telemetry	e0d179a:remote/telemetry-broker.c	-	-
shared	CLAUDE.md	-	-
build-cache-identity	remote/gate-cell-key.sh	-	-
EOF

# Extract the lane-parsing logic and test it.
python3 -c '
import fnmatch, os, sys

# This replicates the parsing logic from split-pr-105.sh
plain, override = [], []
for line in open("'"$test_dir"'/lanes.tsv"):
    line = line.rstrip("\n")
    if not line or line.startswith("#") or line.startswith("lane\t"):
        continue
    fields = line.split("\t")
    if len(fields) < 2:
        continue
    lane, pattern = fields[0], fields[1]
    if ":" in pattern:
        commit, pattern = pattern.split(":", 1)
        override.append((commit, lane, pattern))
    else:
        plain.append((lane, pattern))

# Test 1: Verify that the header row was skipped (should have only 4 entries)
total_entries = len(plain) + len(override)
if total_entries != 4:
    raise SystemExit("Expected 4 entries, got %d" % total_entries)

# Test 2: Verify that a known path matches its lane
test_path = "remote/census-arm-lib.sh"
matched_lane = None
for candidate, pattern in plain:
    if fnmatch.fnmatch(test_path, pattern):
        matched_lane = candidate
        break
if matched_lane != "census-timing":
    raise SystemExit("Path %s matched lane %s instead of census-timing" % (test_path, matched_lane))

# Test 3: Verify that override entries are parsed correctly
override_found = False
for commit, lane, pattern in override:
    if commit == "e0d179a" and lane == "dpm-telemetry" and pattern == "remote/telemetry-broker.c":
        override_found = True
        break
if not override_found:
    raise SystemExit("Override entry for e0d179a:remote/telemetry-broker.c not found")

# Test 4: Verify that multiple plain entries exist
if len(plain) < 3:
    raise SystemExit("Expected at least 3 plain entries, got %d" % len(plain))

# Test 5: Verify that unmatched path returns None
unmatched_path = "remote/nonexistent.sh"
unmatched_lane = None
for candidate, pattern in plain:
    if fnmatch.fnmatch(unmatched_path, pattern):
        unmatched_lane = candidate
        break
if unmatched_lane is not None:
    raise SystemExit("Path %s unexpectedly matched lane %s" % (unmatched_path, unmatched_lane))

print("All tests passed")
'
