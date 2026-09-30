"""Arithmetic checks over frozen public action records; no policy execution."""

import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent
actions = json.loads((ROOT / "actions.json").read_text(encoding="utf-8"))

matches = []
different = []
uncomparable = []
play_count = 0
rerolls = 0
source_actions = Counter()
callback_payloads = Counter()
for row in actions:
    action = row.get("action") or {}
    kind = action.get("kind")
    source_actions[row.get("source")] += 1
    if row.get("source") == "player_callback":
        callback_payloads["empty" if not action else "nonempty"] += 1
    if kind == "reroll_shop":
        rerolls += 1
    if kind != "play":
        continue
    play_count += 1
    title = (row.get("advice") or {}).get("title") or ""
    expected = re.search(r"\(~([\d,]+)\)", title)
    if not expected:
        continue
    before, after = row.get("before") or {}, row.get("after") or {}
    if before.get("round") != after.get("round") or before.get("ante") != after.get("ante"):
        uncomparable.append({"sequence": row["sequence"], "title": title, "reason": "round_changed"})
        continue
    if not isinstance(before.get("chips"), (int, float)) or not isinstance(after.get("chips"), (int, float)):
        uncomparable.append({"sequence": row["sequence"], "title": title, "reason": "chips_missing"})
        continue
    predicted = int(expected.group(1).replace(",", ""))
    actual = after["chips"] - before["chips"]
    item = {"sequence": row["sequence"], "run_instance": row.get("run_instance"),
            "title": title, "predicted": predicted, "actual": actual,
            "anchor": row.get("anchor")}
    (matches if predicted == actual else different).append(item)

out = {"play_actions": play_count, "numeric_title_same_round_matches": len(matches),
       "numeric_title_same_round_differences": len(different),
       "numeric_title_uncomparable": len(uncomparable), "reroll_actions": rerolls,
       "action_sources": dict(source_actions), "player_callback_payloads": dict(callback_payloads),
       "differences": different, "uncomparable": uncomparable}
(ROOT / "arithmetic.json").write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: v for k, v in out.items() if k not in ("differences", "uncomparable")}, indent=2))
print("first_differences", json.dumps(different[:8], indent=2))
