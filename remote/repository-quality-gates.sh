#!/bin/sh
set -eu

# Run the clone-local gates that protect executable policy and retained
# evidence. Hardware, model files, and the pinned llama.cpp source remain
# separate integration surfaces; this gate names that boundary by running only
# tests whose complete fixtures live in this repository.

if [ "$#" -ne 0 ]; then
    printf 'usage: %s\n' "$0" >&2
    exit 2
fi

script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repository_root=$(CDPATH='' cd -- "$script_directory/.." && pwd)
cd "$repository_root"

for required_command in bash node shellcheck ruff mypy python3 curl flock git ps sha256sum c++ bwrap; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        printf 'required quality-gate command is absent: %s\n' \
            "$required_command" >&2
        exit 2
    fi
done

chromium_command=${QWEN_CHROMIUM:-chromium}
if ! command -v "$chromium_command" >/dev/null 2>&1; then
    printf 'required quality-gate browser is absent: %s\n' \
        "$chromium_command" >&2
    exit 2
fi

if [ ! -f "$script_directory/gate-cell-key.sh" ]; then
    printf 'gate cell reader is absent: %s\n' \
        "$script_directory/gate-cell-key.sh" >&2
    exit 2
fi
GATE_CELL_ROOT=$repository_root
export GATE_CELL_ROOT
GATE_CELL_DRIVER_PATH=$script_directory/$(basename -- "$0")
export GATE_CELL_DRIVER_PATH
# shellcheck source=remote/gate-cell-key.sh
. "$script_directory/gate-cell-key.sh"

shell_files=$(find remote -type f -name '*.sh' -print | sort)
python_files=$(find remote -type f -name '*.py' -print | sort)
typed_python_files='remote/open-verified-lock-descriptor.py
remote/test-open-verified-lock-descriptor.py
remote/signal-process-group.py
remote/test-signal-process-group.py
remote/summarize-fixed64-served-campaign.py
remote/test-summarize-fixed64-served-campaign.py
remote/test-verify-external-vulkan-lease.py
remote/verify-external-vulkan-lease.py'

gate_shell_syntax() {
    for shell_file in $shell_files; do
        IFS= read -r shebang <"$shell_file"
        case $shebang in
            *bash*) bash -n "$shell_file" || return 1 ;;
            *) sh -n "$shell_file" || return 1 ;;
        esac
    done
    return 0
}

# Warning-level diagnostics fail the gate. The repository treats warning drift
# as a defect even where ShellCheck would return success at error level.
gate_shellcheck_walk() {
    # shellcheck disable=SC2086
    shellcheck -S warning $shell_files
}

gate_ruff_typed_walk() {
    # shellcheck disable=SC2086
    ruff check --select EXE,I,B $typed_python_files || return 1
    # shellcheck disable=SC2086
    ruff format --check $typed_python_files || return 1
    # shellcheck disable=SC2086
    mypy --strict $typed_python_files || return 1
    return 0
}

gate_python_syntax_walk() {
    # shellcheck disable=SC2086
    python3 -m py_compile $python_files
}

gate_cell_init
trap gate_cell_cleanup EXIT

# The gate runs cheapest and most-likely-to-fail first, so a tree-wide policy
# defect is reported in seconds rather than after the fixture replays. The two
# authorities over the whole tracked tree open the order and always run: each
# enumerates its own inputs through git, which puts its read set past what the
# static reader can name.
gate_cell evidence-manifest universal remote/refresh-evidence-manifest.sh \
    'remote/refresh-evidence-manifest.sh --check'
gate_cell text-policy universal remote/check-text-policy.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/check-text-policy.py'

gate_cell shell-syntax files "$shell_files" gate_shell_syntax
gate_cell shellcheck files "$shell_files" gate_shellcheck_walk
gate_cell ruff-repository files "$python_files" 'ruff check remote'
gate_cell ruff-typed files "$typed_python_files" gate_ruff_typed_walk
gate_cell python-syntax files "$python_files" gate_python_syntax_walk

# Unit tests over parsers, ledgers, and protocol schemas: each holds its whole
# fixture in the repository and finishes in seconds.
gate_cell test-repository-gate-cells derive \
    'remote/test-repository-gate-cells.sh remote/gate-cell-key.sh' \
    remote/test-repository-gate-cells.sh
