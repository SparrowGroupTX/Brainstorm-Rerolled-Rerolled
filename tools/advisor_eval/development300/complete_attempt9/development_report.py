"""Bounded hidden development batches and failure/latency reports; no qualification."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import time


def parse_trace(path):
    """Retain valid flushed records even if a timeout truncates the last line."""
    rows, errors = [], []
    for number, line in enumerate(Path(path).read_text(encoding="utf-8-sig", errors="replace").splitlines(), 1):
        if not line.lstrip().startswith("{"):
            continue
        try:
            value = json.loads(line)
            if not isinstance(value, dict) or not isinstance(value.get("type"), str):
                raise ValueError("Missing trace type")
            rows.append(value)
        except (ValueError, TypeError) as error:
            errors.append({"line": number, "reason": str(error)})
    return rows, errors


def classify(rows, exit_code, parse_errors=()):
    """Process errors take precedence over partial or contradictory terminal data."""
    terminals = [row for row in rows if row.get("type") == "engine_episode_terminal"]
    blocked = next((row for row in rows if row.get("type") == "engine_probe_blocked"), None)
    stops = [row for row in rows if row.get("type") == "engine_episode_stopped"]
    stopped = stops[0] if stops else None
    if exit_code == "timeout":
        return "timeout", "wall_clock_limit"
    if parse_errors:
        return "error", "malformed_trace"
    if len(terminals) > 1:
        return "error", "multiple_terminal_records"
    if blocked:
        reason = str(blocked.get("reason", "unknown_engine_error"))
        defects = ("score disagreement", "policy action rejected", "did not copy", "coordinates disagree")
        return ("unsupported" if "HEADLESS_BOUNDARY" in reason and not any(x in reason for x in defects)
                else "error"), reason
    if exit_code != 0:
        return "error", "process_exit_" + str(exit_code)
    if len(stops) > 1 or terminals and stopped:
        return "error", "contradictory_terminal_or_stop_records"
    if terminals:
        terminal = terminals[0]
        if not all(key in terminal for key in ('source_profile_completed', 'source_game_won', 'game_over')):
            return "unsupported", "terminal_source_evidence_missing"
        if any(type(terminal[key]) is not bool for key in ('source_profile_completed', 'source_game_won', 'game_over')):
            return "error", "invalid_terminal_source_evidence"
        if (terminal.get("outcome") == "loss" and terminal.get("game_won") is False
                and terminal.get('game_over') is True):
            return "loss", "game_over"
        if (terminal.get("outcome") == "win" and terminal.get("game_won") is True
                and terminal.get('source_profile_completed') is True and terminal.get('source_game_won') is True
                and terminal.get('game_over') is False
                and type(terminal.get("ante")) in (int, float) and math.isfinite(terminal['ante']) and terminal["ante"] >= 8):
            return "win", "source_completion"
        return "error", "invalid_terminal_record"
    if stopped and str(stopped.get("reason", "")).startswith("development_"):
        return "censored", stopped["reason"]
    return "error", "missing_terminal_or_development_stop"


def score_coverage(rows):
    """A source outcome and its prediction parity have separate coverage claims."""
    plays = [r for r in rows if r.get('type') == 'engine_episode_action' and r.get('action', {}).get('kind') == 'play']
    verified = [r for r in rows if r.get('type') == 'engine_episode_score_verified']
    gaps = [r for r in rows if r.get('type') == 'engine_episode_score_unverified']
    checked = {r.get('step') for r in verified + gaps}
    missing = [r.get('step') for r in plays if r.get('step') not in checked]
    counts = Counter(r.get('step') for r in verified + gaps)
    duplicates = [step for step, count in counts.items() if count > 1]
    play_steps = {r.get('step') for r in plays}
    unmatched = [r.get('step') for r in verified + gaps if r.get('step') not in play_steps]
    invalid_scopes = [r.get('step') for r in verified if r.get('scope') not in ('deterministic_score', 'supported_random_floor')]
    return {'played_actions': len(plays), 'verified_scores': len(verified), 'explicit_unverified_scores': len(gaps),
            'missing_verification_steps': missing, 'verification_scopes': dict(Counter(r.get('scope') for r in verified)),
            'duplicate_verification_steps': duplicates, 'unmatched_verification_steps': unmatched,
            'invalid_verification_scope_steps': invalid_scopes,
            'complete_exact_or_floor_coverage': bool(plays) and not gaps and not missing and not duplicates
                and not unmatched and not invalid_scopes and len(verified) == len(plays),
            'interpretation': 'Random or unsupported predictions are explicit gaps, not score-parity successes'}


def distribution(values):
    values = sorted(v for v in values if isinstance(v, (int, float)) and math.isfinite(v) and v >= 0)
    if not values:
        return {"count": 0, "total": 0, "mean": None, "p50": None, "p95": None, "p99": None, "max": None}
    def percentile(p):
        return values[max(0, math.ceil(p * len(values)) - 1)]
    return {"count": len(values), "total": sum(values), "mean": sum(values) / len(values),
            "p50": percentile(.5), "p95": percentile(.95), "p99": percentile(.99), "max": values[-1]}


def loss_analysis(rows, outcome, reason):
    """Observed symptoms and replay entry points, never asserted policy causation."""
    context = next((r for r in reversed(rows) if r.get('type') in (
        'engine_episode_terminal_context', 'engine_episode_failure_context',
        'engine_episode_score_mismatch', 'engine_episode_illegal_action')), {})
    starts = [r for r in rows if r.get('type') == 'engine_episode_decision_started']
    profiles = {r['step'] for r in rows if r.get('type') == 'engine_episode_profile'}
    pending = starts[-1] if starts and starts[-1]['step'] not in profiles else None
    # A hard worker timeout cannot run the Lua error exporter. The flushed
    # pre-decision observation preserves the actual expensive input without
    # fabricating an action or replaying an exhausted attempt.
    if outcome == 'timeout' and pending and pending.get('snapshot'):
        context = {'type': pending['type'], 'snapshot': pending['snapshot'],
                   'last_decision': {'step': pending['step'], 'snapshot': pending['snapshot']}}
    decision = context.get('last_decision') or context.get('decision') or {}
    current = context.get('snapshot') or decision.get('snapshot') or {}
    previous = decision.get('snapshot') or current
    actions = [r for r in rows if r.get('type') == 'engine_episode_action']
    last = actions[-1] if actions else {}
    groups = []
    if outcome == 'loss' and current:
        blind = current.get('blind', {})
        deficit = max(0, blind.get('chips', 0) - current.get('chips', 0))
        if deficit:
            groups.append('insufficient_blind_score')
        if 'hands_left' in current and current['hands_left'] <= 0:
            groups.append('hands_exhausted')
        if previous.get('discards_left', 0) > 0:
            groups.append('discards_remaining_at_last_play')
        if current.get('consumeables'):
            groups.append('consumables_unspent')
        cards = current.get('playing_cards', [])
        usable = sum(not c.get('debuff') and not c.get('ability', {}).get('perma_debuff') for c in cards)
        if cards and usable < max(5, current.get('hand_size', 8)):
            groups.append('low_usable_population')
        if blind.get('boss') and not blind.get('disabled'):
            groups.append('active_boss_at_loss')
    else:
        deficit, usable = None, None
        if outcome == 'loss':
            groups.append('terminal_loss_context_missing')
        elif outcome == 'timeout':
            groups.append('decision_latency_timeout' if pending else 'source_transition_timeout')
        elif outcome == 'unsupported':
            groups.append('adapter_coverage_gap')
        elif outcome == 'error':
            groups.append('score_parity_defect' if 'score disagreement' in reason else
                          'action_legality_defect' if 'policy action rejected' in reason else 'adapter_or_policy_error')
    return {'groups': groups, 'interpretation': 'Observed symptoms only; causal claims require replay comparisons',
            'last_step': decision.get('step', last.get('step')),
            'last_action': None if outcome == 'timeout' and pending else decision.get('action', last.get('action')),
            'ante': current.get('ante', last.get('ante')), 'phase': previous.get('phase', last.get('phase')),
            'blind_key': current.get('blind', {}).get('key', last.get('blind')),
            'remaining_score_deficit': deficit, 'usable_cards': usable,
            'snapshot': current or None, 'pre_action_snapshot': previous or None,
            'context_trace_type': context.get('type')}


def episode_record(path, challenge, seed, exit_code, elapsed_seconds, command):
    rows, parse_errors = parse_trace(path)
    outcome, reason = classify(rows, exit_code, parse_errors)
    def first(kind):
        return next((row for row in rows if row.get("type") == kind), None)
    actions = [row for row in rows if row.get("type") == "engine_episode_action"]
    profiles = [row for row in rows if row.get("type") == "engine_episode_profile"]
    resolved = [row for row in rows if row.get("type") == "engine_episode_resolved"]
    started = [row for row in rows if row.get("type") == "engine_episode_decision_started"]
    provenance = first("engine_probe_provenance") or {}
    mismatched = any(provenance.get(key) != value for key, value in (("challenge", challenge), ("seed", seed)))
    if provenance and mismatched:
        outcome, reason = "error", "trace_request_mismatch"
    if not provenance and outcome in ("win", "loss", "censored"):
        outcome, reason = "error", "missing_provenance"
    diagnostics = Counter(row["type"] for row in rows if row.get("type") in (
        "engine_episode_score_mismatch", "engine_episode_illegal_action"))
    if diagnostics and outcome in ("win", "loss", "censored"):
        outcome, reason = "error", "engine_policy_disagreement"
    timings = {"advisor_seconds": distribution(row.get("advisor_seconds") for row in profiles),
               "snapshot_seconds": distribution(row.get("snapshot_seconds") for row in profiles),
               "engine_seconds": distribution(row.get("engine_seconds") for row in resolved),
               "score_calls": distribution(row.get("score_calls") for row in profiles)}
    return {"type": "engine_development_result", "qualification": False,
            "challenge": challenge, "seed": seed, "exit_code": exit_code,
            "outcome": outcome, "reason": reason, "elapsed_seconds": elapsed_seconds,
            "terminal": first("engine_episode_terminal"), "error": first("engine_probe_blocked"),
            "trace": str(Path(path).resolve()), "trace_digest": hashlib.sha256(Path(path).read_bytes()).hexdigest(),
            "command": command, "provenance": provenance, "parse_errors": parse_errors,
            "unlock_profile": first("engine_probe_profile"), "startup": first("engine_probe_startup"),
            "timing": first("engine_probe_timing"), "decision_metrics": timings,
            "profiles": profiles, "actions": dict(Counter(row.get("action", {}).get("kind", "unknown") for row in actions)),
            "diagnostics": dict(diagnostics), "resolved_actions": len(resolved),
            "score_verification": score_coverage(rows),
            "loss_analysis": loss_analysis(rows, outcome, reason),
            "last_action": actions[-1] if actions else None,
            "unfinished_decision": started[-1] if started and started[-1]["step"] not in {p["step"] for p in profiles} else None}


def summarize(records):
    """Every attempt remains in its challenge AND policy/start cohort denominator."""
    cohorts = {}
    for record in records:
        provenance = record.get("provenance", {})
        key = (record["challenge"], provenance.get("policy_digest"),
               json.dumps(provenance.get("start_distribution"), sort_keys=True),
               provenance.get("rules_digest"), provenance.get("runtime_digest"), provenance.get("adapter_digest"),
               provenance.get('profile_spec_digest'), (record.get('unlock_profile') or {}).get('unlock_profile_digest'))
        cohorts.setdefault(key, []).append(record)
    summaries = []
    for (challenge, policy, start, rules, runtime, adapter, profile_spec, profile_flags), members in sorted(cohorts.items(), key=lambda item: str(item[0])):
        outcomes = Counter(row["outcome"] for row in members)
        profiles = [profile for row in members for profile in row.get("profiles", [])]
        failure_examples = {}
        for row in members:
            if row["outcome"] not in ("win", "censored"):
                failure_examples.setdefault(row["reason"], {"outcome": row["outcome"], "seed": row["seed"],
                                                          "trace": row["trace"], "command": row["command"],
                                                          "groups": row.get('loss_analysis', {}).get('groups', []),
                                                          "step": row.get('loss_analysis', {}).get('last_step')})
        summaries.append({"challenge": challenge, "policy_digest": policy, "start_distribution": json.loads(start),
                          "rules_digest": rules, "runtime_digest": runtime, "adapter_digest": adapter,
                          "profile_spec_digest": profile_spec, "unlock_profile_digest": profile_flags,
                          "attempted": len(members), "outcomes": dict(outcomes),
                          "complete_episodes": outcomes["win"] + outcomes["loss"],
                          "observed_complete_win_rate": outcomes["win"] / len(members)
                          if outcomes["win"] + outcomes["loss"] == len(members) else None,
                          "attempt_seconds": distribution(row["elapsed_seconds"] for row in members),
                          "startup_seconds": distribution((row.get("startup") or {}).get("startup_seconds") for row in members),
                          "engine_seconds_per_attempt": distribution(row.get("decision_metrics", {}).get("engine_seconds", {}).get("total") for row in members),
                          "snapshot_seconds_per_attempt": distribution(row.get("decision_metrics", {}).get("snapshot_seconds", {}).get("total") for row in members),
                          "advisor_seconds": distribution(row.get("advisor_seconds") for row in profiles),
                          "score_calls": distribution(row.get("score_calls") for row in profiles),
                          "reason_counts": dict(Counter(row["reason"] for row in members)),
                          "loss_group_counts": dict(Counter(group for row in members for group in row.get('loss_analysis', {}).get('groups', []))),
                          "failure_examples": failure_examples})
    return {"schema": 1, "qualification": False, "development_seeds": True,
            "reporter_digest": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            "attempted": len(records), "outcomes": dict(Counter(row["outcome"] for row in records)),
            "cohorts": summaries, "user_completion_time_estimate": None,
            "timing_scope": "Hidden source-engine wall clock; no live frame, animation or user-click timing",
            "limitations": ["Experimental adapter and synthetic unlock profile; no qualified win-rate evidence",
                            "Filtered-opening policy is not executed; product hashes record dependencies only",
                            "Censored/timeout batches cannot estimate full-run win rates or time to success",
                            "Failure reasons locate observed defects; they do not assign strategic loss causation"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", nargs="+", default=["ADVISOR2", "ADVISOR3"])
    parser.add_argument("--challenge", default="c_omelette_1")
    parser.add_argument("--challenges", nargs="+", help="Optional challenge IDs for a sequential stratified batch")
    parser.add_argument("--timeout", type=float, default=45)
    parser.add_argument("--stop-after-step", type=int, default=40)
    parser.add_argument("--full-episode", action="store_true", help="Omit the development action cutoff; wall-clock and adapter caps still apply")
    parser.add_argument("--label", default="", help="Alphanumeric label; an existing output directory is never overwritten")
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--policy-root", type=Path, help="Stable repository or frozen product root")
    args = parser.parse_args()
    challenges = args.challenges or [args.challenge]
    if not 0 < args.timeout <= 300 or not 1 <= args.stop_after_step <= 500:
        parser.error("Use a finite 0..300 second timeout and 1..500 action limit")
    if len(challenges) * len(args.seeds) > 100:
        parser.error("Development batches are limited to 100 requested episodes")
    if args.label and not args.label.isalnum():
        parser.error("Use an alphanumeric label")
    if any(not seed.isalnum() for seed in args.seeds) or any(not challenge.replace("_", "").isalnum() for challenge in challenges):
        parser.error("Use alphanumeric seeds and challenge IDs")
    label = args.label or datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    directory = args.output_dir or Path(__file__).with_name("runs") / ("development_" + label)
    directory.mkdir(parents=True, exist_ok=False)
    requests = [{"challenge": challenge, "seed": seed} for challenge in challenges for seed in args.seeds]
    (directory / "manifest.json").write_text(json.dumps({"schema": 1, "qualification": False,
        "collector_digest": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "timeout_seconds": args.timeout, "action_limit": None if args.full_episode else args.stop_after_step, "episodes": requests}, indent=2) + "\n", encoding="utf-8")
    records = []
    for index, request in enumerate(requests):
        target = directory / f"{index:03d}_{request['challenge']}_{request['seed']}.log"
        command = [sys.executable, "-u", str(Path(__file__).with_name("engine_probe.py")), "--episode",
                   "--challenge", request["challenge"], "--seed", request["seed"]]
        if not args.full_episode:
            command += ["--stop-after-step", str(args.stop_after_step)]
        if args.policy_root:
            command += ["--policy-root", str(args.policy_root.resolve())]
        started = time.perf_counter()
        with target.open("x", encoding="utf-8") as output:
            try:
                process = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=args.timeout,
                                         creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
                exit_code = process.returncode
            except subprocess.TimeoutExpired:
                exit_code = "timeout"
            except OSError as error:
                exit_code = "launch_error"
                output.write(str(error) + "\n")
        record = episode_record(target, request["challenge"], request["seed"], exit_code,
                                time.perf_counter() - started, command)
        records.append(record)
        analysis = record.get('loss_analysis', {})
        if record['outcome'] in ('loss', 'error', 'unsupported') and analysis.get('snapshot'):
            artifact = target.with_suffix('.failure.json')
            artifact.write_text(json.dumps({'qualification': False, 'trace': record['trace'], 'trace_digest': record['trace_digest'],
                'outcome': record['outcome'], 'reason': record['reason'], 'analysis': analysis}, indent=2) + '\n', encoding='utf-8')
            record['failure_snapshot'] = str(artifact.resolve())
        with (directory / "episodes.jsonl").open("a", encoding="utf-8") as output:
            output.write(json.dumps(record) + "\n")
        print(json.dumps({key: record[key] for key in ("challenge", "seed", "outcome", "reason", "elapsed_seconds", "trace")}), flush=True)
        report = summarize(records)
        report["requested"] = len(requests)
        report["not_attempted"] = len(requests) - len(records)
        (directory / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"report": str((directory / "report.json").resolve()), "outcomes": report["outcomes"]}), flush=True)
    return 2 if any(row["outcome"] in ("error", "unsupported", "timeout") for row in records) else 0


if __name__ == "__main__":
    raise SystemExit(main())
