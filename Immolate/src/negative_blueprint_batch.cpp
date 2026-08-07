#include "negative_blueprint_batch.hpp"

#include "negative_blueprint_batch_vector.hpp"
#include "rng.hpp"
#include "seed.hpp"
#include "util.hpp"

#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <vector>

#if defined(BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_AVX2)
void collectNegativeBlueprintAvx2(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);
#endif

#if defined(BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_AVX512)
void collectNegativeBlueprintAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);
#endif

namespace {

using BrainstormNegativeBlueprintBatchDetail::buffoonEditionKey;
using BrainstormNegativeBlueprintBatchDetail::buffoonRarityKey;
using BrainstormNegativeBlueprintBatchDetail::negativeThreshold;
using BrainstormNegativeBlueprintBatchDetail::packTypeKey;
using BrainstormNegativeBlueprintBatchDetail::preferredChunkSize;
using BrainstormNegativeBlueprintBatchDetail::rareThreshold;
using BrainstormNegativeBlueprintBatchDetail::shopCardTypeKey;
using BrainstormNegativeBlueprintBatchDetail::shopEditionKey;
using BrainstormNegativeBlueprintBatchDetail::shopRarityKey;
using BrainstormNegativeBlueprintBatchDetail::shopTotalRate;

struct ScalarNodeState {
  double value = 0.0;
  bool initialized = false;
};

bool isBuffoonPack(Item item) {
  return item == Item::Buffoon_Pack
      || item == Item::Jumbo_Buffoon_Pack
      || item == Item::Mega_Buffoon_Pack;
}

int buffoonPackSize(Item item) {
  if (item == Item::Buffoon_Pack) {
    return 2;
  }
  if (item == Item::Jumbo_Buffoon_Pack
      || item == Item::Mega_Buffoon_Pack) {
    return 4;
  }
  return 0;
}

Item randomPackFromRoll(double roll) {
  const double poll = roll * PACKS[0].weight;
  int index = 1;
  double cumulativeWeight = 0.0;
  while (cumulativeWeight < poll) {
    cumulativeWeight += PACKS[static_cast<std::size_t>(index)].weight;
    ++index;
  }
  return PACKS[static_cast<std::size_t>(index - 1)].item;
}

class ScalarNegativeBlueprintEval {
 public:
  explicit ScalarNegativeBlueprintEval(Seed &seedRef)
      : seed(seedRef), hashedSeed(seedRef.pseudohash(0)) {}

  bool passes(const NegativeBlueprintCriteria &criteria) {
    return criteria.requireRare
        ? passesForMode<true>(criteria)
        : passesForMode<false>(criteria);
  }

 private:
  template <bool RequireRare>
  bool passesForMode(const NegativeBlueprintCriteria &criteria) {
    for (int shop = 0; shop < criteria.shopCards; ++shop) {
      if (nextShopCardIsJoker(shopTotalRate(criteria.shopRate))) {
        bool rare = true;
        if constexpr (RequireRare) {
          rare = nextRollExceeds(
              shopRarityState, shopRarityKeyString(), rareThreshold);
        }
        // The edition node advances for every Joker. Its Lua RNG transform is
        // pure, so Rare mode can skip that expensive transform when this draw
        // is not Rare while preserving all subsequent node states exactly.
        const double editionSeed = nextNode(
            shopEditionState, shopEditionKeyString());
        const bool negative = (!RequireRare || rare)
            && lua_random_from_seed(editionSeed) > negativeThreshold;
        if (rare && negative) {
          return true;
        }
      }
    }

    Item pack = Item::Buffoon_Pack;
    for (int displayed = 0; displayed < criteria.displayedPacks;
         ++displayed) {
      if (displayed > 0) {
        pack = randomPackFromRoll(lua_random_from_seed(
            nextNode(packTypeState, packTypeKeyString())));
      }
      if (!isBuffoonPack(pack)) {
        continue;
      }
      const int size = buffoonPackSize(pack);
      for (int card = 0; card < size; ++card) {
        bool rare = true;
        if constexpr (RequireRare) {
          rare = nextRollExceeds(
              buffoonRarityState, buffoonRarityKeyString(), rareThreshold);
        }
        const double editionSeed = nextNode(
            buffoonEditionState, buffoonEditionKeyString());
        const bool negative = (!RequireRare || rare)
            && lua_random_from_seed(editionSeed) > negativeThreshold;
        if (rare && negative) {
          return true;
        }
      }
    }
    return false;
  }

  Seed &seed;
  double hashedSeed;
  ScalarNodeState shopCardTypeState;
  ScalarNodeState shopRarityState;
  ScalarNodeState shopEditionState;
  ScalarNodeState packTypeState;
  ScalarNodeState buffoonRarityState;
  ScalarNodeState buffoonEditionState;

  static const std::string &shopCardTypeKeyString() {
    static const std::string key(shopCardTypeKey);
    return key;
  }

