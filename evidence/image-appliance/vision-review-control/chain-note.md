# Retrospective chain note for the vision-review control

The registered chain note was not retained with this run. This retrospective
note records the fields recoverable from the committed arm files and names the
missing fields so later readers do not treat an operator annotation as process
evidence.

## Recoverable inputs and order

- `arms/audit.log` identifies served model id `qwen-apu`, artifact A SHA-256
  `17e452e6974ad6d3174c5d0c9f367c90867eb99ffa8a3a6f9e45e78eb4de7639`,
  artifact B SHA-256
  `7c6b7565059771e7e68d467afeae10233204915659c22728442467552e9e6fe3`,
  prompt SHA-256
  `c59aebadc82bffa15660ab38c507fbfacbd030deaf9a66e7fe05f0d1bde1b973`,
  two constraints, response-schema mode, and prompt caching disabled.
- The numbered filenames and `summary.tsv` record the order as real A,
  withheld A, swapped A with B, and real A.
- `vision-review-control-design.md` records the command template and intended
  falsifiers. The committed records do not prove that the operator invoked that
  template without modification.

## Fields absent from the retained run

The tree contains no run timestamps, original shell invocation, router or
artifact-listener command lines, process identifiers, startup readiness
records, teardown statuses, immutable model digest, or server-properties
response. The tree therefore cannot prove standalone service topology, exact
constraint descriptions as transmitted on the wire, clean teardown between
runs, or immutable attribution of `qwen-apu` to `lfm25-vl-16b`.

The arm replies remain evidence of four responses in the recorded order. Any
claim that depends on the missing process fields requires a new retained run or
recovery of the original sanitized chain log.
