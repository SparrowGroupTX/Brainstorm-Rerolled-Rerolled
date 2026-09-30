"""Summarize already-indexed public actions by run and ante; no counterfactuals."""

from collections import Counter, defaultdict
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
OUT = HERE / "analysis"


def read(name):
    return json.loads((OUT / name).read_text(encoding="utf-8"))


def write(name, value):
    with (OUT / name).open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


def item(row):
    action = row["action"] or {}
    obs = row["observation"] or {}
    state = obs.get("state") or {}
    area = action.get("area")
    objects = {"shop_jokers": "shop_jokers", "shop_booster": "shop_booster",
               "consumeables": "consumables", "jokers": "jokers"}
    source = state.get(objects.get(area, "")) or []
    index = action.get("index")
    if type(index) is int and 1 <= index <= len(source):
        return source[index-1]
    return None


def main():
    actions = read("actions.json")
    grouped = defaultdict(lambda: defaultdict(list))
    for row in actions:
        s = row["observation"]["state"]
        grouped[row["run_id"]][s.get("ante")].append(row)
    result = {}
    for run_id, antes in grouped.items():
        out = []
        for ante, rows in sorted(antes.items(), key=lambda p: p[0] or 0):
            first = rows[0]["observation"]["state"]
            last = rows[-1]["observation"]["state"]
            kinds = Counter((r["action"] or {}).get("kind") for r in rows)
            purchases = []
            uses = []
            shops = []
            blinds = []
            for row in rows:
                act = row["action"] or {}
                s = row["observation"]["state"]
                card = item(row)
                kind = act.get("kind")
                if kind in ("buy", "choose", "open", "sell", "use"):
                    record = {"sequence": row["anchor"]["sequence"], "kind": kind,
                              "area": act.get("area"), "key": card and card.get("key"),
                              "cost": card and card.get("cost"),
                              "edition": card and card.get("edition"),
                              "rental": card and card.get("rental"),
                              "eternal": card and card.get("eternal"),
                              "cash": s.get("dollars")}
                    (uses if kind == "use" else purchases).append(record)
                if kind in ("leave_shop", "reroll"):
                    shops.append({"sequence": row["anchor"]["sequence"],
                                  "kind": kind, "cash": s.get("dollars"),
                                  "reroll_cost": s.get("reroll_cost"),
                                  "joker_keys": [x.get("key") for x in s.get("jokers") or []],
                                  "advice_title": row["advice"]["advice"].get("title"),
                                  "reroll_review": row["advice"]["advice"].get("reroll_review")})
                if kind in ("play", "discard"):
                    blinds.append({"sequence": row["anchor"]["sequence"],
                                   "kind": kind, "blind": s.get("blind_key"),
                                   "target": s.get("target"), "chips": s.get("chips"),
                                   "hands_left": s.get("hands_left"),
                                   "discards_left": s.get("discards_left"),
                                   "indices_count": len(act.get("indices") or []),
                                   "yorick": [x.get("x_mult") for x in s.get("jokers") or []
                                              if x.get("key") == "j_yorick"],
                                   "title": row["advice"]["advice"].get("title"),
                                   "yorick_review": row["advice"]["advice"].get("yorick_review")})
            out.append({"ante": ante, "first_cash": first.get("dollars"),
                        "last_cash": last.get("dollars"),
                        "first_jokers": [x.get("key") for x in first.get("jokers") or []],
                        "last_jokers": [x.get("key") for x in last.get("jokers") or []],
                        "first_yorick": [x.get("x_mult") for x in first.get("jokers") or []
                                         if x.get("key") == "j_yorick"],
                        "last_yorick": [x.get("x_mult") for x in last.get("jokers") or []
                                        if x.get("key") == "j_yorick"],
                        "first_consumables": [x.get("key") for x in first.get("consumables") or []],
                        "last_consumables": [x.get("key") for x in last.get("consumables") or []],
                        "actions": dict(kinds), "purchases": purchases, "uses": uses,
                        "shops": shops, "hand_actions": blinds})
        result[run_id] = out
    write("trajectory.json", result)
    for run_id, antes in result.items():
        print(run_id, [(x["ante"], x["first_cash"], x["last_cash"],
                        x["first_yorick"], x["last_yorick"],
                        x["actions"].get("discard", 0),
                        x["actions"].get("reroll", 0),
                        [y["key"] for y in x["purchases"] if y["kind"] == "buy"])
                       for x in antes])


if __name__ == "__main__":
    main()
