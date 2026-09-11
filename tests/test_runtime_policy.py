"""Parity between the runtime policy modules and the three shell scripts they port.

Every argv case runs the shell and Python over one fixture tree and compares
the two argument lists element by element. The shell has no dry run: it execs,
so the fixture server `remote/test-fixtures/fake-llama-server.sh` records the
argv it was launched with into `QWEN_POLICY_TEST_OUTPUT`, which is how
`remote/test-qwen-capacity-policy.sh` reads it too. `qwen-build-exec-guard.sh`
compares that server's own size and digest against the artifact manifest beside
it, so each fixture build is a copy of the fixture script beside a manifest
that measures the copy.

The environment parity cases exec `/usr/bin/env` through
`remote/radv-low-priority-env.sh` and compare the printed environment against
`profile_environment`, less `PWD` and `SHLVL`, which the shell itself sets.
"""

from __future__ import annotations

import hashlib
import os
import shutil
import stat
import subprocess
from collections.abc import Mapping
from pathlib import Path

import pytest

from qwen_apu.runtime import policy as policy_module
from qwen_apu.runtime.environment import ProfileError, profile_environment
from qwen_apu.runtime.policy import PolicyError, plan_from_environment
from qwen_apu.runtime.preflight import PreflightError, build_report

TREE = Path(__file__).resolve().parents[1]
REMOTE = TREE / "remote"
POLICY = REMOTE / "qwen-capacity-policy.sh"
RADV = REMOTE / "radv-low-priority-env.sh"
FIXTURE_SERVER = REMOTE / "test-fixtures" / "fake-llama-server.sh"
SH = shutil.which("sh")
ENV_BINARY = shutil.which("env")

pytestmark = pytest.mark.skipif(SH is None, reason="no sh")

# A registry row whose cache triple, geometry, depth, and formulation differ
# from every built-in fallback, so a check separates the registry read from the
# default rather than agreeing with both.
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


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def write_fixture_build(directory: Path, semantics: str, q4k_variants: str = "") -> Path:
    """A copy of the fixture server beside a manifest measuring that copy.

    `qwen-build-exec-guard.sh` reads the manifest next to the selected server
    and compares the executable row's byte count and digest against the file,
    so a stand-in for a promoted build is a copy beside its own manifest.
    """
    directory.mkdir(parents=True, exist_ok=True)
    server = directory / "llama-server"
    shutil.copy2(FIXTURE_SERVER, server)
    server.chmod(0o755)
    payload = server.read_bytes()
    rows = ["preset\tfixture"]
    if semantics != "absent":
        rows.append(f"checkpoint_semantics\t{semantics}")
    if q4k_variants:
        rows.append(f"q4k_variants\t{q4k_variants}")
    rows.append(f"executable\tllama-server\t{len(payload)}\t{hashlib.sha256(payload).hexdigest()}")
    (directory / "artifact-manifest.tsv").write_text("\n".join(rows) + "\n", encoding="utf-8")
    return server


@pytest.fixture
def appliance(tmp_path: Path) -> dict[str, Path]:
    """One fixture tree: a build, a weights root, a registry, and three ledgers."""
    root = tmp_path.resolve()
    server = write_fixture_build(root / "fixture-build", "natural-boundary-v1")
    model = root / "model.gguf"
    model.write_bytes(b"")
    registry_model = root / "fabricated.gguf"
    registry_model.write_bytes(b"")
    icd = root / "radeon_icd.x86_64.json"
    icd.write_bytes(b"")
    registry = root / "models.tsv"
    registry.write_text(FABRICATED_ROW + "\n", encoding="utf-8")
    draft_pairs = root / "draft-pairs.tsv"
    draft_pairs.write_text("# the fabricated registry admits no draft pairing\n", encoding="utf-8")
    checkpoints = root / "ctx-checkpoints.tsv"
    checkpoints.write_text(
        "# the fabricated registry admits no checkpoint count\n", encoding="utf-8"
    )
    quarantine = root / "quarantine.tsv"
    quarantine.write_text("", encoding="utf-8")
    return {
        "root": root,
        "server": server,
        "model": model,
        "registry_model": registry_model,
        "icd": icd,
        "registry": registry,
        "draft_pairs": draft_pairs,
        "checkpoints": checkpoints,
        "quarantine": quarantine,
        "state": root / "state",
    }


def base_environment(appliance: Mapping[str, Path], output: Path) -> dict[str, str]:
    """The closed environment both authorities run under."""
    return {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "HOME": str(appliance["root"]),
        "QWEN_RADV_ICD": str(appliance["icd"]),
        "QWEN_POLICY_TEST_OUTPUT": str(output),
        "QWEN_WEBUI_STATE_DIRECTORY": str(appliance["state"]),
        "QWEN_MODEL_ROOT": str(appliance["root"]),
        "QWEN_CTX_CHECKPOINT_LEDGER": str(appliance["checkpoints"]),
        "QWEN_DRAFT_PAIRS": str(appliance["draft_pairs"]),
        "QWEN_QUARANTINE_REGISTRY": str(appliance["quarantine"]),
    }


def run_shell_policy(
    arguments: list[str], environment: Mapping[str, str]
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [SH or "sh", str(POLICY), *arguments],
        env=dict(environment),
        capture_output=True,
        text=True,
        check=False,
        cwd=str(TREE),
    )


def recorded_arguments(output: Path) -> list[str]:
    return [
        line[len("argument=") :]
        for line in output.read_text(encoding="utf-8").splitlines()
        if line.startswith("argument=")
    ]


def assert_argv_parity(
    arguments: list[str], environment: Mapping[str, str], output: Path
) -> policy_module.LaunchPlan:
    """Run both authorities and require the recorded argv to equal the plan's."""
    completed = run_shell_policy(arguments, environment)
    assert completed.returncode == 0, completed.stderr
    plan = plan_from_environment(arguments, environment, script_directory=REMOTE)
    assert list(plan.argv[1:]) == recorded_arguments(output)
    return plan


# ---------------------------------------------------------------------------
# remote/radv-low-priority-env.sh
# ---------------------------------------------------------------------------


