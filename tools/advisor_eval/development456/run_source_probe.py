"""One-use bounded original cash-out comparison. No game process or saves."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from tools.advisor_learning.lifecycle_reference_455 import source_rule_reference

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
PRIOR = HERE.parent / "development455"
MANIFEST = HERE / "SOURCE_PROBE_PREPARED.json"
ATTEMPT = HERE / "source_attempt_001"
WALL_SECONDS = 20
ARTIFACT_CAP_BYTES = 1_048_576
CASE_KEYS = frozenset({
    "pre_cash", "queued", "settled_cash", "hands", "discards", "purchases",
    "previous_dollars", "carry_marker", "shop_free_present",
    "shop_d6ed_present", "phase", "previous_identity", "shuffle_key",
    "repeat_queued", "hands_played", "discards_used", "reset_hands",
    "reset_discards", "bonus_hands", "bonus_discards",
})
FRAME_KEYS = frozenset({
    "index", "phase", "cash", "hands", "discards", "purchases",
    "previous_dollars", "shop_free_present", "shop_d6ed_present",
    "eval_removed",
})
STRING_KEYS = frozenset({"phase", "carry_marker", "shuffle_key"})


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_prepared() -> dict:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if not manifest.get("prepared_only") or manifest.get("source_executed"):
        raise RuntimeError("Invalid prepared-source manifest state")
    archive = Path(manifest["source_archive"])
    if sha(archive) != manifest["source_archive_sha256"]:
        raise RuntimeError("Original source archive drift")
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


def parse_record(line: str, kind: str, keys: frozenset[str]) -> tuple[str, dict]:
    parts = line.split("|")
    if len(parts) != len(keys) + 2 or parts[0] != kind:
        raise ValueError("Malformed " + kind + " line")
    case_id = parts[1]
    values = {}
    for part in parts[2:]:
        key, separator, value = part.partition("=")
        if not separator or key in values or key not in keys:
            raise ValueError("Malformed or duplicate " + kind + " field")
        values[key] = value if key in STRING_KEYS else int(value)
    if set(values) != keys:
        raise ValueError("Missing " + kind + " field")
    return case_id, values


def expected_case(fixture: dict) -> dict:
    state = source_rule_reference(fixture)["state"]
    cr = state["current_round"]
    return {
        "pre_cash": fixture["cash"], "queued": 3,
        "settled_cash": state["cash"],
        "hands": cr["hands_left"], "discards": cr["discards_left"],
        "purchases": cr["jokers_purchased"],
        "previous_dollars": state["previous_round"]["dollars"],
        "carry_marker": state["previous_round"].get("carry_marker", "<none>"),
        "shop_free_present": 0, "shop_d6ed_present": 0,
        "phase": "shop", "previous_identity": 1,
        "shuffle_key": "cashout1", "repeat_queued": 0,
        "hands_played": cr["hands_played"], "discards_used": cr["discards_used"],
        "reset_hands": state["round_resets"]["hands"],
        "reset_discards": state["round_resets"]["discards"],
        "bonus_hands": state["round_bonus"]["next_hands"],
        "bonus_discards": state["round_bonus"]["discards"],
    }


def candidate_case(candidate: dict) -> dict:
    state = candidate["state"]
    stock = candidate["events"][1]
    cr = state["current_round"]
    if stock["event"] != "shop_population_input":
        raise ValueError("Candidate stock observation missing")
    return {
        "settled_cash": stock["cash"],
        "hands": stock["hands_left"], "discards": stock["discards_left"],
        "purchases": stock["jokers_purchased"],
        "previous_dollars": stock["previous_round"]["dollars"],
        "carry_marker": stock["previous_round"].get("carry_marker", "<none>"),
        "shop_free_present": int(stock["shop_free_present"]),
        "shop_d6ed_present": int(stock["shop_d6ed_present"]),
        "phase": stock["shop_phase"],
        "hands_played": cr["hands_played"], "discards_used": cr["discards_used"],
        "reset_hands": state["round_resets"]["hands"],
        "reset_discards": state["round_resets"]["discards"],
        "bonus_hands": state["round_bonus"]["next_hands"],
        "bonus_discards": state["round_bonus"]["discards"],
    }


def expected_frames(fixture: dict) -> list[dict]:
    expected = expected_case(fixture)
    result = []
    for index in range(1, 4):
        result.append({
            "index": index, "phase": "shop",
            "cash": fixture["cash"] if index == 1 else expected["settled_cash"],
            "hands": expected["hands"], "discards": expected["discards"],
            "purchases": 0,
            "previous_dollars": (fixture["previous_round"]["dollars"] if index < 3
                                 else expected["settled_cash"]),
            "shop_free_present": 0, "shop_d6ed_present": 0,
            "eval_removed": 1,
        })
    return result


def parse_cases(output: str, fixtures: dict[str, dict], candidate: dict[str, dict]) -> list[dict]:
    found: dict[str, dict] = {}
    frames: dict[str, list[dict]] = {case_id: [] for case_id in fixtures}
    for line in output.splitlines():
        if line.startswith("FRAME|"):
            case_id, values = parse_record(line, "FRAME", FRAME_KEYS)
            if case_id not in fixtures or len(frames[case_id]) >= 3:
                raise ValueError("Unexpected source frame")
            frames[case_id].append(values)
        elif line.startswith("CASE|"):
            case_id, observed = parse_record(line, "CASE", CASE_KEYS)
            if case_id not in fixtures or case_id in found:
                raise ValueError("Unexpected or duplicate source case")
            fixture = fixtures[case_id]
            reference = expected_case(fixture)
            candidate_values = candidate_case(candidate[case_id])
            expected_trace = expected_frames(fixture)
            actual_trace = frames[case_id]
            differences = {
                key: {"expected": value, "source": observed[key]}
                for key, value in reference.items() if observed[key] != value
            }
            differences.update({
                "candidate_" + key: {"candidate": value, "source": observed[key]}
                for key, value in candidate_values.items() if observed[key] != value
            })
            if actual_trace != expected_trace:
                differences["source_queued_frames"] = {
                    "expected": expected_trace, "source": actual_trace}
            found[case_id] = {
                "case_id": case_id, "source": observed,
                "reference": reference, "candidate": candidate_values,
                "source_queued_frames": actual_trace,
                "agreement": not differences, "differences": differences,
            }
    if any(frames[case_id] for case_id in fixtures if case_id not in found):
        raise ValueError("Source frames without completed case")
    return [found[case_id] for case_id in fixtures if case_id in found]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true",
                        help="Verify frozen bytes; never invoke Lua")
    parser.add_argument("--authorization", help="Fresh user approval for this one-use proposal")
    args = parser.parse_args()
    manifest = verify_prepared()
    if args.check_only:
        print("Prepared cash-out source bytes verified; original source not executed")
        return 0
    if not args.authorization:
        parser.error("--authorization is required for original-source execution")
    fixtures = {case["id"]: case for case in json.loads((PRIOR / "fixtures.json").read_text(
        encoding="utf-8"))["cases"]}
    if list(fixtures) != manifest["case_ids"] or len(fixtures) != 6:
        raise RuntimeError("Fixture partition drift")
    manufactured = json.loads((PRIOR / "MANUFACTURED_COMPARISONS.json").read_text(
        encoding="utf-8"))
    candidate = {item["comparison"]["case_id"]: item["actual"]
                 for item in manufactured["cases"]}
    if set(candidate) != set(fixtures) or not all(item["comparison"]["agreement"]
                                                for item in manufactured["cases"]):
        raise RuntimeError("Candidate receipt incomplete")

    ATTEMPT.mkdir(exist_ok=False)
    lease = {"status": "consumed_before_worker", "authorization": args.authorization,
             "prepared_manifest_sha256": sha(MANIFEST), "max_workers": 1,
             "max_cases": 6, "max_initial_cash_out_calls": 6,
             "max_guarded_repeat_calls": 6, "max_queued_callbacks": 18,
             "worker_wall_seconds": WALL_SECONDS, "coordinator_wall_seconds": 30,
             "artifact_cap_bytes": ARTIFACT_CAP_BYTES, "gpu": False}
    (ATTEMPT / "LEASE.json").write_text(json.dumps(lease, indent=2) + "\n",
                                               encoding="utf-8")
    env = os.environ.copy()
    env.update({"OMP_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1",
                "MKL_NUM_THREADS": "1", "NUMEXPR_NUM_THREADS": "1"})
    command = [sys.executable, str(ROOT / "tests/run_lua_tests.py"), "--workers", "1",
               "--lua-library", str(Path(manifest["source_archive"]).parent / "lua51.dll"),
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
        stdout, stderr = "", repr(error)
        returncode, status = None, "worker_launch_error"
    elapsed = time.perf_counter() - started
    if len(stdout.encode("utf-8")) + len(stderr.encode("utf-8")) > 900_000:
        stdout = stdout[:450_000]
        stderr = stderr[:450_000] + "\nOUTPUT TRUNCATED AT ARTIFACT CAP\n"
        status = "artifact_cap_exceeded"
    (ATTEMPT / "stdout.log").write_text(stdout, encoding="utf-8")
    (ATTEMPT / "stderr.log").write_text(stderr, encoding="utf-8")
    cases = []
    if status in {"completed", "source_error"}:
        try:
            cases = parse_cases(stdout, fixtures, candidate)
            if status == "completed" and (len(cases) != 6 or
                                          not all(item["agreement"] for item in cases)):
                status = "mismatch_or_missing"
        except Exception as error:
            if status == "completed":
                status = "parse_error"
            stderr += "\n" + repr(error)
            (ATTEMPT / "stderr.log").write_text(stderr, encoding="utf-8")
    execution_status = ("not_started" if status == "worker_launch_error" else
                        "confirmed_case_output" if cases else "attempted_unconfirmed")
    report = {"status": status, "returncode": returncode, "wall_seconds": elapsed,
              "cases": cases, "source_execution_status": execution_status,
              "attempt": "source_attempt_001",
              "prepared_manifest_sha256": sha(MANIFEST),
              "source_worker_count": 1, "profile_or_save_read": False,
              "Balatro_process_started": False}
    (ATTEMPT / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                                          encoding="utf-8")
    artifact_bytes = sum(path.stat().st_size for path in ATTEMPT.iterdir() if path.is_file())
    if artifact_bytes > ARTIFACT_CAP_BYTES:
        report["status"] = "artifact_cap_exceeded"
        report["artifact_bytes"] = artifact_bytes
        (ATTEMPT / "report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n",
                                              encoding="utf-8")
    print(json.dumps({"status": report["status"], "cases": len(cases),
                      "attempt": str(ATTEMPT)}, sort_keys=True))
    return 0 if report["status"] == "completed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
