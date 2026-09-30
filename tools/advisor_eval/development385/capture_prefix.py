"""Freeze completed public BRJ2 segments and index shop advice; no policy/scorer."""
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
SESSION = "session-20260925T165555Z-1"
INPUTS = [SOURCE / f"{SESSION}-{index:06d}.brj" for index in range(1, 7)]
RAW = HERE / "logs1"
OUT = HERE / "capture"
RAW.mkdir(exist_ok=False)
OUT.mkdir(exist_ok=False)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def save(path, value):
    with path.open("x", encoding="utf-8") as stream:
        json.dump(value, stream, indent=2, allow_nan=False)
        stream.write("\n")


manifest = []
observations = {}
shops = []
actions = []
lifecycle = []
kinds = Counter()
versions = Counter()
profiles = Counter()
last_sequence = 0
last_at = None
for source in INPUTS:
    before = source.stat()
    assert before.st_size <= 8_388_608
    data = source.read_bytes()
    after = source.stat()
    assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns)
    assert len(data) == before.st_size
    with (RAW / source.name).open("xb") as target:
        target.write(data)
    assert (RAW / source.name).read_bytes() == data
    item = {"name": source.name, "bytes": len(data), "sha256": digest(data), "events": 0}
    for ordinal, (raw, _) in enumerate(records(io.BytesIO(data)), 1):
        event = parsed(raw)
        sequence = event["sequence"]
        assert sequence == last_sequence + 1
        last_sequence = sequence
        item["events"] += 1
        last_at = event.get("at")
        kind = event["kind"]
        kinds[kind] += 1
        context = event.get("context") or {}
        if context.get("version"):
            versions[context["version"]] += 1
        if kind == "teacher_observation":
            observations[event.get("observation_id")] = event
            snapshot = context.get("snapshot") or {}
            if snapshot.get("teacher_profile"):
                profiles[snapshot["teacher_profile"]] += 1
        elif kind == "teacher_advice":
            advice = context.get("advice") or {}
            prior = observations.get(event.get("observation_id")) or {}
            snapshot = (prior.get("context") or {}).get("snapshot") or {}
            if advice.get("status") == "current" and snapshot.get("phase") == "shop":
                shops.append({
                    "sequence": sequence,
                    "anchor": {"segment": source.name, "ordinal": ordinal, "raw_sha256": digest(raw)},
                    "observation_id": event.get("observation_id"),
                    "seed": context.get("seed"),
                    "run_instance": context.get("run_instance"),
                    "ante": snapshot.get("ante"),
                    "cash": snapshot.get("dollars"),
                    "reroll_cost": snapshot.get("reroll_cost"),
                    "joker_keys": [card.get("key") for card in snapshot.get("jokers") or []],
                    "action": advice.get("action"),
                    "reroll_review": advice.get("reroll_review"),
                    "shop_truncated": (advice.get("gold_review") or {}).get("shop_truncated"),
                    "shop_evaluations": (advice.get("gold_review") or {}).get("shop_evaluations"),
                })
        elif kind in ("action_requested", "action_callback_result"):
            actions.append({"sequence": sequence, "kind": kind,
                            "advice_sequence": event.get("advice_sequence"),
                            "details": event.get("details")})
        elif kind == "auto_run" and (event.get("details") or {}).get("event") in (
                "run_started", "run_finished", "run_abandoned", "session_stopped"):
            lifecycle.append({"sequence": sequence, "details": event.get("details")})
    manifest.append(item)

save(OUT / "manifest.json", {
    "captured_utc": datetime.now(timezone.utc).isoformat(),
    "source": str(SOURCE),
    "scope": "Completed public segments 1–6 only; active game tail excluded. No save/profile access or policy/scorer execution.",
    "segments": manifest,
    "bytes": sum(item["bytes"] for item in manifest),
    "events": sum(item["events"] for item in manifest),
    "last_sequence": last_sequence,
    "last_at": last_at,
    "versions": dict(versions),
    "profiles": dict(profiles),
    "kinds": dict(kinds),
    "lifecycle": lifecycle,
})
save(OUT / "shops.json", shops)
save(OUT / "actions.json", actions)
print(json.dumps({"segments": len(manifest), "bytes": sum(x["bytes"] for x in manifest),
                  "events": last_sequence, "versions": versions, "profiles": profiles,
                  "high_cash_leaves": sum(x["action"] and x["action"].get("kind") == "leave_shop"
                                          and (x["cash"] or 0) > 50 for x in shops)}, default=dict))
