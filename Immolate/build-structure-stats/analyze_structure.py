#!/usr/bin/env python3
"""Held-out analysis for the disposable Balatro seed-structure probes."""

from __future__ import annotations

import argparse
import itertools
import json
import math
from pathlib import Path

import mpmath
import numpy as np
import pandas as pd


STAGES = ["charm", "charm_soul", "charm_soul_perkeo"]
CHARS = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def normal_p(z: float) -> float:
    return math.erfc(abs(z) / math.sqrt(2.0))


def chi_square_sf(value: float, degrees_of_freedom: int) -> float:
    return float(mpmath.gammainc(
        degrees_of_freedom / 2.0,
        value / 2.0,
        mpmath.inf,
        regularized=True,
    ))


def two_proportion(a: float, n_a: float, b: float, n_b: float) -> tuple[float, float]:
    if n_a <= 0 or n_b <= 0:
        return float("nan"), float("nan")
    pooled = (a + b) / (n_a + n_b)
    variance = pooled * (1.0 - pooled) * (1.0 / n_a + 1.0 / n_b)
    if variance <= 0:
        return 0.0, 1.0
    z = (a / n_a - b / n_b) / math.sqrt(variance)
    return z, normal_p(z)


def rate_ratio_ci(a: float, n_a: float, b: float, n_b: float) -> tuple[float, float, float]:
    if min(a, b, n_a, n_b) <= 0:
        return float("nan"), float("nan"), float("nan")
    ratio = (a / n_a) / (b / n_b)
    se = math.sqrt(max(0.0, 1.0 / a - 1.0 / n_a + 1.0 / b - 1.0 / n_b))
    return ratio, math.exp(math.log(ratio) - 1.96 * se), math.exp(math.log(ratio) + 1.96 * se)


def ranking_eval(train: pd.DataFrame, test: pd.DataFrame, fraction: float) -> dict:
    train = train.groupby("bucket", as_index=False)[["denominator", "hits"]].sum()
    test = test.groupby("bucket", as_index=False)[["denominator", "hits"]].sum()
    merged = train.merge(test, on="bucket", suffixes=("_train", "_test"))
    merged = merged[(merged.denominator_train > 0) & (merged.denominator_test > 0)].copy()
    if merged.empty:
        return {"valid": False}
    train_coverage = merged.denominator_train.sum() / max(1, train.denominator.sum())
    test_coverage = merged.denominator_test.sum() / max(1, test.denominator.sum())
    base_rate = merged.hits_train.sum() / merged.denominator_train.sum()
    # Fifty thousand prior observations correspond to about ten Perkeo hits.
    # This suppresses obvious winner's-curse ranking in very sparse triples.
    prior_mass = 50000.0
    merged["score"] = (merged.hits_train + base_rate * prior_mass) / (
        merged.denominator_train + prior_mass
    )
    merged = merged.sort_values(["score", "bucket"], ascending=[False, True])
    target = merged.denominator_train.sum() * fraction
    cumulative = merged.denominator_train.cumsum()
    selected = merged[cumulative - merged.denominator_train < target]
    selected_buckets = set(selected.bucket.tolist())
    top = merged[merged.bucket.isin(selected_buckets)]
    rest = merged[~merged.bucket.isin(selected_buckets)]
    train_top_rate = top.hits_train.sum() / top.denominator_train.sum()
    train_all_rate = merged.hits_train.sum() / merged.denominator_train.sum()
    test_top_rate = top.hits_test.sum() / top.denominator_test.sum()
    test_all_rate = merged.hits_test.sum() / merged.denominator_test.sum()
    z, p = two_proportion(
        top.hits_test.sum(), top.denominator_test.sum(),
        rest.hits_test.sum(), rest.denominator_test.sum(),
    )
    rr, lo, hi = rate_ratio_ci(
        top.hits_test.sum(), top.denominator_test.sum(),
        rest.hits_test.sum(), rest.denominator_test.sum(),
    )
    return {
        "valid": True,
        "buckets": int(len(merged)),
        "selected_buckets": int(len(top)),
        "train_coverage": float(train_coverage),
        "test_coverage": float(test_coverage),
        "selected_test_fraction": float(top.denominator_test.sum() / merged.denominator_test.sum()),
        "train_lift_vs_all": float(train_top_rate / train_all_rate),
        "test_lift_vs_all": float(test_top_rate / test_all_rate),
        "test_rr_vs_rest": float(rr),
        "test_rr_ci_low": float(lo),
        "test_rr_ci_high": float(hi),
        "z": float(z),
        "p": float(p),
        "selected": sorted(str(x) for x in selected_buckets),
    }


def split_frame(frame: pd.DataFrame, train_ranges: set[int], test_ranges: set[int]) -> tuple[pd.DataFrame, pd.DataFrame]:
    return frame[frame.range.isin(train_ranges)], frame[frame.range.isin(test_ranges)]


