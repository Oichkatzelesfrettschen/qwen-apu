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
print("pull_request_gate_routing=accepted")
