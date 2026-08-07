#include "opening_batch.hpp"

#include "items.hpp"
#include "opening_batch_vector.hpp"
#include "seed.hpp"
#include "util.hpp"

#include <algorithm>
#include <cassert>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <string_view>
#include <vector>

#if defined(BRAINSTORM_OPENING_BATCH_AVX2)
void collectOpeningCharmSoulAvx2(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);
void collectOpeningTagAvx2(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);
#endif

#if defined(BRAINSTORM_OPENING_BATCH_AVX512)
void collectOpeningCharmSoulAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);
void collectOpeningTagAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);
#endif

namespace {

constexpr double nodeMultiplier = 1.72431234;
constexpr double nodeAddend = 2.134453429141;
constexpr double soulThreshold = 0.997;
constexpr std::string_view tagKey = "Tag1";
constexpr std::string_view soulTarotKey = "soul_Tarot1";
constexpr std::string_view legendaryKey = "Joker4";
constexpr std::size_t preferredChunkSize = 4096;
constexpr std::uint64_t tagConfigurationMode = std::uint64_t{1} << 63u;

static_assert(TAGS.size() == 24 && TAGS[10] == Item::Charm_Tag);
static_assert(LEGENDARY_JOKERS.size() == 5);

bool isAnteOneLockedTag(Item tag) {
  return tag == Item::Negative_Tag || tag == Item::Standard_Tag
      || tag == Item::Meteor_Tag || tag == Item::Buffoon_Tag
      || tag == Item::Handy_Tag || tag == Item::Garbage_Tag
      || tag == Item::Ethereal_Tag || tag == Item::Top_up_Tag
      || tag == Item::Orbital_Tag;
}

double advanceNode(double value) {
  return round13(fractPositive(value * nodeMultiplier + nodeAddend));
}

double freshNode(Seed &seed, double hashedSeed, std::string_view key) {
  const std::string ownedKey(key);
  double value = pseudohash_from(
      ownedKey, seed.pseudohash(static_cast<int>(ownedKey.size())));
  value = advanceNode(value);
  return (value + hashedSeed) * 0.5;
}

bool scalarPassesOpeningCharmSoul(
    Seed &seed, const OpeningCharmSoulCriteria &criteria) {
  const double hashedSeed = seed.pseudohash(0);

  int resample = 1;
  while (true) {
    std::string key(tagKey);
    if (resample > 1) {
      key += "_resample";
      key += std::to_string(resample);
    }
    const Item tag = TAGS[static_cast<std::size_t>(
        lua_randint_from_seed(
            freshNode(seed, hashedSeed, key), 0,
            static_cast<int>(TAGS.size()) - 1))];
    if (!isAnteOneLockedTag(tag) || resample >= 1000) {
      if (tag != Item::Charm_Tag) {
        return false;
      }
      break;
    }
    ++resample;
  }

  const std::string soulKey(soulTarotKey);
  double soulState = pseudohash_from(
      soulKey, seed.pseudohash(static_cast<int>(soulKey.size())));
  int soulCount = 0;
  for (int card = 0; card < 5; ++card) {
    soulState = advanceNode(soulState);
    if (lua_random_from_seed((soulState + hashedSeed) * 0.5)
        > soulThreshold) {
      ++soulCount;
    }
  }
  if (soulCount < criteria.minimumSoulCount) {
    return false;
  }

  if (criteria.legendaryIndex < 0) {
    return true;
  }

  const int legendaryIndex = lua_randint_from_seed(
      freshNode(seed, hashedSeed, legendaryKey), 0,
      static_cast<int>(LEGENDARY_JOKERS.size()) - 1);
  return legendaryIndex == criteria.legendaryIndex;
}

bool scalarPassesOpeningTag(Seed &seed, int targetTagIndex) {
  if (targetTagIndex < 0
      || targetTagIndex >= static_cast<int>(TAGS.size())) {
    return false;
  }
  const double hashedSeed = seed.pseudohash(0);
  int resample = 1;
  while (true) {
    std::string key(tagKey);
    if (resample > 1) {
      key += "_resample";
      key += std::to_string(resample);
    }
    const int tagIndex = lua_randint_from_seed(
        freshNode(seed, hashedSeed, key), 0,
        static_cast<int>(TAGS.size()) - 1);
    const Item tag = TAGS[static_cast<std::size_t>(tagIndex)];
    if (!isAnteOneLockedTag(tag) || resample >= 1000) {
      return tagIndex == targetTagIndex;
    }
    ++resample;
  }
}

void collectScalar(const OpeningCharmSoulCriteria &criteria,
                   long long startSeedId, std::size_t count,
                   std::vector<std::uint32_t> &survivorOffsets) {
  survivorOffsets.clear();
  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    if (scalarPassesOpeningCharmSoul(seed, criteria)) {
      survivorOffsets.push_back(static_cast<std::uint32_t>(offset));
    }
    seed.next();
  }
}

