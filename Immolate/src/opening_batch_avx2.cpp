#include "opening_batch_vector.hpp"

#include <immintrin.h>

namespace {

struct Avx2Backend {
  static constexpr int lanes = 4;
  using DoubleVector = __m256d;
  using IntegerVector = __m256i;
  using GatherIndices = std::array<int, lanes>;
  using Mask = __m256d;

  static DoubleVector set1(double value) { return _mm256_set1_pd(value); }
  static IntegerVector set1Integer(std::uint64_t value) {
    return _mm256_set1_epi64x(static_cast<long long>(value));
  }
  static DoubleVector add(DoubleVector a, DoubleVector b) {
    return _mm256_add_pd(a, b);
  }
  static DoubleVector sub(DoubleVector a, DoubleVector b) {
    return _mm256_sub_pd(a, b);
  }
  static DoubleVector mul(DoubleVector a, DoubleVector b) {
    return _mm256_mul_pd(a, b);
  }
  static DoubleVector div(DoubleVector a, DoubleVector b) {
    return _mm256_div_pd(a, b);
  }
  static DoubleVector floor(DoubleVector value) {
    return _mm256_floor_pd(value);
  }
  static Mask greater(DoubleVector a, DoubleVector b) {
    return _mm256_cmp_pd(a, b, _CMP_GT_OQ);
  }
  static Mask greaterEqual(DoubleVector a, DoubleVector b) {
    return _mm256_cmp_pd(a, b, _CMP_GE_OQ);
  }
  static Mask notEqual(DoubleVector a, DoubleVector b) {
    return _mm256_cmp_pd(a, b, _CMP_NEQ_OQ);
  }
  static int maskBits(Mask mask) { return _mm256_movemask_pd(mask); }
  static DoubleVector select(Mask mask, DoubleVector whenFalse,
                             DoubleVector whenTrue) {
    return _mm256_blendv_pd(whenFalse, whenTrue, mask);
  }
  static DoubleVector load(const double *values) {
    return _mm256_loadu_pd(values);
  }
  static void store(double *output, DoubleVector value) {
    _mm256_storeu_pd(output, value);
  }
  static IntegerVector asInteger(DoubleVector value) {
    return _mm256_castpd_si256(value);
  }
  static DoubleVector asDouble(IntegerVector value) {
    return _mm256_castsi256_pd(value);
  }
  static IntegerVector bitAnd(IntegerVector a, IntegerVector b) {
    return _mm256_and_si256(a, b);
  }
  static IntegerVector bitOr(IntegerVector a, IntegerVector b) {
    return _mm256_or_si256(a, b);
  }
  static IntegerVector bitXor(IntegerVector a, IntegerVector b) {
    return _mm256_xor_si256(a, b);
  }
  static IntegerVector subtractInteger(IntegerVector a, IntegerVector b) {
    return _mm256_sub_epi64(a, b);
  }
  static GatherIndices indices(const int *input, int valid) {
    const int last = input[valid - 1];
    return {input[0], valid > 1 ? input[1] : last,
            valid > 2 ? input[2] : last,
            valid > 3 ? input[3] : last};
  }
  static DoubleVector gather(const double *base,
                             const GatherIndices &indices) {
    const __m128i packedIndices = _mm_set_epi32(
        indices[3], indices[2], indices[1], indices[0]);
    return _mm256_i32gather_pd(base, packedIndices, sizeof(double));
  }
  static DoubleVector gatherByte(const std::uint8_t *base,
                                 const GatherIndices &indices) {
    const __m128i packedIndices = _mm_set_epi32(
        indices[3], indices[2], indices[1], indices[0]);
    const __m128i gathered = _mm_i32gather_epi32(
        reinterpret_cast<const int *>(base), packedIndices, 1);
    return _mm256_cvtepi32_pd(
        _mm_and_si128(gathered, _mm_set1_epi32(0xff)));
  }
  static DoubleVector gatherCharacter(const std::uint64_t *base,
                                      const GatherIndices &indices,
                                      int position) {
    const __m128i packedIndices = _mm_set_epi32(
        indices[3], indices[2], indices[1], indices[0]);
    const auto *positionBase = reinterpret_cast<const int *>(
        reinterpret_cast<const std::uint8_t *>(base) + position);
    const __m128i gathered = _mm_i32gather_epi32(
        positionBase, packedIndices, 8);
    return _mm256_cvtepi32_pd(
        _mm_and_si128(gathered, _mm_set1_epi32(0xff)));
  }
  template <int A, int B, int C, int maskShift>
  static IntegerVector advance(IntegerVector state) {
    const IntegerVector first = _mm256_srli_epi64(
        _mm256_xor_si256(_mm256_slli_epi64(state, A), state), B);
    const IntegerVector second = _mm256_slli_epi64(
        _mm256_and_si256(
            state, _mm256_set1_epi64x(static_cast<long long>(
                       BrainstormOpeningBatchDetail::allBits << maskShift))),
        C);
    return _mm256_xor_si256(first, second);
  }
  static IntegerVector luaRandomBits(
      IntegerVector state0, IntegerVector state1,
      IntegerVector state2, IntegerVector state3) {
    // Lua advances each Tausworthe word eleven times before combining the
    // low 52 bits into a double in [1, 2).
    for (int step = 0; step < 11; ++step) {
      state0 = advance<31, 45, 18, 1>(state0);
      state1 = advance<19, 30, 28, 6>(state1);
      state2 = advance<24, 48, 7, 9>(state2);
      state3 = advance<21, 39, 8, 17>(state3);
    }
    return _mm256_or_si256(
        _mm256_and_si256(
            _mm256_xor_si256(_mm256_xor_si256(state0, state1),
                             _mm256_xor_si256(state2, state3)),
            _mm256_set1_epi64x(static_cast<long long>(
                BrainstormOpeningBatchDetail::randomMantissa))),
        _mm256_set1_epi64x(static_cast<long long>(
            BrainstormOpeningBatchDetail::oneExponent)));
  }
};

} // namespace