gate_cell test-open-verified-lock-descriptor derive \
    remote/test-open-verified-lock-descriptor.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-open-verified-lock-descriptor.py'
gate_cell test-signal-process-group derive remote/test-signal-process-group.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-signal-process-group.py'
gate_cell test-image-protocol derive remote/test-image-protocol.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-image-protocol.py'
gate_cell test-summarize-draft-pair derive remote/test-summarize-draft-pair.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-summarize-draft-pair.py'
gate_cell test-build-cache-keys derive \
    'remote/test-build-cache-keys.sh remote/build-cache-keys.sh remote/build-llama-preset.sh' \
    remote/test-build-cache-keys.sh
gate_cell test-summarize-fixed64-served-campaign derive \
    remote/test-summarize-fixed64-served-campaign.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-summarize-fixed64-served-campaign.py'
gate_cell test-verify-external-vulkan-lease derive \
    'remote/test-verify-external-vulkan-lease.py remote/image_protocol.py' \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-verify-external-vulkan-lease.py'
gate_cell test-verify-representation-pair derive \
    remote/test-verify-representation-pair.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-verify-representation-pair.py'
gate_cell test-quality-suite derive remote/test-quality-suite.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-quality-suite.py'
gate_cell test-regrade-quality-roster derive \
    remote/test-regrade-quality-roster.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-regrade-quality-roster.py'
gate_cell test-gguf-tokenizer-identity derive \
    remote/test-gguf-tokenizer-identity.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-gguf-tokenizer-identity.py'
gate_cell test-admit-candidate-static derive \
    remote/test-admit-candidate-static.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-admit-candidate-static.py'
gate_cell test-check-model-admission-consistency derive \
    remote/test-check-model-admission-consistency.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-check-model-admission-consistency.py'
gate_cell test-analyze-throughput-targets derive \
    remote/test-analyze-throughput-targets.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-analyze-throughput-targets.py'
gate_cell analyze-throughput-targets-check derive \
    remote/analyze-throughput-targets.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/analyze-throughput-targets.py --check'
gate_cell test-image-service derive remote/test-image-service.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-image-service.py'
gate_cell test-image-mcp derive remote/image-mcp/test-image-mcp.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/image-mcp/test-image-mcp.py'
gate_cell test-image-review derive \
    'remote/test-image-review.py remote/image_protocol.py' \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-image-review.py'
gate_cell test-web-mcp derive remote/web-mcp/test-web-mcp.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/web-mcp/test-web-mcp.py'
gate_cell test-authorize-broker derive remote/web-mcp/test-authorize-broker.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/web-mcp/test-authorize-broker.py'
gate_cell test-summarize-kernel-census derive \
    remote/test-summarize-kernel-census.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-summarize-kernel-census.py'
gate_cell test-sample-clock-sidecar derive remote/test-sample-clock-sidecar.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-sample-clock-sidecar.py'
gate_cell test-validate-clock-sidecar derive remote/test-validate-clock-sidecar.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-validate-clock-sidecar.py'
gate_cell test-census-controls derive remote/test-census-controls.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-census-controls.py'
gate_cell test-census-replay-corpus derive \
    remote/test-census-replay-corpus.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-census-replay-corpus.py'
gate_cell test-summarize-perf-logger-slice derive \
    remote/test-summarize-perf-logger-slice.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-summarize-perf-logger-slice.py'
gate_cell test-summarize-prefill-ladder derive remote/test-summarize-prefill-ladder.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-summarize-prefill-ladder.py'
gate_cell test-summarize-bracket-ab derive remote/test-summarize-bracket-ab.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-summarize-bracket-ab.py'
gate_cell test-summarize-margin-witness derive remote/test-summarize-margin-witness.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-summarize-margin-witness.py'
gate_cell test-summarize-radv-isa derive remote/test-summarize-radv-isa.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-summarize-radv-isa.py'
gate_cell test-depth derive remote/raven2-shader-lab/test-depth.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/raven2-shader-lab/test-depth.py'
gate_cell test-measure-code-agent-tasks derive \
    remote/test-measure-code-agent-tasks.py \
    'PYTHONDONTWRITEBYTECODE=1 python3 remote/test-measure-code-agent-tasks.py'

# Ledger readers and registry checks: shell, no fixture server.
gate_cell check-validated-tuples derive remote/check-validated-tuples.sh \
    remote/check-validated-tuples.sh
