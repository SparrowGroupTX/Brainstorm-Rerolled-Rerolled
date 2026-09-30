"""Passive linked index of the verified completed 2.184 ten-start public archive."""

from collections import Counter
from pathlib import Path
import hashlib
import io
import json
import sys

HERE = Path(__file__).resolve().parent
EVAL = HERE.parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(EVAL / "development390"))
from tools.advisor_eval.read_player_log import parsed, records
from audit_preserved import state

verified = json.loads((HERE / "capture/verification.json").read_text(encoding="utf-8"))
observations, advices, requests, callbacks = {}, {}, [], {}
lifecycle, searches = [], []
sequence = 0
for expected in verified["segments"]:
    path = HERE / "logs1" / expected["name"]
    data = path.read_bytes()
    assert len(data) == expected["bytes"] and hashlib.sha256(data).hexdigest() == expected["sha256"]
    for ordinal, (raw, _) in enumerate(records(io.BytesIO(data)), 1):
        event = parsed(raw)
        assert event["sequence"] == sequence + 1
        sequence += 1
        context, details = event.get("context") or {}, event.get("details") or {}
        anchor = {"sequence": sequence, "segment": path.name, "ordinal": ordinal,
                  "raw_sha256": hashlib.sha256(raw).hexdigest()}
        kind = event["kind"]
        if kind == "teacher_observation":
            observations[event.get("observation_id")] = {
                "anchor": anchor, "state": state(context.get("snapshot") or {}),
                "run_instance": context.get("run_instance"),
                "seed": context.get("seed"), "stake": context.get("stake")}
        elif kind == "teacher_advice":
            advices[sequence] = {"anchor": anchor, "advice": context.get("advice") or {}}
        elif kind == "action_requested" and details.get("source") == "auto_run":
            requests.append({"anchor": anchor, "observation_id": event.get("observation_id"),
                             "advice_sequence": event.get("advice_sequence"),
                             "action": (details.get("input") or {}).get("action"),
                             "run_instance": context.get("run_instance")})
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
assert sequence == verified["events"]
starts = [x for x in lifecycle if x["event"] == "run_started"]
ends = [x for x in lifecycle if x["event"] in ("run_finished", "run_abandoned")]
assert len(starts) == len(ends) == 10
assert all(a["run_id"] == b["run_id"] for a, b in zip(starts, ends))
runs = {a["run_id"]: {"start": a, "end": b, "observations": [], "actions": []}
        for a, b in zip(starts, ends)}
for observed in observations.values():
    seq = observed["anchor"]["sequence"]
    for run in runs.values():
        if run["start"]["anchor"]["sequence"] <= seq <= run["end"]["anchor"]["sequence"]:
            run["observations"].append(observed)
            break
for row in requests:
    seq = row["anchor"]["sequence"]
    row["observation"] = observations.get(row["observation_id"])
    row["advice"] = advices.get(row["advice_sequence"])
    row["callback"] = callbacks.get(seq)
    for run in runs.values():
        if run["start"]["anchor"]["sequence"] <= seq <= run["end"]["anchor"]["sequence"]:
            row["run_id"] = run["start"]["run_id"]
            run["actions"].append(row)
            break
assert all(x.get("run_id") and x["observation"] and x["advice"] and x["callback"] for x in requests)

summaries = []
for run in runs.values():
    states = [x["state"] for x in run["observations"]]
    acts = run["actions"]
    discards = [x for x in acts if (x["action"] or {}).get("kind") == "discard"]
    plays = [x for x in acts if (x["action"] or {}).get("kind") == "play"]
    shops = [x for x in acts if (x["observation"] or {}).get("state", {}).get("phase") == "shop"]
    summaries.append({"run_id": run["start"]["run_id"], "number": run["start"]["run_number"],
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
                      "last_observation_anchor": run["observations"][-1]["anchor"] if states else None})
out = HERE / "analysis"
out.mkdir(exist_ok=False)
values = {
    "cohort.json": {"scope": "Completed copied public session; action requests linked to their observation, advice and callback. Callback return does not alone prove settled gameplay.",
                    "session": verified["session"], "events": sequence, "starts": len(starts),
                    "outcome_counts": dict(Counter(x["outcome"] for x in ends)),
                    "run_summary": summaries},
    "lifecycle.json": lifecycle, "searches.json": searches, "actions.json": requests,
}
for name, value in values.items():
    with (out / name).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")
print(json.dumps({"events": sequence, "starts": len(starts),
                  "outcomes": values["cohort.json"]["outcome_counts"],
                  "actions": len(requests),
                  "summary": [{k: r[k] for k in ("number", "outcome", "max_ante", "action_count")}
                              for r in summaries]}))
