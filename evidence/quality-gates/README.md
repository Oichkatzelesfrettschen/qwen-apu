# Sparse gate cell identity

`remote/repository-quality-gates.sh` registers each of its checks through
`gate_cell NAME KIND SPEC COMMAND` in `remote/gate-cell-key.sh`. A cell's key is
the SHA-256 of a manifest carrying its name, its command, the identity of every
tool the gate can invoke, the identity of the driver script and of the reader
itself, its read-set state (`bounded`, `unbounded`, or `universal`), and a
`digest mode path` line for every file `gate_cell_read_set` derives from KIND
and SPEC. An accepted record under that key is reused rather than rerun, so
`remote/test-repository-gate-cells.sh` is the proof that the key moves whenever
something the cell's own verdict depends on moves, over a fixture gate of four
tiny cells rather than the real gate's dozens of minutes-long ones.

Every pull request uses `remote/run-pull-request-gate.py`, independent of its
draft state. The driver maps each changed path to the bounded input surfaces
that consume it and runs the union of their checks. Evidence changes run the
evidence manifest and text policy; documentation changes run the text policy;
Web UI changes add the feature roster, fallback-page behavior checks, browser
fixture, and linters for changed shell and Python files. Browser-preflight,
Q8-attribution, CI-routing, and gate-infrastructure inputs retain their focused
fixtures. An unclassified executable or runtime path delegates to the
exhaustive gate. Scheduled and manual runs also execute the exhaustive gate.

`evidence/SHA256SUMS` belongs to the evidence surface. The manifest accompanies
a changed evidence directory and does not classify that directory as gate
infrastructure. A pull request that combines recognized surfaces runs their
deduplicated union rather than falling through because two independently
bounded path classes appear together.

The hosted runner saves accepted bounded-cell records under a unique immutable
cache key and restores the newest earlier key for the same operating system.
The record's content digest still decides reuse. A cache hit therefore reduces
work without letting a record certify different source or tool bytes. An
exact-tree main push reuses either the accepted targeted PR result or the
accepted exhaustive PR result. Only an exhaustive source supplies a cell-cache
artifact for promotion; targeted reuse records its source identity without
inventing an exhaustive cache.

## What the key binds

- **Every file the cell reads.** `gate_cell_named_paths` walks a `remote/`,
  `evidence/`, or `patches/` literal, a `$script_directory/NAME` construction,
  and every filename or bare Python import `gate_cell_sibling_paths` resolves,
  one level of indirection deep from the cell's own seed and one more level
  from each file that seed names. A path the tree lacks enters the manifest as
  `absent`, so the key moves when the file first appears.
- **The executable mode of each file.** `gate_cell_hash_line` and
  `gate_cell_identity_line` both carry `stat -c '%a'` beside the SHA-256, so a
  cleared or set execute bit moves the key -- several cells run by invoking a
  script directly, where the mode alone decides whether the command reaches an
  interpreter -- and so does a permission change between two modes that leave
  the file executable in both, such as 0755 to 0700, which an earlier
  exec/plain class would have missed.
- **Every tool whose output can change a verdict independently of repository
  bytes.** `gate_cell_tool_versions` resolves shellcheck, ruff, python3, cc,
  c++, bash, sh, node, mypy, git, curl, flock, ps, sha256sum, and the resolved
  Chromium each to their own path and first version-report line, and the
  combined digest is bound into every cell's manifest as `tools=`. `sh` is
  tracked beside `bash` because the gate runs most cells by executing a
  `#!/bin/sh` script directly or by naming `sh script` in its command, so
  whatever `sh` resolves to on the host -- dash on a Debian-family appliance,
  bash itself on this workstation -- decides the interpretation the gate would
  reuse, the same way bash decides `gate_shell_syntax`'s own bash branch.
