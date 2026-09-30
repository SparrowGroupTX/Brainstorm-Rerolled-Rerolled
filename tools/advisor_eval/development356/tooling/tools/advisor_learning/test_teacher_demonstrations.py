"""Manufactured logs only; no simulator initialization, saves or live game."""
from copy import deepcopy
from contextlib import redirect_stdout
from io import StringIO
import importlib.util
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from .teacher_demonstrations import DemonstrationError, TeacherConverter, main
from .test_public_context import event as observation_event, snapshot


def observation(sequence=1, observation_id="obs-1", run="run-1"):
    result = observation_event(snapshot())
    result.update(sequence=sequence, observation_sequence=sequence, observation_id=observation_id,
                  collection_id="batch-1", details={})
    result["context"].update(run_instance=run)
    return result


def event(sequence, kind, details=None, *, ref="obs-1", obs_seq=1, advice=None, context=None):
    result = {"schema": 1, "collection_schema": "teacher_collection_v1", "collection_id": "batch-1",
              "sequence": sequence, "kind": kind, "details": details or {}, "context": context or {},
              "observation_id": ref, "observation_sequence": obs_seq}
    if advice is not None:
        result["advice_sequence"] = advice
    return result


def prefix():
    action = {"type": "discard", "indices": [1, 2, 3, 4, 5]}
    return [observation(), event(2, "teacher_advice", context={"advice": {"status": "current", "action": action}}),
            event(3, "action_requested", {"action": "advisor_execute", "input": {"action": action}, "source": "auto_run"}, advice=2)]


def converter(events):
    result = TeacherConverter()
    rows = [result.accept(value) for value in events]
    return result, rows


def terminal(sequence=2, outcome="win"):
    return event(sequence, "auto_run", {"event": "run_finished", "run_id": "game:1", "outcome": outcome,
                 "evidence": {"verified": True, "run_id": "game:1", "event_id": "terminal:1", "kind": outcome,
                              "source": "original_win_callback" if outcome == "win" else "GAME_OVER"}})


