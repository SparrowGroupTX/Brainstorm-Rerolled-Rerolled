"""Verify copied public BRJ2 bytes and summarize their actual lifecycle."""

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

manifest = json.loads((HERE / "capture/manifest.json").read_text(encoding="utf-8"))
assert manifest["session"] == "session-20260925T214542Z-1"
assert len(manifest["segments"]) == 27 and manifest["all_source_still_matched"]
sequence, kinds, versions, profiles = 0, Counter(), Counter(), Counter()
starts, endings, session_events, searches = [], [], [], []
segments = []
for item in manifest["segments"]:
    path = HERE / "logs1" / item["name"]
    data = path.read_bytes()
    assert len(data) == item["bytes"]
    assert hashlib.sha256(data).hexdigest() == item["sha256"]
    first = sequence + 1
    count = 0
    for ordinal, (raw, _) in enumerate(records(io.BytesIO(data)), 1):
        event = parsed(raw)
        assert event["sequence"] == sequence + 1, (path.name, sequence, event["sequence"])
        sequence += 1
        count += 1
        kind = event["kind"]
        kinds[kind] += 1
        context, details = event.get("context") or {}, event.get("details") or {}
        if context.get("version"):
            versions[context["version"]] += 1
        snapshot = context.get("snapshot") or {}
        if kind == "teacher_observation" and snapshot.get("teacher_profile"):
            profiles[snapshot["teacher_profile"]] += 1
        anchor = {"sequence": sequence, "segment": path.name, "ordinal": ordinal,
                  "raw_sha256": hashlib.sha256(raw).hexdigest()}
        if kind == "auto_run":
            record = {"anchor": anchor, "event": details.get("event"),
                      "run_number": details.get("run_number"),
                      "run_id": details.get("run_id"),
                      "outcome": details.get("outcome"),
                      "reason": details.get("reason"),
                      "runs_started": details.get("runs_started"),
                      "outcomes": details.get("outcomes")}
            if record["event"] == "run_started":
                starts.append(record)
            elif record["event"] in ("run_finished", "run_abandoned"):
                endings.append(record)
            elif record["event"] == "session_stopped":
                session_events.append(record)
        if kind in ("collection_search_started", "collection_search_finished", "collection_run_start"):
            searches.append({"anchor": anchor, "kind": kind,
                             "seed": context.get("seed"), "details": details})
    segments.append({"name": path.name, "bytes": len(data), "events": count,
                     "first_sequence": first, "last_sequence": sequence,
                     "sha256": item["sha256"]})

assert len(starts) == len(endings) == 10, (len(starts), len(endings))
assert all(start["run_id"] == end["run_id"] for start, end in zip(starts, endings))
out = {"verified_utc": datetime.now(timezone.utc).isoformat(),
       "scope": "Copied public BRJ2 only; no live log reads after capture, game/save/profile or policy/scorer execution.",
       "session": manifest["session"], "segments": segments,
       "total_bytes": sum(item["bytes"] for item in segments), "events": sequence,
       "kinds": dict(kinds), "versions": dict(versions), "profiles": dict(profiles),
       "starts": starts, "endings": endings, "outcome_counts": dict(Counter(x["outcome"] for x in endings)),
       "session_events": session_events, "searches": searches}
with (HERE / "capture/verification.json").open("x", encoding="utf-8") as stream:
    json.dump(out, stream, indent=2, allow_nan=False)
    stream.write("\n")
print(json.dumps({"segments": len(segments), "events": sequence,
                  "starts": len(starts), "endings": out["outcome_counts"],
                  "session_stopped": len(session_events),
                  "versions": out["versions"], "profiles": out["profiles"]}))
