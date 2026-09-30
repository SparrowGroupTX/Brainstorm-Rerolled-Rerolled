"""Manufactured public event metadata only; no game, scorer or captured-state replay."""

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.advisor_eval import analyze_teacher_decision_timing as timing


def event(sequence, kind, **fields):
    return {
        "sequence": sequence, "kind": kind, "at": "2026-09-23T00:00:00Z",
        "collection_id": "synthetic-collection", "run_instance": "synthetic-run:1",
        "observation_id": "synthetic-observation:1",
        "anchor": {"segment": "synthetic.brj", "ordinal": sequence,
                   "raw_sha256": "a" * 64},
        **fields,
    }


def receipt(decision_id=1, **fields):
    return {
        "decision_id": decision_id, "phase": "shop", "status": "completed",
        "started_seconds": 1.0, "finished_seconds": 3.0,
        "elapsed_seconds": 2.0, "active_seconds": 0.5,
        "resume_calls": 3, "max_resume_seconds": 0.25,
        "evaluations": 100, "action_kind": "buy", **fields,
    }


class DecisionTiming(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "events.jsonl"

    def analyze(self, events):
        data = b"".join((json.dumps(e, allow_nan=False) + "\n").encode() for e in events)
        self.path.write_bytes(data)
        return timing.analyze(self.path, hashlib.sha256(data).hexdigest())

    def test_coverage_public_join_and_request_link_without_zero_fill(self):
        events = [
            event(1, "teacher_observation", state={"phase": "shop", "ante": 2}),
            event(2, "teacher_advice", advice={"status": "current", "action": {"kind": "buy"},
                                               "timing": receipt()}),
            event(3, "action_requested", advice_sequence=2,
                  details={"source": "auto_run"}),
            event(4, "teacher_advice", advice={"status": "stale", "action": {"kind": "buy"}}),
            event(5, "teacher_advice", advice={"status": "current",
                                               "action": {"kind": "leave_shop"},
                                               "gold_review": {"shop_evaluations": 42}}),
            event(6, "action_requested", advice_sequence=5,
                  details={"source": "auto_run"}),
        ]
        result = self.analyze(events)
        self.assertEqual(result["coverage"]["advice_statuses"], {"current": 2, "stale": 1})
        self.assertEqual(result["coverage"]["timed_receipts"], 1)
        self.assertEqual(result["coverage"]["current_without_timing_after_sidecar_join"], 1)
        self.assertEqual(result["coverage"]["untimed_current_requested_by_auto_run"], 1)
        self.assertEqual(result["coverage"]["action_requests_unmatched_advice"], 0)
        self.assertEqual(result["all_timed"]["active_seconds_sum"], 0.5)
        self.assertEqual(result["by_public_ante"]["2"]["count"], 1)
        self.assertEqual(result["untimed_current"]["shop_evaluations_diagnostic_sum_known"], 42)
        self.assertEqual(result["untimed_current"]["by_public_phase"], {"shop": 1})

    def test_later_action_sidecar_recovers_deduplicated_advice_timing(self):
        later = receipt(decision_id=2, action_kind="leave_shop")
        events = [
            event(1, "teacher_observation", state={"phase": "shop", "ante": 2}),
            event(2, "teacher_advice", advice={"status": "current",
                                               "action": {"kind": "leave_shop"}}),
            event(3, "auto_run", advice_sequence=2, advice_timing=later),
            event(4, "action_requested", advice_sequence=2, advice_timing=later,
                  details={"source": "auto_run"}),
        ]
        result = self.analyze(events)
        self.assertEqual(result["coverage"]["timed_receipts"], 1)
        self.assertEqual(result["coverage"]["current_without_timing_after_sidecar_join"], 0)
        self.assertEqual(result["coverage"]["identical_sidecar_receipt_copies"], 1)
        self.assertEqual(result["coverage"]["receipt_representations_by_event_kind"],
                         {"action_requested": 1, "auto_run": 1, "teacher_advice": 0})
        self.assertEqual(result["coverage"]["timed_receipts_requested_by_auto_run"], 1)
        self.assertEqual(result["all_timed"]["active_seconds_sum"], 0.5)
        self.assertEqual(result["slowest_active_receipts"][0]["timing_sources"],
                         ["auto_run", "action_requested"])

    def test_conflicting_sidecar_receipt_is_rejected(self):
        events = [
            event(1, "teacher_advice", advice={"status": "current", "timing": receipt()}),
            event(2, "action_requested", advice_sequence=1,
                  advice_timing=receipt(active_seconds=0.6), details={"source": "auto_run"}),
        ]
        with self.assertRaisesRegex(timing.TimingAuditError, "Conflicting copies"):
            self.analyze(events)

    def test_recovered_receipt_keeps_missing_or_wrong_run_observation_unknown(self):
        advice = event(2, "teacher_advice", advice={"status": "current",
                                                   "action": {"kind": "buy"}})
        sidecar = event(3, "action_requested", advice_sequence=2,
                        advice_timing=receipt(), details={"source": "auto_run"})
        missing = self.analyze([event(1, "auto_run"), advice, sidecar])
        self.assertEqual(missing["coverage"]["timed_unmatched_public_observation"], 1)
        self.assertIn("unknown", missing["by_public_ante"])
        wrong_run = self.analyze([
            event(1, "teacher_observation", run_instance="synthetic-run:2",
                  state={"phase": "shop", "ante": 8}), advice, sidecar])
        self.assertEqual(wrong_run["coverage"]["timed_unmatched_public_observation"], 1)
        self.assertIn("unknown", wrong_run["by_public_ante"])
        self.assertEqual(wrong_run["slowest_active_receipts"][0]["public_phase"], None)

    def test_forward_or_cross_advice_sidecar_link_is_rejected(self):
        forward = [
            event(1, "action_requested", advice_sequence=2, advice_timing=receipt(),
                  details={"source": "auto_run"}),
            event(2, "teacher_advice", advice={"status": "current",
                                               "action": {"kind": "buy"}}),
        ]
        with self.assertRaisesRegex(timing.TimingAuditError, "Forward or invalid"):
            self.analyze(forward)
        cross = [
            event(1, "teacher_observation", state={"phase": "shop", "ante": 2}),
            event(2, "teacher_advice", advice={"status": "current", "timing": receipt()}),
            event(3, "teacher_advice", advice={"status": "current",
                                               "action": {"kind": "buy"}}),
            event(4, "action_requested", advice_sequence=3, advice_timing=receipt(),
                  details={"source": "auto_run"}),
        ]
        with self.assertRaisesRegex(timing.TimingAuditError, "multiple current advice"):
            self.analyze(cross)

    def test_duplicate_decision_receipt_is_rejected(self):
        events = [
            event(1, "teacher_observation", state={"phase": "shop", "ante": 1}),
            event(2, "teacher_advice", advice={"status": "current", "timing": receipt()}),
            event(3, "teacher_advice", advice={"status": "current", "timing": receipt()}),
        ]
        with self.assertRaisesRegex(timing.TimingAuditError, "Duplicate decision receipt"):
            self.analyze(events)

    def test_bad_interval_and_hash_are_rejected(self):
        bad = receipt(active_seconds=3.0)
        events = [event(1, "teacher_advice", advice={"status": "current", "timing": bad})]
        with self.assertRaisesRegex(timing.TimingAuditError, "Inconsistent active"):
            self.analyze(events)
        good = [event(1, "teacher_advice", advice={"status": "current", "timing": receipt()})]
        self.analyze(good)
        with self.assertRaisesRegex(timing.TimingAuditError, "SHA256"):
            timing.analyze(self.path, "0" * 64)

    def test_sequence_gap_and_duplicate_source_anchor_are_rejected(self):
        with self.assertRaisesRegex(timing.TimingAuditError, "Noncontiguous"):
            self.analyze([event(1, "auto_run"), event(3, "auto_run")])
        repeated = event(1, "auto_run")["anchor"]
        with self.assertRaisesRegex(timing.TimingAuditError, "Duplicate source event anchor"):
            self.analyze([event(1, "auto_run"), event(2, "auto_run", anchor=repeated)])

    def test_incomplete_last_line_is_rejected(self):
        data = json.dumps(event(1, "auto_run")).encode()
        self.path.write_bytes(data)
        with self.assertRaisesRegex(timing.TimingAuditError, "incomplete JSONL"):
            timing.analyze(self.path, hashlib.sha256(data).hexdigest())


if __name__ == "__main__":
    unittest.main()
