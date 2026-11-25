#!/usr/bin/env python3
"""
validate_context.py — External Context Schema & Zero-PII Validator

Validates external context staging files (.agents/context/*.json and *.template.json)
for structural schema integrity and scans for forbidden PII patterns (emails, tokens, SSNs).
Optionally generates sample mock context fixtures for local simulation.

Usage:
    python3 validate_context.py --check-templates
    python3 validate_context.py --check-staged
    python3 validate_context.py --generate-sample all
"""

import argparse
import glob
import json
import os
import re
import sys

# Common regex patterns to detect accidental PII / credential leakage
PII_PATTERNS = [
    (r"(?i)\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,7}\b", "Email address"),
    (r"\b\d{3}-\d{2}-\d{4}\b", "Social Security Number (SSN)"),
    (r"\b(?:\d{4}[ -]?){3}\d{4}\b", "Credit Card Number"),
    (r"(?i)\b(bearer\s+[A-Za-z0-9\-_=]{20,})\b", "Bearer Token"),
    (r"(?i)\b(ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{82})\b", "GitHub Token"),
    (r"(?i)\b(AIza[0-9A-Za-z-_]{35})\b", "Google API Key"),
    (r"(?i)\b(sk-[a-zA-Z0-9]{20,})\b", "Secret Key / API Token"),
]

REQUIRED_STREAM_KEYS = {
    "telemetry_crashes": ["schema_version", "source", "sanitized", "pii_scrubbed", "crashes"],
    "user_feedback": ["schema_version", "source", "sanitized", "pii_scrubbed", "feedback_clusters"],
    "developer_brief": ["schema_version", "channel", "sanitized", "pii_scrubbed", "topics"],
    "market_calendar": ["schema_version", "quarter", "sanitized", "pii_scrubbed", "events"],
}


def scan_for_pii(text: str, filepath: str) -> list[str]:
    """Scan raw text for known PII and secret patterns."""
    findings = []
    for pattern, name in PII_PATTERNS:
        matches = re.findall(pattern, text)
        if matches:
            # Mask the match for safe reporting
            masked = matches[0][:8] + "..." if len(matches[0]) > 8 else "***"
            findings.append(f"Detected {name} ({masked}) in {filepath}")
    return findings


def validate_file(filepath: str, stream_type: str = None) -> tuple[bool, list[str]]:
    """Validate a single context JSON file."""
    errors = []
    if not os.path.isfile(filepath):
        return False, [f"File not found: {filepath}"]

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            raw_text = f.read()
            data = json.loads(raw_text)
    except json.JSONDecodeError as e:
        return False, [f"Invalid JSON in {filepath}: {e}"]

    # 1. PII Scan
    pii_violations = scan_for_pii(raw_text, filepath)
    if pii_violations:
        errors.extend(pii_violations)

    # 2. General Zero-PII Invariant assertions
    if not data.get("pii_scrubbed"):
        errors.append(f"{filepath} must explicitly declare 'pii_scrubbed: true'")
    if not data.get("schema_version"):
        errors.append(f"{filepath} missing 'schema_version'")

    # 3. Stream-specific structure
    if not stream_type:
        base = os.path.basename(filepath)
        for known in REQUIRED_STREAM_KEYS:
            if known in base:
                stream_type = known
                break

    if stream_type and stream_type in REQUIRED_STREAM_KEYS:
        for required_key in REQUIRED_STREAM_KEYS[stream_type]:
            if required_key not in data:
                errors.append(f"{filepath} missing required top-level key: '{required_key}'")

    return len(errors) == 0, errors


def check_templates(context_dir: str) -> bool:
    """Validate all template files."""
    templates = glob.glob(os.path.join(context_dir, "*.template.json"))
    if not templates:
        print(f"[ERROR] No template files found in {context_dir}")
        return False

    all_passed = True
    print(f"[CHECK] Validating {len(templates)} template file(s)...")
    for t in templates:
        passed, errors = validate_file(t)
        if passed:
            print(f"  ✓ {os.path.basename(t)} conforms to Zero-PII schema.")
        else:
            all_passed = False
            print(f"  ✗ {os.path.basename(t)} failed:")
            for err in errors:
                print(f"    - {err}")

    return all_passed


def check_staged(context_dir: str) -> bool:
    """Validate all live staged JSON files."""
    live_files = [
        f for f in glob.glob(os.path.join(context_dir, "*.json"))
        if not f.endswith(".template.json")
    ]
    if not live_files:
        print("[INFO] No live staged context files currently present in .agents/context/")
        return True

    all_passed = True
    print(f"[CHECK] Validating {len(live_files)} live staged context file(s)...")
    for lf in live_files:
        passed, errors = validate_file(lf)
        if passed:
            print(f"  ✓ {os.path.basename(lf)} passed Zero-PII and structural schema check.")
        else:
            all_passed = False
            print(f"  ✗ {os.path.basename(lf)} failed validation:")
            for err in errors:
                print(f"    - {err}")

    return all_passed


def generate_sample(context_dir: str, stream: str):
    """Generate mock sample fixtures from templates for local dry-runs."""
    mapping = {
        "telemetry": ("telemetry_crashes.template.json", "telemetry_crashes.json"),
        "feedback": ("user_feedback.template.json", "user_feedback.json"),
        "brief": ("developer_brief.template.json", "developer_brief.json"),
        "calendar": ("market_calendar.template.json", "market_calendar.json"),
    }

    targets = list(mapping.keys()) if stream == "all" else [stream]
    for target in targets:
        if target not in mapping:
            print(f"[WARN] Unknown stream '{target}'. Choose from {list(mapping.keys())} or 'all'")
            continue

        tmpl_file, live_file = mapping[target]
        tmpl_path = os.path.join(context_dir, tmpl_file)
        live_path = os.path.join(context_dir, live_file)

        if not os.path.exists(tmpl_path):
            print(f"[ERROR] Template {tmpl_path} missing.")
            continue

        with open(tmpl_path, "r", encoding="utf-8") as f:
            content = f.read()

        with open(live_path, "w", encoding="utf-8") as f:
            f.write(content)

        print(f"[GENERATED] Scaffolding mock live context: {live_path}")


def main():
    parser = argparse.ArgumentParser(description="External Context Schema & Zero-PII Validator")
    parser.add_argument("--context-dir", default=".agents/context", help="Path to context directory")
    parser.add_argument("--check-templates", action="store_true", help="Validate all *.template.json files")
    parser.add_argument("--check-staged", action="store_true", help="Validate all live staged *.json files")
    parser.add_argument("--generate-sample", choices=["telemetry", "feedback", "brief", "calendar", "all"], help="Generate sample mock context file(s)")

    args = parser.parse_args()

    # Default to checking templates and staged if no action specified
    if not (args.check_templates or args.check_staged or args.generate_sample):
        args.check_templates = True
        args.check_staged = True

    success = True
    if args.check_templates:
        if not check_templates(args.context_dir):
            success = False

    if args.check_staged:
        if not check_staged(args.context_dir):
            success = False

    if args.generate_sample:
        generate_sample(args.context_dir, args.generate_sample)

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
