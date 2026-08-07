#include "negative_blueprint_batch_vector.hpp"

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
  static Mask greater(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_GT_OQ);
  }
  static Mask greaterEqual(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_GE_OQ);
  }
  static Mask less(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_LT_OQ);
  }
  static Mask lessEqual(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_LE_OQ);
  }
  static Mask notEqual(DoubleVector a, DoubleVector b) {
    return _mm512_cmp_pd_mask(a, b, _CMP_NEQ_OQ);
  }
  static Mask maskAnd(Mask a, Mask b) { return a & b; }
  static Mask maskOr(Mask a, Mask b) { return a | b; }
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
    const __m256i packed = _mm256_set_epi32(
        indices[7], indices[6], indices[5], indices[4],
        indices[3], indices[2], indices[1], indices[0]);
    return _mm512_i32gather_pd(packed, base, sizeof(double));
  }
  static DoubleVector gatherByte(const std::uint8_t *base,
                                 const GatherIndices &indices) {
    const __m256i packed = _mm256_set_epi32(
        indices[7], indices[6], indices[5], indices[4],
        indices[3], indices[2], indices[1], indices[0]);
    const __m256i gathered = _mm256_i32gather_epi32(
        reinterpret_cast<const int *>(base), packed, 1);
    return _mm512_cvtepi32_pd(
        _mm256_and_si256(gathered, _mm256_set1_epi32(0xff)));
  }
  static DoubleVector gatherCharacter(const std::uint64_t *base,
                                      const GatherIndices &indices,
                                      int position) {
    const __m256i packed = _mm256_set_epi32(
        indices[7], indices[6], indices[5], indices[4],
        indices[3], indices[2], indices[1], indices[0]);
    const auto *positionBase = reinterpret_cast<const int *>(
        reinterpret_cast<const std::uint8_t *>(base) + position);
    const __m256i gathered = _mm256_i32gather_epi32(
        positionBase, packed, 8);
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
                       BrainstormOpeningBatchDetail::allBits
                       << maskShift))),
        C);
    return _mm512_xor_si512(first, second);
  }
};

} // namespace

void collectNegativeBlueprintAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  auto &typedWorkspace = *static_cast<
      BrainstormNegativeBlueprintBatchDetail::Workspace *>(workspace);
  BrainstormNegativeBlueprintBatchDetail::
      collectVectorCandidates<Avx512Backend>(
          typedWorkspace, startSeedId, count, survivorOffsets);
}
