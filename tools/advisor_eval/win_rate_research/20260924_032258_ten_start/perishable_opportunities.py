"""Count public pre-screened replacement receipts; never run policy/scorer."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
actions = json.loads((root / "actions.json").read_text(encoding="utf-8"))
seen = {}
for action in actions:
    before = action.get("before") or {}
    review = (action.get("advice") or {}).get("replacement_review") or {}
    if not review.get("complete") or before.get("teacher_profile") != "perkeo_yorick_win_v1":
        continue
    owned = before.get("jokers") or []
    offers = before.get("shop_jokers") or []
    for candidate in review.get("candidates") or []:
        merit = candidate.get("merit")
        sale, buy = candidate.get("sale_index"), candidate.get("offer_index")
        if not isinstance(merit, (int, float)) or not 13 <= merit < 26:
            continue
        if not isinstance(sale, int) or not isinstance(buy, int) or not 1 <= sale <= len(owned) or not 1 <= buy <= len(offers):
            continue
        old, new = owned[sale - 1], offers[buy - 1]
        old_ability, new_ability = old.get("ability") or {}, new.get("ability") or {}
        if not old_ability.get("perishable") or new_ability.get("perishable") or new_ability.get("rental"):
            continue
        if not 1 <= (old_ability.get("perish_tally") or -1) <= 3:
            continue
        key = (action.get("seed"), before.get("ante"), before.get("round"), old.get("id"), new.get("id"))
        seen.setdefault(key, {
            "sequence": action["sequence"], "seed": action.get("seed"),
            "ante": before.get("ante"), "round": before.get("round"),
            "sold": old.get("key"), "offered": new.get("key"),
            "remaining": old_ability.get("perish_tally"),
            "cash_after": candidate.get("cash_after"), "merit": merit,
            "complete_finishing_recorded": False,
        })
result = {"eligible_public_prescreen_opportunities": len(seen),
          "scope": "Complete visible family, positive sub-26 merit, active short perishable to durable; finishing worlds absent from compact receipt",
          "opportunities": list(seen.values())}
(root / "perishable_opportunities.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"count": len(seen), "opportunities": result["opportunities"]}))
