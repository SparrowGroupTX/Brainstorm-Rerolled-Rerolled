"""Freeze completed public journal segments only; never inspect the live tail."""

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
SESSION = "session-20260925T190519Z-1"
available = sorted(SOURCE.glob(f"{SESSION}-*.brj"))
assert 2 <= len(available) <= 64
completed, omitted_tail = available[:-1], available[-1]
RAW, CAPTURE = HERE / "logs1", HERE / "capture"
RAW.mkdir(exist_ok=False)
CAPTURE.mkdir(exist_ok=False)


def sha(data):
    return hashlib.sha256(data).hexdigest()


manifest, lifecycle = [], []
kinds, versions, profiles = Counter(), Counter(), Counter()
last_sequence = 0
for path in completed:
    before = path.stat()
    assert before.st_size <= 8_388_608
    data = path.read_bytes()
    after = path.stat()
    assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns)
    with (RAW / path.name).open("xb") as stream:
        stream.write(data)
    assert (RAW / path.name).read_bytes() == data
    item = {"name": path.name, "bytes": len(data), "sha256": sha(data), "events": 0}
    for ordinal, (raw, _) in enumerate(records(io.BytesIO(data)), 1):
        event = parsed(raw)
        assert event["sequence"] == last_sequence + 1
        last_sequence += 1
        item["events"] += 1
        kind, context = event["kind"], event.get("context") or {}
        kinds[kind] += 1
        if context.get("version"):
            versions[context["version"]] += 1
        if kind == "teacher_observation":
            profile = ((context.get("snapshot") or {}).get("teacher_profile"))
            if profile:
                profiles[profile] += 1
        details = event.get("details") or {}
        if kind == "auto_run" and details.get("event") in (
                "run_started", "run_finished", "run_abandoned", "session_stopped"):
            lifecycle.append({"sequence": last_sequence, "segment": path.name,
                              "ordinal": ordinal, "raw_sha256": sha(raw),
                              "event": details["event"], "run_number": details.get("run_number"),
                              "run_id": details.get("run_id"), "outcome": details.get("outcome"),
                              "reason": details.get("reason")})
    manifest.append(item)

result = {
    "captured_utc": datetime.now(timezone.utc).isoformat(),
    "session": SESSION, "source": str(SOURCE),
    "scope": "Completed public segments only; latest potentially writable segment excluded. No game/save/profile/policy/scorer execution.",
    "omitted_tail_name": omitted_tail.name,
    "segments": manifest, "events": last_sequence,
    "kinds": dict(kinds), "versions": dict(versions), "profiles": dict(profiles),
    "lifecycle": lifecycle,
}
with (CAPTURE / "manifest.json").open("x", encoding="utf-8") as stream:
    json.dump(result, stream, indent=2, allow_nan=False)
    stream.write("\n")
print(json.dumps({"segments": len(manifest), "events": last_sequence,
                  "versions": result["versions"], "profiles": result["profiles"],
                  "lifecycle": lifecycle}))
