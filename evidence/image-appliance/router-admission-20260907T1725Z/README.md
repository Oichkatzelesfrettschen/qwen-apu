# The image router admission on the lease epoch

`remote/admit-image-router.sh` runs the whole image chain against one approved
generation on the appliance, on the deployment this window activated,
`lease-q4k-6b262d93-r1`.

## Falsifiers, stated before the numbers

- A replayed grant, an ungranted call, an argument outside the tool schema, a
  foreign image profile, or an uncredentialed artifact read that is answered
  rather than refused breaks the authorization boundary the lane rests on.
- An artifact whose bytes fail the digest the reply named, or a provenance
  record naming another seed or profile, breaks the content addressing the page
  refetches by.
- A lease still held after the generation refutes the two-sided lease the
  service and the server share.
- A served page turn where the model proposes no call leaves the lane's served
  half unproven whatever the curl replay accepted.

## Result

28 accepted, 2 observed, 1 skipped, and `admit_image_router=refused checks=1`.

Every mechanism check accepts. One generation completes in 14 s at
`sha256 17e452e6...` over 583,938 PNG bytes matching the digest the reply named;
the provenance record names seed 20260829 and profile `image-sdxs-512-a`; the
replayed grant, the ungranted call, the out-of-schema `params.model`, the
foreign image profile, and the uncredentialed artifact read are each refused
once; the lease is free after the generation; and the teardown proves no
service, runtime, partial artifact, router, MCP child, broker, secret, or
listener.

The single failure is the served page turn, on both attempts. The model
proposed no tool call and answered in prose -- attempt 1 with a bracketed
`[An illustration of a fox in a snowy field...]` and attempt 2 with `Here is a
generated...` -- so no dialog opened and each attempt ended on the 600 s wait.

This is the same failure `../../web-live/20260907T1545Z/` records for
`web-reader` on the same afternoon: a checkpoint whose `raw_tool_selection`
grade is low is handed a tool schema, proposes nothing, and answers as though
it had used the tool. `evidence/image-appliance/served-turn-admission/` retains
the run where this turn passed, and its language profile named the 4B distill,
which proposed a schema-valid call in every run there. The lane's mechanism is
unchanged and its served half is a property of the language checkpoint the
profile names.

## Not run

- **The paired-review admission.** Device-window budget after arm (e)'s
  promotion consumed the remaining time; the run is unmeasured rather than
  failed.
- **Generation wall times for `sd15+lcm` and `sd-turbo`, three runs each.** The
  same reason. The one `sdxs-512` generation this admission performed took 14 s
  end to end, which is one observation rather than the three-run record the
  candidate rows need.

## Retained files

`summary.tsv` holds one row per check, `run.log` the whole run, `browser-*` the
page's own request log and replies, and the launch, server, broker, service,
and teardown logs sit beside them. Artifact PNGs are excluded from the copy;
their digests are in the summary. Paths name `$HOME` and the host reads
`qwen-laptop`.
