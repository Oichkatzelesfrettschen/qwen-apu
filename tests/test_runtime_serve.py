"""Router-mode serving: the preset subject, and the argv composed from the bundle.

`qwen-apu serve --model` starts one checkpoint while the gateway's roster
answered for thirteen, which is the gap this pass closes from the serving side.
Router mode reads the activated bundle instead: the preset names the sections,
the bundle's checkpoint ledger states each section's checkpoint count, the
bundle's `llama-server` is the identity the build guard measures, and
`q4k-policy.tsv` beside them is the formulation authority the preset was
generated against.

Two claims are separated here. `router_preflight_subject` is the selection
`qwen-launch.sh` performs before the memory preflight -- the largest resident
section, a draft pairing charged as the sum of both checkpoints -- and it is
tested over presets alone. The composition is then tested by building the whole
plan against a fixture bundle and reading the argv the policy produced, which is
where a preset, ledger, or server taken from somewhere other than the bundle
would show up.
"""

from __future__ import annotations

import hashlib
import shutil
import threading
import time
from pathlib import Path

import pytest

from qwen_apu.config.models import model_by_id
from qwen_apu.runtime import serve as serving
from qwen_apu.runtime.deployment import ActiveDeployment
from qwen_apu.runtime.paths import RuntimePaths
from qwen_apu.runtime.policy import PolicyError, preset_sections, router_preflight_subject
from qwen_apu.runtime.state import RuntimeRecord, RuntimeState

TREE = Path(__file__).resolve().parents[1]
REMOTE = TREE / "remote"
FIXTURE_SERVER = REMOTE / "test-fixtures" / "fake-llama-server.sh"

# The registry row and the preset section `tests/test_runtime_policy.py` builds
# its router parity case from: every tuple value differs from a built-in
# fallback, so a read of the registry is separable from a read of the default.
FABRICATED_ROW = "\t".join(
    [
        "fabricated",
        "research",
        "fabricated.gguf",
        "download-qwen38-4b-distill-q4km.sh",
        "4096",
        "8192",
        "8192",
        "q5_1",
        "iq4_nl",
        "auto",
        "none",
        "-",
        "-",
        "-",
        "untested",
        "candidate",
        "256",
        "64",
        "4096",
        "-",
        "unmeasured",
        "refused",
        "-",
    ]
)

ROUTER_SECTION = "\n".join(
    [
        "[fabricated]",
        "LLAMA_ARG_MODEL = {model}",
        "LLAMA_ARG_CTX_SIZE = 4096",
        "LLAMA_ARG_CACHE_TYPE_K = q5_1",
        "LLAMA_ARG_CACHE_TYPE_V = iq4_nl",
        "LLAMA_ARG_FLASH_ATTN = auto",
        "LLAMA_ARG_BATCH = 256",
        "LLAMA_ARG_UBATCH = 64",
        "LLAMA_ARG_CTX_CHECKPOINTS = 0",
        "",
    ]
)


def _write_server(directory: Path) -> Path:
    """A copy of the fixture server beside a manifest that measures the copy.

    `qwen-build-exec-guard.sh` reads the manifest next to the selected server and
    compares the executable row's byte count and digest against the file, so a
    stand-in for a promoted build is a copy beside its own manifest.
    """
    directory.mkdir(parents=True, exist_ok=True)
    server = directory / "llama-server"
    shutil.copy2(FIXTURE_SERVER, server)
    server.chmod(0o755)
    payload = server.read_bytes()
    (directory / "artifact-manifest.tsv").write_text(
        "preset\tfixture\n"
        "checkpoint_semantics\tnatural-boundary-v1\n"
        f"executable\tllama-server\t{len(payload)}\t{hashlib.sha256(payload).hexdigest()}\n",
        encoding="utf-8",
    )
    return server


