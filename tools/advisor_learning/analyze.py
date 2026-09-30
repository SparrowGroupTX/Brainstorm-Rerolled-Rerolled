"""Read-only analysis of completed frozen simulator-evaluation artifacts.

No simulator, model, optimizer, GPU, or player data is imported. Reported bounds
describe this finite sample's unresolved outcomes; they are not confidence
intervals or retail-game success probabilities. Writing analysis.json/md is
permitted only after the owning experiment's receipt is completed successfully.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
from pathlib import Path
from typing import Any


REORDER_KINDS = {15, 16, 17, 18, 19, 20}
STARTERS = ("j_perkeo", "j_yorick")


def _integer(value, minimum=0):
    return type(value) is int and value >= minimum


def _finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _progress(row):
    value = row.get("blinds_cleared")
    return value if _integer(value) else None


def _terminal(row, missing_count, missing_keys):
    outcome = row.get("outcome")
    if outcome not in {"win", "loss"}:
        return False, None, "unresolved_outcome"
    if row.get("won") is not (outcome == "win"):
        return False, None, "terminal_flag_disagrees_or_missing"
    count, keys = row.get("new_gold_count"), row.get("new_gold_keys")
    if (not _integer(count) or count > missing_count or not isinstance(keys, list)
            or any(not isinstance(key, str) or not key for key in keys)
            or len(keys) != len(set(keys)) or count != len(keys)):
        return False, None, "invalid_or_missing_distinct_award_receipt"
    if missing_keys is not None and not set(keys).issubset(missing_keys):
        return False, None, "award_key_not_in_initial_missing_set"
    if outcome == "loss" and count != 0:
        return False, None, "loss_cannot_award_new_gold"
    if outcome == "win":
        receipt = row.get("clear_receipt")
        if not isinstance(receipt, dict):
            return False, None, "win_missing_final_clear_receipt"
        ante, target, chips = receipt.get("ante"), receipt.get("target"), receipt.get("chips")
        after_ante = receipt.get("after_ante")
        threshold_met, saved = receipt.get("threshold_met"), receipt.get("saved")
        if (receipt.get("blind") != "Boss" or type(ante) is not int or ante != 8
                or type(after_ante) is not int or after_ante != 9
                or receipt.get("before_phase") != "selecting_hand"
                or receipt.get("after_phase") != "round_eval"
                or not _finite(target) or target <= 0 or not _finite(chips)
                or type(threshold_met) is not bool or type(saved) is not bool
                or threshold_met is not (chips >= target)
                or not (threshold_met or saved)
                or receipt.get("scope") != "simulator_play_to_round_eval"):
            return False, None, "invalid_final_clear_receipt"
        # The environment's explicit saved flag already includes its exhausted-
        # hands check; the receipt does not expose hands_left to recheck here.
    return True, keys, None


def _action_evidence(rows, starter_ids):
    valid_steps = [row for row in rows if _integer(row.get("step"), 1)]
    steps = [row["step"] for row in valid_steps]
    well_ordered = len(steps) == len(rows) and len(steps) == len(set(steps))
    ordered = sorted(valid_steps, key=lambda row: row["step"])
    first_two = None
    if well_ordered and len(ordered) >= 2 and [row["step"] for row in ordered[:2]] == [1, 2]:
        first_two = (all(row.get("candidate_kind") == 9 for row in ordered[:2])
                     and {row.get("target_catalog_id") for row in ordered[:2]} == set(starter_ids.values()))
    sold = Counter()
    by_id = {value: key for key, value in starter_ids.items()}
    streak = maximum = streaks = 0
    previous_step = None
    for row in ordered:
        if row.get("candidate_kind") == 9 and row.get("target_catalog_id") in by_id:
            sold[by_id[row["target_catalog_id"]]] += 1
        if row.get("candidate_kind") in REORDER_KINDS:
            streak = streak + 1 if previous_step is not None and row["step"] == previous_step + 1 else 1
            if streak == 2:
                streaks += 1
            maximum = max(maximum, streak)
        else:
            streak = 0
        previous_step = row["step"]
    return {
        "action_records": len(rows),
        "action_steps_valid": well_ordered,
        "first_two_actions_sell_both_starters": first_two,
        "starter_sales": dict(sold),
        "sold_any_starter": bool(sold),
        "sold_both_starters": set(sold) == set(STARTERS),
        "reorder_like_actions": sum(row.get("candidate_kind") in REORDER_KINDS for row in rows),
        "consecutive_reorder_streaks_at_least_two": streaks,
        "maximum_consecutive_reorder_actions": maximum,
    }


def analyze_records(episodes, actions, *, starter_ids, missing_count, missing_keys=None,
                    reference_policy="heuristic", candidate_policy="learned"):
    """Analyze supplied records without filling in missing outcomes/progress."""
    if not _integer(missing_count) or set(starter_ids) != set(STARTERS):
        raise ValueError("Explicit missing-count bound and both starter IDs required")
    if any(not _integer(value, 1) for value in starter_ids.values()) or len(set(starter_ids.values())) != 2:
        raise ValueError("Distinct positive starter catalog IDs required")
    if missing_keys is not None:
        missing_keys = set(missing_keys)
        if len(missing_keys) != missing_count:
            raise ValueError("Missing keys disagree with the declared upper bound")
    by_id, by_policy, action_groups, seeds = {}, defaultdict(list), defaultdict(list), defaultdict(list)
    for row in episodes:
        index = row.get("episode_index")
        if not _integer(index) or index in by_id:
            raise ValueError("Episode indices must be present, nonnegative and unique")
        policy, seed = row.get("policy"), row.get("seed")
        if not isinstance(policy, str) or not policy or not isinstance(seed, str) or not seed:
            raise ValueError("Each episode requires an explicit policy and seed")
        by_id[index] = row
        by_policy[policy].append(row)
        seeds[seed].append(row)
    unassigned = 0
    for row in actions:
        index = row.get("episode_index")
        if index not in by_id:
            unassigned += 1
        else:
            action_groups[index].append(row)
    terminals = {index: _terminal(row, missing_count, missing_keys) for index, row in by_id.items()}
    action_evidence = {index: _action_evidence(action_groups[index], starter_ids) for index in by_id}
    policies = {}
    for policy, rows in sorted(by_policy.items()):
        n = len(rows)
        known, unknown, awarded, distinct = 0, [], 0, set()
        verified_wins = 0
        issues = Counter()
        progress = []
        behavior = Counter()
        maximum_streak = 0
        sales = Counter()
        for row in rows:
            index = row["episode_index"]
            terminal, keys, reason = terminals[index]
            if terminal:
                known += 1
                awarded += len(keys)
                distinct.update(keys)
                verified_wins += row.get("outcome") == "win"
            else:
                issues[reason] += 1
                unknown.append({"episode_index": index, "seed": row["seed"],
                                "reported_outcome": row.get("outcome", "missing"),
                                "reason": row.get("reason"), "audit_reason": reason,
                                "observed_blinds_cleared_prefix": _progress(row)})
            observed_progress = _progress(row)
            if observed_progress is not None:
                progress.append(observed_progress)
            evidence = action_evidence[index]
            behavior["action_records"] += evidence["action_records"]
            behavior["episodes_with_invalid_action_steps"] += not evidence["action_steps_valid"]
            first_two = evidence["first_two_actions_sell_both_starters"]
            behavior["episodes_with_observed_first_two_actions"] += first_two is not None
            behavior["episodes_first_two_actions_sell_both_starters"] += first_two is True
            behavior["episodes_selling_any_starter"] += evidence["sold_any_starter"]
            behavior["episodes_selling_both_starters"] += evidence["sold_both_starters"]
            behavior["reorder_like_actions"] += evidence["reorder_like_actions"]
            behavior["consecutive_reorder_streaks_at_least_two"] += evidence["consecutive_reorder_streaks_at_least_two"]
            maximum_streak = max(maximum_streak, evidence["maximum_consecutive_reorder_actions"])
            sales.update(evidence["starter_sales"])
        complete = not unknown
        policies[policy] = {
            "attempts": n,
            "reported_outcome_counts": dict(Counter(row.get("outcome", "missing") for row in rows)),
            "verified_terminal_attempts": known,
            "verified_terminal_wins": verified_wins,
            "unresolved_attempts": len(unknown),
            "unresolved_records": unknown,
            "audit_issue_counts": dict(issues),
            "observed_terminal_new_gold_sum": awarded,
            "distinct_new_gold_keys_across_verified_wins": sorted(distinct),
            "mean_new_gold_full_cohort": awarded / n if complete and n else None,
            "sample_new_gold_mean_bounds": [awarded / n, (awarded + len(unknown) * missing_count) / n] if n else None,
            "sample_win_fraction_bounds": [verified_wins / n, (verified_wins + len(unknown)) / n] if n else None,
            "bounds_interpretation": "Finite-sample partial identification from unresolved attempts; NOT a confidence interval or retail win probability.",
            "per_unknown_attempt_award_upper_bound": missing_count,
            "observed_progress_records": len(progress),
            "missing_progress_records": n - len(progress),
            "mean_observed_blinds_cleared_prefix": sum(progress) / len(progress) if progress else None,
            "mean_blinds_cleared_full_cohort": sum(progress) / n if complete and len(progress) == n and n else None,
            "behavior": {**dict(behavior), "maximum_consecutive_reorder_actions": maximum_streak,
                         "starter_sale_actions": dict(sales)},
        }
    pairs, pair_issues = [], []
    progress_counts = {"all_observed_pairs": Counter(), "fully_terminal_pairs": Counter(), "unresolved_pairs": Counter()}
    for seed, rows in sorted(seeds.items()):
        grouped = defaultdict(list)
        for row in rows:
            grouped[row["policy"]].append(row)
        if set(grouped) != {reference_policy, candidate_policy} or any(len(group) != 1 for group in grouped.values()):
            pair_issues.append({"seed": seed, "reason": "missing_duplicate_or_unexpected_policy", "policy_counts": {p: len(v) for p, v in grouped.items()}})
            continue
        reference, candidate = grouped[reference_policy][0], grouped[candidate_policy][0]
        context_fields = ("namespace", "deck", "stake", "goal_digest", "scope", "simulator_patch", "opening_reference")
        mismatch = [field for field in context_fields if reference.get(field) != candidate.get(field)]
        if not reference.get("goal_digest"):
            mismatch.append("missing_goal_digest")
        if mismatch:
            pair_issues.append({"seed": seed, "reason": "starting_context_mismatch_or_missing", "fields": mismatch})
            continue
        ri, ci = reference["episode_index"], candidate["episode_index"]
        rt, rk, _ = terminals[ri]
        ct, ck, _ = terminals[ci]
        rp, cp = _progress(reference), _progress(candidate)
        comparison = "unknown" if rp is None or cp is None else "higher" if cp > rp else "lower" if cp < rp else "equal"
        progress_counts["all_observed_pairs"][comparison] += 1
        progress_counts["fully_terminal_pairs" if rt and ct else "unresolved_pairs"][comparison] += 1
        pairs.append({"seed": seed, "reference_episode_index": ri, "candidate_episode_index": ci,
                      "reference_outcome": reference.get("outcome"), "candidate_outcome": candidate.get("outcome"),
                      "reference_unresolved": not rt, "candidate_unresolved": not ct,
                      "reference_observed_blinds_cleared_prefix": rp, "candidate_observed_blinds_cleared_prefix": cp,
                      "candidate_progress_comparison": comparison,
                      "progress_scope": "final_observed_progress" if rt and ct else "observed_prefix_only_not_final_progress",
                      "candidate_new_gold_difference": len(ck) - len(rk) if rt and ct else None})
    return {
        "schema": "learning_evaluation_artifact_audit_v1",
        "simulator_qualified": False, "real_game_win_claim": False, "actual_player_awards": 0,
        "scope": "Recorded simulator attempts under the same initial collection ledger; not cumulative player campaign awards.",
        "episode_records": len(episodes), "action_records": len(actions), "unassigned_action_records": unassigned,
        "starter_catalog_ids": dict(starter_ids), "missing_joker_bound": missing_count,
        "policies": policies,
        "pairing": {"reference_policy": reference_policy, "candidate_policy": candidate_policy,
                    "valid_pair_count": len(pairs), "all_seeds_validly_paired": not pair_issues,
                    "issues": pair_issues, "progress_counts": {key: dict(value) for key, value in progress_counts.items()}, "pairs": pairs},
        "behavior_limit": "Reorder counts/streaks are observed action sequences. Exact repeated-state loops are not proved without public-state fingerprints.",
    }


def _jsonl(path):
    result = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip():
            continue
        value = json.loads(line)
        if not isinstance(value, dict):
            raise ValueError(f"Expected object at {path}:{number}")
        result.append(value)
    return result


def markdown_report(report):
    lines = ["# Frozen simulator evaluation audit", "", report["scope"], "",
             "No retail qualification, actual player award, or confidence interval is claimed.", "",
             "| Policy | Attempts | Verified wins | Unresolved | Observed new Gold | Full-cohort mean | Sample mean bounds | Observed progress prefix |",
             "|---|---:|---:|---:|---:|---:|---|---:|"]
    for name, row in report["policies"].items():
        mean = "unavailable" if row["mean_new_gold_full_cohort"] is None else f'{row["mean_new_gold_full_cohort"]:.4f}'
        progress = row["mean_observed_blinds_cleared_prefix"]
        progress = "unavailable" if progress is None else f"{progress:.4f} ({row['observed_progress_records']} observed)"
        bounds = row["sample_new_gold_mean_bounds"]
        bound_text = "unavailable" if bounds is None else f"[{bounds[0]:.4f}, {bounds[1]:.4f}]"
        lines.append(f"| {name} | {row['attempts']} | {row['verified_terminal_wins']} | {row['unresolved_attempts']} | {row['observed_terminal_new_gold_sum']} | {mean} | {bound_text} | {progress} |")
    lines += ["", "Bounds are finite-sample partial-identification bounds, **not confidence intervals**. Each unresolved attempt can contribute between zero and the initial missing-Joker count; missing progress is never replaced with zero.", ""]
    for name, row in report["policies"].items():
        behavior = row["behavior"]
        lines.append(f"- {name}: first two recorded actions sold both starters in {behavior.get('episodes_first_two_actions_sell_both_starters', 0)}/{behavior.get('episodes_with_observed_first_two_actions', 0)} observed openings; {behavior.get('reorder_like_actions', 0)} reorder-like actions; maximum consecutive reorder streak {behavior['maximum_consecutive_reorder_actions']}.")
    pair = report["pairing"]
    lines += ["", f"Validated seed pairs: {pair['valid_pair_count']}. Pairing issues: {len(pair['issues'])}.",
              f"Candidate versus reference observed progress: {json.dumps(pair['progress_counts'], sort_keys=True)}.",
              "Unresolved-pair progress compares observed prefixes only, not completed-run outcomes.", "", report["behavior_limit"], ""]
    return "\n".join(lines)


def analyze_job(job_dir):
    directory = Path(job_dir).resolve()
    receipt_path = directory / "receipt.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt.get("status") != "completed" or receipt.get("returncode") != 0:
        raise ValueError("Analysis output requires a successfully completed owning job receipt")
    summary_path = directory / "summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    paths = {"episodes": directory / "episodes.jsonl", "actions": directory / "actions.jsonl",
             "goal": directory / "frozen/inputs/goal-file.json",
             "catalog": directory / "frozen/simulator/jackdaw/engine/data/centers.json"}
    episodes, actions = _jsonl(paths["episodes"]), _jsonl(paths["actions"])
    if summary.get("episodes_started") != len(episodes):
        raise ValueError("Summary started-attempt count does not match episode records")
    if summary.get("transitions") != len(actions):
        raise ValueError("Summary transition count does not match action records")
    goal = json.loads(paths["goal"].read_text(encoding="utf-8"))
    if goal.get("schema") != "completionist_distinct_v1" or goal.get("verified_collection") is not True:
        raise ValueError("A verified frozen initial collection goal is required for award bounds")
    missing = {key for key, value in goal["status_by_key"].items() if value == "missing"}
    catalog = json.loads(paths["catalog"].read_text(encoding="utf-8"))
    identities = {key: index + 1 for index, key in enumerate(sorted(catalog))}
    starters = {key: identities[key] for key in STARTERS}
    report = analyze_records(episodes, actions, starter_ids=starters, missing_count=len(missing), missing_keys=missing)
    report["job_directory"] = str(directory)
    report["completed_receipt"] = {key: receipt.get(key) for key in ("job", "status", "returncode", "finished_utc")}
    report["artifact_sha256"] = {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in {
        **paths, "receipt": receipt_path, "summary": summary_path, "analyzer": Path(__file__)
    }.items()}
    (directory / "analysis.json").write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    (directory / "analysis.md").write_text(markdown_report(report), encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--job-dir", type=Path, required=True)
    args = parser.parse_args()
    report = analyze_job(args.job_dir)
    print(json.dumps({"job_directory": report["job_directory"], "policies": {
        key: {field: row[field] for field in ("attempts", "verified_terminal_wins", "unresolved_attempts", "observed_terminal_new_gold_sum", "mean_new_gold_full_cohort", "sample_new_gold_mean_bounds")}
        for key, row in report["policies"].items()
    }, "valid_pairs": report["pairing"]["valid_pair_count"]}, indent=2))


if __name__ == "__main__":
    main()
