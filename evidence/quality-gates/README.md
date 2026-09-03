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
