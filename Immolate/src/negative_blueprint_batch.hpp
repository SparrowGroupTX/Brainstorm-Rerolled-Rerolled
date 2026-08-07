#ifndef BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_HPP
#define BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_HPP

#include <cstddef>
#include <cstdint>
#include <vector>

enum class NegativeBlueprintBackend {
  Auto,
  Scalar,
  Avx2,
  Avx512,
};

enum class NegativeBlueprintShopRate {
  Ordinary,
  Ghost,
  Zodiac,
};

struct NegativeBlueprintCriteria {
  int shopCards = 4;
  int displayedPacks = 4;
  NegativeBlueprintShopRate shopRate =
      NegativeBlueprintShopRate::Ordinary;
  // A Rare roll is a stronger necessary condition for Blueprint. It is
  // enabled only when reducing authoritative survivors repays its two extra
  // RNG streams; the edition-only mode remains faster for a bare query.
  bool requireRare = false;
};

NegativeBlueprintBackend selectedNegativeBlueprintBackend();
bool negativeBlueprintVectorBackendAvailable();
bool negativeBlueprintBackendAvailable(NegativeBlueprintBackend backend);
const char *negativeBlueprintBackendName(NegativeBlueprintBackend backend);

std::uint64_t encodeNegativeBlueprintCriteria(
    NegativeBlueprintCriteria criteria);
void *createNegativeBlueprintBatchContext(std::uint64_t configuration);
void destroyNegativeBlueprintBatchContext(void *context);
void collectNegativeBlueprintCandidatesWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);

// Every returned offset is sorted, lies in [0, count), and identifies a seed
// with at least one Negative-edition Joker opportunity in the exact legacy
// Negative Blueprint shop/pack window. When criteria.requireRare is set, the
// same draw must also be Rare. Blueprint is Rare, so both modes are necessary
// conditions; the authoritative Joker simulator still verifies identity.
void collectNegativeBlueprintCandidates(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    NegativeBlueprintCriteria criteria);

// Explicit selection supports differential tests. An unsupported vector
// backend safely falls back to the scalar implementation.
void collectNegativeBlueprintCandidatesWithBackend(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    NegativeBlueprintCriteria criteria, NegativeBlueprintBackend backend);

#endif // BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_HPP