void collectScalarTag(int targetTagIndex, long long startSeedId,
                      std::size_t count,
                      std::vector<std::uint32_t> &survivorOffsets) {
  survivorOffsets.clear();
  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    if (scalarPassesOpeningTag(seed, targetTagIndex)) {
      survivorOffsets.push_back(static_cast<std::uint32_t>(offset));
    }
    seed.next();
  }
}

bool cpuSupportsAvx2() {
#if defined(BRAINSTORM_OPENING_BATCH_AVX2) \
    && (defined(__GNUC__) || defined(__clang__))
  __builtin_cpu_init();
  return __builtin_cpu_supports("avx2");
#else
  return false;
#endif
}

bool cpuSupportsAvx512() {
#if defined(BRAINSTORM_OPENING_BATCH_AVX512) \
    && (defined(__GNUC__) || defined(__clang__))
  __builtin_cpu_init();
  return __builtin_cpu_supports("avx512f");
#else
  return false;
#endif
}

OpeningCharmSoulBackend automaticBackend() {
  static const OpeningCharmSoulBackend backend = [] {
    if (cpuSupportsAvx512()) {
      return OpeningCharmSoulBackend::Avx512;
    }
    if (cpuSupportsAvx2()) {
      return OpeningCharmSoulBackend::Avx2;
    }
    return OpeningCharmSoulBackend::Scalar;
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

OpeningCharmSoulBackend environmentBackend() {
  const char *value = std::getenv("BRAINSTORM_OPENING_BATCH_BACKEND");
  if (equalsIgnoreCase(value, "scalar")) {
    return OpeningCharmSoulBackend::Scalar;
  }
  if (equalsIgnoreCase(value, "avx2")) {
    return cpuSupportsAvx2() ? OpeningCharmSoulBackend::Avx2
                             : OpeningCharmSoulBackend::Scalar;
  }
  if (equalsIgnoreCase(value, "avx512")
      || equalsIgnoreCase(value, "avx-512")) {
    return cpuSupportsAvx512() ? OpeningCharmSoulBackend::Avx512
                               : OpeningCharmSoulBackend::Scalar;
  }
  return automaticBackend();
}

void collectOneChunk(void *context, long long startSeedId, std::size_t count,
                     std::vector<std::uint32_t> &survivors,
                     OpeningCharmSoulBackend backend) {
  auto &workspace = *static_cast<
      BrainstormOpeningBatchDetail::Workspace *>(context);
  switch (backend) {
#if defined(BRAINSTORM_OPENING_BATCH_AVX512)
  case OpeningCharmSoulBackend::Avx512:
    if (cpuSupportsAvx512()) {
      collectOpeningCharmSoulAvx512(
          &workspace, startSeedId, count, survivors);
      return;
    }
    break;
#endif
#if defined(BRAINSTORM_OPENING_BATCH_AVX2)
  case OpeningCharmSoulBackend::Avx2:
    if (cpuSupportsAvx2()) {
      collectOpeningCharmSoulAvx2(
          &workspace, startSeedId, count, survivors);
      return;
    }
    break;
#endif
  case OpeningCharmSoulBackend::Auto:
  case OpeningCharmSoulBackend::Scalar:
    break;
  }
  collectScalar(workspace.criteria, startSeedId, count, survivors);
}

void collectOneTagChunk(void *context, long long startSeedId,
                        std::size_t count,
                        std::vector<std::uint32_t> &survivors,
                        OpeningCharmSoulBackend backend) {
  auto &workspace = *static_cast<
      BrainstormOpeningBatchDetail::TagWorkspace *>(context);
  switch (backend) {
#if defined(BRAINSTORM_OPENING_BATCH_AVX512)
  case OpeningCharmSoulBackend::Avx512:
    if (cpuSupportsAvx512()) {
      collectOpeningTagAvx512(
          &workspace, startSeedId, count, survivors);
      return;
    }
    break;
#endif
#if defined(BRAINSTORM_OPENING_BATCH_AVX2)
  case OpeningCharmSoulBackend::Avx2:
    if (cpuSupportsAvx2()) {
      collectOpeningTagAvx2(
          &workspace, startSeedId, count, survivors);
      return;
    }
    break;
#endif
  case OpeningCharmSoulBackend::Auto:
  case OpeningCharmSoulBackend::Scalar:
    break;
  }
  collectScalarTag(
      workspace.targetTagIndex, startSeedId, count, survivors);
}

void collectAllWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningCharmSoulBackend backend) {
  assert(count <= std::numeric_limits<std::uint32_t>::max());
  if (backend == OpeningCharmSoulBackend::Auto) {
    backend = environmentBackend();
  }

  survivorOffsets.clear();
  std::vector<std::uint32_t> localSurvivors;
  std::size_t processed = 0;
  while (processed < count) {
    const std::size_t chunkCount =
        std::min(preferredChunkSize, count - processed);
    const long long chunkStart = normalizeSeedId(
        normalizeSeedId(startSeedId)
        + static_cast<long long>(processed));
    collectOneChunk(context, chunkStart, chunkCount, localSurvivors, backend);
    for (std::uint32_t offset : localSurvivors) {
      survivorOffsets.push_back(
          static_cast<std::uint32_t>(processed) + offset);
    }
    processed += chunkCount;
  }
}

void collectAllTagsWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningCharmSoulBackend backend) {
  assert(count <= std::numeric_limits<std::uint32_t>::max());
  if (backend == OpeningCharmSoulBackend::Auto) {
    backend = environmentBackend();
  }

  survivorOffsets.clear();
  std::vector<std::uint32_t> localSurvivors;
  std::size_t processed = 0;
  while (processed < count) {
    const std::size_t chunkCount =
        std::min(preferredChunkSize, count - processed);
    const long long chunkStart = normalizeSeedId(
        normalizeSeedId(startSeedId)
        + static_cast<long long>(processed));
    collectOneTagChunk(
        context, chunkStart, chunkCount, localSurvivors, backend);
    for (std::uint32_t offset : localSurvivors) {
      survivorOffsets.push_back(
          static_cast<std::uint32_t>(processed) + offset);
    }
    processed += chunkCount;
  }
}

} // namespace

