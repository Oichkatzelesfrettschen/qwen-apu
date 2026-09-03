# Replay corpus: real Raven2 bytes for the three census readers

```text
acquisition_head=59c03c8096dee98f03a0805d3f7c715ef7158d6d
source_run=$HOME/raven2-kernel-census-20260902T0525Z-2b-calibration-v6
```

A reader change proves itself against retained device bytes before another
appliance run, and `remote/test-census-replay-corpus.py` is that proof. Every
file here is copied byte-for-byte from
`evidence/raven2-vulkan-kernel-census/20260902T0525Z/`'s own source run on the
appliance, at the acquisition head above, then sanitized: the private host
name becomes `qwen-laptop` and the home prefix becomes `$HOME` wherever either
string appears. `10-I1/pipeline-census.tsv` carries neither string and its
sanitized form is therefore compression alone.

## Records

| record | path | before sha256 | stored artifact | after sha256 |
| --- | --- | --- | --- | --- |
| I1 census | `10-I1/pipeline-census.tsv` (6,760,675 bytes) | `5de43be349dab4b3e6e80003a62bfee20aa264b084ab0537caccf5afe0c75ce0` | `10-I1/pipeline-census.tsv.xz` (458,044 bytes, `xz -9`) | `36081cad84d974aecadb3400b9b7039cf704583d5b55eff74a8456263892136f` |
| I1 request window | `10-I1/request-window.tsv` | `d004f26a92f1af64668428337a1a2eca3f2b992efad77af9e085d18a06cd8ff4` | unchanged | `d004f26a92f1af64668428337a1a2eca3f2b992efad77af9e085d18a06cd8ff4` |
| I1 clock sidecar | `10-I1/clock-sidecar.tsv` | `6a20384655119e9473ac09b959a1ffc95a6a3a46a7bf2565c814c87906d1a7e7` | unchanged | `6a20384655119e9473ac09b959a1ffc95a6a3a46a7bf2565c814c87906d1a7e7` |
| I1 retained verdict | `10-I1/clock-sidecar-verdict.txt` | `da30dd79f359ac8a0167f7347a1a47d89b83bea4e490507730da2c169e0ae38d` | sanitized (`record_readable` path rewritten) | `cf7f28cc5815fda26fab6e24d719e262a92994554f0b86044960ea97f241d546` |
| S slice | `13-S/server-log-request.slice` (147,229 bytes) | `75e5d3b6cde1d31faef02a16287f0bbcf611505602dab351c94c041c733d7552` | unchanged | `75e5d3b6cde1d31faef02a16287f0bbcf611505602dab351c94c041c733d7552` |
| S request window | `13-S/request-window.tsv` | `4f9c0a82e3f20fba15d4cbcae26f9108bca0add2b5e324f93b4b0ef72d177cc0` | unchanged | `4f9c0a82e3f20fba15d4cbcae26f9108bca0add2b5e324f93b4b0ef72d177cc0` |
| P clock sidecar | `02-P/clock-sidecar.tsv` | `616d57344b2043363a0e94419ca84225747760fd6e48a110c174a935f6437db5` | unchanged | `616d57344b2043363a0e94419ca84225747760fd6e48a110c174a935f6437db5` |
| P request window | `02-P/request-window.tsv` | `f6918ce2fac2e25bced716baaa00936cc20fa7ddf2690d23c8e11ff64cabb02a` | unchanged | `f6918ce2fac2e25bced716baaa00936cc20fa7ddf2690d23c8e11ff64cabb02a` |
| P retained verdict | `02-P/clock-sidecar-verdict.txt` | `44f252621cdca5b6642d08c215404c2a8b311a85a203b587d62befd66c035932` | sanitized (`record_readable` path rewritten) | `cc7944e76233bceabcdf8bedb339fc192025a503b64807f962a9fa9c70b3b0c9` |

The two retained verdict files are provenance from the acquisition run alone;
`validate-clock-sidecar.py` changed after `59c03c8` to add
`window_lost_fraction`, so the corpus test regenerates both verdicts from the
current reader against the retained `clock-sidecar.tsv` and
`request-window.tsv` bytes rather than trusting the stored text.