@pytest.fixture
def fixture_tree(tmp_path: Path) -> dict[str, Path]:
    """A tree whose `remote/` carries the fabricated ledgers, and a bundle beside it."""
    tree = tmp_path / "tree"
    remote = tree / "remote"
    remote.mkdir(parents=True)
    (remote / "models.tsv").write_text(FABRICATED_ROW + "\n", encoding="utf-8")
    (remote / "quarantine.tsv").write_text("", encoding="utf-8")
    (remote / "draft-pairs.tsv").write_text(
        "# the fabricated registry admits no draft pairing\n", encoding="utf-8"
    )

    paths = RuntimePaths(tree=tree, root=tmp_path / "runtime")
    paths.lay_out()
    weights = paths["qwen_home_models"] / "fabricated.gguf"
    weights.write_bytes(b"")

    bundle = paths["qwen_home_deployments"] / "bundle-fixture"
    server = _write_server(bundle)
    (bundle / "ctx-checkpoints.tsv").write_text(
        "# the fabricated registry admits no checkpoint count\n", encoding="utf-8"
    )
    (bundle / "bundle-manifest.tsv").write_text("name\tbundle-fixture\n", encoding="utf-8")
    presets = bundle / "router-presets.ini"
    presets.write_text(ROUTER_SECTION.format(model=weights), encoding="utf-8")
    return {
        "paths": paths,
        "bundle": bundle,
        "server": server,
        "presets": presets,
        "weights": weights,
    }


def _active(fixture: dict[str, Path], *, router_presets: Path | None = None) -> ActiveDeployment:
    bundle = fixture["bundle"]
    return ActiveDeployment(
        directory=bundle,
        name="bundle-fixture",
        server=bundle / "llama-server",
        ledger=bundle / "ctx-checkpoints.tsv",
        manifest=bundle / "bundle-manifest.tsv",
        router_presets=router_presets if router_presets is not None else fixture["presets"],
        web_presets=None,
    )


# ---------------------------------------------------------------------------
# The preset reader and the preflight subject
# ---------------------------------------------------------------------------


def test_preset_sections_names_every_section_and_leaves_the_defaults_out(tmp_path: Path) -> None:
    presets = tmp_path / "router-presets.ini"
    presets.write_text(
        "[*]\nLLAMA_ARG_CTX_SIZE = 1024\n\n[alpha]\nLLAMA_ARG_MODEL = /a.gguf\n\n"
        "[beta]\nLLAMA_ARG_MODEL = /b.gguf\n",
        encoding="utf-8",
    )
    sections = preset_sections(presets)
    assert [section.name for section in sections] == ["alpha", "beta"]
    assert sections[0].value("LLAMA_ARG_MODEL") == "/a.gguf"
    assert sections[0].count("LLAMA_ARG_MODEL") == 1


def test_the_subject_is_the_largest_section(tmp_path: Path) -> None:
    small = tmp_path / "small.gguf"
    small.write_bytes(b"x" * 16)
    large = tmp_path / "large.gguf"
    large.write_bytes(b"x" * 64)
    presets = tmp_path / "router-presets.ini"
    presets.write_text(
        f"[small]\nLLAMA_ARG_MODEL = {small}\n\n[large]\nLLAMA_ARG_MODEL = {large}\n",
        encoding="utf-8",
    )
    subject = router_preflight_subject(presets)
    assert subject.section == "large"
    assert subject.model == large
    assert subject.resident_bytes == 64


def test_a_draft_pairing_charges_both_checkpoints(tmp_path: Path) -> None:
    """`common_speculative_init_result` loads the draft as its own model.

    The draft path becomes a second resident checkpoint beside the target rather
    than reusing the target's buffers, so the section's subject is the sum; a
    single-checkpoint section that is larger on its own can still lose the
    selection to a smaller pair.
    """
    target = tmp_path / "target.gguf"
    target.write_bytes(b"x" * 40)
    draft = tmp_path / "draft.gguf"
    draft.write_bytes(b"x" * 30)
    alone = tmp_path / "alone.gguf"
    alone.write_bytes(b"x" * 50)
    presets = tmp_path / "router-presets.ini"
    presets.write_text(
        f"[alone]\nLLAMA_ARG_MODEL = {alone}\n\n"
        f"[pair]\nLLAMA_ARG_MODEL = {target}\nLLAMA_ARG_SPEC_DRAFT_MODEL = {draft}\n",
        encoding="utf-8",
    )
    subject = router_preflight_subject(presets)
    assert subject.section == "pair"
    assert subject.draft == draft
    assert subject.resident_bytes == 70