OpeningCharmSoulBackend selectedOpeningCharmSoulBackend() {
  return environmentBackend();
}

bool openingCharmSoulVectorBackendAvailable() {
  return selectedOpeningCharmSoulBackend()
      != OpeningCharmSoulBackend::Scalar;
}

bool openingCharmSoulBackendAvailable(OpeningCharmSoulBackend backend) {
  switch (backend) {
  case OpeningCharmSoulBackend::Auto:
  case OpeningCharmSoulBackend::Scalar:
    return true;
  case OpeningCharmSoulBackend::Avx2:
    return cpuSupportsAvx2();
  case OpeningCharmSoulBackend::Avx512:
    return cpuSupportsAvx512();
  }
  return false;
}

const char *openingCharmSoulBackendName(OpeningCharmSoulBackend backend) {
  switch (backend) {
  case OpeningCharmSoulBackend::Auto:
    return "auto";
  case OpeningCharmSoulBackend::Scalar:
    return "scalar";
  case OpeningCharmSoulBackend::Avx2:
    return "avx2";
  case OpeningCharmSoulBackend::Avx512:
    return "avx512";
  }
  return "unknown";
}

std::uint64_t encodeOpeningCharmSoulCriteria(
    OpeningCharmSoulCriteria criteria) {
  const int minimumSoulCount = std::clamp(criteria.minimumSoulCount, 1, 4);
  const int legendaryIndex =
      criteria.legendaryIndex >= 0
          && criteria.legendaryIndex
              < static_cast<int>(LEGENDARY_JOKERS.size())
      ? criteria.legendaryIndex
      : -1;
  return static_cast<std::uint64_t>(minimumSoulCount)
      | (static_cast<std::uint64_t>(legendaryIndex + 1) << 8u);
}

