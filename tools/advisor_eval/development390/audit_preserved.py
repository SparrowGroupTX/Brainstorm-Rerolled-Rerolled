"""Passive index of the 20 preserved 2.184 public segments; no policy replay."""

from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import io
import json
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools.advisor_eval.read_player_log import parsed, records

PRE = EVAL / "development387"
MID = EVAL / "development388"
OUT = HERE / "analysis"
SESSION = "session-20260925T190519Z-1"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def write(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


def useful_card(card):
    ability = card.get("ability") or {}
    return {
        "key": card.get("key"), "cost": card.get("cost"),
        "sell_cost": card.get("sell_cost"), "edition": card.get("edition"),
        "rental": ability.get("rental"), "eternal": ability.get("eternal"),
        "debuff": card.get("debuff"), "unknown": card.get("unknown"),
        "face_down": card.get("face_down"),
        "x_mult": ability.get("x_mult"), "mult": ability.get("mult"),
        "extra": ability.get("extra"),
    }


def state(snapshot):
    blind = snapshot.get("blind") or {}
    hands = snapshot.get("hands") or {}
    return {
        "phase": snapshot.get("phase"), "ante": snapshot.get("ante"),
        "round": snapshot.get("round"), "blind": blind.get("name"),
        "blind_key": blind.get("key"), "target": blind.get("chips"),
        "chips": snapshot.get("chips"), "hands_left": snapshot.get("hands_left"),
        "discards_left": snapshot.get("discards_left"),
        "discards_used": snapshot.get("discards_used"),
        "dollars": snapshot.get("dollars"),
        "interest_cap": snapshot.get("interest_cap"),
        "reroll_cost": snapshot.get("reroll_cost"),
        "hand_size": len(snapshot.get("hand") or []),
        "deck_size": len(snapshot.get("deck") or []),
        "population_size": len(snapshot.get("playing_cards") or []),
        "profile": snapshot.get("teacher_profile"),
        "jokers": [useful_card(c) for c in snapshot.get("jokers") or []],
        "consumables": [useful_card(c) for c in snapshot.get("consumeables") or []],
        "shop_jokers": [useful_card(c) for c in snapshot.get("shop_jokers") or []],
        "shop_booster": [useful_card(c) for c in snapshot.get("shop_booster") or []],
        "hands": {k: {"level": v.get("level"), "played": v.get("played"),
                       "chips": v.get("chips"), "mult": v.get("mult")}
                  for k, v in hands.items() if isinstance(v, dict)},
        "observatory": bool((snapshot.get("used_vouchers") or {}).get("v_observatory")
                            or (snapshot.get("vouchers") or {}).get("v_observatory")),
    }


def main():
    manifests = [json.loads((d / "capture/manifest.json").read_text(encoding="utf-8"))
                 for d in (PRE, MID)]
    assert all(m["session"] == SESSION for m in manifests)
    assert manifests[0]["events"] == 7143 and manifests[1]["last_sequence"] == 18531
    assert manifests[1]["first_sequence"] == manifests[0]["events"] + 1
    items = [(PRE / "logs1" / x["name"], x) for x in manifests[0]["segments"]]
    items += [(MID / "logs1" / x["name"], x) for x in manifests[1]["segments"]]
    assert len(items) == 20 and [p.name for p, _ in items] == [
        f"{SESSION}-{n:06d}.brj" for n in range(1, 21)]

    observations, advices, requests, callbacks = {}, {}, [], {}
    lifecycle, searches, phases, kinds, versions, profiles = [], [], Counter(), Counter(), Counter(), Counter()
    sequence = 0
    for path, expected in items:
        data = path.read_bytes()
        assert len(data) == expected["bytes"] and sha(data) == expected["sha256"]
        count = 0
        for ordinal, (raw, _) in enumerate(records(io.BytesIO(data)), 1):
            event = parsed(raw)
            assert event["sequence"] == sequence + 1
            sequence += 1
            count += 1
            kind = event["kind"]
            kinds[kind] += 1
            context, details = event.get("context") or {}, event.get("details") or {}
            anchor = {"sequence": sequence, "segment": path.name,
                      "ordinal": ordinal, "raw_sha256": sha(raw)}
            if context.get("version"):
                versions[context["version"]] += 1
            if kind == "teacher_observation":
                compact = state(context.get("snapshot") or {})
                phases[compact["phase"]] += 1
                if compact["profile"]:
                    profiles[compact["profile"]] += 1
                observations[event.get("observation_id")] = {
                    "anchor": anchor, "state": compact,
                    "run_instance": context.get("run_instance"),
                    "seed": context.get("seed"), "stake": context.get("stake")}
            elif kind == "teacher_advice":
                advices[sequence] = {"anchor": anchor, "advice": context.get("advice") or {}}
            elif kind == "action_requested" and details.get("source") == "auto_run":
                requests.append({"anchor": anchor, "observation_id": event.get("observation_id"),
                                 "advice_sequence": event.get("advice_sequence"),
                                 "action": (details.get("input") or {}).get("action"),
                                 "run_instance": context.get("run_instance"),
                                 "action_sequence": sequence})
            elif kind == "action_callback_result":
                callbacks[details.get("action_sequence")] = {
                    "anchor": anchor, "outcome_kind": details.get("outcome_kind"),
                    "completion": details.get("completion"), "reason": details.get("reason")}
            elif kind == "auto_run" and details.get("event") in (
                    "run_started", "run_finished", "run_abandoned", "session_stopped"):
                lifecycle.append({"anchor": anchor, "event": details["event"],
                                  "run_number": details.get("run_number"),
                                  "run_id": details.get("run_id"),
                                  "outcome": details.get("outcome"),
                                  "reason": details.get("reason"),
                                  "evidence": details.get("evidence"),
                                  "runs_started": details.get("runs_started"),
                                  "outcomes": details.get("outcomes")})
            elif kind in ("collection_search_started", "collection_search_finished", "collection_run_start"):
                searches.append({"anchor": anchor, "kind": kind, "details": details,
                                 "seed": context.get("seed"),
                                 "run_instance": context.get("run_instance")})
        assert count == expected["events"]
    assert sequence == 18531

    starts = [x for x in lifecycle if x["event"] == "run_started"]
    ends = [x for x in lifecycle if x["event"] in ("run_finished", "run_abandoned")]
    assert len(starts) == len(ends) == 8
    assert {x["run_id"] for x in starts} == {x["run_id"] for x in ends}
    assert not any(x["event"] == "session_stopped" for x in lifecycle)
    runs = {}
    for started, ended in zip(starts, ends):
        assert started["run_id"] == ended["run_id"]
        runs[started["run_id"]] = {"start": started, "end": ended,
                                   "actions": [], "observations": []}
    for observed in observations.values():
        seq = observed["anchor"]["sequence"]
        for run in runs.values():
            if run["start"]["anchor"]["sequence"] <= seq <= run["end"]["anchor"]["sequence"]:
                run["observations"].append(observed)
                break
    for row in requests:
        seq = row["anchor"]["sequence"]
        observed = observations.get(row["observation_id"])
        advised = advices.get(row["advice_sequence"])
        row["observation"] = observed
        row["advice"] = advised
        row["callback"] = callbacks.get(row["action_sequence"])
        for run in runs.values():
            if run["start"]["anchor"]["sequence"] <= seq <= run["end"]["anchor"]["sequence"]:
                row["run_id"] = run["start"]["run_id"]
                run["actions"].append(row)
                break
    assert all(x.get("run_id") for x in requests)

    summary = {"captured_utc": datetime.now(timezone.utc).isoformat(),
               "source": "previously frozen public segments only; missing 21-25 were cleared by a later user-started session",
               "session": SESSION, "segments": len(items), "events": sequence,
               "manifest_sha256": [sha((d / "capture/manifest.json").read_bytes()) for d in (PRE, MID)],
               "starts": len(starts), "endings": dict(Counter(x["outcome"] for x in ends)),
               "session_stopped_present": False,
               "versions": dict(versions), "profiles": dict(profiles),
               "kinds": dict(kinds), "phases": dict(phases),
               "run_summary": []}
    for run_id, run in runs.items():
        states = [x["state"] for x in run["observations"]]
        acts = run["actions"]
        hand_actions = [x for x in acts if (x["observation"] or {}).get("state", {}).get("phase") == "hand"]
        discards = [x for x in hand_actions if (x["action"] or {}).get("kind") == "discard"]
        plays = [x for x in hand_actions if (x["action"] or {}).get("kind") == "play"]
        shops = [x for x in acts if (x["observation"] or {}).get("state", {}).get("phase") == "shop"]
        run["summary"] = {
            "run_id": run_id, "number": run["start"]["run_number"],
            "start_sequence": run["start"]["anchor"]["sequence"],
            "end_sequence": run["end"]["anchor"]["sequence"],
            "outcome": run["end"]["outcome"], "reason": run["end"]["reason"],
            "max_ante": max((x.get("ante") or 0 for x in states), default=0),
            "observation_count": len(states), "action_count": len(acts),
            "action_kinds": dict(Counter((x["action"] or {}).get("kind") for x in acts)),
            "discard_count": len(discards),
            "short_discards": sum(len((x["action"] or {}).get("indices") or []) < 5 for x in discards),
            "cards_discarded": sum(len((x["action"] or {}).get("indices") or []) for x in discards),
            "plays_with_discards": sum(((x["observation"] or {}).get("state", {}).get("discards_left") or 0) > 0 for x in plays),
            "shop_actions": len(shops),
            "shop_leaves_50_plus": sum((x["action"] or {}).get("kind") == "leave_shop" and
                                      ((x["observation"] or {}).get("state", {}).get("dollars") or 0) >= 50 for x in shops),
            "max_cash_seen": max((x.get("dollars") or 0 for x in states), default=0),
            "last_state": states[-1] if states else None,
            "last_observation_anchor": run["observations"][-1]["anchor"] if states else None,
        }
        summary["run_summary"].append(run["summary"])

    OUT.mkdir(parents=True, exist_ok=False)
    write(OUT / "cohort.json", summary)
    write(OUT / "lifecycle.json", lifecycle)
    write(OUT / "searches.json", searches)
    write(OUT / "actions.json", requests)
    print(json.dumps({"events": sequence, "starts": len(starts),
                      "endings": summary["endings"],
                      "runs": [{k: r["summary"][k] for k in ("number", "outcome", "max_ante", "action_count",
                                                        "short_discards", "plays_with_discards", "max_cash_seen")}
                               for r in runs.values()]}))


if __name__ == "__main__":
    main()
