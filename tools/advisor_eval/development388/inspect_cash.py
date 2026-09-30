"""Index frozen public shop receipts; no policy, scorer or hidden-state replay."""

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

observations = {}
shops = []
for path in sorted((HERE / "logs1").glob("*.brj")):
    for ordinal, (raw, _) in enumerate(records(io.BytesIO(path.read_bytes())), 1):
        event = parsed(raw)
        context = event.get("context") or {}
        anchor = {"segment": path.name, "ordinal": ordinal,
                  "sequence": event["sequence"], "raw_sha256": hashlib.sha256(raw).hexdigest()}
        if event["kind"] == "teacher_observation":
            observations[event.get("observation_id")] = (context, anchor)
        elif event["kind"] == "teacher_advice":
            advice = context.get("advice") or {}
            prior = observations.get(event.get("observation_id"))
            if not prior or advice.get("status") != "current":
                continue
            snapshot = prior[0].get("snapshot") or {}
            if snapshot.get("phase") != "shop":
                continue
            review = advice.get("reroll_review") or {}
            replacement = advice.get("replacement_review") or {}
            offers = [(card.get("key"), card.get("cost"))
                      for card in snapshot.get("shop_jokers") or []]
            shops.append({
                "anchor": anchor, "observation": prior[1],
                "run_instance": context.get("run_instance"),
                "ante": snapshot.get("ante"), "round": snapshot.get("round"),
                "cash": snapshot.get("dollars"), "reroll_cost": snapshot.get("reroll_cost"),
                "interest_cap": snapshot.get("interest_cap"),
                "action": advice.get("action"), "title": advice.get("title"),
                "reroll_review": review, "joker_keys": [j.get("key") for j in snapshot.get("jokers") or []],
                "joker_limit": snapshot.get("joker_limit"),
                "offers": offers, "replacement_complete": replacement.get("complete"),
                "replacement_candidates": len(replacement.get("candidates") or []),
                "shop_truncated": (advice.get("gold_review") or {}).get("shop_truncated"),
                "shop_evaluations": (advice.get("gold_review") or {}).get("shop_evaluations"),
                "forecast_redacted_from_public_observation": True,
            })

summary = {
    "shop_advices": len(shops),
    "high_cash_leaves_100": sum((x["cash"] or 0) >= 100 and
                                (x["action"] or {}).get("kind") == "leave_shop" for x in shops),
    "high_cash_leave_statuses": dict(Counter((x["reroll_review"] or {}).get("status", "missing")
                                         for x in shops if (x["cash"] or 0) >= 100 and
                                         (x["action"] or {}).get("kind") == "leave_shop")),
}
out = HERE / "analysis"
out.mkdir(exist_ok=False)
with (out / "cash_shops.json").open("x", encoding="utf-8") as stream:
    json.dump({"summary": summary, "shops": shops}, stream, indent=2, allow_nan=False)
    stream.write("\n")
print(json.dumps(summary))