def shell_environment(ambient: Mapping[str, str]) -> dict[str, str]:
    completed = subprocess.run(
        [SH or "sh", str(RADV), ENV_BINARY or "/usr/bin/env"],
        env=dict(ambient),
        capture_output=True,
        text=True,
        check=True,
        cwd=str(TREE),
    )
    printed: dict[str, str] = {}
    for line in completed.stdout.splitlines():
        name, separator, value = line.partition("=")
        if separator:
            printed[name] = value
    # `sh` sets both itself; neither is part of the profile's own transform.
    printed.pop("PWD", None)
    printed.pop("SHLVL", None)
    return printed


@pytest.mark.skipif(ENV_BINARY is None, reason="no env")
@pytest.mark.parametrize(
    ("profile", "extra"),
    [
        ("paced-60", {}),
        ("low-serialized", {}),
        ("low-async", {}),
        ("custom", {}),
        ("custom", {"GGML_VK_MAX_NODES_PER_SUBMIT": "8"}),
        ("custom", {"GGML_VK_SERIALIZE_SUBMISSIONS": "0"}),
        (
            "custom",
            {
                "GGML_VK_MAX_NODES_PER_SUBMIT": "4",
                "GGML_VK_SERIALIZE_SUBMISSIONS": "1",
                "GGML_VK_ALLOW_GRAPHICS_QUEUE": "1",
                "GGML_VK_SUBMIT_TRACE": "1",
            },
        ),
        ("diagnostic", {"QWEN_PERF_LOGGER": "1000"}),
        ("diagnostic", {"QWEN_PERF_LOGGER": "500", "GGML_VK_FORCE_INTEGER_DOT": "1"}),
        ("low-async", {"QWEN_PIPELINE_CENSUS": "1"}),
        ("low-async", {"QWEN_Q4K_VARIANT": "e4-scale/4"}),
        ("low-async", {"QWEN_FORCE_INTEGER_DOT": "1"}),
        # Names the scrub removes, present in the ambient environment.
        (
            "low-serialized",
            {
                "DISPLAY": ":0",
                "WAYLAND_DISPLAY": "wayland-0",
                "RADV_PERFTEST": "gpl",
                "AMD_PRIORITY": "1",
                "GGML_VK_DISABLE_F16": "1",
                "GGML_VK_VISIBLE_DEVICES": "0",
                "GGML_VK_LOW_PRIORITY": "0",
            },
        ),
    ],
)
def test_profile_environment_matches_shell(
    tmp_path: Path, profile: str, extra: dict[str, str]
) -> None:
    icd = tmp_path / "radeon_icd.x86_64.json"
    icd.write_bytes(b"")
    ambient = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "QWEN_RADV_ICD": str(icd),
        "QWEN_VULKAN_PROFILE": profile,
        "QWEN_UNRELATED": "kept",
        **extra,
    }
    assert profile_environment(profile, ambient) == shell_environment(ambient)


def test_profile_environment_default_profile(tmp_path: Path) -> None:
    icd = tmp_path / "icd.json"
    icd.write_bytes(b"")
    ambient = {"PATH": "/usr/bin", "QWEN_RADV_ICD": str(icd)}
    resulting = profile_environment("", ambient)
    assert resulting["QWEN_VULKAN_PROFILE"] == "low-serialized"
    assert resulting["GGML_VK_SERIALIZE_SUBMISSIONS"] == "1"
    assert resulting["GGML_VK_MAX_NODES_PER_SUBMIT"] == "32"


def test_low_async_leaves_serialization_absent(tmp_path: Path) -> None:
    """`low-async` exports the node count alone, which is the measured arm."""
    icd = tmp_path / "icd.json"
    icd.write_bytes(b"")
    resulting = profile_environment(
        "low-async", {"QWEN_RADV_ICD": str(icd), "GGML_VK_SERIALIZE_SUBMISSIONS": "1"}
    )
    assert resulting["GGML_VK_MAX_NODES_PER_SUBMIT"] == "16"
    assert "GGML_VK_SERIALIZE_SUBMISSIONS" not in resulting


@pytest.mark.parametrize(
    ("profile", "ambient", "message"),
    [
        ("nonsense", {}, "unknown Vulkan profile: nonsense"),
        (
            "low-async",
            {"QWEN_PERF_LOGGER": "1000"},
            "QWEN_PERF_LOGGER belongs to the diagnostic profile alone",
        ),
        (
            "diagnostic",
            {},
            "the diagnostic profile requires QWEN_PERF_LOGGER as a positive decimal frequency: ",
        ),
        (
            "diagnostic",
            {"QWEN_PERF_LOGGER": "0500"},
            "the diagnostic profile requires QWEN_PERF_LOGGER as a positive decimal "
            "frequency: 0500",
        ),
        (
            "diagnostic",
            {"QWEN_PERF_LOGGER": "1000", "GGML_VK_FORCE_INTEGER_DOT": "2"},
            "GGML_VK_FORCE_INTEGER_DOT admits 1 or an unset value: 2",
        ),
        (
            "low-async",
            {"QWEN_Q4K_VARIANT": "e4/3"},
            "QWEN_Q4K_VARIANT is production/4, or e4, e4-scale, or e4-scale-licm "
            "over /2, /4, or /8: e4/3",
        ),
        (
            "low-async",
            {"QWEN_FORCE_INTEGER_DOT": "0"},
            "QWEN_FORCE_INTEGER_DOT admits 1 or an unset value: 0",
        ),
    ],
)
def test_profile_environment_refusals(
    tmp_path: Path, profile: str, ambient: dict[str, str], message: str
) -> None:
    icd = tmp_path / "icd.json"
    icd.write_bytes(b"")
    with pytest.raises(ProfileError) as caught:
        profile_environment(profile, {"QWEN_RADV_ICD": str(icd), **ambient})
    assert str(caught.value) == message


