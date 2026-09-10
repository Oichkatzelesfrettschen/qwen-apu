#!/usr/bin/env python3
"""Test the pull-request gate's conservative path routing."""

from __future__ import annotations

import importlib.util
import pathlib

DRIVER = pathlib.Path(__file__).with_name("run-pull-request-gate.py")
SPEC = importlib.util.spec_from_file_location("pull_request_gate", DRIVER)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

assert MODULE.classify_paths(["docs/USER-GUIDE.md", "README.md"]) == "documentation"
assert MODULE.classify_paths(["docs/install-requirements.tsv"]) == "full"
assert (
    MODULE.classify_paths(["remote/repository-quality-gate-declarations.tsv"])
    == "gate-infrastructure"
)
assert (
    MODULE.classify_paths(["docs/install-requirements.tsv", "webui/index.html"])
    == "full"
)
assert MODULE.classify_paths(["webui/index.html"]) == "webui"
assert (
    MODULE.classify_paths(
        [
            "webui/index.html",
            "remote/test-fallback-webui-web-authorization.sh",
            "remote/web-mcp/test-fallback-page-image.py",
        ]
    )
    == "webui"
)
assert MODULE.classify_paths(["remote/qwen-launch.sh"]) == "full"
assert (
    MODULE.classify_paths([".github/workflows/repository-quality-gates.yml"])
    == "ci-routing"
)
assert (
    MODULE.classify_paths(
        [
            "remote/gate-cell-key.sh",
            "remote/repository-quality-gates.sh",
            "remote/test-repository-gate-cells.sh",
            "evidence/SHA256SUMS",
            "evidence/ci-gate-driver-scope-reuse/README.md",
        ]
    )
    == "gate-infrastructure"
)
assert (
    MODULE.classify_paths(
        ["remote/gate-cell-key.sh", "remote/run-pull-request-gate.py"]
    )
    == "gate-infrastructure"
)
assert (
    MODULE.classify_paths(
        ["remote/gate-cell-key.sh", "evidence/unrelated-result/README.md"]
    )
    == "full"
)
assert (
    MODULE.classify_paths(
        [
            "remote/browser-driver-preflight.py",
            "remote/test-browser-driver-preflight.py",
            "evidence/SHA256SUMS",
            "evidence/image-quality-browser-interpreter/README.md",
        ]
    )
    == "browser-preflight"
)
assert MODULE.classify_paths(["remote/qwen-home.sh"]) == "full"
assert (
    MODULE.classify_paths(["remote/qwen-home.sh", "remote/browser-driver-preflight.py"])
    == "full"
)
assert (
    MODULE.classify_paths(
        [
            "remote/browser-driver-preflight.py",
            "remote/run-pull-request-gate.py",
        ]
    )
    == "browser-preflight"
)
assert (
    MODULE.classify_paths(["remote/check-repository-quality-gate-declarations.py"])
    == "gate-infrastructure"
)
assert (
    MODULE.classify_paths(
        [
            "docs/frontier.md",
            "evidence/SHA256SUMS",
            "evidence/q8-attribution/sampler-cost-attribution/README.md",
            "remote/telemetry-broker.c",
            "remote/validate-clock-sidecar.py",
            "remote/test-telemetry-broker.sh",
        ]
    )
    == "q8-sampler-attribution"
)
assert (
    MODULE.classify_paths(
        [
            "remote/telemetry-broker.c",
            "evidence/q8-attribution/unrelated-result/README.md",
        ]
    )
    == "full"
)
assert (
    MODULE.classify_paths(
        [
            "remote/telemetry-broker.c",
            "remote/merged-pr-gate-reuse.py",
        ]
    )
    == "full"
)
assert (
    MODULE.classify_paths(
        [
            "remote/browser-driver-preflight.py",
            "evidence/unrelated-result/README.md",
        ]
    )
    == "full"
)
assert (
    MODULE.classify_paths(
        [
            ".github/workflows/repository-quality-gates.yml",
            "remote/merged-pr-gate-reuse.py",
        ]
    )
    == "ci-routing"
)
assert (
    MODULE.classify_paths(
        [".github/workflows/repository-quality-gates.yml", "webui/index.html"]
    )
    == "full"
)
assert MODULE.classify_paths([]) == "full"
try:
    MODULE.classify_paths(["../outside"])