def analyze_summary(scan_dir: Path) -> tuple[pd.DataFrame, list[dict], list[dict], list[str]]:
    summary = pd.read_csv(scan_dir / "summary.csv")
    lines: list[str] = []
    relations: list[dict] = []
    heterogeneity: list[dict] = []
    pooled = summary.groupby("stage")[["hits", "seeds"]].sum()

    def hits(stage: str) -> float:
        return float(pooled.loc[stage, "hits"])

    charm = hits("charm")
    soul = hits("charm_soul")
    perkeo = hits("charm_soul_perkeo")
    lines.append(f"Charm rate: {charm / pooled.loc['charm', 'seeds']:.9%}")
    lines.append(
        f"Soul given Charm: {soul / charm:.9%} "
        f"(theory {1.0 - 0.997 ** 5:.9%})"
    )
    lines.append(f"Perkeo given Charm+Soul: {perkeo / soul:.9%} (theory 20%)")

    comparisons = [
        ("judgement", "charm_soul_judgement", "perkeo_judgement"),
        ("judgement_invisible", "charm_soul_judgement_invisible", "perkeo_judgement_invisible"),
        ("telescope", "charm_soul_telescope", "perkeo_telescope"),
        ("observatory", "charm_soul_observatory", "perkeo_observatory"),
    ]
    for label, all_stage, perkeo_stage in comparisons:
        all_downstream = hits(all_stage)
        perkeo_downstream = hits(perkeo_stage)
        non_perkeo_downstream = all_downstream - perkeo_downstream
        z, p = two_proportion(
            perkeo_downstream, perkeo,
            non_perkeo_downstream, soul - perkeo,
        )
        rr, lo, hi = rate_ratio_ci(
            perkeo_downstream, perkeo,
            non_perkeo_downstream, soul - perkeo,
        )
        item = {
            "relationship": f"Perkeo vs {label} among Charm+Soul",
            "perkeo_rate": perkeo_downstream / perkeo,
            "non_perkeo_rate": non_perkeo_downstream / (soul - perkeo),
            "rate_ratio": rr,
            "ci_low": lo,
            "ci_high": hi,
            "z": z,
            "p": p,
        }
        relations.append(item)
        lines.append(
            f"{label} given Perkeo vs non-Perkeo: "
            f"{item['perkeo_rate']:.7%} vs {item['non_perkeo_rate']:.7%}; "
            f"RR {rr:.4f} (95% CI {lo:.4f}-{hi:.4f}), p={p:.3g}"
        )
    for item in relations:
        item["p_bonferroni"] = min(1.0, item["p"] * len(relations))
    for stage in summary.stage.unique():
        frame = summary[summary.stage == stage]
        pooled_rate = frame.hits.sum() / frame.seeds.sum()
        expected_hits = frame.seeds * pooled_rate
        expected_misses = frame.seeds * (1.0 - pooled_rate)
        statistic = float(
            (((frame.hits - expected_hits) ** 2 / expected_hits)
             + (((frame.seeds - frame.hits) - expected_misses) ** 2 / expected_misses)).sum()
        )
        heterogeneity.append({
            "stage": stage,
            "chi_square": statistic,
            "degrees_of_freedom": len(frame) - 1,
            "p": chi_square_sf(statistic, len(frame) - 1),
            "minimum_range_rate": float((frame.hits / frame.seeds).min()),
            "maximum_range_rate": float((frame.hits / frame.seeds).max()),
        })
    return summary, relations, heterogeneity, lines


def analyze_characters(scan_dir: Path, train_ranges: set[int], test_ranges: set[int]) -> list[dict]:
    chars = pd.read_csv(scan_dir / "characters.csv")
    output: list[dict] = []
    for stage in STAGES:
        stage_frame = chars[chars.stage == stage].copy()
        for position in range(8):
            frame = stage_frame[stage_frame.position == position].rename(columns={"character": "bucket"})
            train, test = split_frame(frame, train_ranges, test_ranges)
            result = ranking_eval(train, test, 0.20)
            result.update({"family": "character", "stage": stage, "feature": f"display_position_{position}", "top_fraction": 0.20})
            output.append(result)
    return output


def load_selected_features(scan_dir: Path) -> pd.DataFrame:
    pieces: list[pd.DataFrame] = []
    usecols = ["range", "stage", "feature", "bucket", "denominator", "hits"]
    for chunk in pd.read_csv(scan_dir / "features.csv", usecols=usecols, chunksize=400000):
        selected = chunk[chunk.stage.isin(STAGES)]
        if not selected.empty:
            pieces.append(selected)
    return pd.concat(pieces, ignore_index=True)


