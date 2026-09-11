# The runtime root and its deletion plan

The doctrine in `AGENTS.md` states the rule and this file carries the mechanism, the measurements, and the evidence paths behind it in full.

The confirm a removal takes proves an operator meant to run the command, and
`remote/check-deletion-plan.sh` answers the separate question of what the
command selected. `uninstall` and `purge` enumerate their complete selection
through it before the first byte goes, and a plan holding one object it cannot
prove disposable refuses whole, so no sibling is removed while a protected
object stands unresolved. Two object types carry that veto for two reasons: a
measurement acquisition is irreplaceable evidence, and a deployment bundle
stands in a serving or rollback role, which is why a bundle no role link names
is refused the same way -- unreferenced and disposable are different claims.
Every child of `results/` and `deployments/`, and of `models/` under purge, is
one such object, enumerated from the directory rather than from the presence of
a declaration, so an acquisition carrying none reads as `unreviewed` and
refuses; that is what every directory of the retained home sweep is. An entry
under the root outside the layout refuses as unclassified rather than being
read as disposable.

Two identity checks answer two questions at two costs, and the cheap one is
not a content proof. The metadata fingerprint over `(type, relative path,
size, modification time)` detects a changed population and a changed size for
one `find`, and `os.utime` returns a modification timestamp at nanosecond
resolution, so a same-size rewrite reproduces it exactly while the payload
digest moves. A destructive disposal therefore requires the payload manifest,
which hashes every regular file and inventories a FIFO, a socket, and a symlink
by type without opening them. An absent producer lock reads as `unmanaged`
rather than idle, since `flock` is advisory and a free lock proves nothing
about a writer that never took it; both refuse. `runtime-root.sh` holds one
exclusion over `$QWEN_HOME/.deletion.lock` across the classification and the
removal together, and journals what it removed to a path the removal cannot
reach -- `state` by default under uninstall, and an explicit
`QWEN_DELETION_JOURNAL` outside the root under purge, which removes `state`
too. Validation is all-or-nothing and a sequence of removals is not, so a run
that stops part way reports `incomplete` and names where it stopped.
`evidence/deletion-plan-preflight/README.md` carries the object table, the
decision record, the four-field authorization binding, and the falsifiers.

