#!/usr/bin/env bash
# ==============================================================================
# factory.sh — RealizeAlpha Software Factory Developer CLI
#
# Thin wrapper around the software factory scripts for local use: dry-runs,
# autonomous/interactive runs, external context validation, metrics, and
# run-state reset.
#
# Note: when run outside Antigravity's run_workflow, agents are stubbed, so
# dry-run/run exercise the control flow and context loading only.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

FACTORY_PY=".github/skills/software-factory/scripts/factory_pipeline.py"
CONTEXT_PY=".agents/context/scripts/validate_context.py"

usage() {
    cat <<EOF
Usage: ./scripts/factory.sh <command> [options]

Commands:
    dry-run [focus]              Simulate a cycle without writing files, state, or metrics.
    run [focus] [iterations]     Run the autonomous loop (default: 3 iterations).
    interactive [focus]          Run one interactive iteration with user checkpoints.
    context check                Validate context templates and staged files (schema + PII).
    context sample [stream]      Generate a mock context file (telemetry|feedback|brief|calendar|all).
    metrics [--ascii] [--limit N] Show the metrics dashboard (Markdown by default).
    reset [--force-unlock]       Clear .agents/.factory_run_state.json. With --force-unlock,
                                 also remove a stale .git/index.lock if no git process is running.
    help                         Show this help.

Examples:
    ./scripts/factory.sh dry-run "agentic trading"
    ./scripts/factory.sh run "portfolio greeks" 2
    ./scripts/factory.sh metrics --ascii
    ./scripts/factory.sh context sample telemetry
EOF
}

CMD="${1:-help}"
shift || true

case "${CMD}" in
    dry-run)
        ARGS=(--mode=autonomous --stages=ideate --dry-run)
        [ -n "${1:-}" ] && ARGS+=("--focus=${1}")
        echo "==> Running Software Factory simulation (dry-run)..."
        python3 "${FACTORY_PY}" "${ARGS[@]}"
        ;;

    run)
        ITERS="${2:-3}"
        ARGS=(--mode=autonomous --stages=full "--max-iterations=${ITERS}")
        [ -n "${1:-}" ] && ARGS+=("--focus=${1}")
        echo "==> Launching autonomous factory loop (${ITERS} iterations)..."
        python3 "${FACTORY_PY}" "${ARGS[@]}"
        ;;

    interactive)
        ARGS=(--mode=interactive --stages=full --max-iterations=1)
        [ -n "${1:-}" ] && ARGS+=("--focus=${1}")
        echo "==> Launching interactive factory task..."
        python3 "${FACTORY_PY}" "${ARGS[@]}"
        ;;

    context)
        SUBCMD="${1:-check}"
        case "${SUBCMD}" in
            check|validate)
                echo "==> Validating external context schemas and Zero-PII invariant..."
                python3 "${CONTEXT_PY}" --check-templates --check-staged
                ;;
            sample|generate)
                STREAM="${2:-all}"
                echo "==> Generating mock context sample (${STREAM})..."
                python3 "${CONTEXT_PY}" --generate-sample "${STREAM}"
                ;;
            *)
                echo "Unknown context subcommand: ${SUBCMD}. Use 'check' or 'sample'." >&2
                exit 1
                ;;
        esac
        ;;

    metrics)
        MARGS=()
        for a in "$@"; do
            if [ "${a}" = "--ascii" ]; then
                MARGS+=(--format ascii)
            else
                MARGS+=("${a}")
            fi
        done
        python3 "${FACTORY_PY}" --metrics ${MARGS[@]+"${MARGS[@]}"}
        ;;

    reset)
        echo "==> Clearing Software Factory run state..."
        rm -f .agents/.factory_run_state.json
        if [ -f .git/index.lock ]; then
            if [ "${1:-}" = "--force-unlock" ]; then
                if pgrep -x git >/dev/null 2>&1; then
                    echo "!! A git process is running; refusing to remove .git/index.lock." >&2
                    exit 1
                fi
                rm -f .git/index.lock
                echo "==> Removed stale .git/index.lock."
            else
                echo "!! .git/index.lock exists. If no git command is running, re-run with --force-unlock." >&2
            fi
        fi
        echo "==> Run state cleared."
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        echo "Unknown command: ${CMD}" >&2
        echo "" >&2
        usage
        exit 1
        ;;
esac