- **The driver and the reader.** `gate_cell_init` hashes `GATE_CELL_DRIVER_PATH`
  (the invoking script -- `repository-quality-gates.sh` for the gate, the
  fixture's own `remote/gate.sh` for the test) and the `gate-cell-key.sh` that
  sits beside it, and binds the combined digest into every cell as `driver=`.
  Neither file is a path any cell names in its own SPEC, so an edit to
  `gate_shell_syntax` or to `gate_cell_named_paths` used to leave every warm
  record certifying a definition that no longer exists; now it moves every
  bounded cell's key.
- **Cross-directory Python imports and cross-directory script references.**
  `gate_cell_module_search_directories` reports `remote/` plus every immediate
  subdirectory of `remote/` that holds a `.py` file -- `remote/web-mcp/`,
  `remote/image-mcp/`, and any directory added later the same way -- and a
  `.py`, `.sh`, or `.mjs` token (a bare `import NAME`, or a literal filename a
  script names to spawn or exec it) resolves against every one of those
  directories in addition to the reading file's own, with every directory that
  resolves it entering the read set. This closes the gap the filename-only
  reader carried before this change: `remote/image-mcp/server.py` reaches
  `image_protocol.py` in `remote/` and `image_grant.py` in `remote/web-mcp/`
  through `sys.path.insert` rather than its own directory, and
  `remote/image-mcp/test-image-mcp.py` names `remote/web-mcp/authorize-broker.py`
  as a string literal to spawn it; before this change `test-image-mcp`'s read
  set carried neither file, `test-web-mcp`'s carried neither `image_grant.py`
  nor `image-mcp/server.py`, and `test-authorize-broker`'s carried neither the
  image-mcp server nor `image_protocol.py`. A `.tsv`, `.json`, `.ini`, `.md`,
  `.txt`, `.patch`, `.html`, or `.png` token still resolves only beside the
  reading file, because this tree's own prose commonly cites an unrelated
  evidence path for documentation and a directory-wide search over those
  extensions would pull a README's citations into every cell that names it --
  `test-authorize-broker`'s read set already carries two dozen
  `evidence/model-admission/*` paths cited in prose by
  `remote/web-mcp/README.md`, which over-inclusion leaves harmless but a
  directory-wide data search would have multiplied across every directory the
  code search now reaches.
- **An extensionless script that relies on its shebang.** `gate_cell_is_text_path`
  reads a path with no extension at all as text where the tree marks it
  executable, so a script named without a suffix is scanned for the paths it
  names the same way `remote/*.sh` and `remote/*.py` already are, rather than
  being treated as an opaque binary the way a PNG fixture is.
- **A bare-name reference to an extensionless executable.** The filename and
  module readers above both require a `.py`, `.sh`, or `.mjs` suffix, so a
  script that reaches an extensionless helper by joining its own directory
  variable with a literal name in one Python `os.path.join` call named no
  token either reader could match, and the earlier version of this fixture
  only passed because a comment nearby happened to spell the helper's full
  repository path in prose. `gate_cell_bare_name_tokens` now pulls the last,
  dotless argument out of every `os.path.join` call in the file regardless of
  its first argument, and `gate_cell_bare_name_paths` resolves each candidate
  against `gate_cell_named_directories` -- the reading file's own directory,
  every module search directory, the directory of every literal path the same
  file already names, and one further hop through a bare token that is itself
  a directory rather than a leaf (the `"helpers"` in a join of
  `DELTA_DIRECTORY` with that bare name), resolved against that base set
  alone. The extra hop is what resolves a helper reached through a directory
  a script composes purely from two of its own `DIRECTORY` constants, holding
  no `.py` module of its own to put it in the module search set already --
  without it, such a directory would never enter the list and a bare leaf
  named against it would read `unresolved` on that account alone rather than
  on an actual missing file. Each candidate joins the read set with its mode
  bits, the way every other member does, where it names an existing
  executable regular file there, and skipping it silently otherwise:
  over-inclusion at this discovery stage costs at most a few extra `stat(2)`
  calls and can only add a member, never move a cell to `unbounded`. A bare
  token that resolves to a directory rather than a file -- the `"helpers"`
  join itself, evaluated again here as a leaf rather than as the extra hop
  above -- is skipped the same way. Moving a cell to `unbounded` on an
  unresolved token is a narrower decision, in
  `gate_cell_bare_names_are_unresolved`: it judges only
  `gate_cell_bare_name_unbounded_tokens`, the subset of joins whose own first
  argument follows this tree's convention for a directory constant a script
  resolves at run time -- an ALL-CAPS name ending `DIRECTORY`, assigned from
  `os.path.dirname(os.path.abspath(__file__))`, a join of one such name with a
  bare subdirectory, or `os.path.dirname` of one such name (the
  `REMOTE_DIRECTORY` a script derives from its own `SERVER_DIRECTORY`, one
  level up). Unlike discovery, this check does not search every candidate
  directory for a match: `gate_cell_directory_variable_map` traces each
  `DIRECTORY`-suffixed constant to the single directory this reader can prove
  it names, and the check tests the token only there, because binding a bare
  name to a same-spelled executable found in some unrelated directory would
  let the cell stay `bounded` while the reference's actual, still-absent
  target moved nothing. A constant this reader cannot trace to exactly one
  directory this way is judged unresolved on that account alone, the same as
  a target that is genuinely absent. Every other `os.path.join` call in this
  tree -- one composing a state, fixture, or sysfs path from a lowercase
  local or attribute -- is read by the broad discovery pass but never forces
  `unbounded` on a token that names no file at all, which a full-tree sweep
  during this change confirmed resolves nothing outside the scripts this
  change touches. Both readers scan
  through `gate_cell_strip_comment_lines`, which drops every full-line
  comment first, since an unfiltered scan reads a worked example inside a
  comment or docstring the same as a live construction and would mark the
  cell `unbounded` on a reference nothing at run time ever names -- a trailing
  `# comment` sharing a code line still survives this filter, the same
  asymmetry `gate_cell_reads_are_unbounded` already carries against a
  mid-line construction. `gate_cell_bare_name_paths` records every candidate
  directory that resolves a bare name to an executable file, not only the
  first in sort order, the way `gate_cell_sibling_paths` already resolves an
  ambiguous filename: a static reader cannot tell which directory the Python
  variable names at run time, and recording one match would leave the key
  unmoved by an edit to the helper the variable actually resolves to.
  Discovery and the unbounded trigger deliberately disagree on how broadly to
  search, because the two mistakes cost differently: discovery searching
  every candidate directory can only hash a spurious member into the
  manifest, which costs a rerun the next time that member changes and never a
  false reuse, while the unbounded trigger binding to the same spurious
  match would let the cell read `bounded` on a reference whose real target
  stayed absent. `test-repository-gate-cells.sh` now spells the helper's
  reference only as that bare join's last argument, with no comment carrying
  its path, and
  proves both that editing the helper's own bytes or mode moves the key and
  that a bare name in a `DIRECTORY`-suffixed join resolving to nothing marks
  the read set unbounded.
- **An unbounded read set, stated rather than inferred.** Every accepted
  manifest and persisted record now carries `read_set=bounded`,
  `read_set=unbounded`, or `read_set=universal` explicitly, so a reader of a
  cached record sees why a cell always runs without recomputing its KIND and
  SPEC, and `test-repository-gate-cells.sh` reads the persisted record file
  directly to prove the class each cell's record states matches the class its
  behavior already carried.

A construction this reader cannot bound -- `git ls-files`, a path built from a
shell variable, or a `find` over the whole tree -- still marks the cell
`unbounded` and always runs, per `gate_cell_reads_are_unbounded`. Broadening
the code search to `remote/web-mcp/` and `remote/image-mcp/` added read-set
members to eleven cells and flipped none of them from `bounded` to
`unbounded`; a diff of every cell's derived read set before and after this
change, taken with `GATE_CELL_ROOT` pointed at the checked-out tree, showed only
added lines.

## What is still open

The read set is derived from the text of the scripts a cell names, one level
of indirection past what the cell itself names and one more past that; a
dependency reached through a third hop of indirection, or through a
Python import this reader's fixed extension and directory vocabulary does not
cover (a dotted package, a relative import, or a directory added outside
`remote/`), is not read and does not move the key. The design accepts this the
way it accepts a directory over `gate_cell_directory_walk_limit`: an ambiguity
resolves toward running the cell rather than toward a guessed partial read set,
and a construction this reader cannot statically resolve is marked unbounded
rather than silently under-read.

`gate_cell_bare_name_tokens` reads only the Python `os.path.join` construction;
a shell script that composes an extensionless helper as `"$var/NAME"` for a
variable other than the pre-existing `script_directory` substitution, or a
Python script that composes one through string concatenation or an f-string
rather than `os.path.join`, names no token this reader matches and the helper
stays out of the read set the way it did before this change. Widening the
discovery pattern to every quoted string in the file was rejected during this
change for the same reason discovery stays unconstrained on its first
argument while the `unbounded` trigger does not: discovery alone cannot cause
a false reuse, but an unscoped *unbounded* trigger would resolve an ordinary
flag or status literal against the same directories and, finding no file or
directory there, would mark most cells `unbounded` on their own prose rather
than on an actual unread dependency. The `DIRECTORY`-suffix requirement on the
unbounded trigger is itself a residual gap in the other direction: a script
that names its directory constant `HELPERS_DIR` or `helpers_directory` rather
than following the `..._DIRECTORY` convention composes a helper reference the
discovery pass still adds to the read set when the helper resolves, but an
edit that breaks that reference -- the helper renamed or removed -- will not
force the cell to `unbounded`, since the unresolved token never reaches the
narrower check. This tree's own scripts follow the `..._DIRECTORY` convention
throughout, which a full-tree sweep during this change confirmed, so the gap
is latent rather than active.
