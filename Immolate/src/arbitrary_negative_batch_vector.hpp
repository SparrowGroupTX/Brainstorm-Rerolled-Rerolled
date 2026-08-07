#ifndef BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_VECTOR_HPP
#define BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_VECTOR_HPP

#include "arbitrary_negative_batch.hpp"
#include "opening_batch_vector.hpp"
#include "rng.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace BrainstormArbitraryNegativeBatchDetail {

#if defined(__GNUC__)
#define BRAINSTORM_ARBITRARY_NEGATIVE_INLINE \
  inline __attribute__((always_inline))
#else
#define BRAINSTORM_ARBITRARY_NEGATIVE_INLINE inline
#endif

inline constexpr double negativeThreshold = 0.997;
inline constexpr std::size_t preferredChunkSize = 4096;
inline constexpr unsigned int soulSourceBit = 1u << 0;
inline constexpr unsigned int judgementSourceBit = 1u << 1;
inline constexpr unsigned int anteSourceBit(int ante) {
  return 1u << static_cast<unsigned int>(ante + 1);
}

struct AnteKeys {
  std::string cardType;
  std::string shopRarity;
  std::string shopEdition;
  std::string packType;
  std::string buffoonRarity;
  std::string buffoonEdition;
};

inline const std::array<AnteKeys, 8>& anteKeys() {
  static const std::array<AnteKeys, 8> result = [] {
    std::array<AnteKeys, 8> keys{};
    for (int ante = 1; ante <= 8; ++ante) {
      const std::string anteString = anteToString(ante);
      keys[static_cast<std::size_t>(ante - 1)] = AnteKeys{
          RandomType::Card_Type + anteString,
          RandomType::Joker_Rarity + anteString + ItemSource::Shop,
          RandomType::Joker_Edition + ItemSource::Shop + anteString,
          RandomType::Shop_Pack + anteString,
          RandomType::Joker_Rarity + anteString + ItemSource::Buffoon_Pack,
          RandomType::Joker_Edition + ItemSource::Buffoon_Pack + anteString};
    }
    return keys;
  }();
  return result;
}

inline const std::string& soulEditionKey() {
  static const std::string key = RandomType::Joker_Edition
      + ItemSource::Soul + anteToString(1);
  return key;
}

inline const std::string& judgementRarityKey() {
  static const std::string key = RandomType::Joker_Rarity
      + anteToString(1) + ItemSource::Judgement;
  return key;
}

inline const std::string& judgementEditionKey() {
  static const std::string key = RandomType::Joker_Edition
      + ItemSource::Judgement + anteToString(1);
  return key;
}

inline int windowDeadline(ArbitraryNegativeWindow window) {
  switch (window) {
    case ArbitraryNegativeWindow::ByAnteTwo: return 2;
    case ArbitraryNegativeWindow::ByAnteThree: return 3;
    case ArbitraryNegativeWindow::ByAnteFour: return 4;
    case ArbitraryNegativeWindow::ByAnteFive: return 5;
    case ArbitraryNegativeWindow::ByAnteSix: return 6;
    case ArbitraryNegativeWindow::ByAnteSeven: return 7;
    case ArbitraryNegativeWindow::ByAnteEight: return 8;
    default: return 0;
  }
}

