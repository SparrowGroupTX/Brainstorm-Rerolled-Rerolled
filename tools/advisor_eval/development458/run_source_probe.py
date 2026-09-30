"""One-use selected original booster branch probe. Requires fresh authorization."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import zipfile


ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "SOURCE_PROBE_PREPARED.json"
ATTEMPT = HERE / "source_attempt_001"
WALL_SECONDS = 20
ARTIFACT_CAP_BYTES = 1_048_576
RAW_CAPTURE_LIMIT = 700_000
CASE_KEYS = ("used1", "used2", "draws", "offers", "open_seen", "open_count", "cash")
STOCK_KEYS = ("used1", "used2", "draws", "offers")
TRACE_TYPES = frozenset({"DRAW", "UI", "MATERIALIZE", "OFFER", "OPEN"})


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_prepared() -> dict:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if not manifest.get("prepared_only") or manifest.get("source_executed"):
        raise RuntimeError("Invalid prepared-source manifest state")
    archive = Path(manifest["source_archive"])
    if sha(archive) != manifest["source_archive_sha256"]:
        raise RuntimeError("Original source archive drift")
    with zipfile.ZipFile(archive) as source:
        for name, expected in manifest["source_member_sha256"].items():
            if hashlib.sha256(source.read(name)).hexdigest() != expected:
                raise RuntimeError("Original source member drift: " + name)
    for name, expected in manifest["dependencies_sha256"].items():
        if name == "lua51.dll":
            path = archive.parent / name
        elif name.startswith("tests/") or name.startswith("tools/"):
            path = ROOT / name
        else:
            path = HERE / name
        if sha(path) != expected:
            raise RuntimeError("Prepared dependency drift: " + name)
    return manifest


def _slot(value: str) -> int | None:
    if value == "<nil>":
        return None
    number = int(value)
    if number not in (1, 2):
        raise ValueError("Invalid physical booster slot")
    return number


def _expected_trace(fixture: dict) -> list[dict]:
    used = list(fixture["used_packs"])
    draws = iter(fixture["draws"])
    events = []
    for slot in (1, 2):
        key = used[slot - 1] if slot <= len(used) else None
        if key is None or key is False:
            key = next(draws)
            events.append({"kind": "DRAW", "slot": slot, "key": key})
            if slot <= len(used):
                used[slot - 1] = key
            else:
                used.append(key)
        if key == "USED":
            continue
        events.extend((
            {"kind": "UI", "slot": None, "key": key},
            {"kind": "MATERIALIZE", "slot": slot, "key": key},
            {"kind": "OFFER", "slot": slot, "key": key},
        ))
    if fixture["id"] == "used_first_stored_second":
        events.append({"kind": "OPEN", "slot": 2, "key": "USED"})
    try:
        next(draws)
    except StopIteration:
        return events
    raise ValueError("Fixture has unused prescribed draw")


def _projection(stock: dict) -> dict:
    return {
        "draws": [{"slot": event["slot"], "key": event["key"]}
                  for event in stock["events"] if event["event"] == "pack_draw"],
        "used_packs": stock["state"]["used_packs"],
        "offers": [{"slot": offer["slot"], "key": offer["key"]}
                   for offer in stock["state"]["offers"]],
    }


def parse_output(output: str, fixtures: list[dict], expected: dict) -> list[dict]:
    ids = [fixture["id"] for fixture in fixtures]
    expected_by_id = {row["id"]: row for row in expected["cases"]}
    if list(expected_by_id) != ids or len(ids) != 8:
        raise ValueError("Expected-case partition drift")
    events = {case_id: [] for case_id in ids}
    stocked = {}
    completed = {}
    current = 0
    runner_status = {"runtime": 0, "running": 0, "pass": 0, "summary": 0}
    for line in output.splitlines():
        if line.startswith("TRACE|"):
            parts = line.split("|")
            if len(parts) != 5 or parts[1] not in events or parts[2] not in TRACE_TYPES:
                raise ValueError("Malformed source TRACE")
            if current >= len(ids) or parts[1] != ids[current] or len(events[parts[1]]) >= 80:
                raise ValueError("Out-of-order or excess source TRACE")
            if (parts[2] == "OPEN") != (parts[1] in stocked):
                raise ValueError("Source TRACE on wrong side of stock boundary")
            events[parts[1]].append({"kind": parts[2], "slot": _slot(parts[3]),
                                     "key": parts[4]})
        elif line.startswith("STOCK|"):
            parts = line.split("|")
            if (len(parts) != len(STOCK_KEYS) + 2 or current >= len(ids)
                    or parts[1] != ids[current] or parts[1] in stocked):
                raise ValueError("Malformed, duplicate, or out-of-order source STOCK")
            fields = {}
            for name, part in zip(STOCK_KEYS, parts[2:]):
                key, separator, value = part.partition("=")
                if not separator or key != name:
                    raise ValueError("Malformed source STOCK field")
                fields[key] = int(value) if name in ("draws", "offers") else value
            stocked[parts[1]] = fields
        elif line.startswith("CASE|"):
            parts = line.split("|")
            if (len(parts) != len(CASE_KEYS) + 2 or current >= len(ids)
                    or parts[1] != ids[current] or parts[1] not in stocked):
                raise ValueError("Malformed, duplicate, or out-of-order source CASE")
            fields = {}
            for name, part in zip(CASE_KEYS, parts[2:]):
                key, separator, value = part.partition("=")
                if not separator or key != name or "|" in value:
                    raise ValueError("Malformed source CASE field")
                fields[key] = int(value) if name in ("draws", "offers", "open_count", "cash") else value
            completed[parts[1]] = fields
            current += 1
        elif line.startswith("Lua runtime: "):
            runner_status["runtime"] += 1
        elif line.startswith("Running "):
            runner_status["running"] += 1
        elif line.startswith("PASS "):
            runner_status["pass"] += 1
        elif line == "1/1 fixtures passed":
            runner_status["summary"] += 1
        else:
            raise ValueError("Unexpected source worker output line")
    if current != len(ids) or len(stocked) != len(ids) or any(
            count != 1 for count in runner_status.values()):
        raise ValueError("Missing source case or runner status")

    compared = []
    for fixture in fixtures:
        case_id = fixture["id"]
        trace = events[case_id]
        row = completed[case_id]
        stock_row = stocked[case_id]
        reference = _projection(expected_by_id[case_id]["reference"])
        candidate = _projection(expected_by_id[case_id]["candidate"])
        source = {
            "draws": [{"slot": e["slot"], "key": e["key"]}
                      for e in trace if e["kind"] == "DRAW"],
            "used_packs": [stock_row["used1"], stock_row["used2"]],
            "offers": [{"slot": e["slot"], "key": e["key"]}
                       for e in trace if e["kind"] == "OFFER"],
        }
        differences = {}
        if trace != _expected_trace(fixture):
            differences["source_trace"] = {"expected": _expected_trace(fixture), "source": trace}
        for name in ("draws", "used_packs", "offers"):
            if source[name] != reference[name]:
                differences["reference_" + name] = {"reference": reference[name], "source": source[name]}
            if source[name] != candidate[name]:
                differences["candidate_" + name] = {"candidate": candidate[name], "source": source[name]}
        if (stock_row["draws"] != len(source["draws"])
                or stock_row["offers"] != len(source["offers"])
                or row["draws"] != stock_row["draws"]
                or row["offers"] != stock_row["offers"]):
            differences["summary_counts"] = {"stock": stock_row, "case": row}
        if row["cash"] != fixture["cash"]:
            differences["stub_cash"] = {"expected": fixture["cash"], "source": row["cash"]}
        is_opening = case_id == expected["opening"]["case_id"]
        if is_opening:
            wanted = expected["opening"]["reference"]["events"][0]["stored_key"]
            candidate_seen = expected["opening"]["candidate"]["events"][0]["stored_key"]
            if row["open_seen"] != wanted or row["open_seen"] != candidate_seen or row["open_count"] != 1:
                differences["open_callback_order"] = {
                    "reference": wanted, "candidate": candidate_seen,
                    "source": row["open_seen"], "open_count": row["open_count"]}
            if row["used2"] != "USED":
                differences["open_settled_slot"] = {"expected": "USED", "source": row["used2"]}
            if row["used1"] != stock_row["used1"]:
                differences["open_other_slot"] = {"stock": stock_row["used1"], "source": row["used1"]}
        elif (row["open_seen"] != "<nil>" or row["open_count"] != 0
              or row["used1"] != stock_row["used1"]
              or row["used2"] != stock_row["used2"]):
            differences["unexpected_open"] = row
        compared.append({"case_id": case_id, "source": source,
                         "source_trace": trace, "source_stock_summary": stock_row,
                         "source_summary": row,
                         "reference": reference, "candidate": candidate,
                         "agreement": not differences, "differences": differences})
    return compared


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true",
                        help="Verify frozen bytes; never invoke Lua")
    parser.add_argument("--authorization", help="Fresh user approval for this exact one-use job")
    args = parser.parse_args()
    manifest = verify_prepared()
    fixtures = json.loads((HERE.parent / "development457/fixtures.json").read_text(
        encoding="utf-8"))["cases"]
    expected = json.loads((HERE / "EXPECTED_COMPARISONS.json").read_text(encoding="utf-8"))
    if [row["id"] for row in fixtures] != manifest["case_ids"] or len(fixtures) != 8:
        raise RuntimeError("Fixture partition drift")
    if args.check_only:
        print("Prepared booster source bytes verified; original source not executed")
        return 0
    if not args.authorization:
        parser.error("--authorization is required for original-source execution")

    ATTEMPT.mkdir(exist_ok=False)
    lease = {"status": "consumed_before_worker", "authorization": args.authorization,
             "prepared_manifest_sha256": sha(MANIFEST), "max_workers": 1,
             "max_cases": 8, "max_stock_calls": 8, "max_get_pack_calls": 16,
             "max_card_stubs": 16, "max_use_body_calls": 1,
             "worker_wall_seconds": WALL_SECONDS, "coordinator_target_seconds": 30,
             "artifact_cap_bytes": ARTIFACT_CAP_BYTES, "gpu": False}
    (ATTEMPT / "LEASE.json").write_text(json.dumps(lease, indent=2) + "\n",
                                               encoding="utf-8")
    env = os.environ.copy()
    env.update({"OMP_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1",
                "MKL_NUM_THREADS": "1", "NUMEXPR_NUM_THREADS": "1"})
    archive = Path(manifest["source_archive"])
    command = [sys.executable, "-B", str(ROOT / "tests/run_lua_tests.py"),
               "--workers", "1", "--lua-library", str(archive.parent / "lua51.dll"),
               str(HERE / "prepared_source_probe.lua")]
    started = time.perf_counter()
    try:
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                 timeout=WALL_SECONDS, env=env,
                                 creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        stdout, stderr, returncode = process.stdout, process.stderr, process.returncode
        status = "source_error" if returncode else "completed"
    except subprocess.TimeoutExpired as error:
        stdout = (error.stdout.decode("utf-8", "replace") if isinstance(error.stdout, bytes)
                  else error.stdout or "")
        stderr = (error.stderr.decode("utf-8", "replace") if isinstance(error.stderr, bytes)
                  else error.stderr or "")
        returncode, status = None, "timeout"
    except OSError as error:
        stdout, stderr, returncode, status = "", repr(error), None, "worker_launch_error"
    elapsed = time.perf_counter() - started
    raw_size = len(stdout.encode("utf-8")) + len(stderr.encode("utf-8"))
    if raw_size > RAW_CAPTURE_LIMIT:
        stdout = stdout[:350_000]
        stderr = stderr[:350_000] + "\nRAW OUTPUT TRUNCATED AT ARTIFACT CAP\n"
        status = "artifact_cap_exceeded"
    (ATTEMPT / "stdout.log").write_text(stdout, encoding="utf-8")
    (ATTEMPT / "stderr.log").write_text(stderr, encoding="utf-8")
    comparisons = []
    if status == "completed":
        try:
            comparisons = parse_output(stdout, fixtures, expected)
            if len(comparisons) != 8 or any(not row["agreement"] for row in comparisons):
                status = "mismatch_or_missing"
        except Exception as error:
            status = "parse_error"
            stderr += "\n" + repr(error)
            (ATTEMPT / "stderr.log").write_text(stderr, encoding="utf-8")
    report = {"status": status, "returncode": returncode,
              "wall_seconds": elapsed, "cases": comparisons,
              "source_execution_status": (
                  "not_started" if status == "worker_launch_error" else
                  "confirmed_case_output" if comparisons else "attempted_unconfirmed"),
              "attempt": "source_attempt_001", "prepared_manifest_sha256": sha(MANIFEST),
              "source_worker_count": 1, "profile_or_save_read": False,
              "Balatro_process_started": False}
    (ATTEMPT / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                                          encoding="utf-8")
    artifact_bytes = sum(path.stat().st_size for path in ATTEMPT.iterdir() if path.is_file())
    if artifact_bytes > ARTIFACT_CAP_BYTES:
        raise RuntimeError("Attempt artifact cap exceeded; preserve all files")
    print(status)
    return 0 if status == "completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
