# The deletion plan, classified before the first byte goes

`runtime-root.sh uninstall` and `purge` select entries under the runtime root
and remove them. The confirm each takes proves that an operator meant to run
the command. It establishes nothing about what the command selected, and the
root holds objects whose loss is unrecoverable: `evidence/home-sweep-recovery/`
records measurement arms whose raw sources exist in one place, and the
`emergency-forced-tail-40f7b775` rollback pair is the only copy of the server
it carries outside that same sweep. Three copies of one artifact inside one
root are three copies one invocation removes.

`remote/check-deletion-plan.sh` enumerates the complete selection first and
reads a decision record from every protected object in it. A plan holding one
object it cannot prove disposable refuses whole, so no sibling is removed while
a protected object stands unresolved. `remote/runtime-root.sh` holds one
exclusion across the classification and the removal together, since a plan
verified by a process that then exits leaves the interval between the check and
the act open.

The mechanism needs no record written anywhere to protect the sweep. An
acquisition carrying no declaration reads as `unreviewed` and refuses, which is
what every directory under `$QWEN_HOME/results/` is today, so the completion
condition holds from the workstation with no appliance window and no device
time.

## Two protected object types, and what the difference is

A measurement acquisition and a deployment bundle both veto a plan and they do
so for different reasons. An acquisition is evidence: its protection is the
irreplaceability of the bytes. A deployment is an operational artifact: its
protection is the serving and rollback roles it stands in. A bundle is not an
acquisition because it contains a measured executable, and an acquisition is
not disposable because no role link names it.

| Object | Treatment |
| --- | --- |
| Unreviewed or held acquisition | refuse |
| Acquisition reviewed and retained | refuse |
| Acquisition disposed of on a retained copy | refuse while the destination is unverified |
| Acquisition disposed of as an intentional discard, fully bound | admit |
| Deployment named by `deployment-current` or `deployment-previous` | refuse, naming the role |
| Deployment no role link names | refuse |
| Reconstructible product (`bin`, `opt`, `cache`, `tmp`) | admit |
| Session state, under purge's own confirm | admit |
| Anything else under the root | refuse as unclassified |

Reachability is a stronger reason rather than the only one. A bundle nobody
references is refused the same way, because "unreferenced" and "disposable"
are different claims and only the first is readable from the root.

`models/` is selected by purge and kept by uninstall, so purge expands it into
objects needing decisions. `verify-models` proves a pinned digest for the rows
`remote/models.tsv` names; it proves nothing about a derived F16 artifact or
about `qwen-test-models`, whose regeneration `evidence/home-sweep-recovery/`
records as unproven.

## Metadata equality is not content equality

The metadata fingerprint digests `(type, relative path, size, modification
time)` over every node, directories excluded. It detects a changed population
and a changed size at the cost of one `find`, and it is a change indication
rather than a content proof: `os.utime` sets a modification timestamp at
nanosecond resolution, so a same-size rewrite with the original timestamp
returned reproduces the fingerprint exactly. `test-deletion-plan.sh` performs
that rewrite and asserts both halves -- the fingerprint holds still and the
payload digest moves -- so the limit is measured rather than asserted.

The payload manifest hashes the bytes of every regular file and is required
before a destructive disposal, where the cost is paid once against an
acquisition an operator has already decided to lose. A timestamp-preserving
copy or restore is an ordinary operation rather than evidence of tampering, so
a relocated acquisition reads as changed and requires a fresh review; the
refusal direction is safe and the reason is recorded here rather than inferred
as an attack.

Directory rows stay out of the fingerprint. Writing the decision record changes
the timestamp of the directory that holds it, so a fingerprint carrying that
row would be stale the instant the decision naming it was sealed. A changed
population already appears as an added or removed node row.

The control subtree is excluded whole rather than by the name of one file
inside it, and the plan identity digests the selected set as `class` and `path`
rows alone. Those two properties are what let an authorization name the plan it
was written for: sealing a decision and writing an authorization both move
bytes only inside an excluded directory, and neither moves the plan identity.
The root's own exclusion leaf is left out of the selection for the same reason,
since the removal creates it after the operator has read the plan.

## An absent lock is unmanaged, not idle

```text
.acquiring.lock absent   !=   no writer exists
```

`flock` is advisory. A free lock proves that no cooperating writer holds that
leaf and proves nothing about a writer that never took it. The states are
therefore four, and two of them refuse for different reasons:

| Lock state | Reading |
| --- | --- |
| held | a producer is writing; refuse |
| free | cooperating writers are excluded; continue |
| absent | unmanaged activity; refuse |
| malformed | refuse |

Nothing in this tree writes a producer lock today, so every acquisition that
exists predates the protocol and reads as `unmanaged`. That is a migration
limit rather than a reason to defer the refusal: unknown activity blocks a
deletion, which is the direction that loses nothing. Adopting a legacy
acquisition into the lifecycle records that it is closed and verifies its
contents; creating a lock now excludes no writer that ran before it.

