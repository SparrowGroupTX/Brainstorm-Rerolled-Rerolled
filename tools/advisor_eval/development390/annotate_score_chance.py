"""Classify public score arithmetic by selected Lucky-card exposure, without replay."""

from collections import Counter
from pathlib import Path
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools.advisor_eval.read_player_log import parsed, records

actions = json.loads((HERE / "analysis/actions.json").read_text(encoding="utf-8"))
arithmetic = json.loads((HERE / "analysis/scoring_arithmetic.json").read_text(encoding="utf-8"))
eligible = {row["sequence"]: row for row in arithmetic["rows"]}
by_observation = {
    action["observation"]["anchor"]["sequence"]: action
    for action in actions
    if action["anchor"]["sequence"] in eligible
}
assert len(by_observation) == len(eligible) == arithmetic["eligible"]

rows = []
for development in ("development387", "development388"):
    directory = HERE.parent / development / "logs1"
    for path in sorted(directory.glob("session-20260925T190519Z-1-*.brj")):
        with path.open("rb") as stream:
            for raw, _ in records(stream):
                event = parsed(raw)
                action = by_observation.get(event["sequence"])
                if action is None:
                    continue
                assert event["kind"] == "teacher_observation"
                hand = (event.get("context") or {}).get("snapshot", {}).get("hand") or []
                selected = (action["action"] or {}).get("indices") or []
                assert selected and all(isinstance(i, int) and 1 <= i <= len(hand) for i in selected)
                lucky = sum(hand[i - 1].get("key") == "m_lucky" for i in selected)
                estimate = eligible[action["anchor"]["sequence"]]
                rows.append({"sequence": action["anchor"]["sequence"],
                             "observation_sequence": event["sequence"],
                             "selected_lucky_cards": lucky,
                             "predicted": estimate["predicted"],
                             "realized": estimate["realized"],
                             "absolute_error": estimate["absolute_error"]})

assert len(rows) == len(eligible)
assert all(row["selected_lucky_cards"] for row in rows if row["absolute_error"])
groups = Counter((bool(row["selected_lucky_cards"]), bool(row["absolute_error"])) for row in rows)
out = {
    "scope": "Selected public Lucky-card exposure among 64 consecutive same-blind score comparisons; no random-roll inference or policy replay.",
    "without_lucky_exact": groups[(False, False)],
    "without_lucky_mismatch": groups[(False, True)],
    "with_lucky_exact": groups[(True, False)],
    "with_lucky_mismatch": groups[(True, True)],
    "rows": sorted(rows, key=lambda row: row["sequence"]),
}
with (HERE / "analysis/scoring_chance.json").open("x", encoding="utf-8") as stream:
    json.dump(out, stream, indent=2, allow_nan=False)
    stream.write("\n")
print(json.dumps({k: value for k, value in out.items() if k != "rows"}))
