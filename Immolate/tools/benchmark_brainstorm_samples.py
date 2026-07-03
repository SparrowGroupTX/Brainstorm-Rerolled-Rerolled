import argparse
import ctypes
import os
import random
import statistics
import time
from pathlib import Path


SEED_CHARS = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Benchmark brainstorm() across many starting seeds."
    )
    parser.add_argument("--dll", required=True, help="Path to Immolate.dll")
    parser.add_argument("--samples", type=int, default=12)
    parser.add_argument("--seed-rng", type=int, default=1337)
    parser.add_argument("--seed-length", type=int, default=8)
    parser.add_argument("--show-each", action="store_true")
    parser.add_argument("--seed", default=None, help="Optional fixed start seed")
    parser.add_argument("--voucher", default="RETRY")
    parser.add_argument("--pack", default="RETRY")
    parser.add_argument("--tag", default="RETRY")
    parser.add_argument("--souls", type=float, default=0.0)
    parser.add_argument("--observatory", action="store_true")
    parser.add_argument("--perkeo", action="store_true")
    parser.add_argument("--copymoney", action="store_true")
    parser.add_argument("--retcon", action="store_true")
    parser.add_argument("--bean", action="store_true")
    parser.add_argument("--burglar", action="store_true")
    parser.add_argument("--custom-filter", default="No Filter")
    parser.add_argument("--target-rank", default="King")
    parser.add_argument("--target-suit", default="Any Suit")
    parser.add_argument("--specific-rank-min", type=int, default=0)
    parser.add_argument("--any-rank-min", type=int, default=0)
    return parser.parse_args()


def encode(value: str) -> bytes:
    return value.encode("utf-8")


def setup_dll(dll_path: Path):
    os.add_dll_directory(str(dll_path.parent))
    mingw_bin = Path.home() / "scoop" / "apps" / "mingw-winlibs" / "current" / "bin"
    if mingw_bin.exists():
        os.add_dll_directory(str(mingw_bin))

    dll = ctypes.CDLL(str(dll_path))
    brainstorm = dll.brainstorm
    brainstorm.argtypes = [
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_double,
        ctypes.c_bool,
        ctypes.c_bool,
        ctypes.c_bool,
        ctypes.c_bool,
        ctypes.c_bool,
        ctypes.c_bool,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_int,
    ]
    brainstorm.restype = ctypes.c_void_p
    free_result = dll.free_result
    free_result.argtypes = [ctypes.c_void_p]
    free_result.restype = None
    return brainstorm, free_result


def random_seed(rng: random.Random, length: int) -> str:
    return "".join(rng.choice(SEED_CHARS) for _ in range(length))


def percentile(sorted_values: list[float], pct: float) -> float:
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return sorted_values[0]
    index = (len(sorted_values) - 1) * pct
    lower = int(index)
    upper = min(lower + 1, len(sorted_values) - 1)
    weight = index - lower
    return sorted_values[lower] * (1 - weight) + sorted_values[upper] * weight


def main() -> int:
    args = parse_args()
    dll_path = Path(args.dll).resolve()
    brainstorm, free_result = setup_dll(dll_path)

    rng = random.Random(args.seed_rng)
    seeds = []
    if args.seed is not None:
        seeds = [args.seed for _ in range(args.samples)]
    else:
        seeds = [random_seed(rng, args.seed_length) for _ in range(args.samples)]

    times_ms: list[float] = []
    results: list[str] = []

    for start_seed in seeds:
        started = time.perf_counter()
        result_ptr = brainstorm(
            encode(start_seed),
            encode(args.voucher),
            encode(args.pack),
            encode(args.tag),
            args.souls,
            args.observatory,
            args.perkeo,
            args.copymoney,
            args.retcon,
            args.bean,
            args.burglar,
            encode(args.custom_filter),
            encode(args.target_rank),
            encode(args.target_suit),
            args.specific_rank_min,
            args.any_rank_min,
        )
        elapsed_ms = (time.perf_counter() - started) * 1000.0
        result = ""
        if result_ptr:
            result = ctypes.string_at(result_ptr).decode("utf-8")
            free_result(result_ptr)
        times_ms.append(elapsed_ms)
        results.append(result)
        if args.show_each:
            print(f"sample seed={start_seed} elapsed_ms={elapsed_ms:.3f} result={result!r}")

    sorted_times = sorted(times_ms)
    print(f"samples: {len(times_ms)}")
    print(f"mean_ms: {statistics.mean(times_ms):.3f}")
    print(f"median_ms: {statistics.median(times_ms):.3f}")
    print(f"min_ms: {min(times_ms):.3f}")
    print(f"max_ms: {max(times_ms):.3f}")
    print(f"p90_ms: {percentile(sorted_times, 0.90):.3f}")
    print(f"p95_ms: {percentile(sorted_times, 0.95):.3f}")
    print(
        f"mean_seeds_per_sec: {statistics.mean((1.0 / (t / 1000.0)) for t in times_ms if t > 0):.2f}"
    )
    unique_results = len({r for r in results if r})
    print(f"unique_nonempty_results: {unique_results}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
