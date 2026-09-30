"""Synthetic protocol tests: these records are NEVER game win-rate evidence."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "tools/advisor_eval/benchmark.py"
spec = importlib.util.spec_from_file_location("benchmark", MODULE)
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)


def fixture(wins=100):
    episodes = [{"id": f"{challenge}:{index}", "challenge": challenge,
                 "seed": f"fixture:{challenge}:{index}"}
                for challenge in B.CHALLENGES for index in range(100)]
    manifest = {"schema": 1, "scope": "every_challenge_individually", "stage": 50,
                "attempt": 1, "per_challenge": 100, "policy_digest": "fixture-policy",
                "rules_digest": "fixture-rules", "tail_alpha": .05 / 80,
                "episodes": episodes}
    manifest["manifest_digest"] = B.digest(manifest)
    records = [{**row, "manifest_digest": manifest["manifest_digest"],
                "policy_digest": "fixture-policy", "rules_digest": "fixture-rules",
                "source": "game_engine", "followed_advice": True, "decisions": 20,
                "trace_digest": "fixture-trace", "adapter_digest": "fixture-adapter",
                "outcome": "win" if int(row["id"].split(":")[-1]) < wins else "loss",
                "ante": 8, "game_won": True} for row in episodes]
    validation = {"status": "validated", "rules_digest": "fixture-rules",
                  "adapter_digest": "fixture-adapter", "challenges": list(B.CHALLENGES),
                  "checks_passed": list(B.MECHANICS), "parity_report_digest": "fixture-parity"}
    return manifest, records, validation


class ProtocolTests(unittest.TestCase):
    def test_exact_bounds(self):
        self.assertAlmostEqual(B.binomial_tail(10, 5, .5), .623046875)
        self.assertAlmostEqual(B.lower_bound(10, 10, .05), .05 ** .1)
        self.assertEqual(B.lower_bound(0, 100, .05), 0)
        self.assertLess(B.lower_bound(75, 100, .05), .75)
        self.assertLess(B.lower_bound(75, 100, .001), B.lower_bound(75, 100, .05))

    def test_empty_results_do_not_pass(self):
        manifest, _, _ = fixture()
        report = B.audit(manifest, [])
        self.assertFalse(report["passed"])
        self.assertFalse(report["training_allowed"])
        self.assertTrue(all(row["missing"] == 100 for row in report["challenges"]))

    def test_no_unvalidated_win_claim(self):
        manifest, records, _ = fixture()
        self.assertFalse(B.audit(manifest, records)["passed"])

    def test_fifty_percent_gate_does_not_allow_training(self):
        report = B.audit(*fixture())
        self.assertTrue(report["passed"])
        self.assertFalse(report["training_allowed"])

    def test_point_estimate_is_insufficient(self):
        self.assertFalse(B.audit(*fixture(50))["passed"])

    def test_one_bad_challenge_blocks_pooled_success(self):
        manifest, records, validation = fixture()
        for record in records:
            if record["challenge"] == B.CHALLENGES[-1]:
                record["outcome"] = "loss"
        report = B.audit(manifest, records, validation)
        self.assertFalse(report["passed"])
        self.assertEqual(sum(row["passed"] for row in report["challenges"]), 19)

    def test_unsupported_cannot_be_omitted(self):
        for outcome in ("timeout", "error", "unsupported", "censored"):
            manifest, records, validation = fixture()
            records[0]["outcome"] = outcome
            report = B.audit(manifest, records, validation)
            self.assertFalse(report["passed"])
            self.assertEqual(report["challenges"][0]["unresolved"], 1)

    def test_incomplete_campaign_cannot_pass(self):
        manifest, records, validation = fixture()
        self.assertFalse(B.audit(manifest, records[:-1], validation)["passed"])

    def test_mismatches_are_rejected(self):
        for field, value in (("source", "proxy"), ("followed_advice", False),
                             ("ante", 7), ("game_won", False), ("policy_digest", "other"),
                             ("seed", "other"), ("trace_digest", ""), ("decisions", 0)):
            manifest, records, validation = fixture()
            records[0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                B.audit(manifest, records, validation)

    def test_duplicate_and_extra_episodes_are_rejected(self):
        manifest, records, validation = fixture()
        with self.assertRaises(ValueError):
            B.audit(manifest, records + [records[0]], validation)
        records[0]["id"] = "unplanned"
        with self.assertRaises(ValueError):
            B.audit(manifest, records, validation)

    def test_modified_manifest_is_rejected(self):
        manifest, records, validation = fixture()
        manifest["attempt"] = 2
        with self.assertRaises(ValueError):
            B.audit(manifest, records, validation)

    def test_adapter_mechanics_coverage_is_required(self):
        manifest, records, validation = fixture()
        validation["checks_passed"].remove("consumables")
        self.assertFalse(B.audit(manifest, records, validation)["passed"])

    def test_prior_stage_is_required(self):
        manifest, records, validation = fixture()
        manifest["stage"] = 75
        manifest.pop("manifest_digest")
        manifest["manifest_digest"] = B.digest(manifest)
        with self.assertRaises(ValueError):
            B.audit(manifest, [], validation)

    def test_seventy_five_gate_requires_and_retains_prior_gate(self):
        previous = B.audit(*fixture())
        manifest, records, validation = fixture()
        manifest['previous_gate'], manifest['stage'] = previous, 75
        manifest.pop('manifest_digest')
        manifest['manifest_digest'] = B.digest(manifest)
        for record in records:
            record['manifest_digest'] = manifest['manifest_digest']
        report = B.audit(manifest, records, validation)
        self.assertTrue(report['qualified_75_baseline'])
        self.assertFalse(report['training_allowed'])

    def test_freezing_is_reproducible_and_tamper_checked(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp) / "campaign"
            rules = Path(temp) / "rules.fixture"
            rules.write_text("synthetic test rules, not Balatro")
            development = Path(temp) / "development_fixture"
            development.mkdir()
            (development / "manifest.json").write_text('{"qualification": false, "episodes": []}')
            manifest = B.initialize(directory, rules, 100)
            self.assertEqual(len(manifest["episodes"]), 2000)
            self.assertEqual(manifest["start_distribution"], B.ORDINARY_START)
            for relative in ("Brainstorm/Core/challenge_opening.lua", "Brainstorm/UI/ui.lua",
                             "Brainstorm/UI/challenge_opening.lua", "Brainstorm/lovely.toml",
                             "Brainstorm/Immolate-v2.16.dll", "Brainstorm/nativefs.lua"):
                self.assertIn(relative, manifest["policy_files"])
            self.assertFalse(any("deployment-backups" in path for path in manifest["policy_files"]))
            B.verify_frozen_policy(directory, manifest)
            with self.assertRaises(ValueError):
                B.initialize(directory, rules, 100)
            with self.assertRaises(ValueError):
                B.initialize(Path(temp) / 'repeat-attempt', rules, 100)
            second = B.initialize(Path(temp) / 'next-attempt', rules, 100, attempt=2)
            self.assertLess(second['tail_alpha'], manifest['tail_alpha'])
            policy = directory / "policy" / next(iter(manifest["policy_files"]))
            policy.write_text("changed")
            with self.assertRaises(ValueError):
                B.verify_frozen_policy(directory, manifest)

    def test_start_distributions_cannot_be_mixed_or_fabricated(self):
        manifest, records, validation = fixture()
        manifest.update(schema=2, start_distribution=dict(B.ORDINARY_START))
        manifest.pop("manifest_digest")
        manifest["manifest_digest"] = B.digest(manifest)
        for record in records:
            record.update(manifest_digest=manifest["manifest_digest"], start_distribution=dict(B.ORDINARY_START))
        self.assertTrue(B.audit(manifest, records, validation)["passed"])
        records[0]["start_distribution"] = {"kind": "filtered"}
        with self.assertRaises(ValueError):
            B.audit(manifest, records, validation)
        manifest["start_distribution"] = {"kind": "filtered"}
        manifest.pop("manifest_digest")
        manifest["manifest_digest"] = B.digest(manifest)
        with self.assertRaises(ValueError):
            B.audit(manifest, [], validation)


if __name__ == "__main__":
    unittest.main()