The exclusion the removal holds is a different object from the per-acquisition
lock. `runtime-root.sh` opens `$QWEN_HOME/.deletion.lock` through
`open-verified-lock-descriptor.py`, which refuses a symlink, a directory, a
foreign owner, a multiply-linked leaf, and a group-writable mode, and carries
descriptor 7 across one exec. It is taken before the plan runs and held until
the last entry is gone, so the interval between classifying an object and
removing it holds no window a producer can start inside. A per-acquisition lock
is read as a classification input and never taken, because a check that takes a
lock, releases it, and then removes reopens the race it was meant to close.

## Declining a deletion and authorizing one are different acts

Refusing needs no verification of anything: a hold or an absent review is
enough. Permitting needs the reason the permission rests on to be true.

| Decision | What it requires |
| --- | --- |
| `hold`, `retain` | refuse; nothing further is read |
| `dispose`, `verified-copy-retained` | the destination recoverable and outside this same plan |
| `dispose`, `intentional-discard` | an authorization stating that no retained replacement is relied on |

The second reason is parsed and refused. Determining the retained destination
and its evidence is what evidence disposition owns, and a duplicate-based
removal against an unverified destination is the intentional discard it was
not declared to be. The refusal names the reason rather than silently
converting one decision into the other.

The third admits, and its authorization binds four things: the acquisition
identity, the payload manifest digest, the requested action, and the plan
identity. An arbitrary nonempty string authorizes nothing -- a record carried
to a second acquisition, reused after the payload moved, or replayed against a
different removal fails one of the four. No approval service and no signing
system stands behind it; it is a local operator record whose scope the code
checks.

## Validation is all-or-nothing; a removal is not

The plan is validated whole and refuses whole. A sequence of filesystem
removals is a sequence rather than a transaction, and bytes already gone do not
return. The removal therefore writes a journal naming what it removed, what it
kept, and where it stopped, and reports `incomplete` with a non-zero exit
rather than printing a success the tree does not hold. No rollback is
attempted, because none exists.

The journal lives outside what the removal destroys. `uninstall` keeps `state`
and defaults there; `purge` removes `state` too and requires
`QWEN_DELETION_JOURNAL` to name a path resolving outside the root, which is the
same error class as three copies inside one boundary.

## What the tests cover

`remote/test-deletion-plan.sh` runs 62 checks over fixture roots, and every
refusal arm asserts two things together: the command exits non-zero, and an
unrelated sibling seeded beside the protected object is still there afterwards.

The enumeration arm decides whether the mechanism works at all. Its fixture
seeds an acquisition carrying no control directory anywhere, which is what the
retained sweep is, so the refusal has to come from the plan enumerating the
children of a protected layout directory rather than from finding a record to
read. A preflight that iterated objects carrying declarations would leave every
undeclared acquisition invisible and remove it.

One arm separates the two enumerations. The removal iterates the root-level
rows of the plan report rather than taking its own reading of the root, so an
entry created after the classification is outside what the loop can reach. The
exclusion leaf is the one root entry the plan leaves out, so a loop re-reading
the root removes it and a loop reading the plan cannot: its survival past an
admitted uninstall is what distinguishes them.

Three arms isolate one mechanism each against an otherwise complete proof --
the fingerprint against a `touch` that moves no byte, the lock against a sealed
and authorized disposal, and the duplicate reason against the same -- so a
mutation that disables one of them fails a refusal rather than only a reason
string.

Seven mutation controls were run against the suite, each disabling one
mechanism in `check-deletion-plan.sh`:

| Mutation | Killed by |
| --- | --- |
| an absent control directory admits | `unreviewed_acquisition_refuses` |
| the plan enumerates objects carrying a declaration | `unreviewed_acquisition_refuses` |
| an absent producer lock reads as free | `absent_lock_alone_refuses` |
| the fingerprint comparison never differs | `timestamp_alone_refuses` |
| the authorization's plan binding is unchecked | `replayed_authorization_refuses` |
| a duplicate-based disposal admits | `duplicate_reason_alone_refuses` |
| a deployment refuses only through a role link | `unreferenced_deployment_refuses` |

## Falsifiers

The mechanism fails if any of these holds.

- A `results/` or `deployments/` child carrying no control directory is
  removed by either action.
- A removal proceeds past a plan row reading `refuse`.
- A same-size rewrite with the modification timestamp returned passes a
  disposal whose decision was sealed before it.
- An authorization written for one acquisition, one payload, one action, or
  one plan admits a different one.
- An absent producer lock admits a disposal.
- `payload-manifest` or `fingerprint` blocks on a FIFO rather than
  inventorying it by type.
- The plan identity moves between the operator's read and the removal's own
  read of the same root.
- The removal reaches a root entry the plan did not classify.
- A partial removal reports completion.

## What this does not do

It verifies no retained destination, which is why `verified-copy-retained` is
refused rather than admitted. It writes no decision record; an operator writes
one, reading the fingerprint and payload digests out of this script's own
`fingerprint` and `payload-manifest` subcommands. It adopts no legacy
acquisition into the lock protocol. It reads a path holding a newline as
`unrepresentable-path` and refuses rather than digesting a listing it would
misparse.
