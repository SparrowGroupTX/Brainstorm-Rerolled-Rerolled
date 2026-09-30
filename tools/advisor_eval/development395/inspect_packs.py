"""Passively list visible pack choices linked to copied public observations."""

from pathlib import Path
import io
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools.advisor_eval.read_player_log import parsed, records

cohort = json.loads((HERE / "analysis/cohort.json").read_text(encoding="utf-8"))
actions = json.loads((HERE / "analysis/actions.json").read_text(encoding="utf-8"))
losses = {r["run_id"]: r["number"] for r in cohort["run_summary"] if r["outcome"] == "loss"}
selected = {a["observation"]["anchor"]["sequence"]: a for a in actions
            if a["run_id"] in losses and (a["action"] or {}).get("kind") == "choose"
            and (a["action"] or {}).get("area") == "pack_cards"}
rows = []
verification = json.loads((HERE / "capture/verification.json").read_text(encoding="utf-8"))
for item in verification["segments"]:
    if not any(item["first_sequence"] <= seq <= item["last_sequence"] for seq in selected):
        continue
    data = (HERE / "logs1" / item["name"]).read_bytes()
    for raw, _ in records(io.BytesIO(data)):
        event = parsed(raw)
        action = selected.get(event["sequence"])
        if action is None or event["kind"] != "teacher_observation":
            continue
        snapshot = (event.get("context") or {}).get("snapshot") or {}
        choices = []
        for index, c in enumerate(snapshot.get("pack_cards") or [], 1):
            ability = c.get("ability") or {}
            choices.append({"index": index, "key": c.get("key"), "name": c.get("name"),
                            "rental": ability.get("rental"), "eternal": ability.get("eternal"),
                            "edition": (c.get("edition") or {}).get("type") if isinstance(c.get("edition"), dict) else c.get("edition"),
                            "cost": c.get("cost")})
        rows.append({"run": losses[action["run_id"]], "action_sequence": action["anchor"]["sequence"],
                     "observation_sequence": event["sequence"],
                     "ante": action["observation"]["state"]["ante"],
                     "selected_index": action["action"].get("index"),
                     "title": action["advice"]["advice"].get("title"),
                     "choices": choices})
rows.sort(key=lambda r: r["action_sequence"])
path = HERE / "analysis/pack_choices.json"
if path.exists():
    assert json.loads(path.read_text(encoding="utf-8")) == rows
else:
    path.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
print(json.dumps([r for r in rows if r["run"] in (1, 3, 8, 10) and r["ante"] == 1]))
