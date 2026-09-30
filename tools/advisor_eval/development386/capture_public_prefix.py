"""Freeze only completed public journal segments; index teacher decisions without replay."""

from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import io
import json
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT))
from tools.advisor_eval.read_player_log import parsed, records

SOURCE = Path(r"C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2")
SESSION = "session-20260925T174440Z-1"
SEGMENTS = list(sorted(SOURCE.glob(f"{SESSION}-*.brj")))
assert len(SEGMENTS) >= 2, "No completed segment before the active tail"
SEGMENTS = SEGMENTS[:-1]  # never read the current writable tail
RAW = HERE / "logs1"
OUT = HERE / "capture"
RAW.mkdir(exist_ok=False)
OUT.mkdir(exist_ok=False)


def digest(value):
    return hashlib.sha256(value).hexdigest()


def save(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


manifest, selected, lifecycle = [], [], []
observations = {}
versions, profiles, kinds = Counter(), Counter(), Counter()
last_sequence = 0
for source in SEGMENTS:
    before = source.stat()
    assert before.st_size <= 8_388_608
    data = source.read_bytes()
    after = source.stat()
    assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns)
    with (RAW / source.name).open("xb") as target:
        target.write(data)
    assert (RAW / source.name).read_bytes() == data
    item = {"name": source.name, "bytes": len(data), "sha256": digest(data), "events": 0}
    for ordinal, (raw, _) in enumerate(records(io.BytesIO(data)), 1):
        event = parsed(raw)
        assert event["sequence"] == last_sequence + 1
        last_sequence += 1
        item["events"] += 1
        kind = event["kind"]
        kinds[kind] += 1
        context = event.get("context") or {}
        if context.get("version"):
            versions[context["version"]] += 1
        anchor = {"segment": source.name, "ordinal": ordinal, "raw_sha256": digest(raw)}
        if kind == "teacher_observation":
            observations[event.get("observation_id")] = (event, anchor)
            snapshot = context.get("snapshot") or {}
            if snapshot.get("teacher_profile"):
                profiles[snapshot["teacher_profile"]] += 1
        elif kind == "teacher_advice":
            advice = context.get("advice") or {}
            prior = observations.get(event.get("observation_id"))
            snapshot = ((prior or ({},))[0].get("context") or {}).get("snapshot") or {}
            if advice.get("status") != "current":
                continue
            offers = snapshot.get("shop_jokers") or []
            owned = snapshot.get("jokers") or []
            stock = Counter(c.get("key") for c in snapshot.get("consumeables") or [])
            action = advice.get("action") or {}
            interesting = (any(c.get("key") in ("j_blueprint", "j_brainstorm") for c in offers)
                           or any((c.get("ability") or {}).get("eternal") and
                                  (c.get("rarity") == 1 or (c.get("ability") or {}).get("rarity") == 1)
                                  for c in offers)
                           or stock.get("c_strength", 0) >= 5
                           or action.get("kind") in ("sell", "use") and
                                  action.get("area") == "consumeables")
            if interesting:
                cards = snapshot.get("playing_cards") or []
                ranks = Counter(c.get("rank") or (c.get("base") or {}).get("id") for c in cards)
                selected.append({
                    "sequence": last_sequence, "anchor": anchor,
                    "observation_anchor": prior[1] if prior else None,
                    "observation_id": event.get("observation_id"),
                    "run_instance": context.get("run_instance"), "seed": context.get("seed"),
                    "phase": snapshot.get("phase"), "ante": snapshot.get("ante"),
                    "round": snapshot.get("round"), "cash": snapshot.get("dollars"),
                    "hands_left": snapshot.get("hands_left"), "discards_left": snapshot.get("discards_left"),
                    "joker_keys": [c.get("key") for c in owned],
                    "offers": [{"key": c.get("key"), "cost": c.get("cost"),
                                "rarity": c.get("rarity"), "ability": c.get("ability")}
                               for c in offers],
                    "stock": dict(stock), "population_count": len(cards),
                    "visible_ranks": {str(k): v for k, v in ranks.items() if k is not None},
                    "advice_title": advice.get("title"), "action": action,
                    "stock_review": advice.get("stock_review"),
                    "shop_planet_dominance": advice.get("shop_planet_dominance"),
                    "gold_review": advice.get("gold_review"),
                    "scoring_evidence": advice.get("scoring_evidence"),
                })
        elif kind == "auto_run" and (event.get("details") or {}).get("event") in (
                "run_started", "run_finished", "run_abandoned", "session_stopped"):
            lifecycle.append({"sequence": last_sequence, "anchor": anchor,
                              "details": event.get("details")})
    manifest.append(item)

save(OUT / "manifest.json", {
    "captured_utc": datetime.now(timezone.utc).isoformat(),
    "source": str(SOURCE), "session": SESSION,
    "scope": "Completed public segments only; active tail excluded. No policy/scorer execution.",
    "segments": manifest, "events": last_sequence,
    "versions": dict(versions), "profiles": dict(profiles), "kinds": dict(kinds),
    "lifecycle": lifecycle,
})
save(OUT / "selected_advice.json", selected)
print(json.dumps({"segments": len(manifest), "events": last_sequence,
                  "bytes": sum(x["bytes"] for x in manifest),
                  "selected_advice": len(selected), "versions": versions,
                  "profiles": profiles, "run_endings": len([x for x in lifecycle if
                                                    (x["details"] or {}).get("event") == "run_finished"])},
                 default=dict))
