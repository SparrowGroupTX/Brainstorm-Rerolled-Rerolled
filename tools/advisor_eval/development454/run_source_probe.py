"""One-use bounded original-source parity probe. Requires fresh authorization.

This reads a prepared Lua file that contains selected original source functions
and runs it through lua51.dll. It never starts Balatro.exe or reads saves.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from tools.advisor_learning.lifecycle_reference_454 import source_rule_reference

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "SOURCE_PROBE_PREPARED.json"
ATTEMPT = HERE / "source_attempt_001"
WALL_SECONDS = 20
ARTIFACT_CAP_BYTES = 1_048_576


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


def parse_cases(output: str, fixtures: dict[str, dict], candidate: dict[str, dict]) -> list[dict]:
    found: dict[str, dict] = {}
    for line in output.splitlines():
        if not line.startswith("CASE|"):
            continue
        parts = line.split("|")
        if len(parts) != 9:
            raise ValueError("Malformed source case line")
        _, case_id, pre, queued, settled, bonus, interest, total, cards = parts
        if case_id not in fixtures or case_id in found:
            raise ValueError("Unexpected or duplicate source case: " + case_id)
        observed = {
            "cash_before_flush": int(pre), "queued_rentals": int(queued),
            "settled_cash": int(settled), "joker_bonus": int(bonus),
            "interest": int(interest), "cashout_total": int(total),
            "ordered_cards": cards,
        }
        fixture = fixtures[case_id]
        reference = source_rule_reference(fixture)
        row_count = len(fixture["jokers"])
        candidate_events = candidate[case_id]["events"]
        expected = {
            "cash_before_flush": fixture["cash"],
            "queued_rentals": sum(bool(j["rental"]) for j in fixture["jokers"]),
            "settled_cash": reference["events"][row_count]["cash_after"],
            "joker_bonus": reference["events"][row_count + 1]["dollars"],
            "interest": reference["events"][row_count + 2]["interest"],
            "cashout_total": reference["events"][row_count + 2]["total"],
            "ordered_cards": ",".join(f'{j["physical_id"]}:{j["tally"]}:{int(j["debuff"])}'
                                      for j in reference["state"]["jokers"]),
        }
        candidate_values = {
            "settled_cash": candidate_events[row_count]["cash_after"],
            "joker_bonus": candidate_events[row_count + 1]["dollars"],
            "interest": candidate_events[row_count + 2]["interest"],
            "cashout_total": candidate_events[row_count + 2]["total"],
            "ordered_cards": ",".join(f'{j["physical_id"]}:{j["tally"]}:{int(j["debuff"])}'
                                      for j in candidate[case_id]["state"]["jokers"]),
        }
        differences = {key: {"expected": value, "source": observed[key]}
                       for key, value in expected.items() if observed[key] != value}
        differences.update({"candidate_" + key: {"candidate": value, "source": observed[key]}
                            for key, value in candidate_values.items() if observed[key] != value})
        found[case_id] = {"case_id": case_id, "source": observed,
                          "reference": expected, "candidate": candidate_values,
                          "agreement": not differences, "differences": differences}
    return [found[case_id] for case_id in fixtures if case_id in found]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true",
                        help="Verify frozen bytes; never invoke Lua")
    parser.add_argument("--authorization", help="Fresh user approval identifier for this exact proposal")
    args = parser.parse_args()
    manifest = verify_prepared()
    if args.check_only:
        print("Prepared source bytes verified; original source not executed")
        return 0
    if not args.authorization:
        parser.error("--authorization is required for original-source execution")
    fixtures = {case["id"]: case for case in json.loads((HERE / "fixtures.json").read_text(
        encoding="utf-8"))["cases"]}
    if list(fixtures) != manifest["case_ids"] or len(fixtures) != 7:
        raise RuntimeError("Fixture partition drift")
    manufactured = json.loads((HERE / "MANUFACTURED_COMPARISONS.json").read_text(
        encoding="utf-8"))
    candidate = {item["comparison"]["case_id"]: item["actual"]
                 for item in manufactured["cases"]}
    if set(candidate) != set(fixtures) or not all(item["comparison"]["agreement"]
                                                for item in manufactured["cases"]):
        raise RuntimeError("Candidate receipt incomplete")
    # The directory itself is the one-use lease. No retry or renamed attempt.
    ATTEMPT.mkdir(exist_ok=False)
    lease = {"status": "consumed_before_worker", "authorization": args.authorization,
             "prepared_manifest_sha256": sha(MANIFEST), "max_workers": 1,
             "max_cases": 7, "worker_wall_seconds": WALL_SECONDS,
             "coordinator_wall_seconds": 30, "artifact_cap_bytes": ARTIFACT_CAP_BYTES,
             "gpu": False}
    (ATTEMPT / "LEASE.json").write_text(json.dumps(lease, indent=2) + "\n", encoding="utf-8")
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
        stdout = error.stdout.decode("utf-8", "replace") if isinstance(error.stdout, bytes) else error.stdout or ""
        stderr = error.stderr.decode("utf-8", "replace") if isinstance(error.stderr, bytes) else error.stderr or ""
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
    if status == "completed":
        try:
            cases = parse_cases(stdout, fixtures, candidate)
            if len(cases) != len(fixtures) or not all(item["agreement"] for item in cases):
                status = "mismatch_or_missing"
        except (ValueError, KeyError, IndexError, TypeError) as error:
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
