"""Passive public-slot diagnostics for copied concealed-hand advice."""

from collections import Counter
from pathlib import Path
import io
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools.advisor_eval.read_player_log import parsed, records

actions = json.loads((HERE / "analysis/actions.json").read_text(encoding="utf-8"))
by_run = Counter()
examples = []
for row in actions:
    state = row["observation"]["state"]
    if state["phase"] != "hand" or state["discards_left"] <= 0:
        continue
    lines = row["advice"]["advice"].get("lines") or []
    if not any("Immediate-play fallback:" in line for line in lines):
        continue
    by_run[row["run_id"]] += 1
    examples.append({"run_id": row["run_id"], "sequence": row["anchor"]["sequence"],
                     "ante": state["ante"], "blind": state["blind"],
                     "discards_left": state["discards_left"],
                     "action_kind": (row["action"] or {}).get("kind"),
                     "fallback": next(line for line in lines if "Immediate-play fallback:" in line)})

targets = {18589, 18602, 18613}
public_hands = []
for item in json.loads((HERE / "capture/verification.json").read_text(encoding="utf-8"))["segments"]:
    if not any(item["first_sequence"] <= target <= item["last_sequence"] for target in targets):
        continue
    data = (HERE / "logs1" / item["name"]).read_bytes()
    for raw, _ in records(io.BytesIO(data)):
        event = parsed(raw)
        sequence = event["sequence"]
        if sequence not in targets or event["kind"] != "teacher_observation":
            continue
        snapshot = (event.get("context") or {}).get("snapshot") or {}
        hand = []
        for index, card in enumerate(snapshot.get("hand") or [], 1):
            hidden = card.get("face_down") or card.get("identity_redacted") or card.get("unknown")
            if hidden:
                hand.append({"index": index, "hidden": True})
            else:
                hand.append({"index": index, "hidden": False,
                             "rank": card.get("rank"), "suit": card.get("suit"),
                             "seal": card.get("seal")})
        public_hands.append({"sequence": sequence, "hand": hand,
                             "visible_nonpurple": sum(not c["hidden"] and c["seal"] != "Purple" for c in hand)})

result = {"scope": "Copied public observation/advice only; concealed identities masked; no policy/scorer replay.",
          "immediate_fallback_with_discards_by_run": dict(by_run),
          "examples": examples, "wheel_public_hands": public_hands}
path = HERE / "analysis/concealed_public.json"
if path.exists():
    assert json.loads(path.read_text(encoding="utf-8")) == result
else:
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"fallbacks": dict(by_run), "wheel_public_hands": public_hands}))
