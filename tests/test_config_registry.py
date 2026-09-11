"""Parity between qwen_apu.config's typed readers and the remote/*.sh authorities.

Every comparison below runs the shell reader through `subprocess.run` with an
explicit argv list (never `shell=True`), the way tests/test_runtime_paths.py
already does for remote/qwen-home.sh.
"""

from __future__ import annotations

import dataclasses
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from qwen_apu.config import models as m
from qwen_apu.config.loader import RegistryError, read_ledger
from qwen_apu.config.schema import MODEL_ROW_FIELDS, VALIDATED_TUPLE_FIELDS

TREE = Path(__file__).resolve().parents[1]
REMOTE = TREE / "remote"
REGISTRY_SH = REMOTE / "model-registry.sh"
CHECK_VALIDATED_TUPLES_SH = REMOTE / "check-validated-tuples.sh"
SH = shutil.which("sh")

requires_sh = pytest.mark.skipif(SH is None, reason="no /bin/sh")


def run_registry(
    args: list[str], env: dict[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    full_env = dict(os.environ)
    if env:
        full_env.update(env)
    return subprocess.run(
        [SH or "sh", str(REGISTRY_SH), *args],
        capture_output=True,
        text=True,
        env=full_env,
        check=False,
    )


def parse_key_value_lines(text: str) -> dict[str, str]:
    result: dict[str, str] = {}
    for line in text.splitlines():
        if not line:
            continue
        name, _, value = line.partition("=")
        result[name] = value
    return result


def field_matches(python_value: object, shell_text: str) -> bool:
    """Compare one dataclass field against the shell's raw text for it.

    A `None` field types the ledger's `-` sentinel and must read back as
    exactly that text. A `float` field is compared numerically, because
    `remote/models.tsv` writes some values with trailing zeroes
    (`22.40`) that `str(float(...))` does not reproduce
    (`22.4`). Every other field compares as its exact string form.
    """
    if python_value is None:
        return shell_text == "-"
    if isinstance(python_value, bool):
        return str(python_value) == shell_text
    if isinstance(python_value, float):
        return python_value == float(shell_text)
    if isinstance(python_value, int):
        return python_value == int(shell_text)
    return python_value == shell_text


# ---------------------------------------------------------------------------
# remote/models.tsv: `id` and `path` selectors, every field, every row
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def model_rows() -> tuple[m.ModelRow, ...]:
    return m.load_models()


@requires_sh
@pytest.mark.parametrize("model_id", [row.id for row in m.load_models()])
def test_model_by_id_matches_shell_every_field(model_id: str) -> None:
    shell_result = run_registry(["id", model_id])
    assert shell_result.returncode == 0, shell_result.stderr
    shell_fields = parse_key_value_lines(shell_result.stdout)
    python_row = m.model_by_id(model_id)
    assert set(shell_fields) == set(MODEL_ROW_FIELDS)
    for field_name in MODEL_ROW_FIELDS:
        python_value = getattr(python_row, field_name)
        assert field_matches(python_value, shell_fields[field_name]), (
            f"{model_id}.{field_name}: python={python_value!r} shell={shell_fields[field_name]!r}"
        )


@requires_sh
@pytest.mark.parametrize("model_id", [row.id for row in m.load_models()])
def test_model_by_path_matches_shell(model_id: str) -> None:
    row = m.model_by_id(model_id)
    selector = f"/opt/qwen-models/{row.model_file}"
    shell_result = run_registry(["path", selector])
    assert shell_result.returncode == 0, shell_result.stderr
    shell_fields = parse_key_value_lines(shell_result.stdout)
    python_row = m.model_by_path(selector)
    assert python_row.id == shell_fields["id"]


@requires_sh
def test_model_by_id_unknown_matches_shell_refusal() -> None:
    shell_result = run_registry(["id", "no-such-model"])
    assert shell_result.returncode != 0
    with pytest.raises(RegistryError):
        m.model_by_id("no-such-model")


@requires_sh
@pytest.mark.parametrize("field_name", MODEL_ROW_FIELDS)
def test_model_by_id_matches_shell_named_field(field_name: str) -> None:
    """The named `id ID FIELD` invocation, over one representative model."""
    model_id = "qwen38-4b-distill"
    shell_result = run_registry(["id", model_id, field_name])
    assert shell_result.returncode == 0, shell_result.stderr
    python_value = getattr(m.model_by_id(model_id), field_name)
    assert field_matches(python_value, shell_result.stdout.rstrip("\n"))


@requires_sh
def test_model_by_id_unknown_field_matches_shell_exit_3() -> None:
    shell_result = run_registry(["id", "qwen38-4b-distill", "no-such-field"])
    assert shell_result.returncode == 3
    assert not hasattr(m.model_by_id("qwen38-4b-distill"), "no_such_field")


# ---------------------------------------------------------------------------
# remote/validated-tuples.tsv: `tuples MODEL_ID`
# ---------------------------------------------------------------------------


@requires_sh
@pytest.mark.parametrize("model_id", [row.id for row in m.load_models()])
def test_tuples_for_matches_shell(model_id: str) -> None:
    shell_result = run_registry(["tuples", model_id])
    python_rows = m.tuples_for(model_id)
    if not python_rows:
        assert shell_result.returncode != 0
        assert shell_result.stdout == ""
        return
    assert shell_result.returncode == 0, shell_result.stderr
    shell_lines = [line for line in shell_result.stdout.splitlines() if line]
    assert len(shell_lines) == len(python_rows)
    for shell_line, python_row in zip(shell_lines, python_rows, strict=True):
        shell_fields = shell_line.split("\t")
        assert len(shell_fields) == len(VALIDATED_TUPLE_FIELDS)
        for index, field_name in enumerate(VALIDATED_TUPLE_FIELDS):
            python_value = getattr(python_row, field_name)
            assert field_matches(python_value, shell_fields[index]), (
                f"{python_row.tuple_id}.{field_name}: "
                f"python={python_value!r} shell={shell_fields[index]!r}"
            )


# ---------------------------------------------------------------------------
# remote/draft-pairs.tsv: `draft-pairs`, whole ledger in order
# ---------------------------------------------------------------------------


@requires_sh
def test_draft_pairs_matches_shell_raw_rows() -> None:
    shell_result = run_registry(["draft-pairs"])
    assert shell_result.returncode == 0, shell_result.stderr
    shell_lines = [line for line in shell_result.stdout.splitlines() if line]
    table = read_ledger(REMOTE / "draft-pairs.tsv", key_index=0)
    raw_lines = ["\t".join(fields) for _line_number, fields in table.rows]
    assert shell_lines == raw_lines
    python_pairs = m.load_draft_pairs()
    assert [pair.pair_id for pair in python_pairs] == [fields[0] for _n, fields in table.rows]


# ---------------------------------------------------------------------------
# remote/ctx-checkpoints.tsv: `ctx-checkpoints`, whole ledger in order
# ---------------------------------------------------------------------------


@requires_sh
def test_ctx_checkpoints_matches_shell_raw_rows() -> None:
    shell_result = run_registry(["ctx-checkpoints"])
    assert shell_result.returncode == 0, shell_result.stderr
    shell_lines = [line for line in shell_result.stdout.splitlines() if line]
    table = read_ledger(REMOTE / "ctx-checkpoints.tsv", key_index=0)
    raw_lines = ["\t".join(fields) for _line_number, fields in table.rows]
    assert shell_lines == raw_lines
    python_rows = m.load_ctx_checkpoints()
    assert [row.model_id for row in python_rows] == [fields[0] for _n, fields in table.rows]


# ---------------------------------------------------------------------------
# remote/quarantine.tsv: `quarantine-rows`, whole ledger in order
# ---------------------------------------------------------------------------


@requires_sh
def test_quarantine_matches_shell_raw_rows() -> None:
    shell_result = run_registry(["quarantine-rows"])
    assert shell_result.returncode == 0, shell_result.stderr
    shell_lines = [line for line in shell_result.stdout.splitlines() if line]
    table = read_ledger(REMOTE / "quarantine.tsv", key_index=0)
    raw_lines = ["\t".join(fields) for _line_number, fields in table.rows]
    assert shell_lines == raw_lines
    python_rows = m.load_quarantine()
    assert [row.id for row in python_rows] == [fields[0] for _n, fields in table.rows]
    for row, (_line_number, fields) in zip(python_rows, table.rows, strict=True):
        # scope `model` carries `-` across the six geometry columns; scope
        # `profile` fills them, and the loader must round-trip both shapes.
        if row.scope == "model":
            assert fields[4:10] == ("-",) * 6
            assert (row.depth, row.batch, row.ubatch) == (None, None, None)
            assert (row.cache_type_k, row.cache_type_v, row.flash_attention) == (
                None,
                None,
                None,
            )
        else:
            assert row.depth == int(fields[4])
            assert row.batch == int(fields[5])
            assert row.ubatch == int(fields[6])
            assert row.cache_type_k == fields[7]
            assert row.cache_type_v == fields[8]
            assert row.flash_attention == fields[9]


# ---------------------------------------------------------------------------
# remote/model-artifacts.tsv, remote/web-profiles.tsv, remote/feature-claims.tsv:
# no shell subcommand ports these ledgers whole, so this checks the live
# ledgers load and validate cleanly and pins the row counts this session
# observed by hand.
# ---------------------------------------------------------------------------


def test_model_artifacts_web_profiles_feature_claims_load(
    model_rows: tuple[m.ModelRow, ...],
) -> None:
    """No shell subcommand ports these three ledgers whole, so this checks
    each against its own raw row count rather than a number pinned by hand:
    the loader must drop and duplicate no row of the live ledger.
    """
    artifacts = m.load_model_artifacts()
    artifact_table = read_ledger(REMOTE / "model-artifacts.tsv", key_index=0)
    assert len(artifacts) == len(artifact_table.rows)
    # remote/model-artifacts.tsv carries one row per remote/download-*.sh
    # artifact, which is wider than remote/models.tsv: a projector, an
    # unregistered bf16 or i1 rung, and a pre-admission candidate each fetch
    # under their own model_id without a models.tsv row of their own. The
    # direction that must hold is the other one -- every models.tsv row whose
    # fetch_script names a download script (excluding a derive-*.sh row,
    # which is produced on the appliance rather than fetched) has its pin.
    servable_ids = {row.id for row in model_rows if row.fetch_script.startswith("download-")}
    assert servable_ids <= {row.model_id for row in artifacts}

    web_profiles = m.load_web_profiles(models=model_rows)
    web_profile_table = read_ledger(REMOTE / "web-profiles.tsv", key_index=0)
    assert len(web_profiles) == len(web_profile_table.rows)
    assert {row.model_id for row in web_profiles} <= {row.id for row in model_rows}

    draft_pairs = m.load_draft_pairs(models=model_rows)
    feature_claims = m.load_feature_claims(
        models=model_rows, draft_pairs=draft_pairs, web_profiles=web_profiles
    )

    def feature_claim_key(fields: tuple[str, ...]) -> str:
        return f"{fields[0]}\x00{fields[1]}"

    feature_claim_table = read_ledger(REMOTE / "feature-claims.tsv", key_fn=feature_claim_key)
    assert len(feature_claims) == len(feature_claim_table.rows)


# ---------------------------------------------------------------------------
# remote/llama-patch-series.tsv: production members, then candidate members
# ---------------------------------------------------------------------------


def test_patch_series_order_matches_tsv() -> None:
    table = read_ledger(REMOTE / "llama-patch-series.tsv", key_index=1)
    raw_rows = [(fields[0], fields[1]) for _line_number, fields in table.rows]
    python_rows = [(member.stage, member.patch) for member in m.load_patch_series()]
    assert python_rows == raw_rows
    stages = [stage for stage, _patch in python_rows]
    assert stages == sorted(stages, key=lambda stage: stage == "candidate")


# ---------------------------------------------------------------------------
# check-validated-tuples.sh: the models.tsv <-> validated-tuples.tsv arm
# ---------------------------------------------------------------------------


@requires_sh
def test_check_validated_tuples_cross_check_accepts_live_ledgers(
    model_rows: tuple[m.ModelRow, ...],
) -> None:
    shell_result = subprocess.run(
        [SH or "sh", str(CHECK_VALIDATED_TUPLES_SH)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert shell_result.returncode == 0, shell_result.stderr
    # `check_validated_tuples=accepted checked=N reviewers=M` names N as the
    # count of models.tsv rows the shell actually walked into the tuple
    # comparison. Asserting only "both sides accept" cannot distinguish that
    # from both sides silently checking zero rows, so this pins N against the
    # same count computed from the loaded rows.
    checked_match = re.search(r"checked=(\d+)", shell_result.stdout)
    assert checked_match is not None, shell_result.stdout
    shell_checked = int(checked_match.group(1))
    python_checked = sum(1 for row in model_rows if row.validated_filled_depth is not None)
    assert shell_checked == python_checked
    assert shell_checked > 0
    m.check_validated_filled_depth_tuples(models=model_rows)


def test_check_validated_tuples_cross_check_finds_injected_gap(
    model_rows: tuple[m.ModelRow, ...],
) -> None:
    tuples = m.load_validated_tuples(models=model_rows)
    target = next(row for row in model_rows if row.validated_filled_depth is not None)
    mutated_target = dataclasses.replace(target, validated_filled_depth=99999)
    mutated_models = tuple(mutated_target if row.id == target.id else row for row in model_rows)
    with pytest.raises(RegistryError):
        m.check_validated_filled_depth_tuples(models=mutated_models, tuples=tuples)


# ---------------------------------------------------------------------------
# Standalone validators
# ---------------------------------------------------------------------------


@requires_sh
@pytest.mark.parametrize(
    "tier", ["production", "candidate", "quarantine", "archive", "rejected", "bogus-tier"]
)
def test_validate_tier_matches_shell(tier: str) -> None:
    shell_result = run_registry(["validate-tier", tier])
    assert (shell_result.returncode == 0) == m.validate_tier(tier)


@requires_sh
@pytest.mark.parametrize(
    "cache_type", ["f32", "f16", "bf16", "q8_0", "q5_1", "q5_0", "q4_1", "q4_0", "iq4_nl", "bogus"]
)
def test_validate_cache_type_matches_shell(cache_type: str) -> None:
    shell_result = run_registry(["validate-cache-type", cache_type])
    assert (shell_result.returncode == 0) == m.validate_cache_type(cache_type)


@requires_sh
@pytest.mark.parametrize(
    "variant",
    ["-", "production/4", "e4/2", "e4-scale/4", "e4-scale-licm/8", "e4/16", "bogus"],
)
def test_validate_q4k_variant_matches_shell(variant: str) -> None:
    shell_result = run_registry(["validate-q4k-variant", variant])
    assert (shell_result.returncode == 0) == m.validate_q4k_variant(variant)


# ---------------------------------------------------------------------------
# Negative fixtures: Python refuses what the shell refuses
# ---------------------------------------------------------------------------


def _write(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8")


VALIDATED_TUPLES_HEADER = (
    "# tuple_id\tmodel_id\truntime_mode\tcontext\tbatch\tubatch\tcache_k\tcache_v\t"
    "flash_attention\tthreads\tparallel\tprojector_state\tbackend\tstatus\tevidence\t"
    "llama_commit\trunner_sha256\tkernel\tmesa\tamdgpu\tmeasured_at\n"
)


def _validated_tuple_row(**overrides: str) -> str:
    fields = {
        "tuple_id": "fixture-tuple",
        "model_id": "qwen38-2b-distill",
        "runtime_mode": "standalone",
        "context": "8192",
        "batch": "128",
        "ubatch": "32",
        "cache_k": "q8_0",
        "cache_v": "q4_0",
        "flash_attention": "on",
        "threads": "2",
        "parallel": "1",
        "projector_state": "none",
        "backend": "vulkan",
        "status": "validated",
        "evidence": "evidence/fixture/",
        "llama_commit": "-",
        "runner_sha256": "-",
        "kernel": "-",
        "mesa": "-",
        "amdgpu": "-",
        "measured_at": "-",
    }
    fields.update(overrides)
    order = [
        "tuple_id",
        "model_id",
        "runtime_mode",
        "context",
        "batch",
        "ubatch",
        "cache_k",
        "cache_v",
        "flash_attention",
        "threads",
        "parallel",
        "projector_state",
        "backend",
        "status",
        "evidence",
        "llama_commit",
        "runner_sha256",
        "kernel",
        "mesa",
        "amdgpu",
        "measured_at",
    ]
    return "\t".join(fields[name] for name in order)


@requires_sh
def test_bad_cache_type_refused(tmp_path: Path) -> None:
    ledger = tmp_path / "validated-tuples.tsv"
    _write(
        ledger,
        VALIDATED_TUPLES_HEADER + _validated_tuple_row(cache_k="bogus-cache") + "\n",
    )
    shell_result = run_registry(
        ["tuples", "qwen38-2b-distill"], env={"QWEN_VALIDATED_TUPLES": str(ledger)}
    )
    assert shell_result.returncode != 0
    with pytest.raises(RegistryError):
        m.load_validated_tuples(ledger)


@requires_sh
def test_validated_tuple_without_evidence_refused(tmp_path: Path) -> None:
    ledger = tmp_path / "validated-tuples.tsv"
    _write(
        ledger,
        VALIDATED_TUPLES_HEADER + _validated_tuple_row(evidence="-") + "\n",
    )
    shell_result = run_registry(
        ["tuples", "qwen38-2b-distill"], env={"QWEN_VALIDATED_TUPLES": str(ledger)}
    )
    assert shell_result.returncode != 0
    with pytest.raises(RegistryError):
        m.load_validated_tuples(ledger)


@requires_sh
def test_duplicate_tuple_id_refused(tmp_path: Path) -> None:
    ledger = tmp_path / "validated-tuples.tsv"
    row = _validated_tuple_row()
    _write(ledger, VALIDATED_TUPLES_HEADER + row + "\n" + row + "\n")
    shell_result = run_registry(
        ["tuples", "qwen38-2b-distill"], env={"QWEN_VALIDATED_TUPLES": str(ledger)}
    )
    assert shell_result.returncode != 0
    with pytest.raises(RegistryError):
        m.load_validated_tuples(ledger)


@requires_sh
def test_ctx_checkpoint_field_count_mismatch_refused(tmp_path: Path) -> None:
    ledger = tmp_path / "ctx-checkpoints.tsv"
    _write(
        ledger,
        "# model_id\tctx_checkpoints\tevidence\n"
        "qwen38-2b-distill\t2\tevidence/fixture\textra-field\n",
    )
    shell_result = run_registry(
        ["ctx-checkpoints"], env={"QWEN_CTX_CHECKPOINT_LEDGER": str(ledger)}
    )
    assert shell_result.returncode != 0
    with pytest.raises(RegistryError):
        m.load_ctx_checkpoints(ledger)


DRAFT_PAIRS_HEADER = (
    "# pair_id\ttarget_model_id\tdraft_model_id\ttier\tspec_draft_n_max\t"
    "spec_draft_p_min\tacceptance_floor\tdraft_context\tdraft_cache_type_k\t"
    "draft_cache_type_v\tvalidated_evidence\tnotes\n"
)


def _draft_pair_row(**overrides: str) -> str:
    fields = {
        "pair_id": "fixture-pair",
        "target_model_id": "qwen38-2b-distill",
        "draft_model_id": "qwen35-08b",
        "tier": "candidate",
        "spec_draft_n_max": "2",
        "spec_draft_p_min": "0.00",
        "acceptance_floor": "0.896",
        "draft_context": "24576",
        "draft_cache_type_k": "q8_0",
        "draft_cache_type_v": "q4_0",
        "validated_evidence": "-",
        "notes": "fixture pairing",
    }
    fields.update(overrides)
    order = [
        "pair_id",
        "target_model_id",
        "draft_model_id",
        "tier",
        "spec_draft_n_max",
        "spec_draft_p_min",
        "acceptance_floor",
        "draft_context",
        "draft_cache_type_k",
        "draft_cache_type_v",
        "validated_evidence",
        "notes",
    ]
    return "\t".join(fields[name] for name in order)


@requires_sh
def test_bad_tier_refused(tmp_path: Path) -> None:
    assert m.validate_tier("bogus-tier") is False
    ledger = tmp_path / "draft-pairs.tsv"
    _write(ledger, DRAFT_PAIRS_HEADER + _draft_pair_row(tier="bogus-tier") + "\n")
    shell_result = run_registry(["draft-pairs"], env={"QWEN_DRAFT_PAIRS": str(ledger)})
    assert shell_result.returncode != 0
    with pytest.raises(RegistryError):
        m.load_draft_pairs(ledger)


@requires_sh
def test_candidate_before_production_refused(tmp_path: Path) -> None:
    """Python enforces file order; remote/verify-llama-patch-series.sh's own
    `read_series_stage` reads each stage as an independent `awk` selection and
    stays content with either order, which is the divergence this test pins:
    Python is strictly more conservative than the shell reader that consumes
    this ledger.
    """
    ledger = tmp_path / "llama-patch-series.tsv"
    _write(
        ledger,
        "# stage\tpatch\ncandidate\tfirst-candidate.patch\nproduction\tlate-production.patch\n",
    )
    with pytest.raises(RegistryError):
        m.load_patch_series(ledger)
    # Transcribed from remote/verify-llama-patch-series.sh:41-47's
    # `read_series_stage`; the stage and the ledger path arrive as positional
    # parameters ($1, $2) rather than interpolated into the script text, so a
    # path holding a quote or a semicolon still reaches `awk` as data.
    read_series_stage_awk = "/^#/ || NF == 0 { next } NF != 2 { exit 1 } $1 == stage { print $2 }"
    shell_command = "awk -F'\\t' -v stage=\"$1\" '" + read_series_stage_awk + '\' "$2"'
    production = subprocess.run(
        [SH or "sh", "-c", shell_command, "_", "production", str(ledger)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert production.returncode == 0
    assert production.stdout.strip() == "late-production.patch"


@requires_sh
def test_duplicate_model_id_refused(tmp_path: Path) -> None:
    """Python refuses a duplicate id; the shell `id`/`path` selector does not
    detect it at all, since it returns on the first matching row (`exit 0`)
    without ever scanning for a repeat. That is the deviation this pins: the
    shell's own `id` selector accepts this file and answers with the first
    row.
    """
    real = (REMOTE / "models.tsv").read_text(encoding="utf-8")
    lines = real.splitlines()
    data_lines = [line for line in lines if line and not line.startswith("#")]
    header_lines = [line for line in lines if line.startswith("#") and "\t" in line]
    ledger = tmp_path / "models.tsv"
    _write(ledger, "\n".join([*header_lines, *data_lines, data_lines[0]]) + "\n")
    with pytest.raises(RegistryError):
        m.load_models(ledger)
    duplicated_id = data_lines[0].split("\t")[0]
    shell_result = run_registry(["id", duplicated_id], env={"QWEN_MODEL_REGISTRY": str(ledger)})
    assert shell_result.returncode == 0
    assert shell_result.stdout.startswith(f"id={duplicated_id}\n")


@requires_sh
def test_model_row_with_extra_fields_accepted_by_shell_id_selector(tmp_path: Path) -> None:
    """The shell `id`/`path` selector tests `NF < 23 { next }`, so a row with
    *more* than 23 fields is accepted and its first 23 fields are read
    normally; `read_ledger` refuses any field-count mismatch in either
    direction. This is the accept-direction half of the strictness note in
    this module's own docstring.
    """
    real_lines = (REMOTE / "models.tsv").read_text(encoding="utf-8").splitlines()
    header_lines = [line for line in real_lines if line.startswith("#") and "\t" in line]
    first_data_line = next(line for line in real_lines if line and not line.startswith("#"))
    ledger = tmp_path / "models.tsv"
    _write(ledger, "\n".join([*header_lines, first_data_line + "\textra-column"]) + "\n")
    model_id = first_data_line.split("\t")[0]
    shell_result = run_registry(["id", model_id], env={"QWEN_MODEL_REGISTRY": str(ledger)})
    assert shell_result.returncode == 0
    with pytest.raises(RegistryError):
        m.load_models(ledger)
