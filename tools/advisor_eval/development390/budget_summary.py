"""Summarize recorded decision work and discard exposure; passive receipts only."""

from collections import Counter, defaultdict
from pathlib import Path
import json
import statistics

HERE = Path(__file__).resolve().parent
actions = json.loads((HERE / "analysis/actions.json").read_text(encoding="utf-8"))
cohort = json.loads((HERE / "analysis/cohort.json").read_text(encoding="utf-8"))
by_phase = defaultdict(list)
for row in actions:
    advice = ((row.get("advice") or {}).get("advice") or {})
    evaluations = (advice.get("timing") or {}).get("evaluations")
    phase = ((row.get("observation") or {}).get("state") or {}).get("phase")
    if isinstance(evaluations, (int, float)) and phase:
        by_phase[phase].append(evaluations)

out = {
    "scope": "Recorded auto-run request advice timing and hand actions; a short discard or a play with discards left is an inspection opportunity, not a proven safe growth mistake.",
    "decision_evaluations": {
        phase: {"count": len(values), "median": statistics.median(values),
                "p95": sorted(values)[int(len(values) * 0.95)], "maximum": max(values),
                "at_ordinary_cap_140000": sum(value >= 140000 for value in values),
                "at_shop_cap_50000": sum(value >= 50000 for value in values)}
        for phase, values in sorted(by_phase.items())
    },
    "hand_exposure": {
        "discards": sum(row["discard_count"] for row in cohort["run_summary"]),
        "short_discards": sum(row["short_discards"] for row in cohort["run_summary"]),
        "plays_with_discards_left": sum(row["plays_with_discards"] for row in cohort["run_summary"]),
    },
}
with (HERE / "analysis/budget.json").open("x", encoding="utf-8") as stream:
    json.dump(out, stream, indent=2, allow_nan=False)
    stream.write("\n")
print(json.dumps(out))
