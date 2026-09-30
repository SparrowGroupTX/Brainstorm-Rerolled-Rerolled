"""Read-only wall-time bounds from one explicit frozen public teacher JSONL.

Decision receipts measure active coroutine resumes and full elapsed intervals.
Action callback to first settled observation is a separate visible interval,
not a measurement of animation or final effect completion. Neither category
identifies CPU utilization or attributes all remaining run time.
"""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
import sys

MAX_BYTES = 128 * 1024 * 1024
MAX_EVENTS = 100_000
MAX_LINE = 8 * 1024 * 1024


def valid_number(value):
    return type(value) in (int, float) and math.isfinite(value) and value >= 0


def require(ok, why):
    if not ok:
        raise ValueError(why)


def merged(intervals):
    result = []
    for start, end in sorted(intervals):
        require(valid_number(start) and valid_number(end) and end >= start,
                "Invalid interval")
        if result and start <= result[-1][1]:
            result[-1][1] = max(result[-1][1], end)
        else:
            result.append([start, end])
    return result


def length(intervals):
    return sum(end - start for start, end in intervals)


def intersection_length(a, b):
    left, right, total = 0, 0, 0.0
    while left < len(a) and right < len(b):
        total += max(0, min(a[left][1], b[right][1]) - max(a[left][0], b[right][0]))
        if a[left][1] <= b[right][1]:
            left += 1
        else:
            right += 1
    return total


def quantile(values, percent):
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(len(ordered) * percent / 100) - 1)]


def summarize(values):
    return {"count": len(values), "sum_seconds": sum(values),
            "p50_seconds": quantile(values, 50), "p95_seconds": quantile(values, 95),
            "max_seconds": max(values, default=None)}


