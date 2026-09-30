"""Summarize frozen public action/round records; no policy or scorer invocation."""
from collections import Counter
from pathlib import Path
import json

P = Path(__file__).resolve().parent
actions = json.loads((P / "actions.json").read_text(encoding="utf-8"))
rounds = json.loads((P / "rounds.json").read_text(encoding="utf-8"))
runs = json.loads((P / "runs.json").read_text(encoding="utf-8"))


def brief_action(a):
    b, c = a.get("before") or {}, a.get("after") or {}
    return {
        "seq": a["sequence"], "seed": a["seed"], "ante": b.get("ante"),
        "round": b.get("round"), "cash": b.get("dollars"),
        "population_before": b.get("population_size"),
        "population_after": c.get("population_size"),
        "action": a["action"], "selected": (a.get("selected") or {}).get("key"),
    }


late_clears = [r for r in rounds if r["cleared"] and r["ante"] >= 4 and r["remaining_discards"] > 0]
single_play_clears = [r for r in late_clears if r["play_actions"] == 1]
low_discards = [r for r in rounds if any(n < 5 for n in r["discard_sizes"])]
shop_exits = [a for a in actions if a["action"].get("kind") == "leave_shop"]
high_exits = [a for a in shop_exits if a["before"]["dollars"] > 50]
hanged = [a for a in actions if a["action"].get("kind") == "use" and (a.get("selected") or {}).get("key") == "c_hanged_man"]
business = [a for a in actions if a["action"].get("kind") in ("choose", "buy") and (a.get("selected") or {}).get("key") == "j_business"]
reroll_reasons = Counter((a.get("advice") or {}).get("reroll_review", {}).get("status", "missing") for a in high_exits)
stock = Counter()
for a in shop_exits:
    stock.update(c.get("key") for c in a["before"].get("consumeables") or [])

out = {
    "cohort": [{k: r.get(k) for k in ("run", "seed", "outcome", "last_ante", "last_cash", "last_yorick")} for r in runs],
    "late_clears_with_unused_discards": {
        "count": len(late_clears), "unused_total": sum(r["remaining_discards"] for r in late_clears),
        "single_play_count": len(single_play_clears),
        "single_play_rows": [{k: r[k] for k in ("run", "ante", "round", "blind", "entry_sequence", "remaining_discards", "entry_yorick", "exit_yorick", "target", "final_chips")} for r in single_play_clears],
    },
    "low_discard_rounds": [{k: r[k] for k in ("run", "ante", "round", "blind", "discard_sizes", "entry_yorick", "exit_yorick", "cleared")} for r in low_discards],
    "shop_exits": {"count": len(shop_exits), "above_50": len(high_exits), "above_100": sum(a["before"]["dollars"] > 100 for a in high_exits),
        "reroll_reasons_above_50": dict(reroll_reasons),
        "high_rows": [{**brief_action(a), "reroll_reason": (a.get("advice") or {}).get("reroll_review", {}).get("status"),
                       "jokers": [c.get("key") for c in a["before"].get("jokers") or []],
                       "stock": [c.get("key") for c in a["before"].get("consumeables") or []]} for a in high_exits]},
    "consumables_at_shop_exits": dict(stock),
    "hanged": [brief_action(a) for a in hanged],
    "business": [{**brief_action(a), "selected_card": a.get("selected"), "advice": a.get("advice")} for a in business],
}
(P / "diagnostic.json").write_text(json.dumps(out, indent=2, allow_nan=False) + "\n", encoding="utf-8")
print(json.dumps({"late_clear": out["late_clears_with_unused_discards"]["count"],
                  "single_play_late_clear": len(single_play_clears), "high_cash_exits": len(high_exits),
                  "reroll_reasons": dict(reroll_reasons), "hanged_uses": len(hanged),
                  "hanged_population_min": min((x["population_after"] for x in out["hanged"] if x["population_after"] is not None), default=None),
                  "business_choices": len(business)}))