void collectOpeningCharmSoulAvx2(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  auto &typedWorkspace = *static_cast<
      BrainstormOpeningBatchDetail::Workspace *>(workspace);
  BrainstormOpeningBatchDetail::collectVectorCandidates<Avx2Backend>(
      typedWorkspace, startSeedId, count, survivorOffsets);
}

void collectOpeningTagAvx2(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  auto &tagWorkspace = *static_cast<
      BrainstormOpeningBatchDetail::TagWorkspace *>(workspace);
  BrainstormOpeningBatchDetail::collectVectorTagCandidates<Avx2Backend>(
      tagWorkspace.vectorWorkspace, startSeedId, count,
      tagWorkspace.targetTagIndex, survivorOffsets);
}

#if defined(BRAINSTORM_OPENING_BATCH_TESTING)
void collectOpeningCharmSoulAvx2ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    bool sharedInitialHashes) {
  auto &typedWorkspace = *static_cast<
      BrainstormOpeningBatchDetail::Workspace *>(workspace);
  if (sharedInitialHashes) {
    BrainstormOpeningBatchDetail::collectVectorCandidates<Avx2Backend, true>(
        typedWorkspace, startSeedId, count, survivorOffsets);
  } else {
    BrainstormOpeningBatchDetail::collectVectorCandidates<Avx2Backend, false>(
        typedWorkspace, startSeedId, count, survivorOffsets);
  }
}

void collectOpeningCharmSoulInitialHashesAvx2ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<double> &hashedSeeds, std::vector<double> &tagSeedHashes) {
  auto &typedWorkspace = *static_cast<
      BrainstormOpeningBatchDetail::Workspace *>(workspace);
  typedWorkspace.prepare(count);
  BrainstormOpeningBatchDetail::fillChunk(
      typedWorkspace.seeds, startSeedId, count);
  BrainstormOpeningBatchDetail::vectorInitialTagRollsShared<Avx2Backend>(
      typedWorkspace.seeds, count, typedWorkspace.rolls, &tagSeedHashes);
  hashedSeeds = typedWorkspace.seeds.hashedSeeds;
}

void round13PositiveAvx2ForTesting(
    const std::vector<double> &inputs, std::vector<double> &outputs) {
  outputs.resize(inputs.size());
  alignas(32) double inputLanes[Avx2Backend::lanes];
  alignas(32) double outputLanes[Avx2Backend::lanes];
  for (std::size_t offset = 0; offset < inputs.size();
       offset += Avx2Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Avx2Backend::lanes, inputs.size() - offset));
    for (int lane = 0; lane < Avx2Backend::lanes; ++lane) {
      inputLanes[lane] = inputs[
          offset + static_cast<std::size_t>(lane < valid ? lane : 0)];
    }
    const auto rounded =
        BrainstormOpeningBatchDetail::vectorRound13Positive<Avx2Backend>(
            Avx2Backend::load(inputLanes));
    Avx2Backend::store(outputLanes, rounded);
    for (int lane = 0; lane < valid; ++lane) {
      outputs[offset + static_cast<std::size_t>(lane)] = outputLanes[lane];
    }
  }
}
#endif