No truncation was needed: `xz -9` over the 6,760,675-byte I1 census produces
458,044 bytes, under the 2 MiB bound, so the retained file is the complete
record and no derived `census_close` row was written.

## Expected verdicts

Each window is read from the record's own `request-window.tsv` (`begin_ns`,
`end_ns`), decompressed alongside its census file where one applies.

**I1 census**, `remote/summarize-kernel-census.py 10-I1/pipeline-census.tsv
--window-begin-ns 344078388671159 --window-end-ns 344085622450889
--expected-decode-graphs 63 --phase decode --overlap-threshold 0.05`, exits 0
and its closing `graphs` row reads:

```text
graphs	decode	63
ownership=conclusive
contexts=2	selected_context=2
bracket_union_ms_per_graph=97.285
submits_per_graph=40.000
```

**S slice**, `remote/summarize-perf-logger-slice.py
13-S/server-log-request.slice --expected-decode-blocks 63`, exits 0 and
reports:

```text
decode_blocks	63
prefill_blocks	1
unknown_blocks	0
op	MUL_MAT	181.000 calls_per_block
op	MUL_MAT_ADD	30.000 calls_per_block
```

**P sidecar**, `remote/validate-clock-sidecar.py 02-P/clock-sidecar.tsv
--sidecar-status 0 --period-ms 10 --period-tolerance 0.25
--cost-bound-ns 1000000 --max-gap-ns 20000000
--allow-unavailable pp_dpm_fclk_surface_mhz
--window-begin-ns 343712714316927 --window-end-ns 343719788054038`, exits 1
and is refused on `gaps` alone:

```text
gaps=refused max_ns=42019502
gaps_in_window=1 window_lost_fraction=0.0047
clock_sidecar=refused failures=gaps
```

**I1 sidecar**, the same reader over `10-I1/clock-sidecar.tsv` with
`--window-begin-ns 344078388671159 --window-end-ns 344085622450889`, exits 0:

```text
gaps=accepted max_ns=21087138
gaps_in_window=0 window_lost_fraction=0.0000
clock_sidecar=accepted failures=-
```

`remote/test-census-replay-corpus.py` decompresses the I1 census into a
temporary directory, runs all three readers over these five records, and
asserts every value above, printing `census_replay_corpus=accepted` on
success. Add it to the repository gate beside the other reader tests:

```text
remote/test-census-replay-corpus.py
```

## The six cases

Each retained shape is a named case, its own function in the script, and its
own printed `case=<name> verdict=accepted` line. Every reader change
satisfies this corpus before it reaches another appliance run.

- `raven2-i1-good`: the retained I1 census reads 63 decode graphs under
  conclusive ownership at the exact `bracket_union_ms_per_graph` and
  `submits_per_graph` the acquisition run measured.
- `raven2-s-mixed-phase`: the S slice carries one prefill block beyond the
  63 decode blocks, and the decode selector must recover exactly 63 decode,
  1 prefill, 0 unknown, and the per-block `MUL_MAT`/`MUL_MAT_ADD` counts.
- `raven2-sidecar-gap`: the 02-P sidecar's 42 ms scheduler slice refuses
  under the hard-gap contract, accepts under the coverage contract, and
  refuses again under a tightened lost-fraction bound, so the verdict
  follows the asked contract rather than one fixed reading of the record.
- `raven2-sidecar-good`: the 10-I1 sidecar accepts under the coverage
  contract with zero window loss at its own widest gap.
- `raven2-two-context`: the I1 stream carries two Vulkan contexts, the
  reader selects the one the request window intersects and reports both
  `contexts=2` and `selected_context=2`, and a window that intersects
  neither section's graphs -- the only way this reader can be asked for a
  context absent from the stream, since it names no context-selecting flag
  -- refuses rather than defaulting to one.
- `raven2-f32-activation-matmul`: Gated DeltaNet's f32 chunk-product
  matmuls carry `ne1` of 2, 8, and 32 inside decode graphs without setting
  the token column, proven directly by counting those rows in the parsed
  census and again through the summarizer's own 63-decode-graph output.
