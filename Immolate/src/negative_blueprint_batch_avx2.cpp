#include "negative_blueprint_batch_vector.hpp"

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
  static Mask less(DoubleVector a, DoubleVector b) {
    return _mm256_cmp_pd(a, b, _CMP_LT_OQ);
  }
  static Mask lessEqual(DoubleVector a, DoubleVector b) {
    return _mm256_cmp_pd(a, b, _CMP_LE_OQ);
  }
  static Mask notEqual(DoubleVector a, DoubleVector b) {
    return _mm256_cmp_pd(a, b, _CMP_NEQ_OQ);
  }
  static Mask maskAnd(Mask a, Mask b) {
    return _mm256_and_pd(a, b);
  }
  static Mask maskOr(Mask a, Mask b) {
    return _mm256_or_pd(a, b);
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
    const __m128i packed = _mm_set_epi32(
        indices[3], indices[2], indices[1], indices[0]);
    return _mm256_i32gather_pd(base, packed, sizeof(double));
  }
  static DoubleVector gatherByte(const std::uint8_t *base,
                                 const GatherIndices &indices) {
    const __m128i packed = _mm_set_epi32(
        indices[3], indices[2], indices[1], indices[0]);
    const __m128i gathered = _mm_i32gather_epi32(
        reinterpret_cast<const int *>(base), packed, 1);
    return _mm256_cvtepi32_pd(
        _mm_and_si128(gathered, _mm_set1_epi32(0xff)));
  }
  static DoubleVector gatherCharacter(const std::uint64_t *base,
                                      const GatherIndices &indices,
                                      int position) {
    const __m128i packed = _mm_set_epi32(
        indices[3], indices[2], indices[1], indices[0]);
    const auto *positionBase = reinterpret_cast<const int *>(
        reinterpret_cast<const std::uint8_t *>(base) + position);
    const __m128i gathered = _mm_i32gather_epi32(
        positionBase, packed, 8);
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
                       BrainstormOpeningBatchDetail::allBits
                       << maskShift))),
        C);
    return _mm256_xor_si256(first, second);
  }
};

} // namespace

void collectNegativeBlueprintAvx2(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  auto &typedWorkspace = *static_cast<
      BrainstormNegativeBlueprintBatchDetail::Workspace *>(workspace);
  BrainstormNegativeBlueprintBatchDetail::
      collectVectorCandidates<Avx2Backend>(
          typedWorkspace, startSeedId, count, survivorOffsets);
}