def test_a_section_with_two_models_refuses(tmp_path: Path) -> None:
    weights = tmp_path / "a.gguf"
    weights.write_bytes(b"x")
    presets = tmp_path / "router-presets.ini"
    presets.write_text(
        f"[both]\nLLAMA_ARG_MODEL = {weights}\nLLAMA_ARG_MODEL = {weights}\n", encoding="utf-8"
    )
    with pytest.raises(PolicyError) as refusal:
        router_preflight_subject(presets)
    assert "requires exactly one LLAMA_ARG_MODEL" in " ".join(refusal.value.messages)


def test_a_preset_with_no_model_section_refuses(tmp_path: Path) -> None:
    presets = tmp_path / "router-presets.ini"
    presets.write_text("[*]\nLLAMA_ARG_CTX_SIZE = 1024\n", encoding="utf-8")
    with pytest.raises(PolicyError) as refusal:
        router_preflight_subject(presets)
    assert "carries no model section" in " ".join(refusal.value.messages)


def test_a_section_naming_a_file_that_is_not_there_refuses(tmp_path: Path) -> None:
    presets = tmp_path / "router-presets.ini"
    presets.write_text(
        "[absent]\nLLAMA_ARG_MODEL = /weights/never-fetched.gguf\n", encoding="utf-8"
    )
    with pytest.raises(PolicyError) as refusal:
        router_preflight_subject(presets)
    assert "is not a regular file" in " ".join(refusal.value.messages)


# ---------------------------------------------------------------------------
# The plan composed from the bundle
# ---------------------------------------------------------------------------


def test_router_mode_composes_its_argv_from_the_activated_bundle(
    fixture_tree: dict[str, Path],
) -> None:
    """Every router input comes from the bundle rather than from a default.

    The preset under `--models-preset` is the bundle's own file, the server is
    the bundle's executable, and `--models-max` carries the request's limit. The
    six per-checkpoint flags stay off this argv, because `common_preset::merge`
    would push one value onto every served section.
    """
    paths = fixture_tree["paths"]
    request = serving.ServeRequest(router=True, port=18080, require_radv_icd=False)
    plan = serving.build_plan(paths, request, active=_active(fixture_tree))

    assert plan.mode == "router"
    assert plan.deployment == "bundle-fixture"
    assert plan.model_id == "router"
    assert plan.expected_models == ("fabricated",)
    assert plan.argv[0] == str(fixture_tree["server"])
    joined = " ".join(plan.argv)
    assert f"--models-preset {fixture_tree['presets']} --models-max 1" in joined
    for absent in ("--model ", "--ctx-size", "--batch-size", "--ubatch-size", "--alias"):
        assert absent not in joined
    # The supervisor reads a router plan's readiness without requiring a name,
    # since --models-max 1 leaves every other section unloaded by design.
    assert plan.required_models == ()


def test_the_router_limit_reaches_the_argv(fixture_tree: dict[str, Path]) -> None:
    paths = fixture_tree["paths"]
    plan = serving.build_plan(
        paths,
        serving.ServeRequest(router=True, router_max=2, port=18080, require_radv_icd=False),
        active=_active(fixture_tree),
    )
    assert "--models-max 2" in " ".join(plan.argv)


def test_a_bundle_carrying_no_router_preset_refuses(fixture_tree: dict[str, Path]) -> None:
    """A bundle that serves one model at a time is named as such rather than assumed."""
    active = ActiveDeployment(
        directory=fixture_tree["bundle"],
        name="bundle-fixture",
        server=fixture_tree["bundle"] / "llama-server",
        ledger=fixture_tree["bundle"] / "ctx-checkpoints.tsv",
        manifest=fixture_tree["bundle"] / "bundle-manifest.tsv",
        router_presets=None,
        web_presets=None,
    )
    with pytest.raises(ValueError, match="carries no router-presets.ini"):
        serving.build_plan(
            fixture_tree["paths"],
            serving.ServeRequest(router=True, require_radv_icd=False),
            active=active,
        )


def test_an_explicit_server_is_refused_in_router_mode(fixture_tree: dict[str, Path]) -> None:
    """The bundle's server carries the artifact manifest the preset was validated against."""
    with pytest.raises(ValueError, match="research arm"):
        serving.build_plan(
            fixture_tree["paths"],
            serving.ServeRequest(
                router=True,
                llama_server=fixture_tree["server"],
                require_radv_icd=False,
            ),
            active=_active(fixture_tree),
        )