inline bool requirementAcceptsSource(
    const ArbitraryNegativeRequirement& requirement,
    unsigned int sourceBit, bool allowStartingPack) {
  const bool legendary =
      requirement.rarity == ArbitraryNegativeRarity::Legendary;
  if (sourceBit == soulSourceBit) {
    if (!legendary || !allowStartingPack) {
      return false;
    }
    return requirement.window == ArbitraryNegativeWindow::AnteOne
        || requirement.window == ArbitraryNegativeWindow::SoulPack
        || requirement.window == ArbitraryNegativeWindow::SoulOrAnteTwo
        || windowDeadline(requirement.window) > 0;
  }
  if (sourceBit == judgementSourceBit) {
    if (legendary || !allowStartingPack) {
      return false;
    }
    return requirement.window == ArbitraryNegativeWindow::SoulPack
        || requirement.window == ArbitraryNegativeWindow::SoulOrAnteTwo
        || windowDeadline(requirement.window) > 0;
  }
  if (legendary) {
    return false;
  }

  int observedAnte = 0;
  for (int ante = 1; ante <= 8; ++ante) {
    if (sourceBit == anteSourceBit(ante)) {
      observedAnte = ante;
      break;
    }
  }
  if (observedAnte == 0) {
    return false;
  }
  const int deadline = windowDeadline(requirement.window);
  if (deadline > 0) {
    return observedAnte <= deadline;
  }
  switch (requirement.window) {
    case ArbitraryNegativeWindow::AnteOne:
      return observedAnte == 1;
    case ArbitraryNegativeWindow::AnteTwo:
      return observedAnte == 2;
    case ArbitraryNegativeWindow::SoulOrAnteTwo:
      return observedAnte == 2;
    case ArbitraryNegativeWindow::AnteThree:
      return observedAnte == 3;
    case ArbitraryNegativeWindow::AnteFour:
      return observedAnte == 4;
    default:
      return false;
  }
}

inline bool anyRequirementAcceptsSource(
    const ArbitraryNegativeCriteria& criteria, unsigned int sourceBit) {
  for (int requirement = 0;
       requirement < criteria.requirementCount; ++requirement) {
    if (requirementAcceptsSource(
            criteria.requirements[static_cast<std::size_t>(requirement)],
            sourceBit, criteria.allowStartingPack)) {
      return true;
    }
  }
  return false;
}

inline double shopTotalRate(ArbitraryNegativeShopRate rate) {
  switch (rate) {
    case ArbitraryNegativeShopRate::Ghost: return 30.0;
    case ArbitraryNegativeShopRate::Zodiac: return 39.2;
    case ArbitraryNegativeShopRate::Ordinary: return 28.0;
  }
  return 28.0;
}

struct BuffoonBoundaries {
  double normalLower = 0.0;
  double normalUpper = 0.0;
  double jumboLower = 0.0;
  double jumboUpper = 0.0;
  double megaLower = 0.0;
  double megaUpper = 0.0;
};

inline const BuffoonBoundaries& buffoonBoundaries() {
  static const BuffoonBoundaries result = [] {
    BuffoonBoundaries value;
    double cumulative = 0.0;
    for (std::size_t index = 1; index < PACKS.size(); ++index) {
      const double lower = cumulative;
      cumulative += PACKS[index].weight;
      if (PACKS[index].item == Item::Buffoon_Pack) {
        value.normalLower = lower;
        value.normalUpper = cumulative;
      } else if (PACKS[index].item == Item::Jumbo_Buffoon_Pack) {
        value.jumboLower = lower;
        value.jumboUpper = cumulative;
      } else if (PACKS[index].item == Item::Mega_Buffoon_Pack) {
        value.megaLower = lower;
        value.megaUpper = cumulative;
      }
    }
    return value;
  }();
  return result;
}

struct Workspace {
  BrainstormOpeningBatchDetail::ChunkSeeds seeds;
  std::vector<double> seedHashes4;
  std::vector<double> seedHashes7;
  std::vector<double> seedHashes10;
  std::array<int, 8> indices{};
  std::vector<std::uint32_t> localSurvivors;
  ArbitraryNegativeCriteria criteria;

  void prepare(std::size_t count) {
    seeds.resize(count);
    seedHashes4.resize(count);
    seedHashes7.resize(count);
    seedHashes10.resize(count);
    localSurvivors.reserve(count / 100 + 8);
  }
};

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE typename Backend::Mask falseMask() {
  return Backend::less(Backend::set1(1.0), Backend::set1(0.0));
}

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE typename Backend::Mask trueMask() {
  return Backend::greater(Backend::set1(1.0), Backend::set1(0.0));
}

template <class Value, std::size_t Count>
struct alignas(64) AlignedValues {
  Value values[Count];