  static const std::string &shopEditionKeyString() {
    static const std::string key(shopEditionKey);
    return key;
  }

  static const std::string &shopRarityKeyString() {
    static const std::string key(shopRarityKey);
    return key;
  }

  static const std::string &packTypeKeyString() {
    static const std::string key(packTypeKey);
    return key;
  }

  static const std::string &buffoonEditionKeyString() {
    static const std::string key(buffoonEditionKey);
    return key;
  }

  static const std::string &buffoonRarityKeyString() {
    static const std::string key(buffoonRarityKey);
    return key;
  }

  double nextNode(ScalarNodeState &state, const std::string &key) {
    if (!state.initialized) {
      state.value = pseudohash_from(
          key, seed.pseudohash(static_cast<int>(key.size())));
      state.initialized = true;
    }
    state.value = round13(fractPositive(
        state.value * 1.72431234 + 2.134453429141));
    return (state.value + hashedSeed) * 0.5;
  }

  bool nextRollExceeds(ScalarNodeState &state, const std::string &key,
                       double threshold) {
    return lua_random_from_seed(nextNode(state, key)) > threshold;
  }

  bool nextShopCardIsJoker(double totalRate) {
    const double poll = lua_random_from_seed(
        nextNode(shopCardTypeState, shopCardTypeKeyString()))
        * totalRate;
    return poll < 20.0;
  }
};

void collectScalar(
    const NegativeBlueprintCriteria &criteria,
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  survivorOffsets.clear();
  survivorOffsets.reserve(count / 50 + 8);
  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    ScalarNegativeBlueprintEval eval(seed);
    if (eval.passes(criteria)) {
      survivorOffsets.push_back(static_cast<std::uint32_t>(offset));
    }
    seed.next();
  }
}

bool cpuSupportsAvx2() {
#if defined(BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_AVX2) \
    && (defined(__GNUC__) || defined(__clang__))
  __builtin_cpu_init();
  return __builtin_cpu_supports("avx2");
#else
  return false;
#endif
}

bool cpuSupportsAvx512() {
#if defined(BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_AVX512) \
    && (defined(__GNUC__) || defined(__clang__))
  __builtin_cpu_init();
  return __builtin_cpu_supports("avx512f");
#else
  return false;
#endif
}

NegativeBlueprintBackend automaticBackend() {
  static const NegativeBlueprintBackend backend = [] {
    if (cpuSupportsAvx512()) {
      return NegativeBlueprintBackend::Avx512;
    }
    if (cpuSupportsAvx2()) {
      return NegativeBlueprintBackend::Avx2;
    }
    return NegativeBlueprintBackend::Scalar;
  }();
  return backend;
}

bool equalsIgnoreCase(const char *value, const char *expected) {
  if (value == nullptr) {
    return false;
  }
  while (*value != '\0' && *expected != '\0') {
    char left = *value++;
    char right = *expected++;
    if (left >= 'A' && left <= 'Z') {
      left = static_cast<char>(left - 'A' + 'a');
    }
    if (right >= 'A' && right <= 'Z') {
      right = static_cast<char>(right - 'A' + 'a');
    }
    if (left != right) {
      return false;
    }
  }
  return *value == '\0' && *expected == '\0';
}

NegativeBlueprintBackend environmentBackend() {
  const char *value = std::getenv(
      "BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_BACKEND");
  if (equalsIgnoreCase(value, "scalar")) {
    return NegativeBlueprintBackend::Scalar;
  }
  if (equalsIgnoreCase(value, "avx2")) {
    return cpuSupportsAvx2() ? NegativeBlueprintBackend::Avx2
                             : NegativeBlueprintBackend::Scalar;
  }
  if (equalsIgnoreCase(value, "avx512")
      || equalsIgnoreCase(value, "avx-512")) {
    return cpuSupportsAvx512() ? NegativeBlueprintBackend::Avx512
                               : NegativeBlueprintBackend::Scalar;
  }
  return automaticBackend();
}

void collectOneChunk(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    NegativeBlueprintBackend backend) {
  auto &workspace = *static_cast<
      BrainstormNegativeBlueprintBatchDetail::Workspace *>(context);
  switch (backend) {
#if defined(BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_AVX512)
  case NegativeBlueprintBackend::Avx512:
    if (cpuSupportsAvx512()) {
      collectNegativeBlueprintAvx512(
          &workspace, startSeedId, count, survivorOffsets);
      return;
    }
    break;
#endif
#if defined(BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_AVX2)
  case NegativeBlueprintBackend::Avx2:
    if (cpuSupportsAvx2()) {
      collectNegativeBlueprintAvx2(
          &workspace, startSeedId, count, survivorOffsets);
      return;
    }
    break;
#endif
  case NegativeBlueprintBackend::Auto:
  case NegativeBlueprintBackend::Scalar:
    break;
  }
  collectScalar(
      workspace.criteria, startSeedId, count, survivorOffsets);
}

void collectAllWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    NegativeBlueprintBackend backend) {
  assert(count <= std::numeric_limits<std::uint32_t>::max());
  if (backend == NegativeBlueprintBackend::Auto) {
    backend = environmentBackend();
  }

  if (count <= preferredChunkSize) {
    collectOneChunk(
        context, normalizeSeedId(startSeedId), count,
        survivorOffsets, backend);
    return;
  }

  auto &workspace = *static_cast<
      BrainstormNegativeBlueprintBatchDetail::Workspace *>(context);
  survivorOffsets.clear();
  std::size_t processed = 0;
  while (processed < count) {
    const std::size_t chunkCount =
        std::min(preferredChunkSize, count - processed);
    const long long chunkStart = normalizeSeedId(
        normalizeSeedId(startSeedId)
        + static_cast<long long>(processed));
    collectOneChunk(
        context, chunkStart, chunkCount,
        workspace.localSurvivors, backend);
    for (std::uint32_t offset : workspace.localSurvivors) {
      survivorOffsets.push_back(
          static_cast<std::uint32_t>(processed) + offset);
    }
    processed += chunkCount;
  }
}

} // namespace

NegativeBlueprintBackend selectedNegativeBlueprintBackend() {
  return environmentBackend();
}

bool negativeBlueprintVectorBackendAvailable() {
  return selectedNegativeBlueprintBackend()
      != NegativeBlueprintBackend::Scalar;
}

bool negativeBlueprintBackendAvailable(NegativeBlueprintBackend backend) {
  switch (backend) {
  case NegativeBlueprintBackend::Auto:
  case NegativeBlueprintBackend::Scalar:
    return true;
  case NegativeBlueprintBackend::Avx2:
    return cpuSupportsAvx2();
  case NegativeBlueprintBackend::Avx512:
    return cpuSupportsAvx512();
  }
  return false;
}

const char *negativeBlueprintBackendName(
    NegativeBlueprintBackend backend) {
  switch (backend) {
  case NegativeBlueprintBackend::Auto:
    return "auto";
  case NegativeBlueprintBackend::Scalar:
    return "scalar";
  case NegativeBlueprintBackend::Avx2:
    return "avx2";
  case NegativeBlueprintBackend::Avx512:
    return "avx512";
  }
  return "unknown";
}

std::uint64_t encodeNegativeBlueprintCriteria(
    NegativeBlueprintCriteria criteria) {
  const int shopCards = std::clamp(criteria.shopCards, 0, 4);
  const int displayedPacks = std::clamp(criteria.displayedPacks, 0, 4);
  const auto rate = static_cast<std::uint64_t>(criteria.shopRate);
  return static_cast<std::uint64_t>(shopCards)
      | (static_cast<std::uint64_t>(displayedPacks) << 8u)
      | (rate << 16u)
      | (static_cast<std::uint64_t>(criteria.requireRare) << 24u);
}

void *createNegativeBlueprintBatchContext(std::uint64_t configuration) {
  auto *workspace =
      new BrainstormNegativeBlueprintBatchDetail::Workspace();
  workspace->criteria.shopCards = std::clamp(
      static_cast<int>(configuration & 0xffu), 0, 4);
  workspace->criteria.displayedPacks = std::clamp(
      static_cast<int>((configuration >> 8u) & 0xffu), 0, 4);
  const int rate = static_cast<int>((configuration >> 16u) & 0xffu);
  workspace->criteria.shopRate =
      rate == static_cast<int>(NegativeBlueprintShopRate::Ghost)
      ? NegativeBlueprintShopRate::Ghost
      : rate == static_cast<int>(NegativeBlueprintShopRate::Zodiac)
      ? NegativeBlueprintShopRate::Zodiac
      : NegativeBlueprintShopRate::Ordinary;
  workspace->criteria.requireRare =
      ((configuration >> 24u) & 0x1u) != 0;
  return workspace;
}

void destroyNegativeBlueprintBatchContext(void *context) {
  delete static_cast<
      BrainstormNegativeBlueprintBatchDetail::Workspace *>(context);
}

void collectNegativeBlueprintCandidatesWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  collectAllWithContext(
      context, startSeedId, count, survivorOffsets,
      selectedNegativeBlueprintBackend());
}

void collectNegativeBlueprintCandidates(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    NegativeBlueprintCriteria criteria) {
  void *context = createNegativeBlueprintBatchContext(
      encodeNegativeBlueprintCriteria(criteria));
  collectNegativeBlueprintCandidatesWithContext(
      context, startSeedId, count, survivorOffsets);
  destroyNegativeBlueprintBatchContext(context);
}

void collectNegativeBlueprintCandidatesWithBackend(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    NegativeBlueprintCriteria criteria, NegativeBlueprintBackend backend) {
  void *context = createNegativeBlueprintBatchContext(
      encodeNegativeBlueprintCriteria(criteria));
  collectAllWithContext(
      context, startSeedId, count, survivorOffsets, backend);
  destroyNegativeBlueprintBatchContext(context);
}
