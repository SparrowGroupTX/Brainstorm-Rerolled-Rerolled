"""Index settled-intent public hand actions and Yorick receipts; no replay."""

from collections import Counter
from pathlib import Path
import hashlib
import io
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools.advisor_eval.read_player_log import parsed, records

EVAL = HERE.parent
SOURCES = {
    "loaded_2183_complete": sorted((EVAL / "development386/logs1").glob("*.brj"))
        + sorted((EVAL / "development386/logs_complete_tail").glob("*.brj")),
    "loaded_2184_prefix": sorted((HERE / "logs1").glob("*.brj")),
}
OUT = HERE / "analysis"
OUT.mkdir(exist_ok=False)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def brief(s):
    blind = s.get("blind") or {}
    return {
        "phase": s.get("phase"), "ante": s.get("ante"), "round": s.get("round"),
        "blind": blind.get("name"), "blind_key": blind.get("key"),
        "target": blind.get("chips"), "chips": s.get("chips"),
        "hands_left": s.get("hands_left"), "discards_left": s.get("discards_left"),
        "discards_used": s.get("discards_used"),
        "deck_size": len(s.get("deck") or []), "hand_size": len(s.get("hand") or []),
        "dollars": s.get("dollars"), "profile": s.get("teacher_profile"),
        "yorick_x": [(j.get("ability") or {}).get("x_mult")
                     for j in s.get("jokers") or [] if j.get("key") == "j_yorick"],
        "jokers": [{"key": j.get("key"), "ability": j.get("ability"),
                    "debuff": j.get("debuff"), "edition": j.get("edition")}
                   for j in s.get("jokers") or []],
        "hand": [{"id": c.get("id"), "rank": c.get("rank"), "suit": c.get("suit"),
                  "enhancement": c.get("enhancement"), "seal": c.get("seal"),
                  "edition": c.get("edition"), "debuff": c.get("debuff"),
                  "face_down": c.get("face_down"), "identity_redacted": c.get("identity_redacted")}
                 for c in s.get("hand") or []],
        "inventory": [c.get("key") for c in s.get("consumeables") or []],
        "population_size": len(s.get("playing_cards") or []),
        "modifiers": s.get("modifiers"),
    }


result = {}
for cohort, paths in SOURCES.items():
    assert paths
    obs, advice, rows = {}, {}, []
    kind_counts = Counter()
    last_sequence = 0
    for path in paths:
        data = path.read_bytes()
        for ordinal, (raw, _) in enumerate(records(io.BytesIO(data)), 1):
            e = parsed(raw)
            assert e["sequence"] == last_sequence + 1
            last_sequence += 1
            kind = e["kind"]
            kind_counts[kind] += 1
            context = e.get("context") or {}
            anchor = {"segment": path.name, "ordinal": ordinal,
                      "sequence": last_sequence, "raw_sha256": sha(raw)}
            if kind == "teacher_observation":
                obs[e.get("observation_id")] = {
                    "anchor": anchor, "state": brief(context.get("snapshot") or {})}
            elif kind == "teacher_advice":
                advice[last_sequence] = {"anchor": anchor,
                                         "advice": context.get("advice") or {}}
            elif kind == "action_requested":
                action = ((e.get("details") or {}).get("input") or {}).get("action") or {}
                if action.get("kind") not in ("play", "discard", "use"):
                    continue
                observed = obs.get(e.get("observation_id"))
                if not observed or observed["state"]["phase"] != "hand":
                    continue
                chosen = advice.get(e.get("advice_sequence"))
                row = {"anchor": anchor, "run_instance": context.get("run_instance"),
                       "observation": observed["anchor"], "advice": chosen and chosen["anchor"],
                       "action": action, "state": observed["state"],
                       "title": (chosen or {}).get("advice", {}).get("title"),
                       "lines": (chosen or {}).get("advice", {}).get("lines"),
                       "yorick_review": (chosen or {}).get("advice", {}).get("yorick_review")}
                rows.append(row)
    summary = {"events": last_sequence, "actions": len(rows),
               "action_kinds": dict(Counter(r["action"]["kind"] for r in rows)),
               "short_discards": sum(r["action"]["kind"] == "discard" and
                                     len(r["action"].get("indices") or []) < 5 for r in rows),
               "plays_with_discards": sum(r["action"]["kind"] == "play" and
                                          (r["state"]["discards_left"] or 0) > 0 for r in rows),
               "kinds": dict(kind_counts)}
    result[cohort] = summary
    with (OUT / f"{cohort}.json").open("x", encoding="utf-8") as stream:
        json.dump({"summary": summary, "actions": rows}, stream, indent=2, allow_nan=False)
        stream.write("\n")
print(json.dumps(result))