class TeacherDemonstrationTests(unittest.TestCase):
    def test_recommendation_and_requested_action_are_not_success_or_expert_labels(self):
        parsed, rows = converter(prefix())
        self.assertEqual(rows[-1]["execution_status"], "requested_only")
        self.assertTrue(rows[-1]["matches_current_recommendation"])
        self.assertFalse(rows[-1]["imitation_eligible"])
        self.assertEqual(parsed.summary()["actions_without_callback"], 1)
        self.assertEqual(parsed.summary()["expert_labels_assigned"], 0)
        self.assertEqual(parsed.summary()["counts"]["wins"], 0)

    def test_callback_and_settled_observation_link_the_exact_before_and_after(self):
        changed = observation(5, "obs-2")
        changed["context"]["snapshot"]["discards_left"] = 1
        values = prefix() + [event(4, "action_callback_result", {"action_sequence": 3, "callback_returned": True}, advice=2),
                             changed, event(6, "state_after_actions", {"action_sequences": [3], "latest_action_sequence": 3},
                                            ref="obs-2", obs_seq=5)]
        parsed, rows = converter(values)
        self.assertEqual(rows[3]["observation_id"], "obs-1")
        self.assertEqual(rows[-1]["observation_id"], "obs-2")
        self.assertFalse(rows[-1]["semantic_completion_verified"])
        self.assertEqual(parsed.actions["batch-1", 3]["settled"], [6])
        self.assertEqual(parsed.summary()["accepted_callbacks_without_settled_observation"], 0)

    def test_multiple_callbacks_can_share_first_settled_state_without_claiming_causality(self):
        values = prefix() + [event(4, "action_requested", {"action": "discard_cards_from_highlighted", "input": {}}, advice=2),
                             event(5, "action_callback_result", {"action_sequence": 4, "callback_returned": True}, advice=2),
                             event(6, "action_callback_result", {"action_sequence": 3, "callback_returned": True}, advice=2),
                             observation(7, "obs-2"), event(8, "state_after_actions", {"action_sequences": [4, 3], "latest_action_sequence": 4},
                                                          ref="obs-2", obs_seq=7)]
        parsed, rows = converter(values)
        self.assertEqual(parsed.summary()["counts"]["action_requests"], 2)
        self.assertEqual(rows[3]["action_level"], "game_callback")
        self.assertFalse(rows[-1]["semantic_completion_verified"])

    def test_stale_or_different_advice_never_matches_current_executed_macro(self):
        for status, altered in (("stale", False), ("current", True)):
            values = prefix()
            values[1]["context"]["advice"]["status"] = status
            if altered:
                values[2]["details"]["input"]["action"] = {"type": "play", "indices": [1]}
            _, rows = converter(values)
            self.assertFalse(rows[-1]["matches_current_recommendation"])

    def test_unaccepted_or_exception_callbacks_are_preserved_not_punished(self):
        for kind in ("action_callback_result", "action_callback_exception"):
            parsed, rows = converter(prefix() + [event(4, kind, {"action_sequence": 3, "callback_returned": False,
                                                               "reason": "fixture"}, advice=2)])
            self.assertEqual(rows[-1]["execution_status"], "callback_failed")
            self.assertEqual(parsed.summary()["counts"]["losses"], 0)
            with self.assertRaises(DemonstrationError):
                parsed.accept(event(5, "state_after_actions", {"action_sequences": [3], "latest_action_sequence": 3}))

    def test_missing_segment_or_foreign_observation_reference_rejected(self):
        for values in ([prefix()[1]], [observation(), event(2, "warning", ref="other")],
                       [observation(), event(2, "warning", obs_seq=99)],
                       [observation(), event(2, "warning", context={"run_instance": "run-2"})]):
            with self.subTest(values=values), self.assertRaises(DemonstrationError):
                converter(values)

    def test_wrong_advice_or_callback_reference_rejected(self):
        values = prefix()
        values[2]["advice_sequence"] = 99
        with self.assertRaises(DemonstrationError):
            converter(values)
        parsed, _ = converter(prefix())
        with self.assertRaises(DemonstrationError):
            parsed.accept(event(4, "action_callback_result", {"action_sequence": 3, "callback_returned": True}))

    def test_nonmonotonic_sequence_and_duplicate_observation_rejected(self):
        for next_event in (observation(), observation(2), event(3, "warning")):
            with self.assertRaises(DemonstrationError):
                converter([observation(), next_event])

    def test_cross_collection_reference_is_not_resolved(self):
        other = prefix()[1]
        other["collection_id"] = "batch-2"
        with self.assertRaises(DemonstrationError):
            converter([observation(), other])

    def test_actual_win_and_loss_require_separate_correct_terminal_evidence(self):
        for outcome in ("win", "loss"):
            parsed, rows = converter([observation(), terminal(outcome=outcome)])
            self.assertEqual(rows[-1]["outcome_kind"], "terminal")
            self.assertEqual(parsed.summary()["counts"]["wins" if outcome == "win" else "losses"], 1)
        bad = terminal()
        bad["details"]["evidence"]["source"] = "GAME.won"
        with self.assertRaises(DemonstrationError):
            converter([observation(), bad])

    def test_run_bound_outcome_and_duplicate_terminal_rejected(self):
        bad = terminal()
        bad["details"]["evidence"]["run_id"] = "game:2"
        with self.assertRaises(DemonstrationError):
            converter([observation(), bad])
        with self.assertRaises(DemonstrationError):
            converter([observation(), terminal(), terminal(3)])

    def test_stall_unsupported_and_error_are_not_losses(self):
        for outcome in ("abandoned_stall", "unsupported", "error"):
            value = terminal()
            value["details"].update(event="run_abandoned", outcome=outcome, actual_terminal=False)
            value["details"]["evidence"].pop("kind")
            value["details"]["evidence"].pop("source")
            parsed, rows = converter([observation(), value])
            self.assertEqual(rows[-1]["outcome_kind"], "abandonment")
            self.assertEqual(parsed.summary()["counts"][outcome], 1)
            self.assertEqual(parsed.summary()["counts"]["losses"], 0)

    def test_transport_and_teacher_metadata_do_not_enter_policy_features(self):
        first = observation()
        first["context"].update(teacher={"profile": "teacher-a", "policy_hash": "hash-a"}, seed="SEED-A")
        second = deepcopy(first)
        second["context"].update(teacher={"profile": "teacher-b", "policy_hash": "hash-b"}, seed="SEED-B")
        second["monotonic_seconds"] = 888
        _, a = converter([first])
        _, b = converter([second])
        self.assertEqual(a[0]["public_context"], b[0]["public_context"])
        self.assertNotEqual(a[0]["context_metadata"], b[0]["context_metadata"])

    def test_partial_collection_reports_missing_callback_or_settled_without_imputation(self):
        parsed, _ = converter(prefix() + [event(4, "action_callback_result", {"action_sequence": 3, "callback_returned": True}, advice=2)])
        summary = parsed.summary()
        self.assertEqual(summary["accepted_callbacks_without_settled_observation"], 1)
        self.assertEqual(summary["counts"]["wins"] + summary["counts"]["losses"], 0)
        self.assertFalse(summary["legacy_checkpoint_compatible"])

    def test_unrelated_legacy_journal_not_silently_imported(self):
        legacy = observation()
        legacy.pop("collection_schema")
        with self.assertRaises(DemonstrationError):
            converter([legacy])

    def test_cli_decodes_manufactured_jsonl_preserves_source_and_refuses_overwrite(self):
        with TemporaryDirectory() as temp:
            source, output = Path(temp) / "source.jsonl", Path(temp) / "dataset.jsonl"
            raw = "".join(json.dumps(row) + "\n" for row in prefix())
            source.write_text(raw, encoding="utf-8")
            argv = ["teacher_demonstrations", "--input", str(source), "--output", str(output)]
            with patch.object(sys, "argv", argv), redirect_stdout(StringIO()):
                main()
            rows = [json.loads(line) for line in output.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(rows[-1]["kind"], "conversion_summary")
            self.assertEqual(rows[-1]["counts"]["action_requests"], 1)
            self.assertEqual(source.read_text(encoding="utf-8"), raw)
            with patch.object(sys, "argv", argv), self.assertRaises(DemonstrationError):
                main()

    def test_cli_missing_reference_leaves_only_explicit_incomplete_output(self):
        with TemporaryDirectory() as temp:
            source, output = Path(temp) / "source.jsonl", Path(temp) / "dataset.jsonl"
            source.write_text(json.dumps(prefix()[1]) + "\n", encoding="utf-8")
            argv = ["teacher_demonstrations", "--input", str(source), "--output", str(output)]
            with patch.object(sys, "argv", argv), self.assertRaises(DemonstrationError):
                main()
            self.assertFalse(output.exists())
            self.assertTrue(output.with_name("dataset.jsonl.incomplete").exists())

    def test_actual_lua_journal_contract_with_fake_archive_and_nested_callbacks(self):
        root = Path(__file__).resolve().parents[2]
        specification = importlib.util.spec_from_file_location("teacher356_archive_fixture",
                                                               root / "tests/test_advisor_player_log_archive.py")
        host = importlib.util.module_from_spec(specification)
        specification.loader.exec_module(host)
        if not Path(host.Runtime.BALATRO_DLL).exists():
            self.skipTest("Routine manufactured Lua fixture runtime unavailable")
        lua = host.Lua()
        context = {"snapshot": snapshot(), "version": "fixture356", "run_instance": "fixture-run",
                   "teacher": "perkeo_yorick_win_v1",
                   "advice": {"status": "current", "action": {"kind": "discard", "indices": [1, 2]}}}
        script = b"ctx=" + host.lua_value(context) + b"""
local t=1
local archive={physical_bytes=0}
function archive:prepare_collection()return true,{scope='manufactured'}end
function archive:append(entry,raw)HOST_SINK(tostring(entry.sequence),raw);return true end
local journal=J.new({enabled=function()return true end,clock=function()return t end,
  now=function()return 'fixture' end,observe=function()return ctx end,archive=archive})
assert(journal:prepare_collection({collection_id='fixture356'}))
assert(journal:collection_observe())
local macro=assert(journal:before('advisor_execute',{action=ctx.advice.action}))
local nested=assert(journal:before('discard_cards_from_highlighted',{selected={1,2}}))
journal:after(nested,true);journal:after(macro,true)
ctx.snapshot.discards_left=1;ctx.advice.status='stale';t=2
assert(journal:event('state_after_actions',{action_sequences={macro,nested},latest_action_sequence=nested}))
return 'done'
"""
        try:
            self.assertEqual(lua.evaluate(script), b"done")
            values = [json.loads(raw) for _, raw in sorted(lua.outputs.items(), key=lambda pair: int(pair[0]))]
            parsed, rows = converter(values)
            self.assertEqual(parsed.summary()["counts"]["observations"], 2)
            self.assertEqual(parsed.summary()["counts"]["action_requests"], 2)
            self.assertEqual(parsed.summary()["counts"]["callback_results"], 2)
            self.assertEqual(parsed.summary()["accepted_callbacks_without_settled_observation"], 0)
            self.assertEqual(rows[-1]["kind"], "state_after_actions")
        finally:
            lua.close()


if __name__ == "__main__":
    unittest.main()