@pytest.mark.skipif(ENV_BINARY is None, reason="no env")
@pytest.mark.parametrize(
    ("profile", "extra"),
    [
        ("nonsense", {}),
        ("low-async", {"QWEN_PERF_LOGGER": "1000"}),
        ("diagnostic", {}),
        ("diagnostic", {"QWEN_PERF_LOGGER": "1000", "GGML_VK_FORCE_INTEGER_DOT": "2"}),
        ("low-async", {"QWEN_Q4K_VARIANT": "e4/3"}),
        ("low-async", {"QWEN_FORCE_INTEGER_DOT": "0"}),
    ],
)
def test_profile_refusal_text_matches_shell(
    tmp_path: Path, profile: str, extra: dict[str, str]
) -> None:
    icd = tmp_path / "icd.json"
    icd.write_bytes(b"")
    ambient = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
        "QWEN_RADV_ICD": str(icd),
        "QWEN_VULKAN_PROFILE": profile,
        **extra,
    }
    completed = subprocess.run(
        [SH or "sh", str(RADV), ENV_BINARY or "/usr/bin/env"],
        env=ambient,
        capture_output=True,
        text=True,
        check=False,
        cwd=str(TREE),
    )
    assert completed.returncode == 2
    with pytest.raises(ProfileError) as caught:
        profile_environment(profile, ambient)
    assert completed.stderr.splitlines() == [str(caught.value)]


def test_unreadable_icd_refuses(tmp_path: Path) -> None:
    missing = tmp_path / "absent.json"
    with pytest.raises(ProfileError) as caught:
        profile_environment("low-async", {"QWEN_RADV_ICD": str(missing)})
    assert str(caught.value) == f"RADV ICD is not readable: {missing}"
    assert caught.value.status == 1


# ---------------------------------------------------------------------------
# remote/model-memory-preflight.sh
# ---------------------------------------------------------------------------

PROBE_TRANSCRIPT = "\n".join(
    [
        "device_name=AMD Radeon Graphics (RADV RAVEN2)",
        "device_vendor=0x1002",
        "device_id=0x15d8",
        "heap_0_size_bytes=2147483648",
        "heap_0_budget_bytes=2147483648",
        "heap_0_usage_bytes=0",
        "heap_0_available_bytes=2147483648",
        "heap_0_flags=0x1",
        "aggregate_budget_bytes=4294967296",
        "aggregate_usage_bytes=1073741824",
        "aggregate_available_bytes=3221225472",
    ]
)

MEMINFO = "\n".join(
    [
        "MemTotal:       30000000 kB",
        "MemFree:         8000000 kB",
        "MemAvailable:   20000000 kB",
        "SwapTotal:       4000000 kB",
        "SwapFree:        3500000 kB",
    ]
)


def test_preflight_report_arithmetic_and_wording(tmp_path: Path) -> None:
    model = tmp_path / "model.gguf"
    model.write_bytes(b"x" * 1234)
    meminfo = tmp_path / "meminfo"
    meminfo.write_text(MEMINFO + "\n", encoding="utf-8")
    report = build_report(model, 2048, probe_output=PROBE_TRANSCRIPT, meminfo_path=meminfo)
    mib = 1048576
    assert report.model_bytes == 1234
    assert report.mem_available_bytes == 20000000 * 1024
    assert report.required_vulkan_bytes == 2048 * mib
    assert report.desktop_reserve_bytes == 4096 * mib
    assert report.vulkan_margin_bytes == 512 * mib
    # The weights are charged once: required_vulkan_bytes already covers the
    # resident copy, so model_bytes stays out of required_host_bytes.
    assert report.required_host_bytes == (2048 + 4096) * mib
    assert report.required_vulkan_with_margin_bytes == (2048 + 512) * mib
    assert report.swap_used_bytes == 500000 * 1024
    assert report.host_headroom == "ample"
    assert report.vulkan_headroom == "ample"
    lines = report.render().splitlines()
    assert lines[0] == "device_name=AMD Radeon Graphics (RADV RAVEN2)"
    assert "model_bytes=1234" in lines
    assert f"required_host_bytes={(2048 + 4096) * mib}" in lines
    assert lines[-1] == "model_memory_preflight=observe"
    assert any(line.startswith("host_memory_headroom=ample surplus_bytes=") for line in lines)


def test_preflight_reports_shortfall_and_still_admits(tmp_path: Path) -> None:
    """A prediction that a model will not fit is a prediction; the load is the test."""
    model = tmp_path / "model.gguf"
    model.write_bytes(b"x")
    meminfo = tmp_path / "meminfo"
    meminfo.write_text(MEMINFO + "\n", encoding="utf-8")
    report = build_report(model, 20480, probe_output=PROBE_TRANSCRIPT, meminfo_path=meminfo)
    assert report.host_headroom == "short"
    assert report.vulkan_headroom == "short"
    rendered = report.render()
    assert "host_memory_headroom=short shortfall_bytes=" in rendered
    assert "vulkan_budget_headroom=short shortfall_bytes=" in rendered
    assert rendered.splitlines()[-1] == "model_memory_preflight=observe"


def test_preflight_refusals(tmp_path: Path) -> None:
    model = tmp_path / "model.gguf"
    model.write_bytes(b"x")
    meminfo = tmp_path / "meminfo"
    meminfo.write_text(MEMINFO + "\n", encoding="utf-8")
    with pytest.raises(PreflightError) as caught:
        build_report(model, "2048x", probe_output=PROBE_TRANSCRIPT, meminfo_path=meminfo)
    assert str(caught.value) == "memory arguments must be non-negative integer MiB values"
    with pytest.raises(PreflightError) as caught:
        build_report(
            tmp_path / "absent.gguf", 2048, probe_output=PROBE_TRANSCRIPT, meminfo_path=meminfo
        )
    assert str(caught.value).startswith("model is not a regular file: ")
    with pytest.raises(PreflightError) as caught:
        build_report(model, 2048, probe_output="device_name=other\n", meminfo_path=meminfo)
    assert str(caught.value) == "Vulkan budget probe did not report aggregate availability"
    assert caught.value.status == 1


