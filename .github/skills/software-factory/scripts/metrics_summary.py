#!/usr/bin/env python3
"""
metrics_summary.py — RealizeAlpha Software Factory Telemetry Reporter

Parses historical execution runs from .agents/.factory_metrics.json and formats
an executive performance dashboard in Markdown (default) or ASCII format.

Usage:
    python3 metrics_summary.py [--format markdown|ascii] [--limit 5]
"""

import argparse
import json
import os
import sys


def load_metrics(metrics_file: str) -> dict:
    if not os.path.exists(metrics_file):
        return {"runs": []}
    try:
        with open(metrics_file, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"Warning: Could not parse {metrics_file}: {e}", file=sys.stderr)
        return {"runs": []}


def calculate_stats(runs: list) -> dict:
    total_runs = len(runs)
    total_iterations = sum(r.get("iterations_completed", 0) for r in runs)
    items_attempted = sum(r.get("items_attempted", 0) for r in runs)
    items_completed = sum(r.get("items_completed", 0) for r in runs)
    items_failed = sum(r.get("items_failed", 0) for r in runs)
    total_duration = sum(r.get("duration_seconds", 0.0) for r in runs)
    cb_trips = sum(1 for r in runs if r.get("circuit_breaker_tripped"))

    success_rate = 100.0 if (items_completed + items_failed) == 0 else (items_completed / (items_completed + items_failed)) * 100
    avg_duration = 0.0 if total_runs == 0 else total_duration / total_runs

    return {
        "total_runs": total_runs,
        "total_iterations": total_iterations,
        "items_attempted": items_attempted,
        "items_completed": items_completed,
        "items_failed": items_failed,
        "success_rate": success_rate,
        "total_duration": total_duration,
        "avg_duration": avg_duration,
        "cb_trips": cb_trips,
    }


def format_markdown(stats: dict, runs: list, limit: int) -> str:
    lines = [
        "### 📊 Software Factory Telemetry & Performance Dashboard",
        "",
        "| Metric | Value | Description |",
        "|---|---|---|",
        f"| **Total Factory Runs** | `{stats['total_runs']}` | Total executed pipelines |",
        f"| **Total Cycles / Iterations** | `{stats['total_iterations']}` | Iterations through autonomous loop |",
        f"| **Items Completed** | `{stats['items_completed']}` | Verified & shipped features/fixes |",
        f"| **Items Failed** | `{stats['items_failed']}` | Tasks failing verification or critic |",
        f"| **Pass Rate** | `{stats['success_rate']:.1f}%` | Maker-Verifier-Critic success percentage |",
        f"| **Circuit Breaker Trips** | `{stats['cb_trips']}` | Repetitive failure halts |",
        f"| **Avg Cycle Latency** | `{stats['avg_duration']:.1f}s` | Mean duration per factory run |",
        "",
        f"#### Recent Runs (Last {min(limit, len(runs))})",
        "",
        "| Timestamp | Mode | Stages | Dry Run | Iterations | Completed | Failed | CB Tripped |",
        "|---|---|---|---|---|---|---|---|",
    ]

    recent = runs[-limit:] if limit > 0 else runs
    for r in reversed(recent):
        ts = r.get("timestamp", "")[:19].replace("T", " ")
        mode = r.get("mode", "autonomous")
        stages = r.get("stages", "full")
        dry = "✓" if r.get("dry_run") else "✗"
        iters = r.get("iterations_completed", 0)
        done = r.get("items_completed", 0)
        fail = r.get("items_failed", 0)
        cb = "⚠️ Tripped" if r.get("circuit_breaker_tripped") else "Clean"
        lines.append(f"| `{ts}` | `{mode}` | `{stages}` | `{dry}` | {iters} | {done} | {fail} | {cb} |")

    return "\n".join(lines)


def format_ascii(stats: dict, runs: list, limit: int) -> str:
    lines = [
        "+-----------------------------------------------------------------------+",
        "|        SOFTWARE FACTORY TELEMETRY & PERFORMANCE DASHBOARD             |",
        "+-----------------------------------------------------------------------+",
        f"| Total Runs:             {stats['total_runs']:<10} | Cycles Completed:      {stats['total_iterations']:<10} |",
        f"| Items Completed:        {stats['items_completed']:<10} | Items Failed:          {stats['items_failed']:<10} |",
        f"| Pass Rate:              {stats['success_rate']:<9.1f}% | Circuit Breaker Trips: {stats['cb_trips']:<10} |",
        f"| Average Duration:       {stats['avg_duration']:<8.1f}s | Total Duration:        {stats['total_duration']:<8.1f}s |",
        "+-----------------------------------------------------------------------+",
        f"| RECENT RUNS (Last {min(limit, len(runs))} runs):",
        "+---------------------+------------+---------+---------+-------+-------+--+",
        "| Timestamp           | Mode       | Stages  | Dry Run | Done  | Fail  |CB|",
        "+---------------------+------------+---------+---------+-------+-------+--+",
    ]

    recent = runs[-limit:] if limit > 0 else runs
    for r in reversed(recent):
        ts = r.get("timestamp", "")[:19].replace("T", " ")
        mode = r.get("mode", "auto")[:10]
        stages = r.get("stages", "full")[:7]
        dry = "Yes" if r.get("dry_run") else "No"
        done = r.get("items_completed", 0)
        fail = r.get("items_failed", 0)
        cb = "!!" if r.get("circuit_breaker_tripped") else "OK"
        lines.append(f"| {ts:<19} | {mode:<10} | {stages:<7} | {dry:<7} | {done:<5} | {fail:<5} |{cb:<2}|")

    lines.append("+---------------------+------------+---------+---------+-------+-------+--+")
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description="RealizeAlpha Software Factory Telemetry Reporter")
    parser.add_argument("--metrics-file", default=".agents/.factory_metrics.json", help="Path to metrics JSON file")
    parser.add_argument("--format", choices=["markdown", "ascii"], default="markdown", help="Output format (default: markdown)")
    parser.add_argument("--limit", type=int, default=5, help="Number of recent runs to display (default: 5)")
    parser.add_argument("--metrics", "--show-metrics", action="store_true", help="Display metrics report")

    args = parser.parse_args(argv)

    data = load_metrics(args.metrics_file)
    runs = data.get("runs", [])
    stats = calculate_stats(runs)

    if args.format == "ascii":
        print(format_ascii(stats, runs, args.limit))
    else:
        print(format_markdown(stats, runs, args.limit))


if __name__ == "__main__":
    main()