void collectOpeningCharmSoulCandidates(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningCharmSoulCriteria criteria) {
  void *context = createOpeningCharmSoulBatchContext(
      encodeOpeningCharmSoulCriteria(criteria));
  collectOpeningCharmSoulCandidatesWithContext(
      context, startSeedId, count, survivorOffsets);
  destroyOpeningCharmSoulBatchContext(context);
}

void *createOpeningCharmSoulBatchContext(std::uint64_t configuration) {
  auto *workspace = new BrainstormOpeningBatchDetail::Workspace();
  workspace->criteria.minimumSoulCount = std::clamp(
      static_cast<int>(configuration & 0xffu), 1, 4);
  const int legendaryIndex =
      static_cast<int>((configuration >> 8u) & 0xffu) - 1;
  workspace->criteria.legendaryIndex =
      legendaryIndex >= 0
          && legendaryIndex < static_cast<int>(LEGENDARY_JOKERS.size())
      ? legendaryIndex
      : -1;
  return workspace;
}

void destroyOpeningCharmSoulBatchContext(void *context) {
  delete static_cast<BrainstormOpeningBatchDetail::Workspace *>(context);
}

void collectOpeningCharmSoulCandidatesWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  collectAllWithContext(
      context, startSeedId, count, survivorOffsets,
      selectedOpeningCharmSoulBackend());
}

void collectOpeningCharmSoulCandidatesWithBackend(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningCharmSoulCriteria criteria, OpeningCharmSoulBackend backend) {
  void *context = createOpeningCharmSoulBatchContext(
      encodeOpeningCharmSoulCriteria(criteria));
  collectAllWithContext(
      context, startSeedId, count, survivorOffsets, backend);
  destroyOpeningCharmSoulBatchContext(context);
}

std::uint64_t encodeOpeningTagCriteria(OpeningTagCriteria criteria) {
  const int tagIndex = criteria.tagIndex >= 0
          && criteria.tagIndex < static_cast<int>(TAGS.size())
      ? criteria.tagIndex
      : 0xff;
  return tagConfigurationMode
      | static_cast<std::uint64_t>(tagIndex);
}

void *createOpeningTagBatchContext(std::uint64_t configuration) {
  auto *workspace = new BrainstormOpeningBatchDetail::TagWorkspace();
  const int tagIndex = static_cast<int>(configuration & 0xffu);
  workspace->targetTagIndex =
      (configuration & tagConfigurationMode) != 0
          && tagIndex >= 0
          && tagIndex < static_cast<int>(TAGS.size())
      ? tagIndex
      : -1;
  return workspace;
}

void destroyOpeningTagBatchContext(void *context) {
  delete static_cast<BrainstormOpeningBatchDetail::TagWorkspace *>(context);
}

void collectOpeningTagCandidatesWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  collectAllTagsWithContext(
      context, startSeedId, count, survivorOffsets,
      selectedOpeningCharmSoulBackend());
}

void collectOpeningTagCandidates(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningTagCriteria criteria) {
  void *context = createOpeningTagBatchContext(
      encodeOpeningTagCriteria(criteria));
  collectOpeningTagCandidatesWithContext(
      context, startSeedId, count, survivorOffsets);
  destroyOpeningTagBatchContext(context);
}

void collectOpeningTagCandidatesWithBackend(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningTagCriteria criteria, OpeningCharmSoulBackend backend) {
  void *context = createOpeningTagBatchContext(
      encodeOpeningTagCriteria(criteria));
  collectAllTagsWithContext(
      context, startSeedId, count, survivorOffsets, backend);
  destroyOpeningTagBatchContext(context);
}