def test_preflight_matches_shell_arithmetic(tmp_path: Path) -> None:
    """The eight byte counts are the shell's own expressions over one fixture."""
    model = tmp_path / "model.gguf"
    model.write_bytes(b"x" * 4096)
    meminfo = tmp_path / "meminfo"
    meminfo.write_text(MEMINFO + "\n", encoding="utf-8")
    report = build_report(
        model, 2048, 1024, 256, probe_output=PROBE_TRANSCRIPT, meminfo_path=meminfo
    )
    script = (
        "mem_available_kib=20000000; swap_total_kib=4000000; swap_free_kib=3500000;"
        "mib_bytes=1048576; required_vulkan_mib=2048; desktop_reserve_mib=1024;"
        "vulkan_margin_mib=256;"
        "required_vulkan_bytes=$((required_vulkan_mib * mib_bytes));"
        "desktop_reserve_bytes=$((desktop_reserve_mib * mib_bytes));"
        "vulkan_margin_bytes=$((vulkan_margin_mib * mib_bytes));"
        "mem_available_bytes=$((mem_available_kib * 1024));"
        "required_host_bytes=$((required_vulkan_bytes + desktop_reserve_bytes));"
        "required_vulkan_with_margin_bytes=$((required_vulkan_bytes + vulkan_margin_bytes));"
        "swap_used_bytes=$(((swap_total_kib - swap_free_kib) * 1024));"
        "printf '%s %s %s %s %s %s %s\\n' \"$mem_available_bytes\" "
        '"$required_host_bytes" "$desktop_reserve_bytes" "$required_vulkan_bytes" '
        '"$vulkan_margin_bytes" "$required_vulkan_with_margin_bytes" "$swap_used_bytes"'
    )
    completed = subprocess.run(
        [SH or "sh", "-c", script], capture_output=True, text=True, check=True
    )
    assert completed.stdout.split() == [
        str(report.mem_available_bytes),
        str(report.required_host_bytes),
        str(report.desktop_reserve_bytes),
        str(report.required_vulkan_bytes),
        str(report.vulkan_margin_bytes),
        str(report.required_vulkan_with_margin_bytes),
        str(report.swap_used_bytes),
    ]


# ---------------------------------------------------------------------------
# remote/qwen-capacity-policy.sh: byte-for-byte argv parity
# ---------------------------------------------------------------------------


def test_fixed_policy_argv(appliance: dict[str, Path]) -> None:
    """The argv a checkpoint outside the registry serves, at the built-in fallbacks."""
    output = appliance["root"] / "policy.out"
    environment = base_environment(appliance, output)
    environment["QWEN_VULKAN_PROFILE"] = "low-serialized"
    arguments = [str(appliance["server"]), str(appliance["model"]), "24576", "8080"]
    plan = assert_argv_parity(arguments, environment, output)
    assert plan.argv[1:] == (
        "--model",
        str(appliance["model"]),
        "--host",
        "127.0.0.1",
        "--port",
        "8080",
        "--alias",
        "qwen-apu",
        "--cors-origins",
        "localhost",
        "--no-ui",
        "--log-verbosity",
        "4",
        "--device",
        "Vulkan0",
        "--split-mode",
        "none",
        "--n-gpu-layers",
        "all",
        "--override-tensor",
        ".*=Vulkan0",
        "--fit",
        "off",
        "--parallel",
        "1",
        "--threads",
        "1",
        "--threads-batch",
        "1",
        "--cache-ram",
        "0",
        "--no-context-shift",
        "--offline",
        "--ctx-checkpoints",
        "0",
        "--ctx-size",
        "24576",
        "--batch-size",
        "128",
        "--ubatch-size",
        "32",
        "--flash-attn",
        "on",
        "--cache-type-k",
        "q8_0",
        "--cache-type-v",
        "q4_0",
    )
    assert plan.mode == "standalone"
    assert plan.environment_additions["QWEN_VULKAN_WORKLOAD_LOCK"] == str(
        appliance["state"] / "vulkan-workload.lock"
    )


def test_cache_override_argv(appliance: dict[str, Path]) -> None:
    """A cache-triple override takes its own ceiling and reaches the argv."""
    output = appliance["root"] / "cache.out"
    environment = base_environment(appliance, output)
    environment |= {
        "QWEN_CACHE_TYPE_K": "f16",
        "QWEN_CACHE_TYPE_V": "f16",
        "QWEN_FLASH_ATTN": "off",
        "QWEN_CACHE_OVERRIDE_CONTEXT_CEILING": "4096",
    }
    arguments = [str(appliance["server"]), str(appliance["model"]), "4096", "18080"]
    plan = assert_argv_parity(arguments, environment, output)
    joined = " ".join(plan.argv)
    assert "--flash-attn off" in joined
    assert "--cache-type-k f16 --cache-type-v f16" in joined


def test_registry_row_reaches_argv(appliance: dict[str, Path]) -> None:
    """The fabricated row's triple, geometry, and depth separate registry from default."""
    output = appliance["root"] / "registry.out"
    environment = base_environment(appliance, output)
    environment["QWEN_MODEL_REGISTRY"] = str(appliance["registry"])
    arguments = [str(appliance["server"]), str(appliance["registry_model"]), "4096", "18080"]
    plan = assert_argv_parity(arguments, environment, output)
    joined = " ".join(plan.argv)
    assert "--batch-size 256 --ubatch-size 64" in joined
    assert "--flash-attn auto" in joined
    assert "--cache-type-k q5_1 --cache-type-v iq4_nl" in joined
    assert plan.model_id == "fabricated"
    assert "depth_validation admitted=4096 validated=4096 geometry=256/64" in plan.stderr_lines