except ValueError:
    pass
else:
    raise AssertionError("a traversal path entered pull-request routing")

webui_commands = MODULE.selected_checks(
    ["remote/test-fallback-webui-web-authorization.sh"], "webui"
)
assert (
    "shellcheck",
    "-S",
    "warning",
    "remote/test-fallback-webui-web-authorization.sh",
) in webui_commands
assert ("remote/test-feature-roster.sh",) in webui_commands
assert ("python3", "remote/web-mcp/test-fallback-page-image.py") in webui_commands
assert MODULE.selected_checks(["docs/USER-GUIDE.md"], "documentation") == list(
    MODULE.ALWAYS_CHECKS
)
assert ("python3", "remote/test-merged-pr-gate-reuse.py") in MODULE.selected_checks(
    ["remote/merged-pr-gate-reuse.py"], "ci-routing"
)
gate_infrastructure_commands = MODULE.selected_checks(
    [
        "remote/gate-cell-key.sh",
        "remote/repository-quality-gates.sh",
        "remote/test-repository-gate-cells.sh",
        "remote/run-pull-request-gate.py",
    ],
    "gate-infrastructure",
)
assert (
    "shellcheck",
    "-S",
    "warning",
    "remote/gate-cell-key.sh",
    "remote/repository-quality-gates.sh",
    "remote/test-repository-gate-cells.sh",
) in gate_infrastructure_commands
q8_sampler_commands = MODULE.selected_checks(
    [
        "remote/run-raven2-vulkan-kernel-census.sh",
        "remote/test-telemetry-broker.sh",
        "remote/validate-clock-sidecar.py",
    ],
    "q8-sampler-attribution",
)
assert (
    "shellcheck",
    "-S",
    "warning",
    "remote/run-raven2-vulkan-kernel-census.sh",
    "remote/test-telemetry-broker.sh",
) in q8_sampler_commands
assert ("sh", "remote/test-telemetry-broker.sh") in q8_sampler_commands
assert ("python3", "remote/test-census-controls.py") in q8_sampler_commands
assert (
    "sh",
    "remote/test-run-raven2-vulkan-kernel-census.sh",
) in q8_sampler_commands
assert ("remote/test-repository-gate-cells.sh",) in gate_infrastructure_commands
assert ("python3", "remote/test-q8-four-row-select.py") in gate_infrastructure_commands
assert ("python3", "remote/test-ab-shared-series.py") in gate_infrastructure_commands
assert (
    "python3",
    "remote/test-run-pull-request-gate.py",
) in gate_infrastructure_commands
browser_preflight_commands = MODULE.selected_checks(
    [
        "remote/browser-driver-preflight.py",
        "remote/test-browser-driver-preflight.py",
    ],
    "browser-preflight",
)
assert (
    "mypy",
    "--strict",
    "remote/browser-driver-preflight.py",
    "remote/test-browser-driver-preflight.py",
) in browser_preflight_commands
assert (
    "python3",
    "remote/test-browser-driver-preflight.py",
) in browser_preflight_commands
assert ("python3", "remote/test-run-pull-request-gate.py") in browser_preflight_commands
assert (
    "python3",
    "remote/test-merged-pr-gate-reuse.py",
) in browser_preflight_commands
assert ("remote/test-qwen-home.sh",) in browser_preflight_commands
assert ("remote/test-feature-roster.sh",) in browser_preflight_commands
assert (
    "remote/repository-quality-gates.sh",
    "--declarations",
) in browser_preflight_commands
assert (
    "python3",
    "remote/check-repository-quality-gate-declarations.py",
) in gate_infrastructure_commands
assert (
    "python3",
    "remote/test-check-repository-quality-gate-declarations.py",
) in gate_infrastructure_commands
print("pull_request_gate_routing=accepted")