def analyze(path, expected_sha256):
    path = Path(path)
    require(len(expected_sha256) == 64 and all(c in "0123456789abcdefABCDEF" for c in expected_sha256),
            "Invalid expected SHA256")
    require(path.is_file() and path.stat().st_size <= MAX_BYTES,
            "Input must be one explicit bounded file")
    before = path.stat()
    digest = hashlib.sha256()
    run_starts, run_ends, actions, callbacks, settles = {}, {}, {}, {}, {}
    search = []
    kinds = Counter()
    seen_decisions = set()
    events = 0
    prior_sequence = None
    last_time = None
    with path.open("rb") as stream:
        while True:
            raw = stream.readline(MAX_LINE + 1)
            if not raw:
                break
            require(len(raw) <= MAX_LINE and raw.endswith(b"\n"),
                    "Oversized or incomplete JSONL line")
            digest.update(raw)
            events += 1
            require(events <= MAX_EVENTS, "Event cap reached")
            event = json.loads(raw)
            seq, kind, stamp = event.get("sequence"), event.get("kind"), event.get("monotonic_seconds")
            require(type(seq) is int and seq > 0 and (prior_sequence is None or seq == prior_sequence + 1),
                    "Noncontiguous event sequence")
            require(valid_number(stamp) and (last_time is None or stamp >= last_time),
                    "Missing or regressed event clock")
            prior_sequence, last_time = seq, stamp
            kinds[kind] += 1
            run = event.get("run_instance")
            details = event.get("details") or {}
            if kind == "collection_run_start" and details.get("status") == "started":
                require(isinstance(run, str) and run not in run_starts, "Duplicate or invalid run start")
                run_starts[run] = stamp
            elif kind == "auto_run" and details.get("event") == "run_finished":
                require(isinstance(run, str) and run not in run_ends, "Duplicate or invalid run finish")
                run_ends[run] = {"stamp": stamp, "reported_run_seconds": details.get("run_seconds")}
            elif kind == "collection_search_finished":
                receipt = details.get("receipt") or {}
                search.append({"status": details.get("status"),
                               "elapsed_wall_seconds": receipt.get("elapsed_wall_seconds")})
            elif kind == "action_requested" and details.get("source") == "auto_run":
                receipt = event.get("advice_timing")
                require(isinstance(run, str) and isinstance(receipt, dict),
                        "Auto-run action lacks timed advice")
                start, finish, active = (receipt.get("started_seconds"),
                                         receipt.get("finished_seconds"),
                                         receipt.get("active_seconds"))
                elapsed = receipt.get("elapsed_seconds")
                decision_id = receipt.get("decision_id")
                require(valid_number(start) and valid_number(finish) and
                        valid_number(active) and valid_number(elapsed) and
                        type(decision_id) is int and decision_id > 0 and
                        receipt.get("status") == "completed" and
                        start <= finish <= stamp + 1e-6 and
                        abs(finish - start - elapsed) <= max(1e-8, elapsed * 1e-10) and
                        active <= elapsed + 1e-6,
                        "Invalid action decision timing")
                require((run, decision_id) not in seen_decisions,
                        "Duplicate action decision receipt")
                seen_decisions.add((run, decision_id))
                require(seq not in actions, "Duplicate action sequence")
                payload = details.get("input")
                payload_action = payload.get("action") if isinstance(payload, dict) else None
                action_kind = (payload_action.get("kind") if isinstance(payload_action, dict)
                               else None)
                actions[seq] = {"run": run, "requested": stamp, "decision": (start, finish),
                                "active_seconds": active,
                                "phase": receipt.get("phase") if isinstance(receipt.get("phase"), str)
                                else "unknown",
                                "action_kind": action_kind if isinstance(action_kind, str)
                                else "unknown"}
            elif kind == "action_callback_result":
                action_seq = details.get("action_sequence")
                require(type(action_seq) is int and action_seq not in callbacks,
                        "Duplicate or invalid action callback")
                callbacks[action_seq] = stamp
            elif kind == "state_after_actions":
                for action_seq in details.get("action_sequences") or []:
                    require(type(action_seq) is int, "Invalid settled action sequence")
                    settles.setdefault(action_seq, stamp)
        after = path.stat()
    require(before.st_size == after.st_size and before.st_mtime_ns == after.st_mtime_ns,
            "Input changed while reading")
    actual = digest.hexdigest()
    require(actual == expected_sha256.lower(), "Input hash mismatch")
    require(set(run_starts) == set(run_ends), "Run start/finish mismatch")

    grouped = defaultdict(list)
    for seq, action in actions.items():
        grouped[action["run"]].append((seq, action))
    runs = []
    callback_gaps, settle_gaps, request_to_settle = [], [], []
    action_groups = defaultdict(lambda: {"active": [], "elapsed": [],
                                         "settled": [], "settled_outside_decision": []})
    missing_callbacks = missing_settles = 0
    for run, start in run_starts.items():
        finish = run_ends[run]["stamp"]
        require(finish >= start, "Run finish precedes start")
        actions_here = grouped[run]
        decision_intervals = []
        settle_intervals = []
        settle_intervals_by_kind = []
        active = 0.0
        for seq, action in actions_here:
            begin, end = action["decision"]
            require(start <= begin <= end <= finish, "Decision outside its recorded run")
            decision_intervals.append((begin, end))
            active += action["active_seconds"]
            group = action_groups[action["action_kind"]]
            group["active"].append(action["active_seconds"])
            group["elapsed"].append(end - begin)
            callback = callbacks.get(seq)
            settled = settles.get(seq)
            if callback is None:
                missing_callbacks += 1
            else:
                require(action["requested"] <= callback <= finish, "Callback outside action/run")
                callback_gaps.append(callback - action["requested"])
            if settled is None:
                missing_settles += 1
            elif callback is not None:
                require(callback <= settled <= finish, "First settlement outside callback/run")
                settle_gaps.append(settled - callback)
                group["settled"].append(settled - callback)
                request_to_settle.append(settled - action["requested"])
                settle_intervals.append((callback, settled))
                settle_intervals_by_kind.append((action["action_kind"], callback, settled))
        decision_union = merged(decision_intervals)
        settle_union = merged(settle_intervals)
        for action_kind, callback, settled in settle_intervals_by_kind:
            overlap_here = intersection_length(decision_union, [[callback, settled]])
            action_groups[action_kind]["settled_outside_decision"].append(
                settled - callback - overlap_here)
        decision_elapsed = length(decision_union)
        settlement_span = length(settle_union)
        settlement_overlap = sum(end - begin for begin, end in settle_intervals) - settlement_span
        overlap = intersection_length(decision_union, settle_union)
        run_wall = finish - start
        require(active <= decision_elapsed + 1e-4 and
                decision_elapsed + settlement_span - overlap <= run_wall + 1e-4,
                "Interval decomposition inconsistent")
        reported = run_ends[run]["reported_run_seconds"]
        runs.append({"run_instance": run, "actions": len(actions_here),
                     "run_wall_seconds": run_wall, "reported_run_seconds": reported,
                     "decision_active_seconds": active,
                     "decision_elapsed_union_seconds": decision_elapsed,
                     "decision_wait_between_resumes_seconds": decision_elapsed - active,
                     "callback_to_first_settled_union_seconds": settlement_span,
                     "callback_to_settled_inter_action_overlap_seconds": settlement_overlap,
                     "callback_to_settled_overlap_with_decision_seconds": overlap,
                     "outside_decision_and_callback_to_settled_seconds":
                     run_wall - decision_elapsed - settlement_span + overlap})

    fields = ("run_wall_seconds", "decision_active_seconds", "decision_elapsed_union_seconds",
              "decision_wait_between_resumes_seconds", "callback_to_first_settled_union_seconds",
              "callback_to_settled_inter_action_overlap_seconds",
              "callback_to_settled_overlap_with_decision_seconds",
              "outside_decision_and_callback_to_settled_seconds")
    totals = {field: sum(row[field] for row in runs) for field in fields}
    search_times = [item["elapsed_wall_seconds"] for item in search
                    if valid_number(item["elapsed_wall_seconds"])]
    return {"schema": 1,
            "input": {"path": str(path), "sha256": actual, "bytes": before.st_size,
                      "events": events, "last_sequence": prior_sequence},
            "coverage": {"started_runs": len(run_starts), "finished_runs": len(run_ends),
                         "auto_run_actions": len(actions),
                         "missing_action_callbacks": missing_callbacks,
                         "missing_first_settled_observations": missing_settles,
                         "performance_windows": kinds["performance_window"]},
            "totals": totals, "runs": runs,
            "action_request_to_callback": summarize(callback_gaps),
            "callback_to_first_settled": summarize(settle_gaps),
            "action_request_to_first_settled": summarize(request_to_settle),
            "by_action_kind": {kind: {"decision_active": summarize(group["active"]),
                                     "decision_elapsed": summarize(group["elapsed"]),
                                     "callback_to_first_settled": summarize(group["settled"]),
                                     "callback_to_settled_outside_decision":
                                     summarize(group["settled_outside_decision"])}
                               for kind, group in sorted(action_groups.items())},
            "public_search_finished": {"count": len(search),
                                       "status_counts": dict(Counter(item["status"] for item in search)),
                                       "elapsed_known": summarize(search_times)},
            "interpretation": [
                "All sums are elapsed monotonic wall time, not CPU utilization.",
                "Decision active time measures only resume spans; elapsed minus active includes yields, frame scheduling and other interleaved work, not identified animation time.",
                "Callback return is not effect completion; the first settled public observation may precede later queued effects.",
                "Callback-to-first-settled intervals may include game updates, animation, advisor refresh, logging and other work; they are not an animation timer.",
                "Action-kind settlement sums are additive only when inter-action settlement overlap is zero.",
                "Outside both recorded intervals is residual time, not an identified component.",
                "Zero performance_window events prevent direct frame/update/draw/journal attribution in this cohort.",
            ]}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--events", required=True, type=Path)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        result = analyze(args.events, args.expected_sha256)
        with args.out.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(result, stream, indent=2, sort_keys=True, allow_nan=False)
            stream.write("\n")
    except (OSError, ValueError) as exc:
        print(f"wall-time audit failed: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