  Value& operator[](std::size_t index) { return values[index]; }
  const Value& operator[](std::size_t index) const {
    return values[index];
  }
};

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE
void seedPrefixHashes(
    const BrainstormOpeningBatchDetail::ChunkSeeds& seeds,
    const int* indices, int valid,
    AlignedValues<typename Backend::DoubleVector, 4>& values) {
  using D = typename Backend::DoubleVector;
  constexpr std::array<int, 4> prefixLengths = {0, 4, 7, 10};
  const auto gatherIndices = Backend::indices(indices, valid);
  const D lengths = Backend::gatherByte(
      seeds.lengths.data(), gatherIndices);
  for (std::size_t chain = 0; chain < 4; ++chain) {
    values[chain] = Backend::set1(1.0);
  }
  for (int position = 0; position < 8; ++position) {
    const D character = Backend::gatherCharacter(
        seeds.packedCharacters.data(), gatherIndices, position);
    for (std::size_t chain = 0; chain < 4; ++chain) {
      D next = Backend::div(Backend::set1(
          BrainstormOpeningBatchDetail::hashA), values[chain]);
      next = Backend::mul(next, character);
      next = Backend::mul(next, Backend::set1(
          BrainstormOpeningBatchDetail::hashPi));
      const D hashPosition = Backend::add(
          Backend::set1(static_cast<double>(
              prefixLengths[chain] - position)),
          lengths);
      next = Backend::add(
          next, Backend::mul(
              Backend::set1(BrainstormOpeningBatchDetail::hashPi),
              hashPosition));
      const D advanced = BrainstormOpeningBatchDetail::
          vectorFractPositive<Backend>(next);
      values[chain] = Backend::select(
          Backend::greater(
              lengths, Backend::set1(static_cast<double>(position))),
          values[chain], advanced);
    }
  }
}

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE typename Backend::DoubleVector
initialState(typename Backend::DoubleVector seedPrefixHash,
             std::string_view key) {
  return BrainstormOpeningBatchDetail::vectorPseudohashFrom<Backend>(
      key, seedPrefixHash);
}

template <class Backend, std::size_t Count>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE void initialStateBundle(
    AlignedValues<typename Backend::DoubleVector, Count>& values,
    const std::array<std::string_view, Count>& keys) {
  std::size_t maximumLength = 0;
  for (std::string_view key : keys) {
    maximumLength = std::max(maximumLength, key.size());
  }
  for (std::size_t reverseStep = 0; reverseStep < maximumLength;
       ++reverseStep) {
    for (std::size_t stream = 0; stream < Count; ++stream) {
      const std::string_view key = keys[stream];
      if (reverseStep >= key.size()) {
        continue;
      }
      const std::size_t index = key.size() - reverseStep;
      values[stream] = BrainstormOpeningBatchDetail::
          vectorPseudostep<Backend>(
              values[stream],
              Backend::set1(static_cast<unsigned char>(key[index - 1])),
              static_cast<double>(index));
    }
  }
}

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE typename Backend::DoubleVector
randomFromState(typename Backend::DoubleVector state,
                typename Backend::DoubleVector hashedSeed) {
  return BrainstormOpeningBatchDetail::vectorRandom<Backend>(
      Backend::mul(
          Backend::add(state, hashedSeed), Backend::set1(0.5)));
}

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE typename Backend::Mask rarityMatches(
    typename Backend::DoubleVector roll, ArbitraryNegativeRarity rarity) {
  const auto uncommonThreshold = Backend::set1(0.7);
  const auto rareThreshold = Backend::set1(0.95);
  switch (rarity) {
    case ArbitraryNegativeRarity::Common:
      return Backend::lessEqual(roll, uncommonThreshold);
    case ArbitraryNegativeRarity::Uncommon:
      return Backend::maskAnd(
          Backend::greater(roll, uncommonThreshold),
          Backend::lessEqual(roll, rareThreshold));
    case ArbitraryNegativeRarity::Rare:
      return Backend::greater(roll, rareThreshold);
    case ArbitraryNegativeRarity::Legendary:
      return falseMask<Backend>();
  }
  return falseMask<Backend>();
}

