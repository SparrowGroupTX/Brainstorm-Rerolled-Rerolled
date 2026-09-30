"""Preserve the finished public session and classify starts without policy replay."""

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

SESSION = "session-20260925T174440Z-1"
SOURCE = Path(r"C:\Users\trevo\AppData\Roaming\Balatro\advisor_player_log_v2")
PREFIX = json.loads((HERE / "capture/manifest.json").read_text(encoding="utf-8"))
SEGMENTS = sorted(SOURCE.glob(f"{SESSION}-*.brj"))
assert len(SEGMENTS) > len(PREFIX["segments"])
TAIL = HERE / "logs_complete_tail"
OUT = HERE / "completed"
TAIL.mkdir(exist_ok=False)
OUT.mkdir(exist_ok=False)


def sha(value):
    return hashlib.sha256(value).hexdigest()


segments, lifecycle = [], []
versions, profiles, kinds = Counter(), Counter(), Counter()
sequence = 0
for index, source in enumerate(SEGMENTS):
    before = source.stat()
    assert before.st_size <= 8_388_608
    data = source.read_bytes()
    after = source.stat()
    assert (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns)
    digest = sha(data)
    if index < len(PREFIX["segments"]):
        assert source.name == PREFIX["segments"][index]["name"]
        assert digest == PREFIX["segments"][index]["sha256"]
        assert (HERE / "logs1" / source.name).read_bytes() == data
    else:
        with (TAIL / source.name).open("xb") as stream:
            stream.write(data)
        assert (TAIL / source.name).read_bytes() == data
    item = {"name": source.name, "bytes": len(data), "sha256": digest, "events": 0}
    for raw, _ in records(io.BytesIO(data)):
        event = parsed(raw)
        assert event["sequence"] == sequence + 1
        sequence += 1
        item["events"] += 1
        kind = event["kind"]
        kinds[kind] += 1
        context = event.get("context") or {}
        if context.get("version"):
            versions[context["version"]] += 1
        if kind == "teacher_observation":
            profile = ((context.get("snapshot") or {}).get("teacher_profile"))
            if profile:
                profiles[profile] += 1
        details = event.get("details") or {}
        if kind == "auto_run" and details.get("event") in (
                "run_started", "run_finished", "run_abandoned", "session_stopped"):
            lifecycle.append({
                "sequence": sequence, "segment": source.name,
                "event": details["event"], "run_id": details.get("run_id"),
                "run_number": details.get("run_number"),
                "outcome": details.get("outcome"), "reason": details.get("reason"),
                "evidence": details.get("evidence") if details["event"] != "run_finished" else {
                    "kind": (details.get("evidence") or {}).get("kind"),
                    "verified": (details.get("evidence") or {}).get("verified"),
                },
                "outcomes": details.get("outcomes"), "runs_started": details.get("runs_started"),
                "start_attempts": details.get("start_attempts"),
            })
    segments.append(item)

starts = [x for x in lifecycle if x["event"] == "run_started"]
endings = [x for x in lifecycle if x["event"] in ("run_finished", "run_abandoned")]
stops = [x for x in lifecycle if x["event"] == "session_stopped"]
assert len(stops) == 1 and stops[0]["sequence"] == sequence - 1
assert stops[0]["runs_started"] == len(starts) == 10
assert len(endings) == len(starts)
assert {x["run_id"] for x in starts} == {x["run_id"] for x in endings}
assert len({x["run_id"] for x in starts}) == 10
assert sequence > PREFIX["events"]
summary = {
    "captured_utc": datetime.now(timezone.utc).isoformat(),
    "source": str(SOURCE), "session": SESSION,
    "scope": "All completed public segments after game process absence; no save/profile or policy/scorer execution.",
    "prefix_manifest_sha256": sha((HERE / "capture/manifest.json").read_bytes()),
    "segments": segments, "events": sequence,
    "versions": dict(versions), "profiles": dict(profiles), "kinds": dict(kinds),
    "lifecycle": lifecycle,
    "starts": len(starts), "endings": dict(Counter(x["outcome"] for x in endings)),
}
with (OUT / "manifest.json").open("x", encoding="utf-8") as stream:
    json.dump(summary, stream, indent=2, allow_nan=False)
    stream.write("\n")
print(json.dumps({"segments": len(segments), "events": sequence,
                  "starts": len(starts), "endings": summary["endings"],
                  "versions": summary["versions"], "profiles": summary["profiles"]}))
