"""Offline-only recovery of one known stdout interleaving in attempt 456.

Never launches Lua. Keeps the consumed attempt and raw logs immutable.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from .run_source_probe import parse_cases

HERE = Path(__file__).resolve().parent
PRIOR = HERE.parent / "development455"
ATTEMPT = HERE / "source_attempt_001"
OUT = HERE / "offline_recovery"
MARKER = "PASS tools\\advisor_eval\\development456\\prepared_source_probe.lua\n1/1 fixtures passed\n"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    report_path = ATTEMPT / "report.json"
    stdout_path = ATTEMPT / "stdout.log"
    lease_path = ATTEMPT / "LEASE.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    lease = json.loads(lease_path.read_text(encoding="utf-8"))
    if (report["status"] != "parse_error" or report["returncode"] != 0 or
            report["cases"] or lease["status"] != "consumed_before_worker"):
        raise RuntimeError("Attempt is not the recorded parse failure")
    if report["prepared_manifest_sha256"] != lease["prepared_manifest_sha256"]:
        raise RuntimeError("Attempt manifest mismatch")
    raw = stdout_path.read_text(encoding="utf-8")
    if raw.count(MARKER) != 1:
        raise RuntimeError("Unexpected or missing runner-status interleaving")
    before, after = raw.split(MARKER)
    if not before.endswith("discards_u") or not after.startswith("sed=1|"):
        raise RuntimeError("Interleaving not at the documented field boundary")
    recovered = before + after
    if recovered.count("CASE|") != 6 or recovered.count("FRAME|") != 18:
        raise RuntimeError("Incomplete source output after recovery")

    fixtures = {case["id"]: case for case in json.loads((PRIOR / "fixtures.json").read_text(
        encoding="utf-8"))["cases"]}
    manufactured = json.loads((PRIOR / "MANUFACTURED_COMPARISONS.json").read_text(
        encoding="utf-8"))
    candidate = {item["comparison"]["case_id"]: item["actual"]
                 for item in manufactured["cases"]}
    cases = parse_cases(recovered, fixtures, candidate)
    if len(cases) != 6 or not all(item["agreement"] for item in cases):
        raise RuntimeError("Recovered source comparison did not agree exactly")

    OUT.mkdir(exist_ok=False)
    recovered_path = OUT / "recovered_stdout.log"
    recovered_path.write_text(recovered, encoding="utf-8")
    receipt = {
        "status": "offline_recovered_source_agreement",
        "original_runner_status": report["status"],
        "original_returncode": report["returncode"],
        "source_worker_attempts": 1,
        "additional_source_execution": False,
        "source_attempt_report_sha256": sha(report_path),
        "source_attempt_stdout_sha256": sha(stdout_path),
        "source_attempt_stderr_sha256": sha(ATTEMPT / "stderr.log"),
        "source_attempt_lease_sha256": sha(lease_path),
        "prepared_manifest_sha256": report["prepared_manifest_sha256"],
        "recovery_script_sha256": sha(Path(__file__)),
        "recovered_stdout_sha256": sha(recovered_path),
        "exact_removed_marker": MARKER,
        "repaired_field": "discards_used=1 in heldout_zero_payment_with_carry",
        "cases": cases,
        "limits": [
            "Original runner remains parse_error; recovery is a separate offline derivation.",
            "Source Game:update_shop, stock/tags, RNG and candidate frame timing were not executed or compared.",
        ],
    }
    (OUT / "OFFLINE_RECOVERY.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": receipt["status"], "cases": len(cases),
                      "additional_source_execution": False}, sort_keys=True))


if __name__ == "__main__":
    main()