def test_static_path_and_api_key_argv(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "static.out"
    static = appliance["root"] / "webui"
    static.mkdir()
    (static / "index.html").write_text("<html></html>\n", encoding="utf-8")
    key = appliance["root"] / "api.key"
    key.write_text("synthetic-test-key\n", encoding="utf-8")
    environment = base_environment(appliance, output)
    arguments = [
        str(appliance["server"]),
        str(appliance["model"]),
        "4096",
        "18080",
        str(static),
        str(key),
    ]
    plan = assert_argv_parity(arguments, environment, output)
    joined = " ".join(plan.argv)
    assert f"--path {static} --ui" in joined
    assert f"--api-key-file {key}" in joined


def test_lan_bounds_clamp_and_n_predict(appliance: dict[str, Path]) -> None:
    """The combined budget clamps --ctx-size and the output bound becomes --n-predict."""
    output = appliance["root"] / "lan.out"
    static = appliance["root"] / "webui-lan"
    static.mkdir()
    (static / "index.html").write_text(
        '<meta name="qwen-lan-max-prompt-tokens" content="1000">\n'
        '<meta name="qwen-lan-max-output-tokens" content="200">\n',
        encoding="utf-8",
    )
    environment = base_environment(appliance, output)
    environment |= {
        "QWEN_LAN_MAX_PROMPT_TOKENS": "1000",
        "QWEN_LAN_MAX_OUTPUT_TOKENS": "200",
    }
    arguments = [
        str(appliance["server"]),
        str(appliance["model"]),
        "4096",
        "18080",
        str(static),
    ]
    plan = assert_argv_parity(arguments, environment, output)
    joined = " ".join(plan.argv)
    assert "--ctx-size 1200" in joined
    assert "--n-predict 200" in joined
    assert plan.lan_bounds.combined_budget == 1200


def test_speculation_and_sampling_argv(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "spec.out"
    environment = base_environment(appliance, output)
    environment |= {
        "QWEN_SPEC_TYPE": "draft-mtp",
        "QWEN_SPEC_DRAFT_N_MAX": "2",
        "QWEN_SPEC_DRAFT_P_MIN": "0.4",
        "QWEN_SPEC_BACKEND_SAMPLING": "1",
        "QWEN_BACKEND_SAMPLING": "1",
    }
    arguments = [str(appliance["server"]), str(appliance["model"]), "4096", "18080"]
    plan = assert_argv_parity(arguments, environment, output)
    joined = " ".join(plan.argv)
    assert "--spec-type draft-mtp --spec-draft-n-max 2 --spec-draft-p-min 0.4" in joined
    assert "--spec-draft-backend-sampling --backend-sampling" in joined


def test_checkpoint_count_and_minimum_step_argv(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "checkpoints.out"
    appliance["checkpoints"].write_text(
        "fabricated\t2\tevidence/fabricated-checkpoints\n", encoding="utf-8"
    )
    environment = base_environment(appliance, output)
    environment["QWEN_MODEL_REGISTRY"] = str(appliance["registry"])
    environment["QWEN_CHECKPOINT_MIN_STEP"] = "4096"
    arguments = [str(appliance["server"]), str(appliance["registry_model"]), "4096", "18080"]
    plan = assert_argv_parity(arguments, environment, output)
    joined = " ".join(plan.argv)
    assert "--checkpoint-min-step 4096" in joined
    assert "--ctx-checkpoints 2" in joined
    assert plan.checkpoint_guard_requirement == "natural-boundary-v1"


def test_projector_argv(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "mmproj.out"
    projector = appliance["root"] / "mmproj-F16.gguf"
    projector.write_bytes(b"")
    environment = base_environment(appliance, output)
    environment |= {
        "QWEN_MMPROJ": str(projector),
        "QWEN_MMPROJ_OFFLOAD": "0",
        "QWEN_IMAGE_MAX_TOKENS": "512",
    }
    arguments = [str(appliance["server"]), str(appliance["model"]), "4096", "18080"]
    plan = assert_argv_parity(arguments, environment, output)
    joined = " ".join(plan.argv)
    assert f"--mmproj {projector} --no-mmproj-offload --image-max-tokens 512" in joined


def test_router_argv(appliance: dict[str, Path]) -> None:
    """Router mode replaces the model with a preset and drops the six tuple flags."""
    output = appliance["root"] / "router.out"
    presets = appliance["root"] / "router-presets.ini"
    presets.write_text(ROUTER_SECTION.format(model=appliance["registry_model"]), encoding="utf-8")
    environment = base_environment(appliance, output)
    environment |= {
        "QWEN_MODEL_REGISTRY": str(appliance["registry"]),
        "QWEN_ROUTER": "1",
        "QWEN_ROUTER_PRESETS": str(presets),
        "QWEN_ROUTER_MAX": "1",
    }
    arguments = [str(appliance["server"]), str(appliance["model"]), "4096", "18080"]
    plan = assert_argv_parity(arguments, environment, output)
    joined = " ".join(plan.argv)
    assert f"--models-preset {presets} --models-max 1" in joined
    for absent in ("--ctx-size", "--batch-size", "--ubatch-size", "--flash-attn", "--alias"):
        assert absent not in plan.argv
    assert plan.mode == "router"
    assert plan.preset_section_names == ("fabricated",)
    # validate_current_router_authorities runs before the argv and again at the
    # exec, so the formulation receipt is printed twice.
    assert plan.stdout_lines.count("router_q4k_policy source=registry identity=registry") == 2


def test_exec_chain_carries_the_guards(appliance: dict[str, Path]) -> None:
    """The exec argv names the wrapper, the build guard, and its three declarations."""
    output = appliance["root"] / "exec.out"
    environment = base_environment(appliance, output)
    arguments = [str(appliance["server"]), str(appliance["model"]), "4096", "18080"]
    plan = assert_argv_parity(arguments, environment, output)
    assert plan.exec_argv[:3] == (
        str(REMOTE / "radv-low-priority-env.sh"),
        str(REMOTE / "qwen-build-exec-guard.sh"),
        str(appliance["server"]),
    )
    assert plan.exec_argv[3] == plan.checkpoint_manifest_sha256
    assert plan.exec_argv[4:6] == ("-", "-")
    assert plan.exec_argv[6:] == plan.argv


# ---------------------------------------------------------------------------
# remote/qwen-capacity-policy.sh: refusal parity
# ---------------------------------------------------------------------------

_NOTICE_PREFIXES = (
    "depth_validation ",
    "lan_resource_bounds ",
    "quarantine override forces the listener to loopback",
    "web preset unvalidated-depth override forces the listener to loopback",
)


def shell_refusal_lines(completed: subprocess.CompletedProcess[str]) -> list[str]:
    """The shell's stderr with the receipt notices removed.

    `depth_validation` and `lan_resource_bounds` are reported on every launch
    that reaches them, so a refusal after either carries both the notice and
    the reason; the comparison here is against the reason.
    """
    return [line for line in completed.stderr.splitlines() if not line.startswith(_NOTICE_PREFIXES)]


def assert_refusal_parity(arguments: list[str], environment: Mapping[str, str]) -> PolicyError:
    completed = run_shell_policy(arguments, environment)
    assert completed.returncode != 0, completed.stdout
    with pytest.raises(PolicyError) as caught:
        plan_from_environment(arguments, environment, script_directory=REMOTE)
    assert list(caught.value.messages) == shell_refusal_lines(completed)
    return caught.value


def test_context_size_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    environment = base_environment(appliance, output)
    server, model = str(appliance["server"]), str(appliance["model"])
    assert_refusal_parity([server, model, "0", "18080"], environment)
    assert_refusal_parity([server, model, "24577", "18080"], environment)
    assert_refusal_parity([server, model, "notanumber", "18080"], environment)


def test_cache_policy_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    server, model = str(appliance["server"]), str(appliance["model"])
    overrides = {"QWEN_CACHE_TYPE_K": "f16", "QWEN_CACHE_TYPE_V": "f16", "QWEN_FLASH_ATTN": "off"}
    environment = base_environment(appliance, output) | overrides
    assert_refusal_parity([server, model, "4096", "18080"], environment)
    assert_refusal_parity(
        [server, model, "4096", "18080"],
        environment | {"QWEN_CACHE_OVERRIDE_CONTEXT_CEILING": "24577"},
    )
    assert_refusal_parity(
        [server, model, "4097", "18080"],
        environment | {"QWEN_CACHE_OVERRIDE_CONTEXT_CEILING": "4096"},
    )
    assert_refusal_parity(
        [server, model, "4096", "18080"],
        base_environment(appliance, output) | {"QWEN_CACHE_TYPE_K": "q3_unknown"},
    )
    assert_refusal_parity(
        [server, model, "4096", "18080"],
        base_environment(appliance, output) | {"QWEN_FLASH_ATTN": "sometimes"},
    )


def test_port_and_static_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    environment = base_environment(appliance, output)
    server, model = str(appliance["server"]), str(appliance["model"])
    assert_refusal_parity([server, model, "4096", "80"], environment)
    empty = appliance["root"] / "empty-static"
    empty.mkdir()
    assert_refusal_parity([server, model, "4096", "18080", str(empty)], environment)
    static = appliance["root"] / "webui"
    static.mkdir()
    (static / "index.html").write_text("<html></html>\n", encoding="utf-8")
    key = appliance["root"] / "empty.key"
    key.write_bytes(b"")
    assert_refusal_parity([server, model, "4096", "18080", str(static), str(key)], environment)
    # A key with nothing to serve names a caller mistake.
    filled = appliance["root"] / "api.key"
    filled.write_text("synthetic-test-key\n", encoding="utf-8")
    assert_refusal_parity([server, model, "4096", "18080", "", str(filled)], environment)


def test_lan_bound_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    server, model = str(appliance["server"]), str(appliance["model"])
    environment = base_environment(appliance, output)
    assert_refusal_parity(
        [server, model, "4096", "18080"], environment | {"QWEN_LAN_MAX_PROMPT_TOKENS": "1000"}
    )
    assert_refusal_parity(
        [server, model, "4096", "18080"],
        environment | {"QWEN_LAN_MAX_PROMPT_TOKENS": "0", "QWEN_LAN_MAX_OUTPUT_TOKENS": "200"},
    )


def test_page_bound_comparison_refusals(appliance: dict[str, Path]) -> None:
    """A page stating a bound the launch never set is refused ahead of the argv."""
    output = appliance["root"] / "refuse.out"
    server, model = str(appliance["server"]), str(appliance["model"])
    tagged = appliance["root"] / "webui-tagged"
    tagged.mkdir()
    (tagged / "index.html").write_text(
        '<meta name="qwen-lan-max-prompt-tokens" content="1000">\n'
        '<meta name="qwen-lan-max-output-tokens" content="200">\n',
        encoding="utf-8",
    )
    environment = base_environment(appliance, output)
    assert_refusal_parity([server, model, "4096", "18080", str(tagged)], environment)
    untagged = appliance["root"] / "webui-untagged"
    untagged.mkdir()
    (untagged / "index.html").write_text("<html></html>\n", encoding="utf-8")
    assert_refusal_parity(
        [server, model, "4096", "18080", str(untagged)],
        environment | {"QWEN_LAN_MAX_PROMPT_TOKENS": "1000", "QWEN_LAN_MAX_OUTPUT_TOKENS": "200"},
    )
    half = appliance["root"] / "webui-half"
    half.mkdir()
    (half / "index.html").write_text(
        '<meta name="qwen-lan-max-prompt-tokens" content="1000">\n', encoding="utf-8"
    )
    assert_refusal_parity([server, model, "4096", "18080", str(half)], environment)


def test_environment_override_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    environment = base_environment(appliance, output)
    server, model = str(appliance["server"]), str(appliance["model"])
    assert_refusal_parity(
        [server, model, "4096", "18080"], environment | {"LLAMA_ARG_CTX_SIZE": "4096"}
    )
    assert_refusal_parity([server, model, "4096", "18080"], environment | {"QWEN_ROUTER": "2"})
    assert_refusal_parity(
        [server, model, "4096", "18080"], environment | {"QWEN_BIND_HOST": "not-a-host"}
    )


def test_speculation_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    environment = base_environment(appliance, output)
    server, model = str(appliance["server"]), str(appliance["model"])
    assert_refusal_parity(
        [server, model, "4096", "18080"], environment | {"QWEN_SPEC_TYPE": "draft-simple"}
    )
    for n_max in ("17", "0"):
        assert_refusal_parity(
            [server, model, "4096", "18080"],
            environment | {"QWEN_SPEC_TYPE": "draft-mtp", "QWEN_SPEC_DRAFT_N_MAX": n_max},
        )
    assert_refusal_parity(
        [server, model, "4096", "18080"],
        environment | {"QWEN_SPEC_TYPE": "draft-mtp", "QWEN_SPEC_DRAFT_P_MIN": "0.4.1"},
    )


def test_checkpoint_semantics_refusal(appliance: dict[str, Path]) -> None:
    """A positive count requires a build declaring the measured partition."""
    output = appliance["root"] / "refuse.out"
    older = write_fixture_build(appliance["root"] / "older-build", "forced-tail-v1")
    environment = base_environment(appliance, output)
    environment["QWEN_CTX_CHECKPOINTS"] = "2"
    assert_refusal_parity([str(older), str(appliance["model"]), "4096", "18080"], environment)


def test_q4k_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    environment = base_environment(appliance, output)
    environment["QWEN_MODEL_REGISTRY"] = str(appliance["registry"])
    server, registry_model = str(appliance["server"]), str(appliance["registry_model"])
    assert_refusal_parity(
        [server, registry_model, "4096", "18080"], environment | {"QWEN_Q4K_VARIANT": "e4/3"}
    )
    # The row releases `-`, so a differing key needs the experiment declaration.
    assert_refusal_parity(
        [server, registry_model, "4096", "18080"],
        environment | {"QWEN_Q4K_VARIANT": "e4-scale/4"},
    )
    # With the declaration, the build must admit the key.
    assert_refusal_parity(
        [server, registry_model, "4096", "18080"],
        environment | {"QWEN_Q4K_VARIANT": "e4-scale/4", "QWEN_Q4K_EXPERIMENT_ARM": "1"},
    )


def test_q4k_experiment_arm_argv(appliance: dict[str, Path]) -> None:
    """A build declaring the key serves it, and the policy exports the one name."""
    output = appliance["root"] / "q4k.out"
    server = write_fixture_build(
        appliance["root"] / "variant-build", "natural-boundary-v1", "e4/4,e4-scale/4,production/4"
    )
    environment = base_environment(appliance, output)
    environment |= {
        "QWEN_MODEL_REGISTRY": str(appliance["registry"]),
        "QWEN_Q4K_VARIANT": "e4-scale/4",
        "QWEN_Q4K_EXPERIMENT_ARM": "1",
    }
    arguments = [str(server), str(appliance["registry_model"]), "4096", "18080"]
    plan = assert_argv_parity(arguments, environment, output)
    assert plan.q4k_variant == "e4-scale/4"
    assert plan.q4k_selection_source == "environment"
    assert plan.q4k_guard_requirement == "e4-scale/4"
    assert plan.environment_additions["QWEN_Q4K_VARIANT"] == "e4-scale/4"


def test_quarantined_tuple_refusal(appliance: dict[str, Path]) -> None:
    """The quarantined tuple refuses and its neighbours serve."""
    output = appliance["root"] / "refuse.out"
    appliance["quarantine"].write_text(
        "\t".join(
            [
                "fabricated-profile",
                "profile",
                "fabricated",
                "ring-timeout-only",
                "4096",
                "256",
                "64",
                "q5_1",
                "iq4_nl",
                "auto",
                "evidence/x.md",
                "evidence/y.md",
                "evidence/z.md",
                "any",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    environment = base_environment(appliance, output)
    environment["QWEN_MODEL_REGISTRY"] = str(appliance["registry"])
    server, registry_model = str(appliance["server"]), str(appliance["registry_model"])
    error = assert_refusal_parity([server, registry_model, "4096", "18080"], environment)
    assert error.messages[0].startswith("this tuple is quarantined: fabricated at depth 4096")
    # A neighbouring depth under the same geometry is a different tuple.
    assert_argv_parity([server, registry_model, "2048", "18080"], environment, output)


def test_router_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    presets = appliance["root"] / "router-presets.ini"
    presets.write_text(ROUTER_SECTION.format(model=appliance["registry_model"]), encoding="utf-8")
    environment = base_environment(appliance, output) | {
        "QWEN_MODEL_REGISTRY": str(appliance["registry"]),
        "QWEN_ROUTER": "1",
        "QWEN_ROUTER_PRESETS": str(presets),
    }
    server, model = str(appliance["server"]), str(appliance["model"])
    # Both LAN bounds have no per-section preset field.
    assert_refusal_parity(
        [server, model, "4096", "18080"],
        environment | {"QWEN_LAN_MAX_PROMPT_TOKENS": "1000", "QWEN_LAN_MAX_OUTPUT_TOKENS": "200"},
    )
    assert_refusal_parity(
        [server, model, "4096", "18080"], environment | {"QWEN_CTX_CHECKPOINTS": "2"}
    )
    assert_refusal_parity(
        [server, model, "4096", "18080"], environment | {"QWEN_CHECKPOINT_MIN_STEP": "4096"}
    )
    assert_refusal_parity(
        [server, model, "4096", "18080"], environment | {"QWEN_Q4K_VARIANT": "e4-scale/4"}
    )
    unreadable = appliance["root"] / "absent-presets.ini"
    assert_refusal_parity(
        [server, model, "4096", "18080"],
        environment | {"QWEN_ROUTER_PRESETS": str(unreadable)},
    )
    assert_refusal_parity(
        [server, model, "4096", "18080"],
        environment | {"QWEN_ROUTER_PRESET_SHA256": "0" * 64},
    )


def test_router_preset_tuple_refusals(appliance: dict[str, Path]) -> None:
    """A section losing one key, or drifting from the row, refuses the launch."""
    output = appliance["root"] / "refuse.out"
    presets = appliance["root"] / "router-presets.ini"
    server, model = str(appliance["server"]), str(appliance["model"])
    environment = base_environment(appliance, output) | {
        "QWEN_MODEL_REGISTRY": str(appliance["registry"]),
        "QWEN_ROUTER": "1",
        "QWEN_ROUTER_PRESETS": str(presets),
    }
    complete = ROUTER_SECTION.format(model=appliance["registry_model"])
    for mutation in (
        complete.replace("LLAMA_ARG_UBATCH = 64\n", ""),
        complete.replace("LLAMA_ARG_CTX_CHECKPOINTS = 0\n", ""),
        complete.replace("LLAMA_ARG_CTX_CHECKPOINTS = 0", "LLAMA_ARG_CTX_CHECKPOINTS = 3"),
        complete.replace("LLAMA_ARG_CTX_CHECKPOINTS = 0", "LLAMA_ARG_CTX_CHECKPOINTS = 02"),
        complete.replace("LLAMA_ARG_BATCH = 256", "LLAMA_ARG_BATCH = 2048"),
        complete.replace("LLAMA_ARG_CACHE_TYPE_K = q5_1", "LLAMA_ARG_CACHE_TYPE_K = q3_unknown"),
        complete.replace("LLAMA_ARG_CACHE_TYPE_K = q5_1", "LLAMA_ARG_CACHE_TYPE_K = f16"),
        complete.replace("[fabricated]", "[unregistered]"),
        "",
    ):
        presets.write_text(mutation, encoding="utf-8")
        assert_refusal_parity([server, model, "4096", "18080"], environment)


def test_router_quarantine_authority_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    presets = appliance["root"] / "router-presets.ini"
    presets.write_text(ROUTER_SECTION.format(model=appliance["registry_model"]), encoding="utf-8")
    server, model = str(appliance["server"]), str(appliance["model"])
    environment = base_environment(appliance, output) | {
        "QWEN_MODEL_REGISTRY": str(appliance["registry"]),
        "QWEN_ROUTER": "1",
        "QWEN_ROUTER_PRESETS": str(presets),
    }
    # A model-scope row retires the section the preset still names.
    appliance["quarantine"].write_text(
        "\t".join(
            [
                "fabricated-model",
                "model",
                "fabricated",
                "no-validated-safe-tuple",
                *(["-"] * 6),
                "evidence/x.md",
                "evidence/y.md",
                "evidence/z.md",
                "router-child",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    assert_refusal_parity([server, model, "4096", "18080"], environment)
    # An unreadable or malformed authority stops the launch before the preset
    # is read as admitted.
    appliance["quarantine"].write_text("malformed\trow\n", encoding="utf-8")
    assert_refusal_parity([server, model, "4096", "18080"], environment)
    appliance["quarantine"].unlink()
    assert_refusal_parity([server, model, "4096", "18080"], environment)


def test_approved_descriptor_identity(appliance: dict[str, Path]) -> None:
    """The descriptor stays the launch argument after the pathname is replaced."""
    output = appliance["root"] / "identity.out"
    appliance["checkpoints"].write_text(
        "fabricated\t3\tevidence/fabricated-checkpoints\n", encoding="utf-8"
    )
    carrier = appliance["root"] / "identity-model.gguf"
    carrier.write_text("descriptor-bound fixture model\n", encoding="utf-8")
    with open(carrier, "rb") as handle:
        status = os.fstat(handle.fileno())
        descriptor = f"/proc/{os.getpid()}/fd/{handle.fileno()}"  # appliance-path: named
        carrier.rename(appliance["root"] / "identity-model.retained")
        environment = base_environment(appliance, output) | {
            "QWEN_MODEL_REGISTRY": str(appliance["registry"]),
            "QWEN_APPROVED_MODEL_ID": "fabricated",
            "QWEN_APPROVED_MODEL_FILE": "fabricated.gguf",
            "QWEN_APPROVED_MODEL_DEVICE": str(status.st_dev),
            "QWEN_APPROVED_MODEL_INODE": str(status.st_ino),
            "QWEN_APPROVED_MODEL_BYTES": str(status.st_size),
        }
        # The shell opens its own descriptor, so the parity check here is the
        # Python plan alone: a proc path names one process's table.
        plan = plan_from_environment(
            [str(appliance["server"]), descriptor, "4096", "18080"],
            environment,
            script_directory=REMOTE,
        )
    joined = " ".join(plan.argv)
    assert f"--model {descriptor}" in joined
    assert "--ctx-checkpoints 3" in joined
    assert "--batch-size 256 --ubatch-size 64" in joined
    assert "--cache-type-k q5_1 --cache-type-v iq4_nl" in joined
    assert plan.model_id == "fabricated"


def test_approved_identity_refusals(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    server, model = str(appliance["server"]), str(appliance["model"])
    environment = base_environment(appliance, output) | {
        "QWEN_MODEL_REGISTRY": str(appliance["registry"]),
        "QWEN_APPROVED_MODEL_ID": "fabricated",
    }
    assert_refusal_parity([server, model, "4096", "18080"], environment)
    symlink = appliance["root"] / "linked-model.gguf"
    symlink.symlink_to(appliance["model"])
    assert_refusal_parity(
        [server, str(symlink), "4096", "18080"], base_environment(appliance, output)
    )
    assert_refusal_parity(
        [server, "/proc/self/fd/0", "4096", "18080"],  # appliance-path: named
        base_environment(appliance, output),
    )


def test_web_lan_credential_state(appliance: dict[str, Path]) -> None:
    """The open lane refuses a key file and the bearer lane refuses its absence."""
    output = appliance["root"] / "refuse.out"
    static = appliance["root"] / "webui"
    static.mkdir()
    (static / "index.html").write_text("<html></html>\n", encoding="utf-8")
    key = appliance["root"] / "api.key"
    key.write_text("synthetic-test-key\n", encoding="utf-8")
    server, model = str(appliance["server"]), str(appliance["model"])
    environment = base_environment(appliance, output) | {"QWEN_WEB_LAN": "1"}
    assert_refusal_parity(
        [server, model, "4096", "18080", str(static), str(key)],
        environment | {"QWEN_WEB_LAN_OPEN": "1"},
    )
    assert_refusal_parity([server, model, "4096", "18080", str(static)], environment)


def test_usage_refusal() -> None:
    with pytest.raises(PolicyError) as caught:
        plan_from_environment(["one", "two"], {}, script_directory=REMOTE)
    assert str(caught.value) == policy_module.USAGE


def test_unexecutable_server_and_absent_model(appliance: dict[str, Path]) -> None:
    output = appliance["root"] / "refuse.out"
    environment = base_environment(appliance, output)
    plain = appliance["root"] / "not-executable"
    plain.write_text("#!/bin/sh\n", encoding="utf-8")
    plain.chmod(plain.stat().st_mode & ~stat.S_IXUSR & ~stat.S_IXGRP & ~stat.S_IXOTH)
    assert_refusal_parity([str(plain), str(appliance["model"]), "4096", "18080"], environment)
    assert_refusal_parity(
        [str(appliance["server"]), str(appliance["root"] / "absent.gguf"), "4096", "18080"],
        environment,
    )
