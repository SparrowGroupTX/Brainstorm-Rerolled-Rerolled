"""Summarize one explicit, frozen, converted public teacher-event stream.

This reads timing metadata and public phase/ante only. It never calls the
advisor, scorer or game. Missing receipts remain missing, not zero-duration
decisions. The caller must provide the expected input hash and an unused output
path; no directory discovery or overwrite is performed.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys

MAX_INPUT_BYTES = 128 * 1024 * 1024
MAX_LINE_BYTES = 8 * 1024 * 1024
MAX_EVENTS = 100_000
MAX_RECEIPTS = 100_000
HASH = re.compile(r"[0-9a-fA-F]{64}\Z")


class TimingAuditError(ValueError):
    pass


def require(ok: bool, message: str) -> None:
    if not ok:
        raise TimingAuditError(message)


def nonnegative(value: object) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and 0 <= value <= 1e12


def nonnegative_int(value: object) -> bool:
    return type(value) is int and 0 <= value <= 2**53


def quantile(values: list[float | int], percentile: int) -> float | int | None:
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * percentile / 100) - 1)]


def validate_receipt(receipt: object) -> dict:
    require(isinstance(receipt, dict), "Invalid decision receipt")
    require(nonnegative_int(receipt.get("decision_id")) and receipt["decision_id"] > 0,
            "Invalid decision ID")
    require(receipt.get("status") in ("completed", "cancelled", "error"),
            "Invalid decision status")
    require(isinstance(receipt.get("phase"), str) and 0 < len(receipt["phase"]) <= 32,
            "Invalid decision phase")
    for key in ("started_seconds", "finished_seconds", "elapsed_seconds",
                "active_seconds", "max_resume_seconds"):
        require(nonnegative(receipt.get(key)), "Invalid decision " + key)
    require(nonnegative_int(receipt.get("resume_calls")), "Invalid resume count")
    elapsed = receipt["elapsed_seconds"]
    tolerance = max(1e-8, elapsed * 1e-10)
    require(abs(receipt["finished_seconds"] - receipt["started_seconds"] - elapsed) <= tolerance,
            "Inconsistent decision interval")
    require(receipt["active_seconds"] <= elapsed + tolerance and
            receipt["max_resume_seconds"] <= receipt["active_seconds"] + tolerance,
            "Inconsistent active/resume interval")
    if "evaluations" in receipt:
        require(receipt["status"] == "completed" and nonnegative_int(receipt["evaluations"]),
                "Invalid reported evaluations")
    if "action_kind" in receipt:
        require(isinstance(receipt["action_kind"], str) and len(receipt["action_kind"]) <= 32,
                "Invalid action kind")
    return receipt


def add_timing(row: dict, receipt: dict) -> None:
    row.update({
        "phase": receipt["phase"],
        "action_kind": receipt.get("action_kind", row.get("action_kind")),
        "status": receipt["status"],
        "active_seconds": receipt["active_seconds"],
        "elapsed_seconds": receipt["elapsed_seconds"],
        "max_resume_seconds": receipt["max_resume_seconds"],
        "resume_calls": receipt["resume_calls"],
        "evaluations": receipt.get("evaluations"),
    })


def group_summary(rows: list[dict]) -> dict:
    active = [row["active_seconds"] for row in rows]
    elapsed = [row["elapsed_seconds"] for row in rows]
    evaluations = [row["evaluations"] for row in rows if row["evaluations"] is not None]
    return {
        "count": len(rows),
        "status_counts": dict(sorted(Counter(row["status"] for row in rows).items())),
        "active_seconds_sum": sum(active),
        "active_seconds_p50": quantile(active, 50),
        "active_seconds_p95": quantile(active, 95),
        "active_seconds_max": max(active, default=None),
        "elapsed_seconds_sum": sum(elapsed),
        "elapsed_seconds_p95": quantile(elapsed, 95),
        "reported_evaluations_known": len(evaluations),
        "reported_evaluations_unknown": len(rows) - len(evaluations),
        "reported_evaluations_sum_known": sum(evaluations),
        "reported_evaluations_p50_known": quantile(evaluations, 50),
        "reported_evaluations_p95_known": quantile(evaluations, 95),
        "reported_evaluations_max_known": max(evaluations, default=None),
        "resume_calls_sum": sum(row["resume_calls"] for row in rows),
        "max_resume_seconds_max": max((row["max_resume_seconds"] for row in rows), default=None),
    }


def analyze(path: Path, expected_sha256: str) -> dict:
    require(HASH.fullmatch(expected_sha256) is not None, "Expected SHA256 must be 64 hex digits")
    path = Path(path)
    require(path.is_file(), "Input must be one explicit regular file")
    before = path.stat()
    require(before.st_size <= MAX_INPUT_BYTES, "Input byte cap exceeded")
    digest = hashlib.sha256()
    observations: dict[tuple[str, str], dict] = {}
    advice_by_sequence: dict[int, dict] = {}
    requests: list[dict] = []
    sidecar_receipts: list[dict] = []
    started_runs: set[str] = set()
    rows: list[dict] = []
    untimed_current: list[dict] = []
    seen_receipts: set[tuple[str, int]] = set()
    canonical_receipts: dict[tuple[str, int], dict] = {}
    canonical_rows: dict[tuple[str, int], dict] = {}
    seen_anchors: set[tuple[str, int]] = set()
    advice_statuses: Counter[str] = Counter()
    timed_noncurrent = 0
    unmatched_observations = 0
    phase_mismatches = 0
    action_mismatches = 0
    first_at = last_at = None
    first_sequence = None
    previous_sequence = None
    events = 0
    bytes_read = 0

    with path.open("rb") as stream:
        while True:
            raw = stream.readline(MAX_LINE_BYTES + 1)
            if not raw:
                break
            require(len(raw) <= MAX_LINE_BYTES and raw.endswith(b"\n"),
                    "Oversized or incomplete JSONL line")
            bytes_read += len(raw)
            require(bytes_read <= MAX_INPUT_BYTES, "Input byte cap exceeded while reading")
            digest.update(raw)
            events += 1
            require(events <= MAX_EVENTS, "Event cap reached")
            try:
                event = json.loads(raw)
            except (UnicodeError, json.JSONDecodeError) as exc:
                raise TimingAuditError(f"Invalid JSONL at line {events}: {exc}") from exc
            require(isinstance(event, dict), "Invalid public event")
            sequence = event.get("sequence")
            require(type(sequence) is int and sequence > 0 and
                    (previous_sequence is None or sequence == previous_sequence + 1),
                    "Noncontiguous or invalid event sequence")
            previous_sequence = sequence
            if first_sequence is None:
                first_sequence = sequence
            if first_at is None:
                first_at = event.get("at")
            last_at = event.get("at")
            anchor = event.get("anchor")
            if isinstance(anchor, dict) and isinstance(anchor.get("segment"), str) and \
                    type(anchor.get("ordinal")) is int:
                anchor_key = (anchor["segment"], anchor["ordinal"])
                require(anchor_key not in seen_anchors, "Duplicate source event anchor")
                seen_anchors.add(anchor_key)
            kind = event.get("kind")
            collection = event.get("collection_id")
            observation = event.get("observation_id")
            run = event.get("run_instance")
            if kind == "collection_run_start":
                details = event.get("details")
                if isinstance(run, str) and isinstance(details, dict) and details.get("status") == "started":
                    started_runs.add(run)
            if kind != "teacher_advice" and event.get("advice_timing") is not None:
                sidecar_receipts.append({
                    "receipt": event["advice_timing"], "kind": kind,
                    "sequence": sequence, "advice_sequence": event.get("advice_sequence"),
                    "run": run, "collection": collection,
                })
            if kind == "teacher_observation":
                state = event.get("state")
                if (isinstance(collection, str) and isinstance(observation, str) and
                        isinstance(state, dict)):
                    phase = state.get("phase")
                    ante = state.get("ante")
                    observations[(collection, observation)] = {
                        "run": run, "phase": phase if isinstance(phase, str) else None,
                        "ante": ante if type(ante) is int and ante >= 0 else None,
                    }
            elif kind == "teacher_advice":
                advice = event.get("advice")
                require(isinstance(advice, dict), "Invalid teacher advice")
                status = advice.get("status")
                require(isinstance(status, str) and len(status) <= 32,
                        "Invalid advice status")
                advice_statuses[status] += 1
                action = advice.get("action")
                action_kind = action.get("kind") if isinstance(action, dict) else None
                receipt = advice.get("timing")
                advice_by_sequence[sequence] = {"status": status, "timed": receipt is not None,
                                                 "run": run, "collection": collection}
                if receipt is None:
                    if status == "current":
                        public = observations.get((collection, observation))
                        if public is None or public["run"] != run:
                            public = {}
                        review = advice.get("gold_review")
                        review_evaluations = (review.get("shop_evaluations")
                                              if isinstance(review, dict) else None)
                        row = {
                            "sequence": sequence, "run": run,
                            "observation_id": observation, "phase": public.get("phase"),
                            "ante": public.get("ante"), "action_kind": action_kind,
                            "shop_evaluations_diagnostic": review_evaluations
                            if nonnegative_int(review_evaluations) else None,
                            "anchor": {key: anchor.get(key) for key in ("segment", "ordinal", "raw_sha256")
                                       if isinstance(anchor, dict) and key in anchor},
                            "request_sources": [],
                        }
                        untimed_current.append(row)
                        advice_by_sequence[sequence]["row"] = row
                    continue
                require(isinstance(collection, str) and collection and isinstance(run, str),
                        "Timed advice lacks run identity")
                receipt = validate_receipt(receipt)
                require(len(rows) < MAX_RECEIPTS, "Decision receipt cap reached")
                key = (collection, receipt["decision_id"])
                require(key not in seen_receipts, "Duplicate decision receipt")
                seen_receipts.add(key)
                canonical_receipts[key] = receipt
                if status != "current":
                    timed_noncurrent += 1
                if action_kind is not None and receipt.get("action_kind") not in (None, action_kind):
                    action_mismatches += 1
                public = observations.get((collection, observation))
                if public is None or public["run"] != run:
                    unmatched_observations += 1
                    public = {}
                if public.get("phase") is not None and public["phase"] != receipt["phase"]:
                    phase_mismatches += 1
                anchor = anchor or {}
                row = {
                    "sequence": sequence, "run": run, "observation_id": observation,
                    "phase": receipt["phase"], "public_phase": public.get("phase"),
                    "ante": public.get("ante"), "action_kind": receipt.get("action_kind", action_kind),
                    "status": receipt["status"], "advice_status": status,
                    "active_seconds": receipt["active_seconds"],
                    "elapsed_seconds": receipt["elapsed_seconds"],
                    "max_resume_seconds": receipt["max_resume_seconds"],
                    "resume_calls": receipt["resume_calls"],
                    "evaluations": receipt.get("evaluations"),
                    "anchor": {key: anchor.get(key) for key in ("segment", "ordinal", "raw_sha256")
                               if isinstance(anchor, dict) and key in anchor},
                    "request_sources": [],
                    "timing_sources": ["teacher_advice"],
                }
                rows.append(row)
                canonical_rows[key] = row
                advice_by_sequence[sequence]["row"] = row
            elif kind == "action_requested":
                details = event.get("details") or {}
                source = details.get("source") if isinstance(details, dict) else None
                requests.append({"sequence": sequence,
                                 "advice_sequence": event.get("advice_sequence"),
                                 "run": run, "collection": collection,
                                 "source": source if isinstance(source, str) else "unknown"})

        after = os.fstat(stream.fileno())
    require(before.st_size == after.st_size and before.st_mtime_ns == after.st_mtime_ns and
            bytes_read == before.st_size, "Input changed while reading")
    actual_hash = digest.hexdigest()
    require(actual_hash == expected_sha256.lower(), "Input SHA256 does not match expected frozen bytes")

    identical_receipt_copies = 0
    orphan_sidecar_receipts = 0
    receipt_sources = Counter({"teacher_advice": len(rows)})
    for sidecar in sidecar_receipts:
        receipt = validate_receipt(sidecar["receipt"])
        receipt_sources[sidecar["kind"]] += 1
        collection = sidecar["collection"]
        link = sidecar["advice_sequence"]
        require(type(link) is int and 0 < link < sidecar["sequence"],
                "Forward or invalid timing advice link")
        advice = advice_by_sequence.get(sidecar["advice_sequence"])
        if (not isinstance(collection, str) or not isinstance(sidecar["run"], str) or
                advice is None or advice["collection"] != collection or
                advice["run"] != sidecar["run"] or "row" not in advice):
            orphan_sidecar_receipts += 1
            continue
        key = (collection, receipt["decision_id"])
        if key in canonical_receipts:
            require(canonical_receipts[key] == receipt, "Conflicting copies of decision receipt")
            identical_receipt_copies += 1
            row = canonical_rows[key]
            require(advice["row"] is row,
                    "Decision receipt linked to multiple current advice rows")
        else:
            require(len(rows) < MAX_RECEIPTS, "Decision receipt cap reached")
            row = advice["row"]
            require(row in untimed_current, "Sidecar receipt lacks untimed current advice")
            untimed_current.remove(row)
            public = observations.get((collection, row["observation_id"]))
            if public is None or public["run"] != row["run"]:
                unmatched_observations += 1
                public = {}
            public_phase = public.get("phase")
            if public_phase is not None and public_phase != receipt["phase"]:
                phase_mismatches += 1
            if row["action_kind"] is not None and receipt.get("action_kind") not in (
                    None, row["action_kind"]):
                action_mismatches += 1
            add_timing(row, receipt)
            row["advice_status"] = advice["status"]
            row["public_phase"] = public_phase
            row["timing_sources"] = []
            rows.append(row)
            seen_receipts.add(key)
            canonical_receipts[key] = receipt
            canonical_rows[key] = row
        if sidecar["kind"] not in row["timing_sources"]:
            row["timing_sources"].append(sidecar["kind"])

    request_statuses: dict[str, Counter[str]] = defaultdict(Counter)
    unmatched_requests = 0
    for request in requests:
        advice = advice_by_sequence.get(request["advice_sequence"])
        if (advice is None or advice["run"] != request["run"] or
                advice["collection"] != request["collection"]):
            unmatched_requests += 1
            continue
        request_statuses[request["source"]][advice["status"]] += 1
        if "row" in advice:
            advice["row"]["request_sources"].append(request["source"])

    by_phase: dict[str, list[dict]] = defaultdict(list)
    by_action: dict[str, list[dict]] = defaultdict(list)
    by_ante: dict[str, list[dict]] = defaultdict(list)
    auto_requested = [row for row in rows if "auto_run" in row["request_sources"]]
    for row in rows:
        by_phase[row["phase"]].append(row)
        by_action[row["action_kind"] or "unknown"].append(row)
        by_ante[str(row["ante"]) if row["ante"] is not None else "unknown"].append(row)
    top = sorted(rows, key=lambda row: (-row["active_seconds"], row["sequence"]))[:16]
    return {
        "schema": 1,
        "input": {"path": str(path), "sha256": actual_hash, "bytes": bytes_read,
                  "events": events, "first_sequence": first_sequence,
                  "last_sequence": previous_sequence, "first_at": first_at, "last_at": last_at},
        "coverage": {
            "advice_total": sum(advice_statuses.values()),
            "advice_statuses": dict(sorted(advice_statuses.items())),
            "timed_receipts": len(rows),
            "current_without_timing_after_sidecar_join": len(untimed_current),
            "receipt_representations_by_event_kind": dict(sorted(receipt_sources.items())),
            "identical_sidecar_receipt_copies": identical_receipt_copies,
            "orphan_sidecar_receipts": orphan_sidecar_receipts,
            "timed_noncurrent": timed_noncurrent,
            "timed_unmatched_public_observation": unmatched_observations,
            "timed_phase_mismatches": phase_mismatches,
            "timed_action_mismatches": action_mismatches,
            "action_requests": len(requests),
            "collection_started_run_instances": len(started_runs),
            "timed_receipts_in_started_runs": sum(row["run"] in started_runs for row in rows),
            "action_requests_unmatched_advice": unmatched_requests,
            "action_request_linked_advice_status_by_source": {
                source: dict(sorted(counts.items())) for source, counts in sorted(request_statuses.items())},
            "timed_receipts_requested_by_auto_run": sum(
                "auto_run" in row["request_sources"] for row in rows),
            "untimed_current_requested_by_auto_run": sum(
                "auto_run" in row["request_sources"] for row in untimed_current),
        },
        "untimed_current": {
            "count": len(untimed_current),
            "by_public_phase": dict(sorted(Counter(
                row["phase"] or "unknown" for row in untimed_current).items())),
            "by_action": dict(sorted(Counter(
                row["action_kind"] or "unknown" for row in untimed_current).items())),
            "shop_evaluations_diagnostic_known": sum(
                row["shop_evaluations_diagnostic"] is not None for row in untimed_current),
            "shop_evaluations_diagnostic_sum_known": sum(
                row["shop_evaluations_diagnostic"] or 0 for row in untimed_current),
            "examples": sorted(untimed_current, key=lambda row: (
                -(row["shop_evaluations_diagnostic"] or 0), row["sequence"]))[:12],
        },
        "all_timed": group_summary(rows),
        "auto_run_requested_timed": group_summary(auto_requested),
        "by_phase": {key: group_summary(value) for key, value in sorted(by_phase.items())},
        "by_action": {key: group_summary(value) for key, value in sorted(by_action.items())},
        "by_public_ante": {key: group_summary(value) for key, value in sorted(by_ante.items())},
        "slowest_active_receipts": top,
        "interpretation": [
            "Active seconds sum measured decision-resume wall intervals; they are not CPU usage or total game time.",
            "Elapsed seconds include waits between resumes; nested and overlapping work must not be inferred from sums.",
            "Reported evaluations are policy work counters, not a uniform per-call cost or a count of all game work.",
            "Advice timing can be omitted from a deduplicated current-advice event and carried on later linked events; identical sidecar copies count once.",
            "Untimed shop evaluation diagnostics have a different scope and must not be added to receipt evaluation totals.",
            "Advice is a recommendation; request linkage does not prove settled execution or an optimal action.",
            "Missing receipt, public observation, or evaluation telemetry is unknown, never zero.",
            "This supplied frozen public cohort is selected; timing is not a benchmark across versions or machines.",
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--events", type=Path, required=True, help="Explicit frozen converted JSONL file")
    parser.add_argument("--expected-sha256", required=True, help="SHA256 of the exact input file")
    parser.add_argument("--out", type=Path, required=True, help="Unused output JSON path")
    args = parser.parse_args(argv)
    try:
        result = analyze(args.events, args.expected_sha256)
        with args.out.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(result, stream, indent=2, sort_keys=True, allow_nan=False)
            stream.write("\n")
    except (OSError, TimingAuditError) as exc:
        print(f"timing audit failed: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
