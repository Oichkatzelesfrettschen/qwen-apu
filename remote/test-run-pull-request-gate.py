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

WORKFLOW = DRIVER.parent.parent / ".github/workflows/repository-quality-gates.yml"

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
assert MODULE.classify_paths(["remote/feature-claims.tsv"]) == "webui"
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

IMAGE_QUALITY_RESULT_PATHS = [
    "README.md",
    "evidence/SHA256SUMS",
    "evidence/image-quality-browser-interpreter/README.md",
    "evidence/image-quality-successor-broker-grant-stop/README.md",
    "evidence/image-quality-successor-broker-grant-stop/result.tsv",
    "evidence/image-quality-successor-broker-grant-stop/transformation.tsv",
]
assert MODULE.classify_paths(IMAGE_QUALITY_RESULT_PATHS) == ("documentation+evidence")
assert (
    MODULE.classify_paths(["evidence/SHA256SUMS", "evidence/new-result/README.md"])
    == "evidence"
)
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
    == "evidence+gate-infrastructure"
)
assert (
    MODULE.classify_paths(
        ["remote/gate-cell-key.sh", "remote/run-pull-request-gate.py"]
    )
    == "ci-routing+gate-infrastructure"
)
assert (
    MODULE.classify_paths(
        ["remote/gate-cell-key.sh", "evidence/unrelated-result/README.md"]
    )
    == "evidence+gate-infrastructure"
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
    == "browser-preflight+evidence"
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
    == "browser-preflight+ci-routing"
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
    == "documentation+evidence+q8-sampler-attribution"
)
assert (
    MODULE.classify_paths(
        [
            "remote/telemetry-broker.c",
            "evidence/q8-attribution/unrelated-result/README.md",
        ]
    )
    == "evidence+q8-sampler-attribution"
)
assert (
    MODULE.classify_paths(
        [
            "remote/screen-ngram-retrieval.py",
            "remote/test-screen-ngram-retrieval.py",
        ]
    )
    == "ngram-screen"
)
assert (
    MODULE.classify_paths(
        [
            "evidence/SHA256SUMS",
            "evidence/ngram-retrieval-screen/README.md",
            "remote/screen-ngram-retrieval.py",
            "remote/test-screen-ngram-retrieval.py",
        ]
    )
    == "evidence+ngram-screen"
)
assert (
    MODULE.classify_paths(
        [
            "remote/telemetry-broker.c",
            "remote/merged-pr-gate-reuse.py",
        ]
    )
    == "ci-routing+q8-sampler-attribution"
)
assert (
    MODULE.classify_paths(
        [
            "remote/browser-driver-preflight.py",
            "evidence/unrelated-result/README.md",
        ]
    )
    == "browser-preflight+evidence"
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
    == "ci-routing+webui"
)
assert MODULE.classify_paths([]) == "full"
try:
    MODULE.classify_paths(["../outside"])
except ValueError:
    pass
else:
    raise AssertionError("a traversal path entered pull-request routing")

workflow_text = WORKFLOW.read_text(encoding="utf-8")
assert "github.event.pull_request.draft" not in workflow_text
assert "ready_for_review" not in workflow_text
assert workflow_text.count("python3 remote/run-pull-request-gate.py") == 1

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
    MODULE.TEXT_POLICY_CHECKS
)

image_quality_commands = MODULE.selected_checks(
    IMAGE_QUALITY_RESULT_PATHS, "documentation+evidence"
)
assert ("remote/refresh-evidence-manifest.sh", "--check") in image_quality_commands
assert ("python3", "remote/check-text-policy.py") in image_quality_commands
assert ("python3", "remote/check-appliance-paths.py") not in image_quality_commands
assert ("remote/test-feature-roster.sh",) not in image_quality_commands
assert not any(
    "fallback-webui" in argument
    for command in image_quality_commands
    for argument in command
)
assert not any(
    "telemetry" in argument
    for command in image_quality_commands
    for argument in command
)
assert not any(
    "browser-driver" in argument
    for command in image_quality_commands
    for argument in command
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
    "ci-routing+gate-infrastructure",
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
ngram_screen_commands = MODULE.selected_checks(
    [
        "remote/screen-ngram-retrieval.py",
        "remote/test-screen-ngram-retrieval.py",
    ],
    "ngram-screen",
)
assert (
    "python3",
    "remote/test-screen-ngram-retrieval.py",
) in ngram_screen_commands
assert (
    "ruff",
    "format",
    "--check",
    "remote/screen-ngram-retrieval.py",
    "remote/test-screen-ngram-retrieval.py",
) in ngram_screen_commands
assert not any(
    "telemetry" in argument or "browser-driver" in argument
    for command in ngram_screen_commands
    for argument in command
)
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
assert (
    "python3",
    "remote/check-repository-quality-gate-declarations.py",
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
