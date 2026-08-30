#!/usr/bin/env python3
"""Mutation tests for the model-admission consistency checker."""

import importlib.util
import pathlib
import shutil
import tempfile


SCRIPT_DIRECTORY = pathlib.Path(__file__).resolve().parent
REPOSITORY_ROOT = SCRIPT_DIRECTORY.parent


def load_checker():
    path = SCRIPT_DIRECTORY / "check-model-admission-consistency.py"
    spec = importlib.util.spec_from_file_location("model_admission_consistency", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"checker is unreadable: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = load_checker()
FIXTURE_PATHS = (
    pathlib.Path("evidence/model-admission/candidate-ledger.tsv"),
    pathlib.Path("evidence/model-admission/readiness-candidates.tsv"),
    pathlib.Path("evidence/model-admission/readiness-appliance-artifacts.tsv"),
    pathlib.Path("evidence/model-admission/static-admission.tsv"),
    pathlib.Path("evidence/model-admission/readiness-quality-protocols.tsv"),
    pathlib.Path("remote/models.tsv"),
)


def make_fixture(temporary_root):
    for relative_path in FIXTURE_PATHS:
        target = temporary_root / relative_path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPOSITORY_ROOT / relative_path, target)


def mutate(temporary_root, relative_path, old, new):
    path = temporary_root / relative_path
    text = path.read_text(encoding="utf-8")
    if text.count(old) != 1:
        raise AssertionError(f"mutation anchor count for {old!r} is {text.count(old)}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def require_rejection(relative_path, old, new, expected_fragment):
    with tempfile.TemporaryDirectory(prefix="qwen-model-admission-test-") as scratch:
        temporary_root = pathlib.Path(scratch)
        make_fixture(temporary_root)
        mutate(temporary_root, relative_path, old, new)
        try:
            CHECKER.validate(temporary_root)
        except CHECKER.ConsistencyError as error:
            if expected_fragment not in str(error):
                raise AssertionError(
                    f"unexpected rejection for {relative_path}: {error}"
                ) from error
        else:
            raise AssertionError(f"mutation was admitted: {relative_path} {new!r}")


def main():
    counts = CHECKER.validate(REPOSITORY_ROOT)
    if counts["candidate_staging_rows"] != 17:
        raise AssertionError(f"unexpected staging count: {counts}")

    require_rejection(
        pathlib.Path("evidence/model-admission/readiness-candidates.tsv"),
        "prithivMLmods/Qwen3.5-2B-Opus-Distilled-Heretic-Thinking-Multistage-SFT-v1.0-GGUF",
        "prithivMLmods/Qwen3.5-2B-...-GGUF",
        "inexact identifier",
    )
    require_rejection(
        pathlib.Path("evidence/model-admission/readiness-appliance-artifacts.tsv"),
        "\tqwen38-4b-i1-q6k\tnone\tremote/download-qwen38-4b-distill-i1-q6k.sh",
        "\tqwen38-4b-i1-q6k\tmissing-ledger-row\tremote/download-qwen38-4b-distill-i1-q6k.sh",
        "not a ledger id",
    )
    require_rejection(
        pathlib.Path("evidence/model-admission/readiness-candidates.tsv"),
        "qwen38-9b-distill\tempero-ai/Qwen3.8-9B-Distill-GGUF\tQwen3.8-9B-Q4_K_M.gguf\tserved",
        "qwen38-9b-distill\tempero-ai/Qwen3.8-9B-Distill-GGUF\tQwen3.8-9B-Q4_K_M.gguf\tphase-1",
        "differs from ledger stage",
    )
    # Mutate the transition without changing any measured evidence. The checker
    # must refuse a quality stage whose readiness row lacks artifact throughput.
    require_rejection(
        pathlib.Path("evidence/model-admission/candidate-ledger.tsv"),
        "\t-\t-\tthroughput-arm\tmeasure artifact-specific decode before any quality transition\tpending",
        "\t-\t-\tquality-sweep\tmeasure artifact-specific decode before any quality transition\tpending",
        "lacks artifact-specific throughput",
    )

    require_rejection(
        pathlib.Path("evidence/model-admission/static-admission.tsv"),
        "minicpm5-1b-stock\topenbmb/MiniCPM5-1B-GGUF",
        "minicpm5-1b-stock\twrong/MiniCPM5-1B-GGUF",
        "repository differs from ledger",
    )
    print("model_admission_consistency_tests=accepted")


if __name__ == "__main__":
    main()
