"""Unit tests for Software Factory helper scripts (stdlib unittest, no deps).

Run from anywhere:
    python3 -m unittest discover -s .github/skills/software-factory/tests -v
"""

import contextlib
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(REPO_ROOT / ".github/skills/software-factory/scripts"))
sys.path.insert(0, str(REPO_ROOT / ".agents/context/scripts"))

STATE_FILE = REPO_ROOT / ".agents/.factory_run_state.json"
METRICS_FILE = REPO_ROOT / ".agents/.factory_metrics.json"


def _snapshot(path):
    return path.read_bytes() if path.exists() else None


# Importing must not run the pipeline or touch state/metrics files.
_before = (_snapshot(STATE_FILE), _snapshot(METRICS_FILE))
with contextlib.redirect_stdout(io.StringIO()) as _import_out:
    import factory_pipeline as fp  # noqa: E402
_after = (_snapshot(STATE_FILE), _snapshot(METRICS_FILE))

import metrics_summary  # noqa: E402
import validate_context  # noqa: E402


class ImportSideEffectsTest(unittest.TestCase):
    def test_import_has_no_side_effects(self):
        self.assertEqual(_before, _after)
        self.assertNotIn("Starting Software Factory pipeline", _import_out.getvalue())


class InferTestFilesTest(unittest.TestCase):
    def setUp(self):
        self._cwd = os.getcwd()
        os.chdir(REPO_ROOT)

    def tearDown(self):
        os.chdir(self._cwd)

    def test_flat_test_resolution(self):
        src = "src/robinhood_options_mobile/lib/services/portfolio_alert_service.dart"
        self.assertEqual(
            fp.infer_test_files([src]),
            ["src/robinhood_options_mobile/test/portfolio_alert_service_test.dart"],
        )

    def test_missing_test_warns_and_returns_empty(self):
        src = "src/robinhood_options_mobile/lib/widgets/does_not_exist_xyz.dart"
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(fp.infer_test_files([src]), [])
        self.assertIn("No companion test found", out.getvalue())

    def test_deduplicates(self):
        src = "src/robinhood_options_mobile/lib/services/portfolio_alert_service.dart"
        self.assertEqual(len(fp.infer_test_files([src, src])), 1)


class CategorizeReleaseItemsTest(unittest.TestCase):
    def test_conventional_prefixes(self):
        result = fp.categorize_release_items([
            "feat(alerts): skew alert",
            "fix(portfolio): mask flicker",
            "perf(gex): faster loop",
            "sec(auth): rotate tokens",
        ])
        self.assertEqual(result["Added"], ["feat(alerts): skew alert"])
        self.assertEqual(result["Fixed"], ["fix(portfolio): mask flicker"])
        self.assertEqual(result["Changed"], ["perf(gex): faster loop"])
        self.assertEqual(result["Security"], ["sec(auth): rotate tokens"])

    def test_unprefixed_defaults_to_added_and_empty_sections_dropped(self):
        self.assertEqual(fp.categorize_release_items(["Volatility cone card"]),
                         {"Added": ["Volatility cone card"]})


class SimilarityTest(unittest.TestCase):
    def test_identical_titles_are_duplicates(self):
        dup, match = fp.is_duplicate_proposal(
            "Option volatility skew alert", ["Option Volatility Skew Alert"])
        self.assertTrue(dup)
        self.assertEqual(match, "Option Volatility Skew Alert")

    def test_unrelated_titles_are_not_duplicates(self):
        dup, _ = fp.is_duplicate_proposal("Carry trade optimizer", ["Tax lot matching"])
        self.assertFalse(dup)

    def test_empty_tokens_score_zero(self):
        self.assertEqual(fp.compute_token_similarity("a the", "an or"), 0.0)


class MetricsSummaryTest(unittest.TestCase):
    def test_empty_runs(self):
        stats = metrics_summary.calculate_stats([])
        self.assertEqual(stats["total_runs"], 0)
        self.assertEqual(stats["success_rate"], 100.0)

    def test_mixed_runs(self):
        runs = [
            {"items_completed": 3, "items_failed": 1, "duration_seconds": 10.0,
             "iterations_completed": 2},
            {"items_completed": 1, "items_failed": 0, "duration_seconds": 20.0,
             "iterations_completed": 1, "circuit_breaker_tripped": True},
        ]
        stats = metrics_summary.calculate_stats(runs)
        self.assertEqual(stats["items_completed"], 4)
        self.assertAlmostEqual(stats["success_rate"], 80.0)
        self.assertAlmostEqual(stats["avg_duration"], 15.0)
        self.assertEqual(stats["cb_trips"], 1)


class ValidateContextTest(unittest.TestCase):
    def test_templates_pass(self):
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertTrue(validate_context.check_templates(
                str(REPO_ROOT / ".agents/context")))

    def _validate(self, payload):
        with tempfile.NamedTemporaryFile("w", suffix="_user_feedback.json",
                                         delete=False) as f:
            json.dump(payload, f)
        try:
            return validate_context.validate_file(f.name)
        finally:
            os.unlink(f.name)

    def _base(self, **extra):
        payload = {"schema_version": "1.0.0", "source": "test", "sanitized": True,
                   "pii_scrubbed": True, "feedback_clusters": []}
        payload.update(extra)
        return payload

    def test_clean_payload_passes(self):
        ok, errors = self._validate(self._base())
        self.assertTrue(ok, errors)

    def test_email_is_flagged(self):
        ok, errors = self._validate(self._base(note="contact jane.doe@example.com"))
        self.assertFalse(ok)
        self.assertTrue(any("Email" in e for e in errors))

    def test_luhn_valid_card_is_flagged(self):
        ok, _ = self._validate(self._base(note="card 4111 1111 1111 1111"))
        self.assertFalse(ok)

    def test_non_luhn_number_is_not_flagged(self):
        ok, errors = self._validate(self._base(note="order 1234 5678 9012 3456"))
        self.assertTrue(ok, errors)

    def test_missing_pii_flag_fails(self):
        ok, _ = self._validate(self._base(pii_scrubbed=False))
        self.assertFalse(ok)


if __name__ == "__main__":
    unittest.main()
