"""Bounded diagnostic: exact IEEE-754/bit-vector inversion of initial Tag1.

This is intentionally isolated from production.  It asks Z3 for a fixed-length
Balatro seed whose *initial* (pre-lock-resample) Tag1 roll is Charm (index 10).
Every floating-point operation is represented at binary64/RNE precision; the
Lua Tausworthe state transition is represented as 64-bit bit-vector logic.
"""

from __future__ import annotations

import argparse
import struct
import time

import z3


F64 = z3.Float64()
RNE = z3.RNE()
RNA = z3.RNA()
RTN = z3.RTN()


def f64(value: float) -> z3.FPRef:
    bits = struct.unpack(">Q", struct.pack(">d", value))[0]
    return z3.fpBVToFP(z3.BitVecVal(bits, 64), F64)


HASH_A = f64(1.1239285023)
HASH_PI = 3.141592653589793116
NODE_MULTIPLIER = f64(1.72431234)
NODE_ADDEND = f64(2.134453429141)
INV_PREC = f64(10.0**13)
TWO_INV_PREC = f64(2.0**13)
FIVE_INV_PREC = f64(5.0**13)
ONE = f64(1.0)
HALF = f64(0.5)


def fp_floor(value: z3.FPRef) -> z3.FPRef:
    return z3.fpRoundToIntegral(RTN, value)


def fract_positive(value: z3.FPRef) -> z3.FPRef:
    return z3.fpSub(RNE, value, fp_floor(value))


def pseudostep(value: z3.FPRef, character: z3.FPRef, position: int) -> z3.FPRef:
    result = z3.fpDiv(RNE, HASH_A, value)
    result = z3.fpMul(RNE, result, character)
    result = z3.fpMul(RNE, result, f64(HASH_PI))
    # Production constant-folds this multiplication before the final add.
    result = z3.fpAdd(RNE, result, f64(HASH_PI * float(position)))
    return fract_positive(result)


def nextafter_toward_negative(value: z3.FPRef) -> z3.FPRef:
    bits = z3.fpToIEEEBV(value)
    previous = z3.If(
        z3.fpIsZero(value),
        z3.BitVecVal(0x8000000000000001, 64),
        bits - z3.BitVecVal(1, 64),
    )
    return z3.fpBVToFP(previous, F64)


def round13(value: z3.FPRef) -> z3.FPRef:
    scaled = z3.fpMul(RNE, value, INV_PREC)
    normal = z3.fpDiv(RNE, z3.fpRoundToIntegral(RNA, scaled), INV_PREC)

    previous = nextafter_toward_negative(value)
    previous_scaled = z3.fpMul(RNE, previous, INV_PREC)
    previous_normal = z3.fpDiv(
        RNE, z3.fpRoundToIntegral(RNA, previous_scaled), INV_PREC
    )

    truncated = z3.fpMul(
        RNE, fract_positive(z3.fpMul(RNE, value, TWO_INV_PREC)), FIVE_INV_PREC
    )
    rounded_integer = z3.If(
        z3.fpGEQ(fract_positive(truncated), HALF),
        z3.fpAdd(RNE, fp_floor(scaled), ONE),
        fp_floor(scaled),
    )
    fallback = z3.fpDiv(RNE, rounded_integer, INV_PREC)
    return z3.If(z3.fpEQ(normal, previous_normal), normal, fallback)


def advance_node(value: z3.FPRef) -> z3.FPRef:
    value = z3.fpMul(RNE, value, NODE_MULTIPLIER)
    value = z3.fpAdd(RNE, value, NODE_ADDEND)
    return round13(fract_positive(value))


def advance_word(value: z3.BitVecRef, recurrence: int) -> z3.BitVecRef:
    parameters = ((31, 45, 18, 1), (19, 30, 28, 6),
                  (24, 48, 7, 9), (21, 39, 8, 17))
    a, b, c, mask_shift = parameters[recurrence]
    mask = ((1 << 64) - 1) << mask_shift & ((1 << 64) - 1)
    return z3.LShR((value << a) ^ value, b) ^ ((value & mask) << c)