template <class Backend>
struct VectorEventRoll {
  typename Backend::Mask eligible;
  typename Backend::DoubleVector rarityRoll;
};

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE VectorEventRoll<Backend>
conditionalJokerEvent(
    typename Backend::Mask drawMask,
    typename Backend::DoubleVector hashedSeed,
    typename Backend::DoubleVector& rarityState,
    typename Backend::DoubleVector& editionState) {
  if (Backend::maskBits(drawMask) == 0) {
    return VectorEventRoll<Backend>{drawMask, Backend::set1(0.0)};
  }
  const auto nextRarity =
      BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(rarityState);
  rarityState = Backend::select(drawMask, rarityState, nextRarity);
  const auto nextEdition =
      BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(editionState);
  editionState = Backend::select(drawMask, editionState, nextEdition);
  const auto negative = Backend::greater(
      randomFromState<Backend>(editionState, hashedSeed),
      Backend::set1(negativeThreshold));
  const auto eligible = Backend::maskAnd(drawMask, negative);
  if (Backend::maskBits(eligible) == 0) {
    return VectorEventRoll<Backend>{eligible, Backend::set1(0.0)};
  }
  return VectorEventRoll<Backend>{
      eligible,
      randomFromState<Backend>(rarityState, hashedSeed)};
}

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE typename Backend::Mask
unconditionalEditionEvent(
    typename Backend::DoubleVector hashedSeed,
    typename Backend::DoubleVector& editionState) {
  editionState =
      BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(editionState);
  return Backend::greater(
      randomFromState<Backend>(editionState, hashedSeed),
      Backend::set1(negativeThreshold));
}

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE typename Backend::Mask
intervalOpenClosed(typename Backend::DoubleVector value,
                   double lower, double upper) {
  return Backend::maskAnd(
      Backend::greater(value, Backend::set1(lower)),
      Backend::lessEqual(value, Backend::set1(upper)));
}

template <class Backend>
struct VectorRequirementMatcher {
  using Mask = typename Backend::Mask;
  const ArbitraryNegativeCriteria& criteria;
  AlignedValues<
      Mask, 1u << BRAINSTORM_ARBITRARY_NEGATIVE_MAX_REQUIREMENTS>
      reachable;

  explicit VectorRequirementMatcher(
      const ArbitraryNegativeCriteria& criteriaRef)
      : criteria(criteriaRef) {
    for (std::size_t subset = 0;
         subset < (1u << BRAINSTORM_ARBITRARY_NEGATIVE_MAX_REQUIREMENTS);
         ++subset) {
      reachable[subset] = falseMask<Backend>();
    }
    reachable[0] = trueMask<Backend>();
  }

  BRAINSTORM_ARBITRARY_NEGATIVE_INLINE void observe(
      unsigned int sourceBit, const VectorEventRoll<Backend>& event,
      bool fixedLegendary = false) {
    if (Backend::maskBits(event.eligible) == 0) {
      return;
    }
    const auto previous = reachable;
    const int subsetCount = 1 << criteria.requirementCount;
    for (int subset = 0; subset < subsetCount; ++subset) {
      const Mask existing = previous[static_cast<std::size_t>(subset)];
      if (Backend::maskBits(existing) == 0) {
        continue;
      }
      for (int requirement = 0;
           requirement < criteria.requirementCount; ++requirement) {
        const int requirementBit = 1 << requirement;
        const auto& target =
            criteria.requirements[static_cast<std::size_t>(requirement)];
        if ((subset & requirementBit) != 0
            || !requirementAcceptsSource(
                target, sourceBit, criteria.allowStartingPack)) {
          continue;
        }
        Mask qualifies = event.eligible;
        if (fixedLegendary) {
          if (target.rarity != ArbitraryNegativeRarity::Legendary) {
            continue;
          }
        } else {
          qualifies = Backend::maskAnd(
              qualifies, rarityMatches<Backend>(
                  event.rarityRoll, target.rarity));
        }
        const std::size_t destination = static_cast<std::size_t>(
            subset | requirementBit);
        reachable[destination] = Backend::maskOr(
            reachable[destination],
            Backend::maskAnd(existing, qualifies));
      }
    }
  }