def collapse_buckets(frame: pd.DataFrame, modulus: int) -> pd.DataFrame:
    result = frame.copy()
    result["bucket"] = result.bucket.astype(np.int64) % modulus
    return result.groupby(["range", "stage", "feature", "bucket"], as_index=False)[["denominator", "hits"]].sum()


def analyze_features(features: pd.DataFrame, train_ranges: set[int], test_ranges: set[int]) -> list[dict]:
    output: list[dict] = []
    feature_names = [
        "prefix2", "suffix2", "outer2", "prefix3", "suffix3",
        "id_mod_4096", "seed_hash_256", "tag_seed_hash_256",
    ]
    for stage in STAGES:
        for feature in feature_names:
            frame = features[(features.stage == stage) & (features.feature == feature)]
            train, test = split_frame(frame, train_ranges, test_ranges)
            result = ranking_eval(train, test, 0.10)
            result.update({"family": "bucket", "stage": stage, "feature": feature, "top_fraction": 0.10})
            output.append(result)

    residue = features[features.feature == "id_mod_4096"]
    for stage in STAGES:
        stage_residue = residue[residue.stage == stage]
        for modulus in [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 4096]:
            frame = collapse_buckets(stage_residue, modulus)
            train, test = split_frame(frame, train_ranges, test_ranges)
            fraction = max(1.0 / modulus, 0.10)
            result = ranking_eval(train, test, fraction)
            result.update({"family": "stride", "stage": stage, "feature": f"id_mod_{modulus}", "top_fraction": fraction})
            output.append(result)

    for source in ["seed_hash_256", "tag_seed_hash_256"]:
        source_frame = features[features.feature == source]
        for stage in STAGES:
            frame = source_frame[source_frame.stage == stage].copy()
            frame["bucket"] = frame.bucket.astype(np.int64) // 16
            frame = frame.groupby(["range", "stage", "feature", "bucket"], as_index=False)[["denominator", "hits"]].sum()
            train, test = split_frame(frame, train_ranges, test_ranges)
            result = ranking_eval(train, test, 0.125)
            result.update({"family": "intermediate", "stage": stage, "feature": source.replace("256", "16"), "top_fraction": 0.125})
            output.append(result)
    return output


def suffix_frame(path: Path, stage: str, pair: bool) -> pd.DataFrame:
    frame = pd.read_csv(path)
    if pair:
        frame["bucket"] = frame.rightmost.astype(str) + frame.second_rightmost.astype(str)
    else:
        frame["bucket"] = frame.rightmost.astype(str)
    return frame.rename(columns={stage: "hits", "seeds": "denominator"})


def analyze_balanced_suffix(balanced_dir: Path) -> list[dict]:
    output: list[dict] = []
    for stage in STAGES:
        for pair, filename, fraction in [
            (False, "suffix1.csv", 0.20),
            (True, "suffix2.csv", 0.10),
        ]:
            frame = suffix_frame(balanced_dir / filename, stage, pair)
            train = frame[frame.fold == 0]
            test = frame[frame.fold == 1]
            result = ranking_eval(train, test, fraction)
            result.update({
                "family": "balanced_suffix",
                "stage": stage,
                "feature": "rightmost_pair" if pair else "rightmost_character",
                "top_fraction": fraction,
            })
            output.append(result)

    # Marginalize the pair experiment to isolate the second-rightmost char.
    raw = pd.read_csv(balanced_dir / "suffix2.csv")
    for stage in STAGES:
        frame = raw.groupby(["fold", "second_rightmost"], as_index=False)[["seeds", stage]].sum()
        frame = frame.rename(columns={"second_rightmost": "bucket", "seeds": "denominator", stage: "hits"})
        result = ranking_eval(frame[frame.fold == 0], frame[frame.fold == 1], 0.20)
        result.update({"family": "balanced_suffix", "stage": stage, "feature": "second_rightmost_character", "top_fraction": 0.20})
        output.append(result)
    return output


