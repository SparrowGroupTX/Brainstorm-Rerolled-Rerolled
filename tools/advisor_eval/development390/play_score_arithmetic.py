"""Passive public prediction/next-observation score arithmetic; no replay."""

from collections import Counter
from pathlib import Path
import json
import re

HERE = Path(__file__).resolve().parent
actions = json.loads((HERE / "analysis/actions.json").read_text(encoding="utf-8"))
pat = re.compile(r"\(~([\d,]+)\)")
rows = []
for index, row in enumerate(actions[:-1]):
    if (row.get("action") or {}).get("kind") != "play":
        continue
    current = ((row.get("observation") or {}).get("state") or {})
    following = actions[index + 1]
    next_state = ((following.get("observation") or {}).get("state") or {})
    advice = ((row.get("advice") or {}).get("advice") or {})
    match = pat.search(advice.get("title") or "")
    if not match or row.get("run_id") != following.get("run_id") or \
            current.get("phase") != "hand" or next_state.get("blind_key") != current.get("blind_key") or \
            next_state.get("ante") != current.get("ante"):
        continue
    before, after = current.get("chips"), next_state.get("chips")
    if not isinstance(before, (int, float)) or not isinstance(after, (int, float)) or after < before:
        continue
    predicted = int(match.group(1).replace(",", ""))
    realized = after - before
    rows.append({"sequence": row["anchor"]["sequence"], "run_id": row["run_id"],
                 "ante": current.get("ante"), "blind": current.get("blind_key"),
                 "predicted": predicted, "realized": realized,
                 "absolute_error": abs(realized - predicted)})

out = {"scope": "Only consecutive auto-run play requests with a numeric advice title and a same-blind next public observation; omitted plays are unknown.",
       "eligible": len(rows),
       "exact": sum(x["absolute_error"] == 0 for x in rows),
       "within_one": sum(x["absolute_error"] <= 1 for x in rows),
       "by_run": dict(Counter(x["run_id"] for x in rows)),
       "largest_errors": sorted(rows, key=lambda x: -x["absolute_error"])[:20],
       "rows": rows}
with (HERE / "analysis/scoring_arithmetic.json").open("x", encoding="utf-8") as stream:
    json.dump(out, stream, indent=2, allow_nan=False)
    stream.write("\n")
print(json.dumps({k: out[k] for k in ("eligible", "exact", "within_one", "by_run", "largest_errors")}))
