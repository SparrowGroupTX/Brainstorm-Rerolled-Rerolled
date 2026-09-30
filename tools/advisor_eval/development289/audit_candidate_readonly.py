"""Extract one completed C3/C4 trace; never load source, Lua, the game, or saves.

Writes a new immutable postmortem directory after the coordinator's record exists.
This is a trace audit, not another attempt, replay, scorer or counterfactual probe.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CYCLE = ROOT / "tools/advisor_eval/runs/diagnostic287_20260913_222344"


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def reference(path):
    return {"path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def rows(path):
    parsed, invalid = [], []
    for number, raw in enumerate(path.read_bytes().splitlines(), 1):
        if not raw.startswith(b"{"):
            continue
        try:
            value = json.loads(raw)
        except (ValueError, UnicodeDecodeError) as error:
            invalid.append({"line": number, "sha256": hashlib.sha256(raw).hexdigest(), "error": str(error)})
            continue
        parsed.append((number, raw, value))
    return parsed, invalid


def selected_action_audit(records):
    starts = {row["step"]: row for _, _, row in records if row.get("type") == "engine_episode_decision_started"}
    resolved = {row["step"]: row for _, _, row in records if row.get("type") == "engine_episode_resolved"}
    audits = []
    for _, _, row in records:
        if row.get("type") != "engine_episode_action":
            continue
        action, step = row.get("action", {}), row["step"]
        kind = action.get("kind")
        if kind not in ("play", "discard", "use") or action.get("area") not in ("hand", "consumeables"):
            continue
        state = starts.get(step, {}).get("snapshot")
        if not state:
            audits.append({"step": step, "kind": kind, "public_selection_legal": None, "reason": "No recorded public start."})
            continue
        indices = action.get("targets" if kind == "use" else "indices", []) or []
        hand = state.get("hand", []) or []
        legal = isinstance(indices, list) and len(indices) == len(set(indices))
        legal = legal and all(type(i) is int and 1 <= i <= len(hand) for i in indices)
        if kind in ("play", "discard"):
            legal = legal and 1 <= len(indices) <= min(5, state.get("hand_limit", 5))
            legal = legal and state.get("hands_left" if kind == "play" else "discards_left", 0) > 0
        owned_id = None
        if kind == "use":
            inventory = state.get("consumeables", []) or []
            index = action.get("index")
            legal = legal and type(index) is int and 1 <= index <= len(inventory)
            if type(index) is int and 1 <= index <= len(inventory):
                owned_id = inventory[index - 1].get("id")
            legal = legal and indices == sorted(indices)
        if indices:
            forced = [i for i, c in enumerate(hand, 1) if c.get("ability", {}).get("forced_selection")]
            legal = legal and all(i in indices for i in forced)
        blind = state.get("blind", {})
        if kind == "play" and not blind.get("disabled"):
            if blind.get("key") == "bl_psychic" or blind.get("name") == "The Psychic":
                legal = legal and len(indices) == 5
        audits.append({"step": step, "kind": kind, "indices": indices,
                       "selected_ids": [hand[i - 1].get("id") for i in indices] if legal else [],
                       "owned_id": owned_id, "public_selection_legal": bool(legal),
                       "source_action_resolved": step in resolved,
                       "scope": "Recorded index/resource/forced-selection checks only; effect and full boss legality retain source callback evidence."})
    return audits


def summarize(job):
    folder = CYCLE / job
    record = read(folder / "record.json")
    trace = folder / "attempt.log"
    parsed, invalid = rows(trace)
    values = [row for _, _, row in parsed]
    terminal = record.get("terminal") or {}
    context = [row for row in values if row.get("type") == "engine_episode_terminal_context"]
    final = context[-1].get("snapshot", {}) if context else (record.get("loss_analysis") or {}).get("snapshot", {})
    chips, threshold = final.get("chips"), final.get("blind", {}).get("chips")
    consistent = None
    if terminal and record.get("outcome") == "loss":
        consistent = terminal.get("game_over") is True and terminal.get("outcome") == "loss"
        if isinstance(chips, (int, float)) and isinstance(threshold, (int, float)):
            consistent = consistent and chips < threshold
    elif terminal and record.get("outcome") == "win":
        consistent = terminal.get("outcome") == "win" and terminal.get("source_profile_completed") is True and not terminal.get("game_over")
    evidence = Path(__file__).resolve().parents[1] / "development287/report_cycle.py"
    spec = importlib.util.spec_from_file_location("existing_readonly_cycle_report", evidence)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    summary = helper.attempt(job)
    summary.update({"kind": "read_only_candidate_postmortem289", "qualification": False,
                    "terminal_chips": chips, "terminal_threshold": threshold,
                    "terminal_consistent": consistent, "selection_legality_audit": selected_action_audit(parsed),
                    "random_or_unknown_score_gaps": [r for r in values if r.get("type") == "engine_episode_score_unverified"],
                    "exact_or_floor_rows": [r for r in values if r.get("type") == "engine_episode_score_verified"],
                    "trace_parse_failures": invalid, "trace_event_counts": dict(Counter(r.get("type") for r in values)),
                    "first_divergence": helper.divergence({"C3": "C1", "C4": "C2"}[job], job),
                    "profile": record.get("provenance", {}).get("profile_spec"),
                    "retry_context": record.get("provenance", {}).get("retry_context_spec"),
                    "trace_hash_matches_record": reference(trace)["sha256"] == record.get("trace_digest"),
                    "new_source_executions": 0, "new_replays": 0, "counterfactual_simulations": 0,
                    "causal_claim": False, "win_rate_claim": None, "full_adapter_qualified": False})
    return summary, parsed, context


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("job", choices=("C3", "C4"))
    args = parser.parse_args()
    summary, parsed, context = summarize(args.job)
    destination = CYCLE / (args.job + "_postmortem")
    destination.mkdir(exist_ok=False)
    extraction = {}
    for line, raw, row in parsed:
        if row.get("type") != "engine_episode_decision":
            continue
        step = row["step"]
        files = {}
        for field in ("snapshot", "result"):
            path = destination / f"step{step}_{field}.json"
            with path.open("x", encoding="utf-8") as stream:
                json.dump(row[field], stream, ensure_ascii=False, separators=(",", ":")); stream.write("\n")
            files[field] = reference(path)
        path = destination / f"step{step}_decision.json"
        with path.open("xb") as stream:
            stream.write(raw + b"\n")
        files.update({"exact_trace_row": reference(path), "source_line": line,
                      "source_line_sha256": hashlib.sha256(raw).hexdigest()})
        extraction[str(step)] = files
    summary["created_at_utc"] = datetime.now(timezone.utc).isoformat()
    summary["extracted_decisions"] = extraction
    with (destination / "extraction.json").open("x", encoding="utf-8") as stream:
        json.dump(summary, stream, indent=2); stream.write("\n")
    with (destination / "terminal_context.json").open("x", encoding="utf-8") as stream:
        json.dump(context, stream, indent=2); stream.write("\n")
    print(json.dumps({k: summary[k] for k in ("job", "outcome", "terminal_chips", "terminal_threshold",
                                               "score_verification", "first_divergence", "elapsed_seconds")}, indent=2))


if __name__ == "__main__":
    main()
