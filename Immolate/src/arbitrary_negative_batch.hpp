#ifndef BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_HPP
#define BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_HPP

#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>

struct Seed;

inline constexpr std::size_t BRAINSTORM_ARBITRARY_NEGATIVE_MAX_REQUIREMENTS = 5;

enum class ArbitraryNegativeBackend {
  Auto,
  Scalar,
  Avx2,
  Avx512,
};

enum class ArbitraryNegativeRarity : std::uint8_t {
  Common,
  Uncommon,
  Rare,
  Legendary,
};

// Values intentionally mirror BrainstormJokerLocationRequirement without
// coupling this reusable batch kernel to immolate.cpp's private query state.
enum class ArbitraryNegativeWindow : std::uint8_t {
  AnteOne,
  SoulPack,
  AnteTwo,
  SoulOrAnteTwo,
  AnteThree,
  AnteFour,
  ByAnteTwo,
  ByAnteThree,
  ByAnteFour,
  ByAnteFive,
  ByAnteSix,
  ByAnteSeven,
  ByAnteEight,
};

enum class ArbitraryNegativeShopRate : std::uint8_t {
  Ordinary,
  Ghost,
  Zodiac,
};

struct ArbitraryNegativeRequirement {
  ArbitraryNegativeRarity rarity = ArbitraryNegativeRarity::Common;
  ArbitraryNegativeWindow window = ArbitraryNegativeWindow::AnteOne;
};

struct ArbitraryNegativeCriteria {
  std::array<ArbitraryNegativeRequirement,
             BRAINSTORM_ARBITRARY_NEGATIVE_MAX_REQUIREMENTS>
      requirements{};
  int requirementCount = 0;
  int maximumAnte = 1;
  int anteOneShops = 2;
  int stockSize = 2;
  ArbitraryNegativeShopRate shopRate =
      ArbitraryNegativeShopRate::Ordinary;
  // True when the authoritative route can select from the starting Charm
  // pack. Deadline searches may set this even when Charm is optional; that
  // deliberately creates a safe union of the Charm and no-Charm routes.
  bool allowStartingPack = false;
};

ArbitraryNegativeBackend selectedArbitraryNegativeBackend();
bool arbitraryNegativeVectorBackendAvailable();
bool arbitraryNegativeBackendAvailable(ArbitraryNegativeBackend backend);
const char* arbitraryNegativeBackendName(ArbitraryNegativeBackend backend);

std::uint64_t encodeArbitraryNegativeCriteria(
    const ArbitraryNegativeCriteria& criteria);
ArbitraryNegativeCriteria decodeArbitraryNegativeCriteria(
    std::uint64_t configuration);

void* createArbitraryNegativeBatchContext(std::uint64_t configuration);
void destroyArbitraryNegativeBatchContext(void* context);
void collectArbitraryNegativeCandidatesWithContext(
    void* context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivorOffsets);

void collectArbitraryNegativeCandidates(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivorOffsets,
    const ArbitraryNegativeCriteria& criteria);
void collectArbitraryNegativeCandidatesWithBackend(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivorOffsets,
    const ArbitraryNegativeCriteria& criteria,
    ArbitraryNegativeBackend backend);

// Scalar seed check used after an even more selective opening batch. It has
// exactly the same necessary-condition semantics as the SIMD collector.
bool passesArbitraryNegativeCriteria(
    Seed& seed, const ArbitraryNegativeCriteria& criteria);

#endif  // BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_HPP
