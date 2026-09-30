"""Compact arithmetic of frozen public teacher observations and linked actions.

Never loads a policy/scorer, game source, saves, or concealed identities.
"""
from __future__ import annotations

from collections import Counter, defaultdict
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COHORT = ROOT / "win_rate_research/20260924_132921_interrupted"
EVENTS = COHORT / "capture/events.jsonl"
OUT = Path(__file__).with_name("public_choice_audit.json")


def compact_state(event: dict) -> dict:
    s = event["state"]
    b = s.get("blind") or {}
    yorick = next((j.get("ability", {}).get("x_mult") for j in s.get("jokers", [])
                   if j.get("key") == "j_yorick"), None)
    return {"sequence": event["sequence"], "anchor": event["anchor"],
            "run_instance": event.get("run_instance"), "seed": event.get("seed"),
            "phase": s.get("phase"), "ante": s.get("ante"), "round": s.get("round"),
            "blind": b.get("name"), "target": b.get("chips"),
            "chips": s.get("chips"), "hands_left": s.get("hands_left"),
            "discards_left": s.get("discards_left"), "hand_size": len(s.get("hand") or []),
            "yorick_x": yorick, "cash": s.get("dollars"),
            "visible_jokers": [j.get("key") for j in s.get("jokers") or []
                               if j.get("key")],
            "hand": [{"rank": c.get("rank"), "suit": c.get("suit"),
                      "enhancement": c.get("enhancement"), "face_down": c.get("face_down")}
                     for c in s.get("hand") or []]}


def main() -> None:
    observations: dict[str, dict] = {}
    advice: dict[int, dict] = {}
    starts, ends, actions = [], [], []
    for line in EVENTS.open(encoding="utf-8"):
        event = json.loads(line)
        kind = event.get("kind")
        if kind == "teacher_observation":
            observations[event["observation_id"]] = compact_state(event)
        elif kind == "teacher_advice":
            a = event.get("advice") or {}
            advice[event["sequence"]] = {"title": a.get("title"),
                                           "status": a.get("status"),
                                           "action": a.get("action"),
                                           "lines": a.get("lines") or []}
        elif kind == "auto_run":
            name = (event.get("details") or {}).get("event")
            if name == "run_started":
                starts.append({"run": event["details"].get("run_number"),
                               "seed": event.get("seed"),
                               "run_instance": event.get("run_instance"),
                               "sequence": event["sequence"]})
            elif name in ("run_finished", "run_abandoned", "session_stopped"):
                ends.append({"run_instance": event.get("run_instance"),
                             "sequence": event["sequence"], "event": name,
                             "outcome": event["details"].get("outcome"),
                             "reason": event["details"].get("reason")})
        elif kind == "action_requested":
            a = (event.get("details") or {}).get("input", {}).get("action") or {}
            before = observations.get(event.get("observation_id"))
            actions.append({"sequence": event["sequence"], "anchor": event["anchor"],
                            "run_instance": event.get("run_instance"),
                            "kind": a.get("kind"), "indices": a.get("indices"),
                            "order": a.get("order"), "area": a.get("area"),
                            "index": a.get("index"), "before": before,
                            "advice": advice.get(event.get("advice_sequence"))})
    by_round: dict[tuple, list] = defaultdict(list)
    for s in observations.values():
        if s["phase"] == "hand" and s["round"] is not None:
            by_round[s["run_instance"], s["round"]].append(s)
    action_rounds: dict[tuple, list] = defaultdict(list)
    for action in actions:
        before = action["before"]
        if before and before["round"] is not None:
            action_rounds[action["run_instance"], before["round"]].append(action)
    rounds = []
    for key, states in by_round.items():
        states.sort(key=lambda s: s["sequence"])
        entry = states[0]
        aa = action_rounds[key]
        cash = next((a for a in reversed(aa) if a["kind"] == "cash_out"), None)
        if not cash:
            continue
        end = cash["before"]
        discards = [a for a in aa if a["kind"] == "discard"]
        plays = [a for a in aa if a["kind"] == "play"]
        rounds.append({"run_instance": key[0], "round": key[1],
                       "ante": entry["ante"], "blind": entry["blind"],
                       "entry_sequence": entry["sequence"],
                       "exit_sequence": end["sequence"],
                       "target": entry["target"], "end_chips": end["chips"],
                       "entry_discards": entry["discards_left"],
                       "unused_discards": end["discards_left"],
                       "discard_actions": len(discards),
                       "discard_cards": sum(len(a["indices"] or []) for a in discards),
                       "discard_sequences": [a["sequence"] for a in discards],
                       "play_sequences": [a["sequence"] for a in plays],
                       "first_play_advice": plays[0]["advice"] if plays else None,
                       "entry_yorick_x": entry["yorick_x"],
                       "exit_yorick_x": end["yorick_x"],
                       "entry_hands": entry["hands_left"],
                       "entry_hand_size": entry["hand_size"],
                       "cash": entry["cash"]})
    rounds.sort(key=lambda r: (r["run_instance"] or "", r["round"]))
    early = [r for r in rounds if r["ante"] and r["ante"] <= 5]
    result = {"scope": "Frozen public observations and linked actions; arithmetic only",
              "cohort": str(COHORT.relative_to(ROOT)),
              "starts": starts, "ends": ends,
              "counts": {"actions": dict(Counter(a["kind"] for a in actions)),
                         "clear_rounds": len(rounds),
                         "early_clear_rounds": len(early),
                         "early_unused_discards": sum(r["unused_discards"] or 0 for r in early),
                         "early_rounds_with_unused": sum((r["unused_discards"] or 0) > 0 for r in early)},
              "rounds": rounds,
              "actions": actions}
    OUT.write_text(json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps(result["counts"]))


if __name__ == "__main__":
    main()
