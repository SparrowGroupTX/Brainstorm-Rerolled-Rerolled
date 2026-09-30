"""Inspect only the last fully visible public Joker row before Acorn concealment."""

import io
import json

from audit_preserved import PRE, MID, SESSION, parsed, records


def segments():
    for folder, lo, hi in ((PRE, 1, 7), (MID, 8, 20)):
        for number in range(lo, hi + 1):
            yield folder / "logs1" / f"{SESSION}-{number:06d}.brj"


visible = {}
first_hidden = {}
ante8_count = 0
hidden_count = 0
for path in segments():
    for raw, _ in records(io.BytesIO(path.read_bytes())):
        event = parsed(raw)
        if event.get("kind") != "teacher_observation":
            continue
        context = event.get("context") or {}
        snapshot = context.get("snapshot") or {}
        if snapshot.get("ante") != 8:
            continue
        ante8_count += 1
        run = context.get("run_instance")
        jokers = snapshot.get("jokers") or []
        if not jokers:
            continue
        hidden = any(j.get("face_down") or j.get("unknown") or j.get("concealed")
                     for j in jokers)
        hidden_count += bool(hidden)
        if not hidden:
            visible.setdefault(run, []).append((event["sequence"], jokers))
        elif run not in first_hidden:
            first_hidden[run] = event["sequence"]

print(json.dumps({"ante8": ante8_count, "hidden": hidden_count,
                  "runs": list(first_hidden)}))
for run, first in sorted(first_hidden.items()):
    preceding = [row for row in visible.get(run, []) if row[0] < first]
    if not preceding:
        print(json.dumps({"run": run, "first_hidden": first,
                          "visible_count": len(visible.get(run, [])),
                          "first_visible": visible.get(run, [(None, None)])[0][0]}))
        continue
    prior = preceding[-1]
    print(json.dumps({"run": run, "last_visible_sequence": prior[0],
                      "first_hidden_sequence": first,
                      "public_abilities": sorted(({"key": j.get("key"),
                                                   "ability": j.get("ability"),
                                                   "edition": j.get("edition"),
                                                   "debuff": j.get("debuff")}
                                                  for j in prior[1]),
                                                 key=lambda j: j["key"] or "")},
                     sort_keys=True))
