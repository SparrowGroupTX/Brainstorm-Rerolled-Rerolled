#include "opening_batch_vector.hpp"

#include <immintrin.h>

namespace {

struct Avx512Backend {
  static constexpr int lanes = 8;
  using DoubleVector = __m512d;
  using IntegerVector = __m512i;
  using GatherIndices = std::array<int, lanes>;
  using Mask = __mmask8;

  static DoubleVector set1(double value) { return _mm512_set1_pd(value); }
  static IntegerVector set1Integer(std::uint64_t value) {
    return _mm512_set1_epi64(static_cast<long long>(value));
  }
  static DoubleVector add(DoubleVector a, DoubleVector b) {
    return _mm512_add_pd(a, b);
  }
  static DoubleVector sub(DoubleVector a, DoubleVector b) {
    return _mm512_sub_pd(a, b);
  }
  static DoubleVector mul(DoubleVector a, DoubleVector b) {
    return _mm512_mul_pd(a, b);
  }
  static DoubleVector div(DoubleVector a, DoubleVector b) {
    return _mm512_div_pd(a, b);
  }
  static DoubleVector floor(DoubleVector value) {
    return _mm512_roundscale_pd(
        value, _MM_FROUND_TO_NEG_INF | _MM_FROUND_NO_EXC);
  }
  static DoubleVector round13Divide(DoubleVector numerator) {
    const DoubleVector reciprocal = _mm512_set1_pd(1.0e-13);
    const DoubleVector quotient = _mm512_mul_pd(numerator, reciprocal);
    const DoubleVector residual = _mm512_fnmadd_pd(
        quotient, _mm512_set1_pd(10000000000000.0), numerator);
    return _mm512_fmadd_pd(residual, reciprocal, quotient);
  }
  static Mask greater(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_GT_OQ);
  }
  static Mask greaterEqual(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_GE_OQ);
  }
  static Mask notEqual(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_NEQ_OQ);
  }
  static int maskBits(Mask mask) { return static_cast<int>(mask); }
  static DoubleVector select(Mask mask, DoubleVector whenFalse,
                             DoubleVector whenTrue) {
    return _mm512_mask_blend_pd(mask, whenFalse, whenTrue);
  }
  static DoubleVector load(const double *values) {
    return _mm512_loadu_pd(values);
  }
  static void store(double *output, DoubleVector value) {
    _mm512_storeu_pd(output, value);
  }
  static void storeInteger(std::uint64_t *output, IntegerVector value) {
    _mm512_storeu_si512(output, value);
  }
  static IntegerVector asInteger(DoubleVector value) {
    return _mm512_castpd_si512(value);
  }
  static DoubleVector asDouble(IntegerVector value) {
    return _mm512_castsi512_pd(value);
  }
  static IntegerVector bitAnd(IntegerVector a, IntegerVector b) {
    return _mm512_and_si512(a, b);
  }
  static IntegerVector bitOr(IntegerVector a, IntegerVector b) {
    return _mm512_or_si512(a, b);
  }
  static IntegerVector bitXor(IntegerVector a, IntegerVector b) {
    return _mm512_xor_si512(a, b);
  }
  static IntegerVector subtractInteger(IntegerVector a, IntegerVector b) {
    return _mm512_sub_epi64(a, b);
  }
  static GatherIndices indices(const int *input, int valid) {
    const int last = input[valid - 1];
    return {input[0], valid > 1 ? input[1] : last,
            valid > 2 ? input[2] : last,
            valid > 3 ? input[3] : last,
            valid > 4 ? input[4] : last,
            valid > 5 ? input[5] : last,
            valid > 6 ? input[6] : last,
            valid > 7 ? input[7] : last};
  }
  static DoubleVector gather(const double *base,
                             const GatherIndices &indices) {
    const __m256i packedIndices = _mm256_set_epi32(
        indices[7], indices[6], indices[5], indices[4],
        indices[3], indices[2], indices[1], indices[0]);
    return _mm512_i32gather_pd(packedIndices, base, sizeof(double));
  }
  static DoubleVector gatherByte(const std::uint8_t *base,
                                 const GatherIndices &indices) {
    const __m256i packedIndices = _mm256_set_epi32(
        indices[7], indices[6], indices[5], indices[4],
        indices[3], indices[2], indices[1], indices[0]);
    const __m256i gathered = _mm256_i32gather_epi32(
        reinterpret_cast<const int *>(base), packedIndices, 1);
    return _mm512_cvtepi32_pd(
        _mm256_and_si256(gathered, _mm256_set1_epi32(0xff)));
  }
  static DoubleVector gatherCharacter(const std::uint64_t *base,
                                      const GatherIndices &indices,
                                      int position) {
    const __m256i packedIndices = _mm256_set_epi32(
        indices[7], indices[6], indices[5], indices[4],
        indices[3], indices[2], indices[1], indices[0]);
    const auto *positionBase = reinterpret_cast<const int *>(
        reinterpret_cast<const std::uint8_t *>(base) + position);
    const __m256i gathered = _mm256_i32gather_epi32(
        positionBase, packedIndices, 8);
    return _mm512_cvtepi32_pd(
        _mm256_and_si256(gathered, _mm256_set1_epi32(0xff)));
  }
  template <int A, int B, int C, int maskShift>
  static IntegerVector advance(IntegerVector state) {
    const IntegerVector first = _mm512_srli_epi64(
        _mm512_xor_si512(_mm512_slli_epi64(state, A), state), B);
    const IntegerVector second = _mm512_slli_epi64(
        _mm512_and_si512(
            state, _mm512_set1_epi64(static_cast<long long>(
                       BrainstormOpeningBatchDetail::allBits << maskShift))),
        C);
    return _mm512_xor_si512(first, second);
  }
  template <int shift>
  static IntegerVector addLeftMasked(
      IntegerVector result, IntegerVector value, std::uint64_t mask) {
    return _mm512_ternarylogic_epi64(
        result, _mm512_slli_epi64(value, shift),
        _mm512_set1_epi64(static_cast<long long>(mask)), 0x78);
  }
  template <int shift>
  static IntegerVector addRightMasked(
      IntegerVector result, IntegerVector value, std::uint64_t mask) {
    return _mm512_ternarylogic_epi64(
        result, _mm512_srli_epi64(value, shift),
        _mm512_set1_epi64(static_cast<long long>(mask)), 0x78);
  }
  template <int recurrence>
  static IntegerVector jump11Mantissa(IntegerVector value) {
    // Mechanically synthesized GF(2) transforms for exactly the low 52 bits
    // Lua retains after eleven Tausworthe recurrences. Restricting the output
    // avoids materializing intermediate state bits that are discarded.
    IntegerVector result = _mm512_setzero_si512();
    if constexpr (recurrence == 0) {
      result = addLeftMasked<40>(result, value, 0x000ffe0000000000ull);
      result = addLeftMasked<38>(result, value, 0x000fff8000000000ull);
      result = addLeftMasked<9>(result, value, 0x000ffffffffffc00ull);
      result = addLeftMasked<8>(result, value, 0x000ffe0000000000ull);
      result = addLeftMasked<7>(result, value, 0x000fffffffffff00ull);
      result = addLeftMasked<6>(result, value, 0x0000007fffffff80ull);
      result = addRightMasked<23>(result, value, 0x000001fffffffc00ull);
      result = addRightMasked<25>(result, value, 0x0000007fffffff00ull);
      result = addRightMasked<26>(result, value, 0x000000000000007full);
      result = addRightMasked<54>(result, value, 0x00000000000003ffull);
      result = addRightMasked<56>(result, value, 0x00000000000000ffull);
      result = addRightMasked<57>(result, value, 0x000000000000007full);
    } else if constexpr (recurrence == 1) {
      result = addLeftMasked<37>(result, value, 0x000ff80000000000ull);
      result = addLeftMasked<36>(result, value, 0x000ffc0000000000ull);
      result = addLeftMasked<35>(result, value, 0x000ffe0000000000ull);
      result = addLeftMasked<18>(result, value, 0x000fffffff000000ull);
      result = addLeftMasked<16>(result, value, 0x000fffffffc00000ull);
      result = addRightMasked<2>(result, value, 0x000007fffffffff0ull);
      result = addRightMasked<3>(result, value, 0x000003fffffffff8ull);
      result = addRightMasked<4>(result, value, 0x000001fffffffffcull);
      result = addRightMasked<21>(result, value, 0x000007ffff000000ull);
      result = addRightMasked<22>(result, value, 0x000003ffffffffffull);
      result = addRightMasked<23>(result, value, 0x000001ffffc00000ull);
      result = addRightMasked<40>(result, value, 0x0000000000ffffffull);
      result = addRightMasked<41>(result, value, 0x000000000000000full);
      result = addRightMasked<42>(result, value, 0x00000000003ffff8ull);
      result = addRightMasked<43>(result, value, 0x0000000000000003ull);
      result = addRightMasked<60>(result, value, 0x000000000000000full);
      result = addRightMasked<61>(result, value, 0x0000000000000007ull);
      result = addRightMasked<62>(result, value, 0x0000000000000003ull);
    } else if constexpr (recurrence == 2) {
      result = addLeftMasked<22>(result, value, 0x000fffff80000000ull);
      result = addLeftMasked<15>(result, value, 0x000fffffff000000ull);
      result = addRightMasked<9>(result, value, 0x000fffff80000000ull);
      result = addRightMasked<16>(result, value, 0x0000000000ffffffull);
      result = addRightMasked<33>(result, value, 0x000000007fffffffull);
      result = addRightMasked<40>(result, value, 0x0000000000ffffffull);
    } else {
      result = addLeftMasked<10>(result, value, 0x000ffffff8000000ull);
      result = addRightMasked<6>(result, value, 0x000ffffffffff800ull);
      result = addRightMasked<11>(result, value, 0x000fffffffffffc0ull);
      result = addRightMasked<16>(result, value, 0x0000000007fffffeull);
      result = addRightMasked<32>(result, value, 0x00000000000007ffull);
      result = addRightMasked<37>(result, value, 0x0000000007ffffc0ull);
      result = addRightMasked<42>(result, value, 0x0000000000000001ull);
      result = addRightMasked<53>(result, value, 0x00000000000007ffull);
      result = addRightMasked<58>(result, value, 0x000000000000003full);
      result = addRightMasked<63>(result, value, 0x0000000000000001ull);
    }
    return result;
  }
  static IntegerVector luaRandomBits(
      IntegerVector state0, IntegerVector state1,
      IntegerVector state2, IntegerVector state3) {
    const IntegerVector output0 = jump11Mantissa<0>(state0);
    const IntegerVector output1 = jump11Mantissa<1>(state1);
    const IntegerVector output2 = jump11Mantissa<2>(state2);
    const IntegerVector output3 = jump11Mantissa<3>(state3);
    const IntegerVector firstThree = _mm512_ternarylogic_epi64(
        output0, output1, output2, 0x96);
    const IntegerVector combined = _mm512_xor_si512(firstThree, output3);
    return _mm512_or_si512(
        combined, _mm512_set1_epi64(static_cast<long long>(
            BrainstormOpeningBatchDetail::oneExponent)));
  }
  static IntegerVector luaRandomHighPrefix(
      IntegerVector state0, IntegerVector state1,
      IntegerVector state2, IntegerVector state3) {
    // Only mantissa bits 43..51 are needed for the staged opening-tag
    // classifier. These are the exact restricted GF(2) transforms after the
    // same eleven Tausworthe advances as luaRandomBits().
    const IntegerVector output0a = _mm512_ternarylogic_epi64(
        _mm512_slli_epi64(state0, 40), _mm512_slli_epi64(state0, 38),
        _mm512_slli_epi64(state0, 9), 0x96);
    const IntegerVector output0b = _mm512_xor_si512(
        _mm512_slli_epi64(state0, 8), _mm512_slli_epi64(state0, 7));
    const IntegerVector output1a = _mm512_ternarylogic_epi64(
        _mm512_slli_epi64(state1, 37), _mm512_slli_epi64(state1, 36),
        _mm512_slli_epi64(state1, 35), 0x96);
    const IntegerVector output1b = _mm512_xor_si512(
        _mm512_slli_epi64(state1, 18), _mm512_slli_epi64(state1, 16));
    const IntegerVector output2 = _mm512_ternarylogic_epi64(
        _mm512_slli_epi64(state2, 22), _mm512_slli_epi64(state2, 15),
        _mm512_srli_epi64(state2, 9), 0x96);
    const IntegerVector output3 = _mm512_ternarylogic_epi64(
        _mm512_slli_epi64(state3, 10), _mm512_srli_epi64(state3, 6),
        _mm512_srli_epi64(state3, 11), 0x96);
    const IntegerVector first = _mm512_ternarylogic_epi64(
        output0a, output0b, output1a, 0x96);
    const IntegerVector second = _mm512_ternarylogic_epi64(
        output1b, output2, output3, 0x96);
    return _mm512_and_si512(
        _mm512_xor_si512(first, second),
        _mm512_set1_epi64(0x000ff80000000000ll));
  }
};

} // namespace

void collectOpeningCharmSoulAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  auto &typedWorkspace = *static_cast<
      BrainstormOpeningBatchDetail::Workspace *>(workspace);
  if (typedWorkspace.criteria.legendaryIndex >= 0) {
    BrainstormOpeningBatchDetail::
        collectVectorCandidatesLegendaryFirst<Avx512Backend>(
            typedWorkspace, startSeedId, count, survivorOffsets);
  } else {
    BrainstormOpeningBatchDetail::collectVectorCandidates<Avx512Backend>(
        typedWorkspace, startSeedId, count, survivorOffsets);
  }
}

void collectOpeningTagAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  auto &tagWorkspace = *static_cast<
      BrainstormOpeningBatchDetail::TagWorkspace *>(workspace);
  BrainstormOpeningBatchDetail::collectVectorTagCandidates<Avx512Backend>(
      tagWorkspace.vectorWorkspace, startSeedId, count,
      tagWorkspace.targetTagIndex, survivorOffsets);
}

#if defined(BRAINSTORM_OPENING_BATCH_TESTING)
void collectOpeningCharmSoulAvx512ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    bool sharedInitialHashes) {
  auto &typedWorkspace = *static_cast<
      BrainstormOpeningBatchDetail::Workspace *>(workspace);
  if (sharedInitialHashes) {
    BrainstormOpeningBatchDetail::collectVectorCandidates<Avx512Backend, true>(
        typedWorkspace, startSeedId, count, survivorOffsets);
  } else {
    BrainstormOpeningBatchDetail::collectVectorCandidates<Avx512Backend, false>(
        typedWorkspace, startSeedId, count, survivorOffsets);
  }
}