  BRAINSTORM_ARBITRARY_NEGATIVE_INLINE Mask complete() const {
    return reachable[static_cast<std::size_t>(
        (1 << criteria.requirementCount) - 1)];
  }
};

template <class Backend>
BRAINSTORM_ARBITRARY_NEGATIVE_INLINE typename Backend::Mask evaluateLanes(
    const Workspace& workspace,
    const int* indices, int valid,
    const ArbitraryNegativeCriteria& criteria) {
  using D = typename Backend::DoubleVector;
  const auto& seeds = workspace.seeds;
  const auto gatherIndices = Backend::indices(indices, valid);
  const auto hashedSeed = Backend::gather(
      seeds.hashedSeeds.data(), gatherIndices);
  const auto seedHash4 = Backend::gather(
      workspace.seedHashes4.data(), gatherIndices);
  const auto seedHash7 = Backend::gather(
      workspace.seedHashes7.data(), gatherIndices);
  const auto seedHash10 = Backend::gather(
      workspace.seedHashes10.data(), gatherIndices);
  VectorRequirementMatcher<Backend> matcher(criteria);

  const bool needsSoul =
      anyRequirementAcceptsSource(criteria, soulSourceBit);
  const bool needsJudgement =
      anyRequirementAcceptsSource(criteria, judgementSourceBit);
  if (needsSoul || needsJudgement) {
    AlignedValues<D, 3> startingStates;
    startingStates[0] = seedHash7;
    startingStates[1] = seedHash10;
    startingStates[2] = seedHash7;
    initialStateBundle<Backend, 3>(
        startingStates,
        std::array<std::string_view, 3>{
            soulEditionKey(), judgementRarityKey(),
            judgementEditionKey()});
    if (needsSoul) {
      matcher.observe(
          soulSourceBit,
          VectorEventRoll<Backend>{
              unconditionalEditionEvent<Backend>(
                  hashedSeed, startingStates[0]),
              Backend::set1(0.0)},
          true);
      matcher.observe(
          soulSourceBit,
          VectorEventRoll<Backend>{
              unconditionalEditionEvent<Backend>(
                  hashedSeed, startingStates[0]),
              Backend::set1(0.0)},
          true);
    }
    if (needsJudgement) {
      matcher.observe(
          judgementSourceBit,
          conditionalJokerEvent<Backend>(
              trueMask<Backend>(), hashedSeed,
              startingStates[1], startingStates[2]));
    }
  }

  const BuffoonBoundaries& boundaries = buffoonBoundaries();
  for (int ante = 1; ante <= criteria.maximumAnte; ++ante) {
    const unsigned int sourceBit = anteSourceBit(ante);
    if (!anyRequirementAcceptsSource(criteria, sourceBit)) {
      continue;
    }
    const AnteKeys& keys = anteKeys()[static_cast<std::size_t>(ante - 1)];
    AlignedValues<D, 6> anteStates;
    anteStates[0] = seedHash4;
    anteStates[1] = seedHash10;
    anteStates[2] = seedHash7;
    anteStates[3] = seedHash10;
    anteStates[4] = seedHash10;
    anteStates[5] = seedHash7;
    initialStateBundle<Backend, 6>(
        anteStates,
        std::array<std::string_view, 6>{
            keys.cardType, keys.shopRarity, keys.shopEdition,
            keys.packType, keys.buffoonRarity, keys.buffoonEdition});
    auto& cardType = anteStates[0];
    auto& shopRarity = anteStates[1];
    auto& shopEdition = anteStates[2];
    auto& packType = anteStates[3];
    auto& buffoonRarity = anteStates[4];
    auto& buffoonEdition = anteStates[5];
    const int shops = ante == 1 ? criteria.anteOneShops : 3;

    for (int shop = 0; shop < shops; ++shop) {
      for (int card = 0; card < criteria.stockSize; ++card) {
        cardType = BrainstormOpeningBatchDetail::
            vectorAdvanceNode<Backend>(cardType);
        const auto typePoll = Backend::mul(
            randomFromState<Backend>(cardType, hashedSeed),
            Backend::set1(shopTotalRate(criteria.shopRate)));
        const auto joker = Backend::less(
            typePoll, Backend::set1(20.0));
        matcher.observe(
            sourceBit, conditionalJokerEvent<Backend>(
                joker, hashedSeed, shopRarity, shopEdition));
      }

      for (int displayed = 0; displayed < 2; ++displayed) {
        auto normalBuffoon = falseMask<Backend>();
        auto largeBuffoon = falseMask<Backend>();
        if (ante == 1 && shop == 0 && displayed == 0) {
          normalBuffoon = trueMask<Backend>();
        } else {
          packType = BrainstormOpeningBatchDetail::
              vectorAdvanceNode<Backend>(packType);
          const auto packPoll = Backend::mul(
              randomFromState<Backend>(packType, hashedSeed),
              Backend::set1(PACKS[0].weight));
          normalBuffoon = intervalOpenClosed<Backend>(
              packPoll, boundaries.normalLower, boundaries.normalUpper);
          largeBuffoon = Backend::maskOr(
              intervalOpenClosed<Backend>(
                  packPoll, boundaries.jumboLower,
                  boundaries.jumboUpper),
              intervalOpenClosed<Backend>(
                  packPoll, boundaries.megaLower,
                  boundaries.megaUpper));
        }
        const auto anyBuffoon = Backend::maskOr(
            normalBuffoon, largeBuffoon);
        for (int card = 0; card < 4; ++card) {
          const auto draws = card < 2 ? anyBuffoon : largeBuffoon;
          matcher.observe(
              sourceBit, conditionalJokerEvent<Backend>(
                  draws, hashedSeed,
                  buffoonRarity, buffoonEdition));
        }
      }
    }
  }
  return matcher.complete();
}

