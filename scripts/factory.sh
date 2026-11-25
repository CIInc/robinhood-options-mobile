#!/usr/bin/env bash
# ==============================================================================
# factory.sh — RealizeAlpha Software Factory Developer CLI
#
# Provides a zero-friction developer interface for executing simulation dry-runs,
# autonomous engineering loops, external context validation, telemetry metrics,
# and state recovery without memorizing nested paths or arguments.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

FACTORY_PY=".github/skills/software-factory/scripts/factory_pipeline.py"
CONTEXT_PY=".agents/context/scripts/validate_context.py"
METRICS_PY=".github/skills/software-factory/scripts/metrics_summary.py"

usage() {
    cat <<EOF
Usage: ./scripts/factory.sh <command> [options]

Commands:
    dry-run [focus]          Simulate feature discovery & task execution without mutating files.
    run [focus] [iters]      Execute continuous autonomous closed loop (default: 3 iterations).
    interactive [focus]      Run interactive Maker-Verifier-Critic loop with user checkpoints.
    context check            Validate context templates and staged files for schema & Zero PII.
    context sample [stream]  Generate mock context fixture (telemetry|feedback|brief|calendar|all).
    metrics [--ascii]        Display factory execution metrics and pass-rate dashboard.
    reset                    Reset interrupted run state (.factory_run_state.json) and lockfiles.
    help                     Display this help menu.

Examples:
    ./scripts/factory.sh dry-run "agentic trading"
    ./scripts/factory.sh run "portfolio greeks" 2
    ./scripts/factory.sh metrics
    ./scripts/factory.sh metrics --format ascii
    ./scripts/factory.sh context check
    ./scripts/factory.sh context sample telemetry
    ./scripts/factory.sh reset
EOF
}

CMD="${1:-help}"

case "${CMD}" in
    dry-run)
        FOCUS="${2:-}"
        ARGS="--mode=autonomous --stages=ideate --dry-run"
        if [ -n "${FOCUS}" ]; then
            ARGS="${ARGS} --focus=${FOCUS}"
        fi
        echo "==> Running Software Factory Simulation (Dry-Run)..."
        python3 "${FACTORY_PY}" ${ARGS}
        ;;

    run)
        FOCUS="${2:-}"
        ITERS="${3:-3}"
        ARGS="--mode=autonomous --stages=full --max-iterations=${ITERS}"
        if [ -n "${FOCUS}" ]; then
            ARGS="${ARGS} --focus=${FOCUS}"
        fi
        echo "==> Launching Continuous Autonomous Factory Loop (${ITERS} iterations)..."
        python3 "${FACTORY_PY}" ${ARGS}
        ;;

    interactive)
        FOCUS="${2:-}"
        ARGS="--mode=interactive --stages=full --max-iterations=1"
        if [ -n "${FOCUS}" ]; then
            ARGS="${ARGS} --focus=${FOCUS}"
        fi
        echo "==> Launching Interactive Software Factory Task..."
        python3 "${FACTORY_PY}" ${ARGS}
        ;;

    context)
        SUBCMD="${2:-check}"
        case "${SUBCMD}" in
            check|validate)
                echo "==> Validating External Context Schemas and Zero-PII Invariant..."
                python3 "${CONTEXT_PY}" --check-templates --check-staged
                ;;
            sample|generate)
                STREAM="${3:-all}"
                echo "==> Generating Mock Context Sample (${STREAM})..."
                python3 "${CONTEXT_PY}" --generate-sample "${STREAM}"
                ;;
            *)
                echo "Unknown context subcommand: ${SUBCMD}. Use 'check' or 'sample'."
                exit 1
                ;;
        esac
        ;;

    metrics)
        shift || true
        python3 "${FACTORY_PY}" --metrics "$@"
        ;;

    reset)
        echo "==> Resetting Software Factory Run State..."
        rm -f .agents/.factory_run_state.json
        if [ -f .git/index.lock ]; then
            echo "==> Clearing stale git index.lock..."
            rm -f .git/index.lock
        fi
        echo "==> Run state clean. Factory is ready for a new autonomous cycle."
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        echo "Unknown command: ${CMD}"
        echo ""
        usage
        exit 1
        ;;
esac
