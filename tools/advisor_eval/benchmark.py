"""Freeze an advisor, pre-register fresh challenge seeds, and audit episode results.

This is evaluation infrastructure, not a game simulator. Only a validated game
adapter can supply evidence for the win-rate gates. No GPU work is performed.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import secrets
import shutil

ROOT = Path(__file__).resolve().parents[2]
CHALLENGES = tuple("c_" + name + "_1" for name in (
    "omelette", "city", "rich", "knife", "xray", "mad_world", "luxury",
    "non_perishable", "medusa", "double_nothing", "typecast", "inflation",
    "bram_poker", "fragile", "monolith", "blast_off", "five_card",
    "golden_needle", "cruelty", "jokerless"))
OUTCOMES = {"win", "loss", "error", "timeout", "unsupported", "censored"}
ORDINARY_START = {"kind": "ordinary", "seed_selection": "unfiltered"}
MECHANICS = {"challenge_setup", "draw_rng", "hand_scoring", "joker_triggers",
            "boss_rules", "shop_and_packs", "consumables", "round_economy",
            "terminal_outcomes", "verbatim_actions", "save_isolation"}


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def file_digest(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def policy_sources(root=ROOT):
    """Product dependencies, excluding personal config/saves and build backups.

    Hash installed runtime variants and native seed datasets as well as policy
    code. Presence in this manifest does not imply adapter execution coverage.
    """
    root = Path(root)
    product = root / "Brainstorm"
    sources = []
    for directory in (product, product / "Advisor", product / "Core", product / "UI"):
        # The installed mod stores personal preferences beside runtime Lua.
        # Source checkouts usually lack this file, so a blanket root glob would
        # accidentally copy/hash settings only for installed-product freezes.
        sources.extend(path for path in directory.glob("*.lua")
                       if not (directory == product and path.name.lower() == "config.lua"))
    for pattern in ("lovely.toml", "*.dll", "*.so", "*.dylib", "*.ids", "*.manifest.json"):
        sources.extend(product.glob(pattern))
    required = [product / "Core" / "Brainstorm.lua", product / "Core" / "challenge_opening.lua",
                product / "UI" / "advisor.lua", product / "UI" / "ui.lua",
                product / "UI" / "challenge_opening.lua", product / "lovely.toml"]
    if not list((product / "Advisor").glob("*.lua")) or any(not p.is_file() for p in required):
        raise ValueError("Product manifest is missing required advisor/runtime sources")
    return sorted(set(sources))


def policy_hashes(root=ROOT):
    root = Path(root)
    return {source.relative_to(root).as_posix(): file_digest(source)
            for source in policy_sources(root)}


def freeze_policy(destination):
    expected = policy_hashes()
    hashes = {}
    for relative in expected:
        source = ROOT / relative
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        hashes[relative] = file_digest(target)
    if hashes != expected or policy_hashes() != expected:
        raise ValueError("Policy changed while freezing; use a fresh stable campaign")
    return hashes


def initialize(directory, engine, count=400, stage=50, attempt=1, previous_gate=None):
    if count < 100 or stage not in (50, 75) or attempt < 1:
        raise ValueError("Use >=100 seeds per challenge, stage 50 or 75, and attempt >=1")
    if stage == 75 and not valid_previous_gate(previous_gate):
        raise ValueError("The 75% campaign requires a completed 50% gate for all challenges")
    directory, engine = Path(directory), Path(engine)
    if directory.exists():
        raise ValueError("Use a fresh directory; previous evaluation seeds must not be reused")
    # Keep campaigns under one runs directory. An adaptive improvement must not
    # reset the confidence allocation by repeatedly naming itself attempt 1.
    earlier = [json.loads(path.read_text(encoding="utf-8")) for path in directory.parent.glob('*/manifest.json')]
    earlier = [item for item in earlier if item.get("qualification") is not False]
    last_attempt = max((item.get('attempt', 0) for item in earlier if item.get('stage') == stage), default=0)
    if attempt <= last_attempt:
        raise ValueError(f"Stage {stage} already registered attempt {last_attempt}; increment --attempt")
    rules_hash = file_digest(engine)
    directory.mkdir(parents=True)
    hashes = freeze_policy(directory / "policy")
    # Never use seeds supplied by the reroll/seed-search feature. Freeze first,
    # then sample independent seeds. This seed list is for the engine, not policy.
    alphabet = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    used, episodes = set(), []
    for challenge in CHALLENGES:
        for index in range(count):
            while True:
                seed = "".join(secrets.choice(alphabet) for _ in range(8))
                if seed not in used:
                    break
            used.add(seed)
            episodes.append({"id": f"{challenge}:{index:04d}",
                             "challenge": challenge, "seed": seed})
    manifest = {
        "schema": 2, "created_utc": datetime.now(timezone.utc).isoformat(),
        "start_distribution": dict(ORDINARY_START),
        "product_manifest_scope": "runtime_and_native_dependencies_v1",
        "stage": stage, "attempt": attempt, "per_challenge": count,
        "policy_files": hashes, "policy_digest": digest(hashes),
        "rules_digest": rules_hash, "engine_file": str(engine.resolve()),
        "scope": "every_challenge_individually", "episodes": episodes,
        "previous_gate": previous_gate,
        "earlier_campaigns": [item['manifest_digest'] for item in earlier],
        # Allocate total family error .05 over two gates, 20 challenges and all
        # attempts: sum(1/[a(a+1)], a>=1)=1. Attempts require fresh seeds.
        "tail_alpha": .05 / (2 * len(CHALLENGES) * attempt * (attempt + 1)),
    }
    manifest["manifest_digest"] = digest(manifest)
    (directory / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (directory / "episodes.jsonl").touch()
    return manifest


def valid_previous_gate(report):
    return (isinstance(report, dict) and report.get("stage") == 50
            and report.get("passed") is True and bool(report.get("manifest_digest"))
            and len(report.get("challenges", [])) == len(CHALLENGES)
            and {row.get("challenge") for row in report["challenges"]} == set(CHALLENGES)
            and all(row.get("passed") is True for row in report["challenges"]))


def binomial_tail(n, k, p):
    if k <= 0:
        return 1.0
    if p <= 0:
        return 0.0
    if p >= 1:
        return 1.0
    logs = [math.lgamma(n + 1) - math.lgamma(i + 1) - math.lgamma(n - i + 1)
            + i * math.log(p) + (n - i) * math.log1p(-p)
            for i in range(k, n + 1)]
    peak = max(logs)
    return min(1.0, math.exp(peak) * sum(math.exp(x - peak) for x in logs))


def lower_bound(wins, total, alpha):
    """One-sided exact Clopper-Pearson binomial lower confidence bound."""
    if total < 1 or not 0 <= wins <= total or not 0 < alpha < 1:
        raise ValueError("Invalid binomial confidence inputs")
    if wins == 0:
        return 0.0
    low, high = 0.0, wins / total
    for _ in range(55):
        midpoint = (low + high) / 2
        if binomial_tail(total, wins, midpoint) < alpha:
            low = midpoint
        else:
            high = midpoint
    return (low + high) / 2


def audit(manifest, records, validation=None):
    """Fail closed: missing/error/unsupported episodes cannot pass a gate.

    Adapter attestations are an audit contract, not cryptographic proof of engine
    correctness. Source parity must be reviewed before issuing validation.
    """
    unsigned = dict(manifest)
    claimed = unsigned.pop("manifest_digest", None)
    if digest(unsigned) != claimed:
        raise ValueError("Manifest was modified after registration")
    if manifest["scope"] != "every_challenge_individually":
        raise ValueError("A pooled win rate does not meet this user's target")
    if manifest.get("schema", 1) >= 2 and manifest.get("start_distribution") != ORDINARY_START:
        raise ValueError("This qualification protocol only supports ordinary independent starts")
    if manifest["stage"] not in (50, 75) or manifest["attempt"] < 1 or manifest["per_challenge"] < 100:
        raise ValueError("Invalid campaign stage, attempt or sample count")
    expected_alpha = .05 / (2 * len(CHALLENGES) * manifest["attempt"] * (manifest["attempt"] + 1))
    if manifest["tail_alpha"] != expected_alpha:
        raise ValueError("Confidence allocation differs from the registered protocol")
    if manifest["stage"] == 75 and not valid_previous_gate(manifest.get("previous_gate")):
        raise ValueError("Missing completed 50% gate")
    planned = {row["id"]: row for row in manifest["episodes"]}
    if len(planned) != len(manifest["episodes"]):
        raise ValueError("Duplicate manifest episode")
    if Counter(row["challenge"] for row in planned.values()) != {
            challenge: manifest["per_challenge"] for challenge in CHALLENGES}:
        raise ValueError("Manifest must contain every challenge with equal coverage")
    if len({row["seed"] for row in planned.values()}) != len(planned):
        raise ValueError("Repeated seeds in manifest")
    completed = {}
    for record in records:
        episode = planned.get(record.get("id"))
        if episode is None or record["id"] in completed:
            raise ValueError("Unknown or duplicated episode result")
        for field in ("challenge", "seed"):
            if record.get(field) != episode[field]:
                raise ValueError(f"Episode {field} does not match registration")
        for field in ("manifest_digest", "policy_digest", "rules_digest"):
            if record.get(field) != manifest[field]:
                raise ValueError(f"Episode {field} mismatch")
        if manifest.get("schema", 1) >= 2 and record.get("start_distribution") != manifest["start_distribution"]:
            raise ValueError("Episode opening distribution differs from registration")
        if record.get("outcome") not in OUTCOMES:
            raise ValueError("Unknown terminal outcome")
        if record.get("source") != "game_engine":
            raise ValueError("Unit tests, proxy simulations and manual runs are not win-rate evidence")
        if record.get("followed_advice") is not True:
            raise ValueError("Episode did not follow the advisor verbatim")
        if not isinstance(record.get("decisions"), int) or record["decisions"] < 1:
            raise ValueError("Episode lacks an action trace")
        if not record.get("trace_digest") or not record.get("adapter_digest"):
            raise ValueError("Episode lacks engine/trace provenance")
        if record["outcome"] == "win" and (record.get("ante", 0) < 8 or
                                                record.get("game_won") is not True):
            raise ValueError("Win must be a game-confirmed Ante 8 completion")
        completed[record["id"]] = record
    reasons = []
    validation = validation or {}
    valid_adapter = (validation.get("rules_digest") == manifest["rules_digest"]
                     and validation.get("status") == "validated"
                     and set(validation.get("challenges", [])) == set(CHALLENGES)
                     and MECHANICS <= set(validation.get("checks_passed", []))
                     and bool(validation.get("parity_report_digest"))
                     and bool(validation.get("adapter_digest")))
    if not valid_adapter:
        reasons.append("No validated full-run engine adapter covering all challenges")
    if any(row["adapter_digest"] != validation.get("adapter_digest") for row in completed.values()):
        valid_adapter = False
        reasons.append("Episode adapter does not match the validated adapter")
    rows = []
    for challenge in CHALLENGES:
        outcomes = Counter(row["outcome"] for row in completed.values()
                           if row["challenge"] == challenge)
        n, wins = manifest["per_challenge"], outcomes["win"]
        missing = n - sum(outcomes.values())
        failures = sum(outcomes[key] for key in ("error", "timeout", "unsupported", "censored"))
        # Incomplete episodes are conservatively nonwins for the bound as well
        # as explicitly blocking the campaign gate; never omit hard cases.
        lower = lower_bound(wins, n, manifest["tail_alpha"])
        rows.append({"challenge": challenge, "planned": n, "finished": n - missing,
                     "wins": wins, "losses": outcomes["loss"], "unresolved": failures,
                     "missing": missing, "observed_win_rate": wins / n if not missing else None,
                     "lower_bound": lower,
                     "passed": valid_adapter and not missing and not failures
                               and lower >= manifest["stage"] / 100})
    if any(row["missing"] for row in rows):
        reasons.append("Campaign is incomplete")
    if any(row["unresolved"] for row in rows):
        reasons.append("Engine errors/timeouts/unsupported or censored episodes require resolution")
    return {"stage": manifest["stage"], "manifest_digest": claimed,
            "policy_digest": manifest["policy_digest"], "passed": all(row["passed"] for row in rows),
            "start_distribution": manifest.get("start_distribution", dict(ORDINARY_START)),
            "qualified_75_baseline": manifest["stage"] == 75 and all(row["passed"] for row in rows),
            # The user narrowed the task to deterministic improvements. A
            # statistical milestone does not restore training authorization.
            "training_allowed": False,
            "reasons": reasons, "tail_alpha": manifest["tail_alpha"], "challenges": rows}


def verify_frozen_policy(directory, manifest):
    for relative, expected in manifest["policy_files"].items():
        path = (directory / "policy" / relative).resolve()
        if not path.is_relative_to((directory / "policy").resolve()):
            raise ValueError("Invalid frozen policy path")
        if file_digest(path) != expected:
            raise ValueError("Frozen policy was changed during the campaign")
    if digest(manifest["policy_files"]) != manifest["policy_digest"]:
        raise ValueError("Frozen policy identity mismatch")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    init = commands.add_parser("init")
    init.add_argument("directory", type=Path)
    init.add_argument("--engine", type=Path, required=True, help="Installed Balatro.exe or exact rules bundle")
    init.add_argument("--per-challenge", type=int, default=400)
    init.add_argument("--stage", type=int, choices=(50, 75), default=50)
    init.add_argument("--attempt", type=int, default=1)
    init.add_argument("--previous-gate", type=Path, help="Completed all-challenge 50% report, required for stage 75")
    report = commands.add_parser("report")
    report.add_argument("directory", type=Path)
    report.add_argument("--validation", type=Path)
    args = parser.parse_args()
    if args.command == "init":
        previous = json.loads(args.previous_gate.read_text()) if args.previous_gate else None
        manifest = initialize(args.directory, args.engine, args.per_challenge, args.stage, args.attempt, previous)
        print(f"Registered {len(manifest['episodes'])} episodes; policy {manifest['policy_digest']}")
        print("No episodes have run. No win-rate target is established.")
        return 0
    manifest = json.loads((args.directory / "manifest.json").read_text())
    verify_frozen_policy(args.directory, manifest)
    records = [json.loads(line) for line in (args.directory / "episodes.jsonl").read_text().splitlines() if line.strip()]
    validation = json.loads(args.validation.read_text()) if args.validation else None
    result = audit(manifest, records, validation)
    (args.directory / "report.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"{result['stage']}% on every challenge: {'PASS' if result['passed'] else 'NOT ESTABLISHED'}")
    for row in result["challenges"]:
        print(f"{row['challenge']:25} {row['finished']:4}/{row['planned']} complete; "
              f"{row['wins']:4} wins; lower bound {row['lower_bound']:.1%}")
    for reason in result["reasons"]:
        print(reason)
    print("GPU/model training is outside the current deterministic-only task.")
    return 0 if result["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