template <class Backend>
void collectVectorCandidates(
    Workspace& workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t>& survivors) {
  workspace.prepare(count);
  BrainstormOpeningBatchDetail::fillChunk(
      workspace.seeds, startSeedId, count);
  survivors.clear();
  survivors.reserve(count / 100 + 8);

  alignas(64) double hashLanes[4][Backend::lanes];
  for (std::size_t offset = 0; offset < count;
       offset += Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Backend::lanes, count - offset));
    for (int lane = 0; lane < Backend::lanes; ++lane) {
      workspace.indices[static_cast<std::size_t>(lane)] =
          static_cast<int>(offset) + std::min(lane, valid - 1);
    }
    AlignedValues<typename Backend::DoubleVector, 4> hashes;
    seedPrefixHashes<Backend>(
        workspace.seeds, workspace.indices.data(), valid, hashes);
    for (std::size_t hash = 0; hash < 4; ++hash) {
      Backend::store(hashLanes[hash], hashes[hash]);
    }
    for (int lane = 0; lane < valid; ++lane) {
      const std::size_t index =
          offset + static_cast<std::size_t>(lane);
      workspace.seeds.hashedSeeds[index] = hashLanes[0][lane];
      workspace.seedHashes4[index] = hashLanes[1][lane];
      workspace.seedHashes7[index] = hashLanes[2][lane];
      workspace.seedHashes10[index] = hashLanes[3][lane];
    }
  }

  for (std::size_t offset = 0; offset < count;
       offset += Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Backend::lanes, count - offset));
    for (int lane = 0; lane < Backend::lanes; ++lane) {
      workspace.indices[static_cast<std::size_t>(lane)] =
          static_cast<int>(offset) + std::min(lane, valid - 1);
    }
    const int validBits = (1 << valid) - 1;
    const int passed = Backend::maskBits(evaluateLanes<Backend>(
        workspace, workspace.indices.data(), valid,
        workspace.criteria)) & validBits;
    for (int lane = 0; lane < valid; ++lane) {
      if ((passed & (1 << lane)) != 0) {
        survivors.push_back(
            static_cast<std::uint32_t>(offset)
            + static_cast<std::uint32_t>(lane));
      }
    }
  }
}

}  // namespace BrainstormArbitraryNegativeBatchDetail

#endif  // BRAINSTORM_ARBITRARY_NEGATIVE_BATCH_VECTOR_HPP