void collectOpeningCharmSoulInitialHashesAvx512ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<double> &hashedSeeds, std::vector<double> &tagSeedHashes) {
  auto &typedWorkspace = *static_cast<
      BrainstormOpeningBatchDetail::Workspace *>(workspace);
  typedWorkspace.prepare(count);
  BrainstormOpeningBatchDetail::fillChunk(
      typedWorkspace.seeds, startSeedId, count);
  BrainstormOpeningBatchDetail::vectorInitialTagRollsShared<Avx512Backend>(
      typedWorkspace.seeds, count, typedWorkspace.rolls, &tagSeedHashes);
  hashedSeeds = typedWorkspace.seeds.hashedSeeds;
}

void round13PositiveAvx512ForTesting(
    const std::vector<double> &inputs, std::vector<double> &outputs) {
  outputs.resize(inputs.size());
  alignas(64) double inputLanes[Avx512Backend::lanes];
  alignas(64) double outputLanes[Avx512Backend::lanes];
  for (std::size_t offset = 0; offset < inputs.size();
       offset += Avx512Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Avx512Backend::lanes, inputs.size() - offset));
    for (int lane = 0; lane < Avx512Backend::lanes; ++lane) {
      inputLanes[lane] = inputs[
          offset + static_cast<std::size_t>(lane < valid ? lane : 0)];
    }
    const auto rounded =
        BrainstormOpeningBatchDetail::vectorRound13Positive<Avx512Backend>(
            Avx512Backend::load(inputLanes));
    Avx512Backend::store(outputLanes, rounded);
    for (int lane = 0; lane < valid; ++lane) {
      outputs[offset + static_cast<std::size_t>(lane)] = outputLanes[lane];
    }
  }
}
#endif