def test_the_single_model_plan_expects_the_alias_its_argv_names(
    fixture_tree: dict[str, Path],
) -> None:
    """`--alias qwen-apu` is what the server reports, so readiness compares that.

    Requiring the registry id instead would refuse every healthy single-model
    launch, since the argv never gives the server that name.
    """
    paths = fixture_tree["paths"]
    row = model_by_id(serving.DEFAULT_MODEL)
    weights = paths["qwen_home_models"] / row.model_file
    weights.parent.mkdir(parents=True, exist_ok=True)
    weights.write_bytes(b"")
    plan = serving.build_plan(
        paths,
        serving.ServeRequest(
            model_id=serving.DEFAULT_MODEL,
            llama_server=fixture_tree["server"],
            port=18080,
            require_radv_icd=False,
        ),
    )
    assert plan.mode == "standalone"
    assert plan.expected_models == (serving.ROUTER_ALIAS,)
    assert plan.required_models == (serving.ROUTER_ALIAS,)
    assert f"--alias {serving.ROUTER_ALIAS}" in " ".join(plan.argv)


# ---------------------------------------------------------------------------
# The detached launch's own wait
# ---------------------------------------------------------------------------


def test_the_daemon_wait_passes_over_the_previous_run_s_record(tmp_path: Path) -> None:
    """A stale `stopped` record is the previous supervisor's, not this launch's.

    The detached supervisor spends its interpreter startup before it publishes
    anything, so the first reads land on whatever the last run left. After a
    clean stop that record is terminal, and a wait acting on it would report a
    failure while the new supervisor loads a model behind it. The wait passes
    over every record still naming the superseded pid.
    """
    paths = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    paths.lay_out()
    record = RuntimeRecord(path=paths["qwen_home_runtime_state"])
    record.write(
        RuntimeState(
            state="stopped",
            supervisor_pid=4242,
            supervisor_start_time=11,
            primary_failure=None,
        )
    )

    def publish_after_a_delay() -> None:
        time.sleep(0.3)
        record.write(
            RuntimeState(
                state="loading",
                supervisor_pid=4343,
                supervisor_start_time=12,
                server_pid=4344,
                server_start_time=13,
            )
        )

    publisher = threading.Thread(target=publish_after_a_delay)
    publisher.start()
    try:
        assert serving._await_ownership(paths, 20.0, 4242) == 0
    finally:
        publisher.join(timeout=10.0)


def test_the_daemon_wait_reports_a_launch_that_failed(tmp_path: Path) -> None:
    """A terminal record from this launch's own supervisor is the failure to report."""
    paths = RuntimePaths(tree=TREE, root=tmp_path / "runtime")
    paths.lay_out()
    RuntimeRecord(path=paths["qwen_home_runtime_state"]).write(
        RuntimeState(
            state="failed",
            supervisor_pid=4343,
            supervisor_start_time=12,
            primary_failure="readiness_refused pid 4344 left before readiness",
        )
    )
    assert serving._await_ownership(paths, 5.0, 4242) == 1


def test_the_built_in_ui_reaches_the_argv_as_ui_alone(fixture_tree: dict[str, Path]) -> None:
    """`ui` adds `--ui` and names no `--path`.

    `tools/server/server-http.cpp` mounts `public_path` at the server root
    where `--path` names one and registers the embedded asset routes where it
    names none, so the plain built-in surface is exactly the flag without the
    directory. A request that leaves `ui` false keeps `--no-ui`.
    """
    paths = fixture_tree["paths"]
    request = serving.ServeRequest(router=True, port=18080, require_radv_icd=False, ui=True)
    plan = serving.build_plan(paths, request, active=_active(fixture_tree))
    joined = " ".join(plan.argv)
    assert "--ui" in plan.argv
    assert "--no-ui" not in plan.argv
    assert "--path" not in joined

    plain = serving.build_plan(
        paths,
        serving.ServeRequest(router=True, port=18080, require_radv_icd=False),
        active=_active(fixture_tree),
    )
    assert "--no-ui" in plain.argv