def lua_mantissa(seed: z3.FPRef) -> z3.BitVecRef:
    d = seed
    masks = (1 << 1, 1 << 6, 1 << 9, 1 << 17)
    states: list[z3.BitVecRef] = []
    for minimum in masks:
        d = z3.fpAdd(RNE, z3.fpMul(RNE, d, f64(3.14159265358979323846)),
                     f64(2.7182818284590452354))
        bits = z3.fpToIEEEBV(d)
        states.append(z3.If(z3.ULT(bits, minimum), bits + minimum, bits))
    outputs: list[z3.BitVecRef] = []
    for recurrence, state in enumerate(states):
        for _ in range(11):
            state = advance_word(state, recurrence)
        outputs.append(state)
    combined = outputs[0] ^ outputs[1] ^ outputs[2] ^ outputs[3]
    return combined & z3.BitVecVal((1 << 52) - 1, 64)


def symbolic_ascii(name: str) -> tuple[z3.BitVecRef, z3.FPRef]:
    digit = z3.BitVec(name, 8)
    ascii_code = z3.If(z3.ULE(digit, 8), digit + 49, digit + 56)
    return digit, z3.fpUnsignedToFP(RNE, ascii_code, F64)


def build_initial_charm(
    length: int, fixed_digit: int | None = None, max_digit: int = 34,
    logic: str = "default",
) -> tuple[z3.Solver, list[z3.BitVecRef]]:
    solver = z3.Solver() if logic == "default" else z3.SolverFor("QF_FPBV")
    digits: list[z3.BitVecRef] = []
    characters: list[z3.FPRef] = []
    for position in range(length):
        digit, character = symbolic_ascii(f"d{position}")
        solver.add(z3.ULE(digit, max_digit))
        if fixed_digit is not None and position == 0:
            solver.add(digit == fixed_digit)
        digits.append(digit)
        characters.append(character)

    hashed = ONE
    tag_seed_hash = ONE
    for position, character in enumerate(characters):
        hashed = pseudostep(hashed, character, length - position)
        tag_seed_hash = pseudostep(tag_seed_hash, character, 4 + length - position)

    tag_value = tag_seed_hash
    for key_index, character in reversed(list(enumerate(b"Tag1", start=1))):
        tag_value = pseudostep(tag_value, f64(float(character)), key_index)
    tag_value = advance_node(tag_value)
    lua_seed = z3.fpMul(RNE, z3.fpAdd(RNE, tag_value, hashed), HALF)
    mantissa = lua_mantissa(lua_seed)

    # floor(mantissa * 24 / 2^52) == 10, without any FP approximation.
    scaled = mantissa * z3.BitVecVal(24, 64)
    solver.add(z3.UGE(scaled, z3.BitVecVal(10 << 52, 64)))
    solver.add(z3.ULT(scaled, z3.BitVecVal(11 << 52, 64)))
    return solver, digits


def decode_seed(model: z3.ModelRef, digits: list[z3.BitVecRef]) -> str:
    alphabet = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    # Seed's internal array is right-to-left.
    return "".join(alphabet[model.eval(d).as_long()] for d in reversed(digits))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--length", type=int, default=8)
    parser.add_argument("--timeout-ms", type=int, default=15000)
    parser.add_argument("--fix-digit", type=int)
    parser.add_argument("--max-digit", type=int, default=34)
    parser.add_argument("--logic", choices=("default", "qffpbv"),
                        default="default")
    args = parser.parse_args()
    if not 1 <= args.length <= 8:
        raise SystemExit("length must be 1..8")

    build_start = time.perf_counter()
    solver, digits = build_initial_charm(
        args.length, args.fix_digit, args.max_digit, args.logic
    )
    build_seconds = time.perf_counter() - build_start
    solver.set(timeout=args.timeout_ms)
    solve_start = time.perf_counter()
    result = solver.check()
    solve_seconds = time.perf_counter() - solve_start
    print(
        f"length={args.length} result={result} build_s={build_seconds:.6f} "
        f"solve_s={solve_seconds:.6f} assertions={len(solver.assertions())}"
    )
    if result == z3.sat:
        print(f"seed={decode_seed(solver.model(), digits)}")
    elif result == z3.unknown:
        print(f"reason={solver.reason_unknown()}")
    print(f"statistics={solver.statistics()}")


if __name__ == "__main__":
    main()