gate_cell check-ledger-evidence derive remote/check-ledger-evidence.sh \
    remote/check-ledger-evidence.sh
# Row shape and cited-source existence are properties of the tree, so the gate
# asserts them here. The checks themselves observe software on the appliance or
# the workstation helper and run there under the host argument.
gate_cell check-install-requirements derive remote/check-install-requirements.sh \
    'remote/check-install-requirements.sh validate'
gate_cell test-model-registry derive remote/test-model-registry.sh \
    remote/test-model-registry.sh
gate_cell test-model-tiers derive remote/test-model-tiers.sh \
    remote/test-model-tiers.sh
gate_cell test-model-artifact-identity derive \
    remote/test-model-artifact-identity.sh remote/test-model-artifact-identity.sh
gate_cell test-image-registry derive remote/test-image-registry.sh \
    remote/test-image-registry.sh
gate_cell test-projector-fetch-dispatch derive \
    remote/test-projector-fetch-dispatch.sh remote/test-projector-fetch-dispatch.sh
gate_cell test-projector-pairing derive remote/test-projector-pairing.sh \
    remote/test-projector-pairing.sh
gate_cell test-probe-depth-projector derive \
    remote/test-probe-depth-projector.sh remote/test-probe-depth-projector.sh
gate_cell test-fetch-candidate-artifact derive \
    remote/test-fetch-candidate-artifact.sh remote/test-fetch-candidate-artifact.sh
gate_cell test-representation-arm derive remote/test-representation-arm.sh \
    remote/test-representation-arm.sh
gate_cell test-one-token-admission derive remote/test-one-token-admission.sh \
    remote/test-one-token-admission.sh
gate_cell test-measure-draft-pair derive remote/test-measure-draft-pair.sh \
    remote/test-measure-draft-pair.sh
gate_cell test-classify-checkpoint-semantics derive \
    remote/test-classify-checkpoint-semantics.sh \
    remote/test-classify-checkpoint-semantics.sh
gate_cell test-write-clangd-config derive remote/test-write-clangd-config.sh \
    remote/test-write-clangd-config.sh
gate_cell test-check-trace-source-status derive \
    remote/test-check-trace-source-status.sh remote/test-check-trace-source-status.sh
gate_cell test-prefix-checkpoint-key derive \
    'remote/test-prefix-checkpoint-key.sh remote/test-fixtures/prefix-checkpoint-key-probe.cpp patches/llama-server-prefix-checkpoint.patch' \
    remote/test-prefix-checkpoint-key.sh
gate_cell test-sync-runtime-tree derive remote/test-sync-runtime-tree.sh \
    remote/test-sync-runtime-tree.sh
gate_cell test-web-search-live derive remote/test-web-search-live.sh \
    remote/test-web-search-live.sh
gate_cell test-compute-state-lease derive remote/test-compute-state-lease.sh \
    remote/test-compute-state-lease.sh
gate_cell test-run-prefill-ladder derive remote/test-run-prefill-ladder.sh \
    remote/test-run-prefill-ladder.sh
gate_cell test-feature-roster derive remote/test-feature-roster.sh \
    remote/test-feature-roster.sh
gate_cell test-run-served-binary-ab derive remote/test-run-served-binary-ab.sh \
    remote/test-run-served-binary-ab.sh
gate_cell test-run-kernel-delta-witness derive remote/test-run-kernel-delta-witness.sh \
    remote/test-run-kernel-delta-witness.sh
gate_cell test-receipt-diff derive remote/raven2-shader-lab/test-receipt-diff.sh \
    remote/raven2-shader-lab/test-receipt-diff.sh
gate_cell test-lab-replay derive remote/raven2-shader-lab/test-lab-replay.sh \
    remote/raven2-shader-lab/test-lab-replay.sh
gate_cell test-web-presets derive remote/test-web-presets.sh \
    remote/test-web-presets.sh
gate_cell test-qwen-capacity-policy derive remote/test-qwen-capacity-policy.sh \
    remote/test-qwen-capacity-policy.sh
gate_cell test-qwen-launch-router-preflight derive \
    remote/test-qwen-launch-router-preflight.sh \
    remote/test-qwen-launch-router-preflight.sh
gate_cell test-qwen-web-launch derive remote/test-qwen-web-launch.sh \
    remote/test-qwen-web-launch.sh