def analyze_lags_and_blocks(scan_dir: Path, summary: pd.DataFrame, train_ranges: set[int], test_ranges: set[int]) -> tuple[list[dict], list[dict]]:
    lags = pd.read_csv(scan_dir / "lags.csv")
    blocks = pd.read_csv(scan_dir / "blocks.csv")
    lag_output: list[dict] = []
    block_output: list[dict] = []
    for stage in STAGES:
        rates = summary[summary.stage == stage].set_index("range")
        stage_lags = lags[lags.stage == stage]
        for lag in sorted(stage_lags.lag.unique()):
            row = stage_lags[stage_lags.lag == lag]
            expected = 0.0
            for value in row.itertuples():
                p = rates.loc[value.range, "hits"] / rates.loc[value.range, "seeds"]
                expected += value.pairs * p * p
            observed = float(row.both.sum())
            ratio = observed / expected if expected else float("nan")
            z = (observed - expected) / math.sqrt(expected) if expected else float("nan")
            lag_output.append({"stage": stage, "lag": int(lag), "observed_pairs": observed, "expected_pairs": expected, "ratio": ratio, "z_poisson": z, "p_poisson": normal_p(z) if expected else float("nan")})

        stage_blocks = blocks[blocks.stage == stage]
        for block_size in sorted(stage_blocks.block_size.unique()):
            row = stage_blocks[stage_blocks.block_size == block_size]
            count = float(row.blocks.sum())
            total = float(row.sum_hits.sum())
            squares = float(row.sum_squares.sum())
            mean = total / count
            variance = squares / count - mean * mean
            fano = variance / mean if mean else float("nan")
            p_seed = summary[summary.stage == stage].hits.sum() / summary[summary.stage == stage].seeds.sum()
            expected_zero = count * math.exp(block_size * math.log1p(-p_seed))
            observed_zero = float(row.zero_blocks.sum())
            block_output.append({
                "stage": stage,
                "block_size": int(block_size),
                "blocks": int(count),
                "mean_hits": mean,
                "fano": fano,
                "fano_se_approx": math.sqrt(2.0 / max(1.0, count - 1.0)),
                "observed_zero": observed_zero,
                "expected_zero": expected_zero,
                "zero_ratio": observed_zero / expected_zero if expected_zero > 1e-300 else float("nan"),
            })
    return lag_output, block_output


def gray_inverse_rank(values_fast_to_slow: tuple[int, ...], base: int = 35) -> int:
    gray = list(reversed(values_fast_to_slow))
    ordinary: list[int] = []
    parity = 0
    for value in gray:
        digit = value if parity == 0 else base - 1 - value
        ordinary.append(digit)
        parity = (parity + digit) & 1
    rank = 0
    for digit in ordinary:
        rank = rank * base + digit
    return rank


