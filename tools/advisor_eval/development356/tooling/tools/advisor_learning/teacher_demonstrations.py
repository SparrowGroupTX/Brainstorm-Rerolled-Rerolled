"""Validate and link real-game teacher journals without running a game or model.

Recommendations, callback requests, callback acceptance, a subsequent settled
observation and audited run outcomes are separate records. None alone makes an
expert action label. The current 355 network does not consume this interface.
"""
from __future__ import annotations

import argparse
from collections.abc import Mapping
from copy import deepcopy
import hashlib
import json
from pathlib import Path

from .public_context import context_from_teacher_observation


SCHEMA = "brainstorm_teacher_demonstrations_v1"
COLLECTION_SCHEMA = "teacher_collection_v1"


class DemonstrationError(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise DemonstrationError(reason)


def identity(value):
    return isinstance(value, str) and 0 < len(value) <= 256


class TeacherConverter:
    """Ordered collection-event linker; accepts already decoded public journals.

    A journal segment may reference a preceding segment. Pass the complete
    ordered collection: a missing earlier observation/action is an error, never
    a manufactured empty state or negative training example.
    """

    def __init__(self):
        self.collections = {}
        self.observations = {}
        self.advice = {}
        self.actions = {}
        self.outcomes = {}
        self.outcome_events = set()
        self.counts = {key: 0 for key in ("events", "observations", "recommendations", "action_requests",
                                        "callback_results", "settled_observations", "wins", "losses",
                                        "abandoned_stall", "unsupported", "error")}

    def accept(self, event):
        require(isinstance(event, Mapping) and event.get("schema") == 1
                and event.get("collection_schema") == COLLECTION_SCHEMA,
                "Expected a versioned teacher collection event")
        collection, sequence, kind = event.get("collection_id"), event.get("sequence"), event.get("kind")
        require(identity(collection) and type(sequence) is int and sequence > 0 and identity(kind),
                "Invalid teacher event identity")
        previous = self.collections.get(collection, 0)
        require(sequence == previous + 1, "Complete ordered collection required; missing or repeated event sequence")
        context, details = event.get("context", {}), event.get("details", {})
        require(isinstance(context, Mapping) and isinstance(details, Mapping), "Invalid event context/details")
        reference = event.get("observation_id")
        observation_sequence = event.get("observation_sequence")
        row = {"schema": SCHEMA, "collection_id": collection, "sequence": sequence, "kind": kind,
               "observation_id": reference, "advice_sequence": event.get("advice_sequence"),
               "label_quality": "unreviewed_heuristic", "details": deepcopy(details),
               "provenance": {key: deepcopy(event.get(key)) for key in
                              ("at", "monotonic_seconds", "monotonic_status", "monotonic_reason")},
               "context_metadata": deepcopy({key: value for key, value in context.items()
                                              if key not in {"snapshot", "advice"}})}
        # These are provenance/labels, deliberately outside encoded policy input.
        # Seed, timing, advisor scores and terminal outcomes never enter features.
        if kind == "teacher_observation":
            require(identity(reference) and type(observation_sequence) is int and observation_sequence == sequence,
                    "Full observation requires its own exact sequence reference")
            require((collection, reference) not in self.observations, "Duplicate observation identity")
            row["public_context"] = context_from_teacher_observation(event)
            self.observations[collection, reference] = {"sequence": sequence,
                                                       "run_instance": context.get("run_instance")}
            self.counts["observations"] += 1
        elif reference is not None:
            known = self.observations.get((collection, reference))
            require(known is not None and type(observation_sequence) is int and known["sequence"] == observation_sequence,
                    "Missing, foreign or mismatched prior public observation")
            if context.get("run_instance") is not None and known["run_instance"] is not None:
                require(context["run_instance"] == known["run_instance"],
                        "Observation reference crosses real run instances")
        else:
            require(observation_sequence is None, "Observation sequence without observation identity")

        advice_sequence = event.get("advice_sequence")
        if advice_sequence is not None:
            require(type(advice_sequence) is int and advice_sequence > 0, "Invalid recommendation sequence")
            advice = self.advice.get((collection, advice_sequence))
            require(advice is not None and advice["observation_id"] == reference,
                    "Missing or cross-observation recommendation reference")

        if kind == "teacher_advice":
            require(reference is not None and isinstance(context.get("advice"), Mapping),
                    "Recommendation requires its public observation and advice")
            row["recommendation"] = deepcopy(context["advice"])
            self.advice[collection, sequence] = {"observation_id": reference, **deepcopy(context["advice"])}
            self.counts["recommendations"] += 1
        elif kind == "action_requested":
            require(reference is not None and identity(details.get("action")),
                    "Action request requires public observation and callback identity")
            require(isinstance(details.get("input", {}), Mapping), "Invalid action request input")
            row["execution_status"] = "requested_only"
            row["action_level"] = "advisor_macro" if details["action"] == "advisor_execute" else "game_callback"
            row["imitation_eligible"] = False  # A downstream review/training protocol must opt in.
            advice = self.advice.get((collection, advice_sequence)) if advice_sequence is not None else None
            row["matches_current_recommendation"] = bool(
                advice and advice.get("status") == "current" and row["action_level"] == "advisor_macro"
                and details.get("input", {}).get("action") == advice.get("action"))
            self.actions[collection, sequence] = {"observation_id": reference, "advice_sequence": advice_sequence,
                                                  "callback": None, "settled": []}
            self.counts["action_requests"] += 1
        elif kind in {"action_callback_result", "action_callback_exception"}:
            action_sequence = details.get("action_sequence")
            require(type(action_sequence) is int and action_sequence > 0, "Invalid action sequence")
            action = self.actions.get((collection, action_sequence))
            require(action is not None and action["observation_id"] == reference
                    and action["advice_sequence"] == advice_sequence,
                    "Callback must bind the exact requested action and pre-action advice/state")
            require(action["callback"] is None, "Duplicate callback result")
            returned = details.get("callback_returned")
            require(type(returned) is bool, "Callback result must retain explicit acceptance")
            require(kind != "action_callback_exception" or not returned, "Exception cannot be callback acceptance")
            row["execution_status"] = "callback_accepted" if returned else "callback_failed"
            row["semantic_completion_verified"] = False
            action["callback"] = {"sequence": sequence, "accepted": returned}
            self.counts["callback_results"] += 1
        elif kind == "state_after_actions":
            require(reference is not None, "Settled record requires an observed public state")
            action_sequences = details.get("action_sequences")
            require(isinstance(action_sequences, list) and action_sequences
                    and all(type(item) is int for item in action_sequences)
                    and len(action_sequences) == len(set(action_sequences)),
                    "Settled record requires explicit unique action sequence links")
            require(details.get("latest_action_sequence") == max(action_sequences), "Invalid latest action reference")
            for action_sequence in action_sequences:
                action = self.actions.get((collection, action_sequence))
                require(action is not None and action["callback"] is not None and action["callback"]["accepted"],
                        "Settled record references an absent or rejected callback")
                action["settled"].append(sequence)
            row["semantic_completion_verified"] = False
            row["settled_scope"] = "first_settled_observation_after_callbacks"
            self.counts["settled_observations"] += 1
        elif kind == "auto_run" and details.get("event") in {"run_finished", "run_abandoned"}:
            evidence, run_id, outcome = details.get("evidence"), details.get("run_id"), details.get("outcome")
            require(identity(run_id) and isinstance(evidence, Mapping) and evidence.get("verified") is True
                    and evidence.get("run_id") == run_id and identity(evidence.get("event_id")),
                    "Run outcome requires verified run-bound evidence")
            require((collection, run_id) not in self.outcomes, "Duplicate or conflicting run outcome")
            require((collection, evidence["event_id"]) not in self.outcome_events, "Duplicate outcome evidence event")
            if details["event"] == "run_finished":
                require(outcome in {"win", "loss"} and evidence.get("kind") == outcome,
                        "Terminal kind/outcome mismatch")
                source = "original_win_callback" if outcome == "win" else "GAME_OVER"
                require(evidence.get("source") == source, "Unqualified terminal evidence")
                self.counts["wins" if outcome == "win" else "losses"] += 1
                row["outcome_kind"] = "terminal"
            else:
                require(outcome in {"abandoned_stall", "unsupported", "error"}
                        and details.get("actual_terminal") is False,
                        "Abandonment must remain separate from terminal losses")
                self.counts[outcome] += 1
                row["outcome_kind"] = "abandonment"
            row["outcome"] = outcome
            self.outcomes[collection, run_id] = {"sequence": sequence, "outcome": outcome}
            self.outcome_events.add((collection, evidence["event_id"]))

        self.collections[collection] = sequence
        self.counts["events"] += 1
        return row

    def summary(self):
        return {"schema": SCHEMA, "counts": dict(self.counts), "collections": len(self.collections),
                "actions_without_callback": sum(a["callback"] is None for a in self.actions.values()),
                "accepted_callbacks_without_settled_observation": sum(
                    bool(a["callback"] and a["callback"]["accepted"] and not a["settled"])
                    for a in self.actions.values()),
                "legacy_checkpoint_compatible": False, "expert_labels_assigned": 0,
                "limitations": ["No legal-candidate reconstruction or training is performed.",
                                "Callback acceptance and first settled state do not prove complete queued effects.",
                                "Outcomes are audited journal evidence, not independent game replay verification.",
                                "Unfinished collections remain incomplete; no missing outcome is imputed."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, action="append", required=True,
                        help="Complete ordered journal files; JSONL or BRJ2, read only.")
    parser.add_argument("--output", type=Path, required=True, help="New JSONL output; never overwrite.")
    args = parser.parse_args()
    from tools.advisor_eval.read_player_log import records, parsed
    require(not args.output.exists(), "Output already exists")
    incomplete = args.output.with_name(args.output.name + ".incomplete")
    converter, provenance = TeacherConverter(), []
    with incomplete.open("x", encoding="utf-8", newline="\n") as sink:
        for path in args.input:
            digest = hashlib.sha256()
            with path.open("rb") as source:
                for chunk in iter(lambda: source.read(1048576), b""):
                    digest.update(chunk)
            provenance.append({"path": str(path.resolve()), "sha256": digest.hexdigest()})
            with path.open("rb") as source:
                for raw, _metadata in records(source):
                    row = converter.accept(parsed(raw))
                    sink.write(json.dumps(row, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n")
            after = hashlib.sha256()
            with path.open("rb") as source:
                for chunk in iter(lambda: source.read(1048576), b""):
                    after.update(chunk)
            require(after.digest() == digest.digest(), "Input changed while being converted; retain a stable capture first")
        sink.write(json.dumps({"kind": "conversion_summary", **converter.summary(), "source_files": provenance},
                              sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n")
    # A decoding/link failure leaves an explicitly incomplete artifact for audit.
    # Windows rename refuses an existing destination. Recheck for other hosts.
    require(not args.output.exists(), "Output appeared during conversion")
    incomplete.rename(args.output)
    print(json.dumps(converter.summary(), sort_keys=True))


if __name__ == "__main__":
    main()
