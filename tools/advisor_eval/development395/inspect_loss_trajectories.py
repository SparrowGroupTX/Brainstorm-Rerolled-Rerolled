"""Passive compact inspection of copied 2.184 public decisions only."""

from collections import Counter
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
actions = json.loads((HERE / "analysis/actions.json").read_text(encoding="utf-8"))
cohort = json.loads((HERE / "analysis/cohort.json").read_text(encoding="utf-8"))
losses = {r["run_id"]: r["number"] for r in cohort["run_summary"] if r["outcome"] == "loss"}
rows = []
for item in actions:
    run_id = item["run_id"]
    if run_id not in losses:
        continue
    state = item["observation"]["state"]
    action = item["action"] or {}
    advice = item["advice"]["advice"]
    kind = action.get("kind")
    if kind not in ("leave_shop", "reroll", "buy", "choose", "use", "discard", "play", "sell"):
        continue
    row = {
        "run": losses[run_id], "sequence": item["anchor"]["sequence"],
        "observation": item["observation"]["anchor"],
        "advice": item["advice"]["anchor"],
        "action_anchor": item["anchor"],
        "ante": state["ante"], "round": state["round"],
        "phase": state["phase"], "blind": state["blind"],
        "kind": kind, "action": action, "title": advice.get("title"),
        "dollars": state["dollars"], "interest_cap": state["interest_cap"],
        "reroll_cost": state["reroll_cost"],
        "jokers": [{"key": j["key"], "x_mult": j["x_mult"],
                    "rental": j["rental"], "eternal": j["eternal"]}
                   for j in state["jokers"]],
        "consumables": [c["key"] for c in state["consumables"]],
        "shop_jokers": [{"key": c["key"], "cost": c["cost"],
                         "rental": c["rental"], "eternal": c["eternal"]}
                        for c in state["shop_jokers"]],
        "shop_booster": [{"key": c["key"], "cost": c["cost"]}
                         for c in state["shop_booster"]],
        "hands_left": state["hands_left"],
        "discards_left": state["discards_left"],
        "cards_selected": len(action.get("indices") or []),
        "reroll_review": advice.get("reroll_review"),
        "replacement_review": advice.get("replacement_review"),
        "gold_review": advice.get("gold_review"),
        "timing": advice.get("timing"),
        "lines": advice.get("lines"),
    }
    rows.append(row)

out = HERE / "analysis/loss_decisions.json"
if out.exists():
    assert json.loads(out.read_text(encoding="utf-8")) == rows
else:
    out.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")

print("loss actions", len(rows), "by kind", dict(Counter(r["kind"] for r in rows)))
for run in sorted(losses.values()):
    selected = [r for r in rows if r["run"] == run and r["kind"] == "leave_shop"]
    print("\nrun", run, "shop exits", len(selected))
    for r in selected:
        if r["dollars"] >= 25:
            rr = r["reroll_review"] or {}
            gr = r["gold_review"] or {}
            print(r["sequence"], "A", r["ante"], "cash", r["dollars"],
                  "fee", r["reroll_cost"], "reroll", rr.get("status"),
                  "mode", rr.get("mode"), "budget", gr.get("shop_evaluations"),
                  "truncated", gr.get("shop_truncated"),
                  "offers", ",".join(c["key"] or "?" for c in r["shop_jokers"]))
