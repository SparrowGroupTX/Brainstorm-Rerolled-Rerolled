import argparse
import ctypes
import os
from pathlib import Path
import time


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Call Immolate.dll brainstorm() for bounded profiling runs."
    )
    parser.add_argument("--dll", required=True, help="Path to Immolate.dll")
    parser.add_argument("--seed", default="KY9AZX31")
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


def as_bytes(value: str) -> bytes:
    return value.encode("utf-8")


def main() -> int:
    args = parse_args()
    dll_path = Path(args.dll).resolve()
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

    started_at = time.perf_counter()
    result_ptr = brainstorm(
        as_bytes(args.seed),
        as_bytes(args.voucher),
        as_bytes(args.pack),
        as_bytes(args.tag),
        args.souls,
        args.observatory,
        args.perkeo,
        args.copymoney,
        args.retcon,
        args.bean,
        args.burglar,
        as_bytes(args.custom_filter),
        as_bytes(args.target_rank),
        as_bytes(args.target_suit),
        args.specific_rank_min,
        args.any_rank_min,
    )
    elapsed_ms = (time.perf_counter() - started_at) * 1000.0

    if not result_ptr:
        print(f"elapsed_ms: {elapsed_ms:.3f}")
        print("result: <null>")
        return 1

    result = ctypes.string_at(result_ptr).decode("utf-8")
    free_result(result_ptr)
    print(f"elapsed_ms: {elapsed_ms:.3f}")
    print(f"result: {result!r}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