gate_cell test-qwen-image-launch derive remote/test-qwen-image-launch.sh \
    remote/test-qwen-image-launch.sh
gate_cell test-check-runtime-tree derive remote/test-check-runtime-tree.sh \
    remote/test-check-runtime-tree.sh
gate_cell test-prepare-llama-vulkan-source derive \
    remote/test-prepare-llama-vulkan-source.sh \
    remote/test-prepare-llama-vulkan-source.sh
gate_cell test-promote-llama-build derive remote/test-promote-llama-build.sh \
    remote/test-promote-llama-build.sh
gate_cell test-deployment-bundle derive remote/test-deployment-bundle.sh \
    remote/test-deployment-bundle.sh
gate_cell test-run-image-standalone derive remote/test-run-image-standalone.sh \
    remote/test-run-image-standalone.sh
gate_cell test-run-fixed64-served-campaign derive \
    remote/test-run-fixed64-served-campaign.sh \
    remote/test-run-fixed64-served-campaign.sh
gate_cell test-run-trace-campaign derive remote/test-run-trace-campaign.sh \
    remote/test-run-trace-campaign.sh
gate_cell test-measurement-harnesses derive remote/test-measurement-harnesses.sh \
    remote/test-measurement-harnesses.sh
gate_cell test-qwen-session-signals derive \
    'remote/test-qwen-session-signals.sh remote/image_protocol.py' \
    remote/test-qwen-session-signals.sh
gate_cell test-qwen-runtime-guards derive remote/test-qwen-runtime-guards.sh \
    remote/test-qwen-runtime-guards.sh
gate_cell test-telemetry-session-records derive \
    'remote/test-telemetry-session-records.sh remote/image_protocol.py' \
    remote/test-telemetry-session-records.sh
gate_cell test-quality-roster derive remote/test-quality-roster.sh \
    remote/test-quality-roster.sh
gate_cell test-await-quiescence derive remote/test-await-quiescence.sh \
    remote/test-await-quiescence.sh
gate_cell test-telemetry-broker derive remote/test-telemetry-broker.sh \
    remote/test-telemetry-broker.sh
gate_cell test-census-sha256 derive remote/test-census-sha256.sh \
    remote/test-census-sha256.sh
gate_cell test-run-raven2-vulkan-kernel-census derive \
    remote/test-run-raven2-vulkan-kernel-census.sh \
    remote/test-run-raven2-vulkan-kernel-census.sh

# Served-page and full-chain replays: each starts a fixture server, a browser,
# or a whole launch chain, and each costs minutes.
gate_cell test-fallback-webui-model-state derive \
    remote/test-fallback-webui-model-state.mjs \
    'node remote/test-fallback-webui-model-state.mjs'
gate_cell test-fallback-webui-roster derive remote/test-fallback-webui-roster.mjs \
    'node remote/test-fallback-webui-roster.mjs'
gate_cell test-fallback-webui-model-selection derive \
    remote/test-fallback-webui-model-selection.sh \
    remote/test-fallback-webui-model-selection.sh
gate_cell test-fallback-webui-web-authorization derive \
    'remote/test-fallback-webui-web-authorization.sh remote/image_protocol.py' \
    remote/test-fallback-webui-web-authorization.sh
gate_cell test-fallback-webui-image-authorization derive \
    remote/test-fallback-webui-image-authorization.sh \
    remote/test-fallback-webui-image-authorization.sh
gate_cell test-web-tools-roundtrip derive \
    'remote/test-web-tools-roundtrip.sh remote/image_protocol.py' \
    remote/test-web-tools-roundtrip.sh
gate_cell test-admit-web-router-fake derive remote/test-admit-web-router-fake.sh \
    remote/test-admit-web-router-fake.sh
gate_cell test-admit-image-router derive remote/test-admit-image-router.sh \
    remote/test-admit-image-router.sh
gate_cell test-fallback-page-image derive \
    remote/web-mcp/test-fallback-page-image.py \
    'PYTHONDONTWRITEBYTECODE=1 QWEN_CHROMIUM="$chromium_command" python3 remote/web-mcp/test-fallback-page-image.py'
gate_cell test-code-agent-endpoint-fixture derive \
    remote/test-code-agent-endpoint-fixture.sh \
    remote/test-code-agent-endpoint-fixture.sh

gate_cell_summary
printf 'repository_quality_gates=accepted\n'
