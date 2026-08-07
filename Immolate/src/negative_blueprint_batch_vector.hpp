#ifndef BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_VECTOR_HPP
#define BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_VECTOR_HPP

#include "negative_blueprint_batch.hpp"
#include "opening_batch_vector.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <string_view>
#include <vector>

namespace BrainstormNegativeBlueprintBatchDetail {

using BrainstormOpeningBatchDetail::ChunkSeeds;

#if defined(__GNUC__)
#define BRAINSTORM_NEGATIVE_VECTOR_ALWAYS_INLINE \
  inline __attribute__((always_inline))
#else
#define BRAINSTORM_NEGATIVE_VECTOR_ALWAYS_INLINE inline
#endif

inline constexpr double negativeThreshold = 0.997;
inline constexpr double rareThreshold = 0.95;
inline constexpr std::size_t preferredChunkSize = 4096;
inline constexpr std::string_view shopCardTypeKey = "cdt1";
inline constexpr std::string_view shopRarityKey = "rarity1sho";
inline constexpr std::string_view shopEditionKey = "edisho1";
inline constexpr std::string_view packTypeKey = "shop_pack1";
inline constexpr std::string_view buffoonRarityKey = "rarity1buf";
inline constexpr std::string_view buffoonEditionKey = "edibuf1";

inline double shopTotalRate(NegativeBlueprintShopRate rate) {
  switch (rate) {
  case NegativeBlueprintShopRate::Ghost:
    return 30.0;
  case NegativeBlueprintShopRate::Zodiac:
    return 39.2;
  case NegativeBlueprintShopRate::Ordinary:
    return 28.0;
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

inline const BuffoonBoundaries &buffoonBoundaries() {
  // Match Instance::randweightedchoice's ordered additions exactly. This is
  // deliberately derived from PACKS rather than reconstructed decimal sums.
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
  ChunkSeeds seeds;
  std::array<int, 8> indices{};
  std::vector<std::uint32_t> localSurvivors;
  NegativeBlueprintCriteria criteria;

  void prepare(std::size_t count) {
    seeds.resize(count);
    localSurvivors.reserve(count / 50 + 8);
  }
};

template <class Backend>
BRAINSTORM_NEGATIVE_VECTOR_ALWAYS_INLINE
typename Backend::DoubleVector initialState(
    const ChunkSeeds &seeds, const int *indices, int valid,
    std::string_view key) {
  auto state =
      BrainstormOpeningBatchDetail::vectorSeedPseudohash<Backend>(
          seeds, indices, valid, static_cast<int>(key.size()));
  return BrainstormOpeningBatchDetail::vectorPseudohashFrom<Backend>(
      key, state);
}

template <class Backend>
BRAINSTORM_NEGATIVE_VECTOR_ALWAYS_INLINE
typename Backend::DoubleVector randomFromState(
    typename Backend::DoubleVector state,
    typename Backend::DoubleVector hashedSeed) {
  return BrainstormOpeningBatchDetail::vectorRandom<Backend>(
      Backend::mul(
          Backend::add(state, hashedSeed), Backend::set1(0.5)));
}

template <class Backend>
BRAINSTORM_NEGATIVE_VECTOR_ALWAYS_INLINE typename Backend::Mask
intervalOpenClosed(typename Backend::DoubleVector value,
                   double lower, double upper) {
  return Backend::maskAnd(
      Backend::greater(value, Backend::set1(lower)),
      Backend::lessEqual(value, Backend::set1(upper)));
}

template <class Backend, bool RequireRare>
BRAINSTORM_NEGATIVE_VECTOR_ALWAYS_INLINE int evaluateLanes(
    const ChunkSeeds &seeds, const int *indices, int valid,
    const NegativeBlueprintCriteria &criteria) {
  using D = typename Backend::DoubleVector;
  using M = typename Backend::Mask;

  const auto gatherIndices = Backend::indices(indices, valid);
  const D hashedSeed = Backend::gather(
      seeds.hashedSeeds.data(), gatherIndices);
  D shopTypeState = initialState<Backend>(
      seeds, indices, valid, shopCardTypeKey);
  D shopRarityState = Backend::set1(0.0);
  if constexpr (RequireRare) {
    shopRarityState = initialState<Backend>(
        seeds, indices, valid, shopRarityKey);
  }
  D shopEditionState = initialState<Backend>(
      seeds, indices, valid, shopEditionKey);
  D packState = initialState<Backend>(
      seeds, indices, valid, packTypeKey);
  D buffoonRarityState = Backend::set1(0.0);
  if constexpr (RequireRare) {
    buffoonRarityState = initialState<Backend>(
        seeds, indices, valid, buffoonRarityKey);
  }
  D buffoonEditionState = initialState<Backend>(
      seeds, indices, valid, buffoonEditionKey);
  const BuffoonBoundaries &boundaries = buffoonBoundaries();
  M passed = Backend::less(
      Backend::set1(1.0), Backend::set1(0.0));

  for (int shop = 0; shop < criteria.shopCards; ++shop) {
    shopTypeState =
        BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(
            shopTypeState);
    const D typePoll = Backend::mul(
        randomFromState<Backend>(shopTypeState, hashedSeed),
        Backend::set1(shopTotalRate(criteria.shopRate)));
    const M joker = Backend::less(
        typePoll, Backend::set1(20.0));

    if constexpr (RequireRare) {
      const D advancedRarity =
          BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(
              shopRarityState);
      shopRarityState = Backend::select(
          joker, shopRarityState, advancedRarity);
    }
    const D advancedEdition =
        BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(
            shopEditionState);
    shopEditionState = Backend::select(
        joker, shopEditionState, advancedEdition);
    M qualifies;
    if constexpr (RequireRare) {
      const D rarityRoll = randomFromState<Backend>(
          shopRarityState, hashedSeed);
      const M rareJoker = Backend::maskAnd(
          joker,
          Backend::greater(
              rarityRoll, Backend::set1(rareThreshold)));
      qualifies = Backend::less(
          Backend::set1(1.0), Backend::set1(0.0));
      if (Backend::maskBits(rareJoker) != 0) {
        const D editionRoll = randomFromState<Backend>(
            shopEditionState, hashedSeed);
        qualifies = Backend::maskAnd(
            rareJoker,
            Backend::greater(
                editionRoll, Backend::set1(negativeThreshold)));
      }
    } else {
      const D editionRoll = randomFromState<Backend>(
          shopEditionState, hashedSeed);
      qualifies = Backend::maskAnd(
          joker,
          Backend::greater(
              editionRoll, Backend::set1(negativeThreshold)));
    }
    passed = Backend::maskOr(
        passed, qualifies);
  }

  // The first displayed Ante-1 pack is deterministically a normal Buffoon
  // Pack in the supported game version, so it consumes two Joker draws.
  if (criteria.displayedPacks > 0) {
    for (int card = 0; card < 2; ++card) {
      if constexpr (RequireRare) {
        buffoonRarityState =
            BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(
                buffoonRarityState);
      }
      buffoonEditionState =
          BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(
              buffoonEditionState);
      M qualifies;
      if constexpr (RequireRare) {
        const M rare = Backend::greater(
            randomFromState<Backend>(
                buffoonRarityState, hashedSeed),
            Backend::set1(rareThreshold));
        qualifies = Backend::less(
            Backend::set1(1.0), Backend::set1(0.0));
        if (Backend::maskBits(rare) != 0) {
          qualifies = Backend::maskAnd(
              rare,
              Backend::greater(
                  randomFromState<Backend>(
                      buffoonEditionState, hashedSeed),
                  Backend::set1(negativeThreshold)));
        }
      } else {
        qualifies = Backend::greater(
            randomFromState<Backend>(buffoonEditionState, hashedSeed),
            Backend::set1(negativeThreshold));
      }
      passed = Backend::maskOr(passed, qualifies);
    }
  }

  for (int displayed = 1; displayed < criteria.displayedPacks;
       ++displayed) {
    packState =
        BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(
            packState);
    const D packPoll = Backend::mul(
        randomFromState<Backend>(packState, hashedSeed),
        Backend::set1(PACKS[0].weight));

    // The scalar weighted-choice loop assigns boundary values to the pack on
    // their left, hence each pack interval is (lower, upper].
    const M normalBuffoon = intervalOpenClosed<Backend>(
        packPoll, boundaries.normalLower, boundaries.normalUpper);
    const M largeBuffoon = Backend::maskOr(
        intervalOpenClosed<Backend>(
            packPoll, boundaries.jumboLower, boundaries.jumboUpper),
        intervalOpenClosed<Backend>(
            packPoll, boundaries.megaLower, boundaries.megaUpper));
    const M anyBuffoon =
        Backend::maskOr(normalBuffoon, largeBuffoon);

    for (int card = 0; card < 4; ++card) {
      const M draws = card < 2 ? anyBuffoon : largeBuffoon;
      if constexpr (RequireRare) {
        const D advancedRarity =
            BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(
                buffoonRarityState);
        buffoonRarityState = Backend::select(
            draws, buffoonRarityState, advancedRarity);
      }
      const D advancedEdition =
          BrainstormOpeningBatchDetail::vectorAdvanceNode<Backend>(
              buffoonEditionState);
      buffoonEditionState = Backend::select(
          draws, buffoonEditionState, advancedEdition);
      M qualifies;
      if constexpr (RequireRare) {
        const M rareDraw = Backend::maskAnd(
            draws,
            Backend::greater(
                randomFromState<Backend>(
                    buffoonRarityState, hashedSeed),
                Backend::set1(rareThreshold)));
        qualifies = Backend::less(
            Backend::set1(1.0), Backend::set1(0.0));
        if (Backend::maskBits(rareDraw) != 0) {
          const D editionRoll = randomFromState<Backend>(
              buffoonEditionState, hashedSeed);
          qualifies = Backend::maskAnd(
              rareDraw,
              Backend::greater(
                  editionRoll, Backend::set1(negativeThreshold)));
        }
      } else {
        const D editionRoll = randomFromState<Backend>(
            buffoonEditionState, hashedSeed);
        qualifies = Backend::maskAnd(
            draws,
            Backend::greater(
                editionRoll, Backend::set1(negativeThreshold)));
      }
      passed = Backend::maskOr(
          passed, qualifies);
    }
  }

  const int validBits = (1 << valid) - 1;
  return Backend::maskBits(passed) & validBits;
}

template <class Backend>
void collectVectorCandidates(
    Workspace &workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets) {
  workspace.prepare(count);
  BrainstormOpeningBatchDetail::fillChunk(
      workspace.seeds, startSeedId, count);
  survivorOffsets.clear();
  survivorOffsets.reserve(count / 50 + 8);

  alignas(64) double hashLanes[Backend::lanes];
  for (std::size_t offset = 0; offset < count;
       offset += Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Backend::lanes, count - offset));
    for (int lane = 0; lane < Backend::lanes; ++lane) {
      workspace.indices[static_cast<std::size_t>(lane)] =
          static_cast<int>(offset) + std::min(lane, valid - 1);
    }
    const auto hash =
        BrainstormOpeningBatchDetail::vectorSeedPseudohash<Backend>(
            workspace.seeds, workspace.indices.data(), valid, 0);
    Backend::store(hashLanes, hash);
    for (int lane = 0; lane < valid; ++lane) {
      workspace.seeds.hashedSeeds[
          offset + static_cast<std::size_t>(lane)] = hashLanes[lane];
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
    const int passed = workspace.criteria.requireRare
        ? evaluateLanes<Backend, true>(
            workspace.seeds, workspace.indices.data(), valid,
            workspace.criteria)
        : evaluateLanes<Backend, false>(
            workspace.seeds, workspace.indices.data(), valid,
            workspace.criteria);
    for (int lane = 0; lane < valid; ++lane) {
      if ((passed & (1 << lane)) != 0) {
        survivorOffsets.push_back(
            static_cast<std::uint32_t>(offset)
            + static_cast<std::uint32_t>(lane));
      }
    }
  }
}

} // namespace BrainstormNegativeBlueprintBatchDetail

#endif // BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH_VECTOR_HPP