def analyze_subtree(subtree_dir: Path) -> tuple[dict, list[dict]]:
    hits = pd.read_csv(subtree_dir / "hits.csv")
    hits = hits[hits.stage == "charm_soul_perkeo"]
    hits = hits[hits.seed.astype(str).str.len() == 8].copy()
    char_to_digit = {char: index for index, char in enumerate(CHARS)}
    digit_rows = np.array([[char_to_digit[char] for char in seed[:6]] for seed in hits.seed.astype(str)], dtype=np.int16)
    powers = np.array([35 ** index for index in range(6)], dtype=np.int64)
    encoded = (digit_rows * powers).sum(axis=1).astype(np.int64)
    hit_set = set(int(value) for value in encoded)
    domain = 35 ** 6
    hit_count = len(hit_set)
    edge_probability = hit_count * (hit_count - 1) / (domain * (domain - 1))
    hamming_by_position = []
    observed_total = 0
    for position in range(6):
        step = 35 ** position
        observed = 0
        for index, value in enumerate(encoded):
            digit = int(digit_rows[index, position])
            for replacement in range(digit + 1, 35):
                observed += int(int(value + (replacement - digit) * step) in hit_set)
        edges = domain * 34 / 2
        expected = edges * edge_probability
        observed_total += observed
        hamming_by_position.append({
            "position": position,
            "observed": observed,
            "expected": expected,
            "ratio": observed / expected,
            "z_poisson": (observed - expected) / math.sqrt(expected),
        })
    expected_total = domain * 6 * 34 / 2 * edge_probability
    hamming = {
        "domain": domain,
        "hits": hit_count,
        "observed_hamming1_pairs": observed_total,
        "expected_hamming1_pairs": expected_total,
        "ratio": observed_total / expected_total,
        "z_poisson": (observed_total - expected_total) / math.sqrt(expected_total),
        "positions": hamming_by_position,
    }

    block_size = 35 ** 3
    block_ids = (encoded // block_size).astype(np.int64)
    fast_digits = digit_rows[:, :3]
    permutations = list(itertools.permutations(range(3)))
    methods: dict[str, np.ndarray] = {}
    for permutation in permutations:
        rank = np.zeros(len(encoded), dtype=np.int64)
        for exponent, axis in enumerate(permutation):
            rank += fast_digits[:, axis].astype(np.int64) * (35 ** exponent)
        methods["transpose_" + "".join(str(x) for x in permutation)] = rank
    for permutation in permutations:
        ranks = np.fromiter(
            (gray_inverse_rank(tuple(int(row[axis]) for axis in permutation)) for row in fast_digits),
            dtype=np.int64,
            count=len(fast_digits),
        )
        methods["gray_" + "".join(str(x) for x in permutation)] = ranks

    unique_blocks = 35 ** 3
    first_ranks: dict[str, np.ndarray] = {}
    for name, ranks in methods.items():
        first = np.full(unique_blocks, block_size, dtype=np.int64)
        np.minimum.at(first, block_ids, ranks)
        first_ranks[name] = first
    train_mask = np.arange(unique_blocks) % 2 == 0
    test_mask = ~train_mask
    baseline = first_ranks["transpose_012"]
    best_name = min(first_ranks, key=lambda name: float(first_ranks[name][train_mask].mean()))
    order_results: list[dict] = []
    for name, first in first_ranks.items():
        train_mean = float(first[train_mask].mean())
        test_mean = float(first[test_mask].mean())
        delta = first[test_mask].astype(np.float64) - baseline[test_mask]
        se = float(delta.std(ddof=1) / math.sqrt(len(delta)))
        z = float(delta.mean() / se) if se > 0 else 0.0
        order_results.append({
            "method": name,
            "selected_on_train": name == best_name,
            "train_mean_first_rank": train_mean,
            "test_mean_first_rank": test_mean,
            "test_speedup_vs_current": float((baseline[test_mask].mean() + 1.0) / (test_mean + 1.0)),
            "paired_test_delta": float(delta.mean()),
            "paired_z": z,
            "paired_p": normal_p(z),
        })
    return hamming, order_results


def analyze_disjoint_range_orders(scan_dir: Path) -> list[dict]:
    hits = pd.read_csv(scan_dir / "hits.csv")
    hits = hits[hits.stage == "charm_soul_perkeo"]
    hits = hits[hits.seed.astype(str).str.len() == 8].copy()
    char_to_digit = {char: index for index, char in enumerate(CHARS)}
    fast_digits = np.array(
        [[char_to_digit[char] for char in seed[:3]] for seed in hits.seed.astype(str)],
        dtype=np.int16,
    )
    hits["block"] = hits.range.astype(str) + ":" + hits.seed.astype(str).str[3:]
    methods: dict[str, np.ndarray] = {}
    permutations = list(itertools.permutations(range(3)))
    for permutation in permutations:
        rank = np.zeros(len(hits), dtype=np.int64)
        for exponent, axis in enumerate(permutation):
            rank += fast_digits[:, axis].astype(np.int64) * (35 ** exponent)
        methods["transpose_" + "".join(str(x) for x in permutation)] = rank
    for permutation in permutations:
        methods["gray_" + "".join(str(x) for x in permutation)] = np.fromiter(
            (gray_inverse_rank(tuple(int(row[axis]) for axis in permutation)) for row in fast_digits),
            dtype=np.int64,
            count=len(fast_digits),
        )

    minima: dict[str, pd.Series] = {}
    for name, ranks in methods.items():
        temporary = pd.DataFrame({"block": hits.block.to_numpy(), "rank": ranks})
        minima[name] = temporary.groupby("block")["rank"].min()
    common = sorted(set.intersection(*(set(series.index) for series in minima.values())))
    ranges = np.array([int(key.split(":", 1)[0]) for key in common])
    train_mask = ranges < 4
    test_mask = ranges >= 4
    arrays = {name: series.reindex(common).to_numpy(dtype=np.float64) for name, series in minima.items()}
    baseline = arrays["transpose_012"]
    best_name = min(arrays, key=lambda name: float(arrays[name][train_mask].mean()))
    results: list[dict] = []
    for name, values in arrays.items():
        delta = values[test_mask] - baseline[test_mask]
        se = float(delta.std(ddof=1) / math.sqrt(len(delta)))
        z = float(delta.mean() / se) if se > 0 else 0.0
        results.append({
            "method": name,
            "selected_on_train": name == best_name,
            "training_blocks": int(train_mask.sum()),
            "heldout_blocks": int(test_mask.sum()),
            "train_mean_first_rank": float(values[train_mask].mean()),
            "test_mean_first_rank": float(values[test_mask].mean()),
            "test_speedup_vs_current": float((baseline[test_mask].mean() + 1.0) / (values[test_mask].mean() + 1.0)),
            "paired_test_delta": float(delta.mean()),
            "paired_z": z,
            "paired_p": normal_p(z),
        })
    return results


def learned_bucket_order(frame: pd.DataFrame) -> list[int]:
    pooled = frame.groupby("bucket", as_index=False)[["denominator", "hits"]].sum()
    base_rate = pooled.hits.sum() / pooled.denominator.sum()
    prior_mass = 50000.0
    pooled["score"] = (pooled.hits + base_rate * prior_mass) / (
        pooled.denominator + prior_mass
    )
    return [int(value) for value in pooled.sort_values(
        ["score", "bucket"], ascending=[False, True]
    ).bucket]


def paired_time_result(name: str, baseline: np.ndarray, candidate: np.ndarray) -> dict:
    delta = candidate.astype(np.float64) - baseline.astype(np.float64)
    se = float(delta.std(ddof=1) / math.sqrt(len(delta)))
    z = float(delta.mean() / se) if se > 0 else 0.0
    return {
        "feature": name,
        "replicate_blocks": int(len(delta)),
        "baseline_mean_seeds_to_first": float(baseline.mean() + 1.0),
        "candidate_mean_seeds_to_first": float(candidate.mean() + 1.0),
        "heldout_seed_evaluation_speedup": float((baseline.mean() + 1.0) / (candidate.mean() + 1.0)),
        "paired_delta": float(delta.mean()),
        "paired_z": z,
        "paired_p": normal_p(z),
    }


def analyze_learned_prefix_time(
    scan_dir: Path, subtree_dir: Path, features: pd.DataFrame,
    train_ranges: set[int],
) -> list[dict]:
    subtree_hits = pd.read_csv(subtree_dir / "hits.csv")
    subtree_hits = subtree_hits[
        (subtree_hits.stage == "charm_soul_perkeo")
        & (subtree_hits.seed.astype(str).str.len() == 8)
    ]
    char_to_digit = {char: index for index, char in enumerate(CHARS)}
    digits = np.array(
        [[char_to_digit[char] for char in seed[:6]] for seed in subtree_hits.seed.astype(str)],
        dtype=np.int16,
    )
    block_ids = (
        digits[:, 3].astype(np.int64)
        + 35 * digits[:, 4].astype(np.int64)
        + 35 ** 2 * digits[:, 5].astype(np.int64)
    )
    block_count = 35 ** 3
    block_size = 35 ** 3
    current_rank = (
        digits[:, 0].astype(np.int64)
        + 35 * digits[:, 1].astype(np.int64)
        + 35 ** 2 * digits[:, 2].astype(np.int64)
    )
    baseline = np.full(block_count, block_size, dtype=np.int64)
    np.minimum.at(baseline, block_ids, current_rank)

    character_data = pd.read_csv(scan_dir / "characters.csv")
    character_data = character_data[
        (character_data.stage == "charm_soul_perkeo")
        & (character_data.range.isin(train_ranges))
        & (character_data.position.isin([0, 1, 2]))
    ].copy()
    character_data["bucket"] = character_data.character.map(char_to_digit)
    results: list[dict] = []
    for position in [0, 1, 2]:
        order = learned_bucket_order(character_data[character_data.position == position])
        priority = np.empty(35, dtype=np.int64)
        for rank, bucket in enumerate(order):
            priority[bucket] = rank
        if position == 0:
            inner = digits[:, 1].astype(np.int64) + 35 * digits[:, 2].astype(np.int64)
        elif position == 1:
            inner = digits[:, 0].astype(np.int64) + 35 * digits[:, 2].astype(np.int64)
        else:
            inner = digits[:, 0].astype(np.int64) + 35 * digits[:, 1].astype(np.int64)
        rank = priority[digits[:, position]] * (35 ** 2) + inner
        first = np.full(block_count, block_size, dtype=np.int64)
        np.minimum.at(first, block_ids, rank)
        results.append(paired_time_result(f"display_position_{position}", baseline, first))

    stage_features = features[
        (features.stage == "charm_soul_perkeo")
        & (features.range.isin(train_ranges))
    ]
    for feature, bucket_values, group_size, inner in [
        (
            "prefix2",
            digits[:, 0].astype(np.int64) * 35 + digits[:, 1].astype(np.int64),
            35,
            digits[:, 2].astype(np.int64),
        ),
        (
            "prefix3",
            (digits[:, 0].astype(np.int64) * 35 + digits[:, 1].astype(np.int64)) * 35
            + digits[:, 2].astype(np.int64),
            1,
            np.zeros(len(digits), dtype=np.int64),
        ),
    ]:
        order = learned_bucket_order(stage_features[stage_features.feature == feature])
        priority = np.empty(max(order) + 1, dtype=np.int64)
        for rank_index, bucket in enumerate(order):
            priority[bucket] = rank_index
        rank = priority[bucket_values] * group_size + inner
        first = np.full(block_count, block_size, dtype=np.int64)
        np.minimum.at(first, block_ids, rank)
        results.append(paired_time_result(feature, baseline, first))
    for result in results:
        result["p_bonferroni"] = min(1.0, result["paired_p"] * len(results))
    return results


def analyze_learned_stride_time(
    subtree_dir: Path, features: pd.DataFrame, train_ranges: set[int],
) -> list[dict]:
    hits = pd.read_csv(subtree_dir / "hits.csv")
    hits = hits[hits.stage == "charm_soul_perkeo"]
    start = 2
    window_size = 1 << 20
    total_count = 1892332261
    window_count = total_count // window_size
    ids = hits.id.to_numpy(dtype=np.int64)
    window = (ids - start) // window_size
    keep = window < window_count
    ids = ids[keep]
    window = window[keep]
    offsets = (ids - start) % window_size
    baseline = np.full(window_count, window_size, dtype=np.int64)
    np.minimum.at(baseline, window, offsets)

    residue = features[
        (features.stage == "charm_soul_perkeo")
        & (features.feature == "id_mod_4096")
        & (features.range.isin(train_ranges))
    ]
    results: list[dict] = []
    for modulus in [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 4096]:
        collapsed = collapse_buckets(residue, modulus)
        order = learned_bucket_order(collapsed)
        priority = np.empty(modulus, dtype=np.int64)
        for rank_index, bucket in enumerate(order):
            priority[bucket] = rank_index
        residues = ids % modulus
        starts = (start + window * window_size) % modulus
        first_offsets = (residues - starts) % modulus
        within = (offsets - first_offsets) // modulus
        rank = priority[residues] * (window_size // modulus) + within
        candidate = np.full(window_count, window_size, dtype=np.int64)
        np.minimum.at(candidate, window, rank)
        results.append(paired_time_result(f"id_mod_{modulus}", baseline, candidate))
    for result in results:
        result["p_bonferroni"] = min(1.0, result["paired_p"] * len(results))
    return results


def json_safe(value):
    if isinstance(value, dict):
        return {key: json_safe(item) for key, item in value.items()}
    if isinstance(value, list):
        return [json_safe(item) for item in value]
    if isinstance(value, (np.integer,)):
        return int(value)
    if isinstance(value, (np.floating,)):
        return float(value)
    if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
        return None
    return value


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scan", type=Path, required=True)
    parser.add_argument("--balanced", type=Path, required=True)
    parser.add_argument("--subtree", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    train_ranges = {0, 1, 2, 3}
    test_ranges = {4, 5, 6, 7}

    summary, relationships, heterogeneity, summary_lines = analyze_summary(args.scan)
    character_results = analyze_characters(args.scan, train_ranges, test_ranges)
    features = load_selected_features(args.scan)
    feature_results = analyze_features(features, train_ranges, test_ranges)
    suffix_results = analyze_balanced_suffix(args.balanced)
    lag_results, block_results = analyze_lags_and_blocks(args.scan, summary, train_ranges, test_ranges)
    hamming, order_results = analyze_subtree(args.subtree)
    disjoint_order_results = analyze_disjoint_range_orders(args.scan)
    learned_prefix_time = analyze_learned_prefix_time(
        args.scan, args.subtree, features, train_ranges
    )
    learned_stride_time = analyze_learned_stride_time(
        args.subtree, features, train_ranges
    )

    rankings = character_results + feature_results + suffix_results
    valid_rankings = [item for item in rankings if item.get("valid")]
    family_test_count = len(valid_rankings)
    for item in valid_rankings:
        item["p_bonferroni_all_rankings"] = min(1.0, item["p"] * family_test_count)

    payload = {
        "training_ranges": sorted(train_ranges),
        "heldout_ranges": sorted(test_ranges),
        "summary": summary.to_dict(orient="records"),
        "conditional_relationships": relationships,
        "range_heterogeneity": heterogeneity,
        "rankings": rankings,
        "lags": lag_results,
        "blocks": block_results,
        "hamming": hamming,
        "enumeration_orders": order_results,
        "disjoint_range_enumeration_orders": disjoint_order_results,
        "learned_prefix_time_to_hit": learned_prefix_time,
        "learned_stride_time_to_hit": learned_stride_time,
    }
    with (args.output / "analysis.json").open("w", encoding="utf-8") as handle:
        json.dump(json_safe(payload), handle, indent=2)

    ranking_columns = [
        "family", "stage", "feature", "top_fraction", "buckets",
        "selected_buckets", "train_coverage", "test_coverage",
        "train_lift_vs_all", "test_lift_vs_all", "test_rr_vs_rest",
        "test_rr_ci_low", "test_rr_ci_high", "p",
        "p_bonferroni_all_rankings",
    ]
    pd.DataFrame(valid_rankings).reindex(columns=ranking_columns).to_csv(
        args.output / "ranking_summary.csv", index=False
    )

    csp_rankings = [
        item for item in valid_rankings
        if item["stage"] == "charm_soul_perkeo"
    ]
    csp_rankings.sort(key=lambda item: item["test_lift_vs_all"], reverse=True)
    selected_order = next(item for item in order_results if item["selected_on_train"])
    selected_disjoint_order = next(
        item for item in disjoint_order_results if item["selected_on_train"]
    )
    csp_blocks = [item for item in block_results if item["stage"] == "charm_soul_perkeo"]
    csp_lags = [item for item in lag_results if item["stage"] == "charm_soul_perkeo"]
    largest_lag = max(csp_lags, key=lambda item: abs(item["ratio"] - 1.0))

    report: list[str] = []
    report.append("# Balatro seed-structure held-out analysis")
    report.append("")
    report.append("## Pooled exact rates")
    report.append("")
    report.extend(f"- {line}" for line in summary_lines)
    csp_heterogeneity = next(
        item for item in heterogeneity if item["stage"] == "charm_soul_perkeo"
    )
    report.append(
        f"- Perkeo-opening rate across eight disjoint ranges: "
        f"{csp_heterogeneity['minimum_range_rate']:.7%}-{csp_heterogeneity['maximum_range_rate']:.7%}; "
        f"heterogeneity p={csp_heterogeneity['p']:.3g}."
    )
    report.append("")
    report.append("## Held-out ranking results (Charm+Soul+Perkeo)")
    report.append("")
    report.append("The first four 500M ranges selected each ranking; the final four disjoint 500M ranges measured it. Lifts below are hit-rate lifts in the prioritized region, before any throughput penalty.")
    report.append("")
    report.append("| Predictor | Held-out lift | 95% RR CI vs rest | Bonferroni p | Coverage |")
    report.append("|---|---:|---:|---:|---:|")
    for item in csp_rankings:
        if item.get("test_coverage", 0.0) < 0.80:
            continue
        report.append(
            f"| {item['family']} / {item['feature']} | {item['test_lift_vs_all']:.4f}x | "
            f"{item['test_rr_ci_low']:.4f}-{item['test_rr_ci_high']:.4f} | "
            f"{item['p_bonferroni_all_rankings']:.3g} | {item['test_coverage']:.1%} |"
        )
    report.append("")
    report.append("## Clustering and alternative enumeration")
    report.append("")
    report.append(
        f"- Largest tested sequential-lag ratio for the Perkeo opening was lag {largest_lag['lag']}: "
        f"{largest_lag['ratio']:.4f}x expected ({largest_lag['observed_pairs']:.0f} observed vs {largest_lag['expected_pairs']:.1f} expected)."
    )
    for item in csp_blocks:
        report.append(
            f"- Block {item['block_size']}: Fano {item['fano']:.4f} +/- {1.96 * item['fano_se_approx']:.4f}; "
            f"zero-block ratio {item['zero_ratio']:.4f}."
        )
    report.append(
        f"- One-character Hamming neighbors: {hamming['observed_hamming1_pairs']} observed vs "
        f"{hamming['expected_hamming1_pairs']:.1f} expected; ratio {hamming['ratio']:.4f}, z={hamming['z_poisson']:.2f}."
    )
    report.append(
        f"- Best transposed/Gray order selected on training blocks was {selected_order['method']}; "
        f"held-out speedup {selected_order['test_speedup_vs_current']:.4f}x, paired p={selected_order['paired_p']:.3g} "
        f"(12-order Bonferroni p={min(1.0, selected_order['paired_p'] * len(order_results)):.3g})."
    )
    report.append(
        f"- Independent validation across the 2B/2B disjoint ranges selected {selected_disjoint_order['method']}; "
        f"held-out speedup {selected_disjoint_order['test_speedup_vs_current']:.4f}x, paired p={selected_disjoint_order['paired_p']:.3g} "
        f"(12-order Bonferroni p={min(1.0, selected_disjoint_order['paired_p'] * len(disjoint_order_results)):.3g})."
    )
    report.append("- Independently held-out seed-evaluation time-to-first-hit for learned prefix rankings:")
    for item in learned_prefix_time:
        report.append(
            f"  - {item['feature']}: {item['heldout_seed_evaluation_speedup']:.4f}x, "
            f"Bonferroni p={item['p_bonferroni']:.3g}."
        )
    report.append("- Independently held-out seed-evaluation time-to-first-hit for learned stride rankings:")
    for item in learned_stride_time:
        report.append(
            f"  - {item['feature']}: {item['heldout_seed_evaluation_speedup']:.4f}x, "
            f"Bonferroni p={item['p_bonferroni']:.3g}."
        )
    report.append("")
    report.append("## Practical interpretation")
    report.append("")
    significant = [
        item for item in csp_rankings
        if item.get("test_coverage", 0.0) >= 0.80
        and item["p_bonferroni_all_rankings"] < 0.05
    ]
    if significant:
        report.append("At least one ranking survived the global held-out correction; inspect analysis.json before considering implementation.")
    else:
        report.append("No tested character, prefix/suffix, stride, or intermediate-state ranking survived the global held-out correction. Any theoretical ordering lift is therefore treated as noise, and sparse ordering would additionally sacrifice the current contiguous SIMD throughput.")
    report.append("The block and Hamming tests also show no effect large enough to support safe block skipping. A mathematically exact inverse/preimage method remains qualitatively different and is not ruled out by these statistical negatives.")
    (args.output / "analysis_report.md").write_text("\n".join(report) + "\n", encoding="utf-8")

    print("\n".join(report))


if __name__ == "__main__":
    main()
