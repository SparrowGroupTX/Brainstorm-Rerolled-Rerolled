"""Manufactured public timing metadata only; no captured-state policy replay."""

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tools.advisor_eval.development372 import wall_time_decomposition as wall


def event(sequence, kind, stamp, **fields):
    return {"sequence": sequence, "kind": kind, "monotonic_seconds": stamp,
            "run_instance": "synthetic-run", "details": {}, **fields}


class WallTime(unittest.TestCase):
    def test_union_and_intersection_do_not_double_count_overlap(self):
        decisions = wall.merged([(1, 3), (2, 4)])
        settlement = wall.merged([(3, 5)])
        self.assertEqual(wall.length(decisions), 3)
        self.assertEqual(wall.length(settlement), 2)
        self.assertEqual(wall.intersection_length(decisions, settlement), 1)
        self.assertEqual(10 - 3 - 2 + 1, 6)

    def test_complete_public_action_timeline(self):
        events = [
            event(1, "collection_run_start", 0, details={"status": "started"}),
            event(2, "action_requested", 3,
                  details={"source": "auto_run"},
                  advice_timing={"decision_id": 1, "status": "completed",
                                 "started_seconds": 1, "finished_seconds": 2,
                                 "elapsed_seconds": 1, "active_seconds": 0.5}),
            event(3, "action_callback_result", 3.2,
                  details={"action_sequence": 2}),
            event(4, "state_after_actions", 5,
                  details={"action_sequences": [2]}),
            event(5, "auto_run", 10,
                  details={"event": "run_finished", "run_seconds": 10}),
        ]
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "public.jsonl"
            data = b"".join((json.dumps(row) + "\n").encode() for row in events)
            path.write_bytes(data)
            result = wall.analyze(path, hashlib.sha256(data).hexdigest())
        self.assertEqual(result["coverage"]["auto_run_actions"], 1)
        self.assertEqual(result["coverage"]["missing_action_callbacks"], 0)
        self.assertEqual(result["coverage"]["missing_first_settled_observations"], 0)
        self.assertAlmostEqual(result["totals"]["run_wall_seconds"], 10)
        self.assertAlmostEqual(result["totals"]["decision_active_seconds"], 0.5)
        self.assertAlmostEqual(result["totals"]["decision_wait_between_resumes_seconds"], 0.5)
        self.assertAlmostEqual(result["totals"]["callback_to_first_settled_union_seconds"], 1.8)
        self.assertAlmostEqual(result["totals"]["outside_decision_and_callback_to_settled_seconds"], 7.2)


if __name__ == "__main__":
    unittest.main()
