#!/usr/bin/env python3
"""Verify exact shared-series membership and the one-patch comparison delta."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
census = 'llama-vulkan-pipeline-census.patch'
delta = 'llama-vulkan-q8-four-row-select.patch'
shared = ','.join((
    'llama-vulkan-q4k-activation-group-sums.patch',
    'llama-vulkan-q4k-activation-sideplane.patch',
    'llama-vulkan-q4k-scale-word-select.patch',
    'llama-vulkan-q4k-superblock-loop-licm.patch',
    'llama-vulkan-q4k-variant-select.patch',
    'llama-vulkan-q4k-row-select.patch',
))

def resolve(mode, base, addition=delta):
    return subprocess.run([
        'sh', '-c', '. "$1"; shift; census_expected_ab_series "$@"',
        'fixture', str(root / 'census-arm-lib.sh'), mode, census, addition, base,
        str(root / 'llama-patch-series.tsv'),
    ], text=True, capture_output=True)

for mode, base, control in (
    ('served', '-', '-'),
    ('kernel-delta', '-', census),
    ('served', shared, shared),
    ('kernel-delta', shared, census + ',' + shared),
):
    result = resolve(mode, base)
    assert result.returncode == 0, result.stderr
    expected_candidate = (control + ',' if control != '-' else '') + delta
    assert result.stdout.strip() == control + '\t' + expected_candidate
for base in (shared + ',' + delta, shared + ',' + census,
             shared + ',' + shared.split(',')[0], 'unknown.patch',
             ','.join(reversed(shared.split(','))), ''):
    assert resolve('served', base).returncode != 0, base
assert resolve('served', shared, 'unknown.patch').returncode != 0
print('shared_series_fixture=accepted membership_order_and_single_delta=held')
