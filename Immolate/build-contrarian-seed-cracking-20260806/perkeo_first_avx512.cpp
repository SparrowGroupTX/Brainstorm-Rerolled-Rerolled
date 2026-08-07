// Diagnostic-only AVX-512 implementation that evaluates the independently
// keyed Legendary predicate before the expensive lock-aware Charm/Soul gate.
// Including the production backend in this translation unit keeps every SIMD
// primitive and staged top-nine tag classifier identical to production.

#include "../src/opening_batch_avx512.cpp"

#include <algorithm>
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace BrainstormOpeningBatchDetail {

template <class Backend>
void vectorInitialLegendaryRollsShared(ChunkSeeds &seeds,
                                       std::size_t count,
                                       std::vector<double> &rolls) {
  rolls.resize(count);
  seeds.sharedGroupStarts.clear();
  seeds.eightCharacterSeedIndices.clear();
  seeds.eightCharacterGroupIndices.clear();

  std::size_t index = 0;
  while (index < count) {
    if (seeds.lengths[index] != 8) {
      const double hashed = scalarSeedHashFromColumns(seeds, index, 0);
      double value = scalarSeedHashFromColumns(seeds, index, 6);
      value = scalarPseudohashFromPositive(legendaryKey, value);
      value = scalarAdvanceNode(value);
      seeds.hashedSeeds[index] = hashed;
      rolls[index] = lua_random_from_seed((value + hashed) * 0.5);
      ++index;
      continue;
    }

    const std::size_t runStart = index;
    std::size_t runEnd = runStart + 1;
    while (runEnd < count && seeds.lengths[runEnd] == 8) {
#ifndef NDEBUG
      for (std::size_t position = 0; position < 7; ++position) {
        assert(characterAt(seeds, runStart, static_cast<int>(position))
               == characterAt(seeds, runEnd, static_cast<int>(position)));
      }
#endif
      ++runEnd;
    }
    const int groupIndex = static_cast<int>(seeds.sharedGroupStarts.size());
    seeds.sharedGroupStarts.push_back(static_cast<int>(runStart));
    for (std::size_t seedIndex = runStart; seedIndex < runEnd; ++seedIndex) {
      seeds.eightCharacterSeedIndices.push_back(static_cast<int>(seedIndex));
      seeds.eightCharacterGroupIndices.push_back(groupIndex);
    }
    index = runEnd;
  }

  const std::size_t groupCount = seeds.sharedGroupStarts.size();
  seeds.sharedPrefix0.resize(groupCount);
  // Reuse this scratch column for prefix length 6 in the diagnostic.
  seeds.sharedPrefix4.resize(groupCount);
  alignas(64) double hashLanes[Backend::lanes];
  alignas(64) double keyLanes[Backend::lanes];
  for (std::size_t groupOffset = 0; groupOffset < groupCount;
       groupOffset += Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Backend::lanes, groupCount - groupOffset));
    const auto groupStarts = Backend::indices(
        seeds.sharedGroupStarts.data() + groupOffset, valid);
    auto prefix0 = Backend::set1(1.0);
    auto prefix6 = Backend::set1(1.0);
    for (int position = 0; position < 7; ++position) {
      const auto character = Backend::gatherCharacter(
          seeds.packedCharacters.data(), groupStarts, position);
      prefix0 = vectorPseudostep<Backend>(
          prefix0, character, static_cast<double>(8 - position));
      prefix6 = vectorPseudostep<Backend>(
          prefix6, character, static_cast<double>(14 - position));
    }
    Backend::store(hashLanes, prefix0);
    Backend::store(keyLanes, prefix6);
    for (int lane = 0; lane < valid; ++lane) {
      const std::size_t output = groupOffset + static_cast<std::size_t>(lane);
      seeds.sharedPrefix0[output] = hashLanes[lane];
      seeds.sharedPrefix4[output] = keyLanes[lane];
    }
  }

  constexpr int pipelineWidth = BRAINSTORM_FRESH_ROLL_PIPELINE_WIDTH;
  constexpr std::size_t pipelineSeeds =
      static_cast<std::size_t>(Backend::lanes * pipelineWidth);
  using D = typename Backend::DoubleVector;
  const std::size_t eightCount = seeds.eightCharacterSeedIndices.size();
  for (std::size_t offset = 0; offset < eightCount;
       offset += pipelineSeeds) {
    const int vectorCount = static_cast<int>(std::min<std::size_t>(
        pipelineWidth,
        (eightCount - offset + Backend::lanes - 1) / Backend::lanes));
    D hashed[pipelineWidth];
    D values[pipelineWidth];
    int valids[pipelineWidth];
    for (int vector = 0; vector < vectorCount; ++vector) {
      const std::size_t vectorOffset = offset
          + static_cast<std::size_t>(vector * Backend::lanes);
      const int valid = static_cast<int>(std::min<std::size_t>(
          Backend::lanes, eightCount - vectorOffset));
      valids[vector] = valid;
      const auto seedIndices = Backend::indices(
          seeds.eightCharacterSeedIndices.data() + vectorOffset, valid);
      const auto groupIndices = Backend::indices(
          seeds.eightCharacterGroupIndices.data() + vectorOffset, valid);
      const auto character = Backend::gatherCharacter(
          seeds.packedCharacters.data(), seedIndices, 7);
      hashed[vector] = vectorPseudostep<Backend>(
          Backend::gather(seeds.sharedPrefix0.data(), groupIndices),
          character, 1.0);
      values[vector] = vectorPseudostep<Backend>(
          Backend::gather(seeds.sharedPrefix4.data(), groupIndices),
          character, 7.0);
    }

    for (std::size_t keyIndex = legendaryKey.size(); keyIndex > 0;
         --keyIndex) {
      const auto character = Backend::set1(static_cast<unsigned char>(
          legendaryKey[keyIndex - 1]));
      for (int vector = 0; vector < vectorCount; ++vector) {
        values[vector] = vectorPseudostep<Backend>(
            values[vector], character, static_cast<double>(keyIndex));
      }
    }

    for (int vector = 0; vector < vectorCount; ++vector) {
      auto value = vectorAdvanceNode<Backend>(values[vector]);
      value = Backend::mul(
          Backend::add(value, hashed[vector]), Backend::set1(0.5));
      Backend::store(hashLanes, hashed[vector]);
      Backend::store(keyLanes, vectorRandom<Backend>(value));
      const std::size_t vectorOffset = offset
          + static_cast<std::size_t>(vector * Backend::lanes);
      for (int lane = 0; lane < valids[vector]; ++lane) {
        const std::size_t packedIndex = vectorOffset
            + static_cast<std::size_t>(lane);
        const std::size_t seedIndex = static_cast<std::size_t>(
            seeds.eightCharacterSeedIndices[packedIndex]);
        seeds.hashedSeeds[seedIndex] = hashLanes[lane];
        rolls[seedIndex] = keyLanes[lane];
      }
    }
  }
}

template <class Backend>
void collectPerkeoFirstCandidates(Workspace &workspace,
                                  long long startSeedId,
                                  std::size_t count,
                                  std::vector<std::uint32_t> &survivors) {
  workspace.prepare(count);
  fillChunk(workspace.seeds, startSeedId, count);
  vectorInitialLegendaryRollsShared<Backend>(
      workspace.seeds, count, workspace.rolls);

  workspace.active.clear();
  for (std::size_t index = 0; index < count; ++index) {
    if (static_cast<int>(workspace.rolls[index]
                         * LEGENDARY_JOKERS.size())
        == workspace.criteria.legendaryIndex) {
      workspace.active.push_back(static_cast<int>(index));
    }
  }

  vectorFreshRolls<Backend>(workspace.seeds, workspace.active, tagKey,
                            workspace.rolls, nullptr,
                            &workspace.tagCategories);
  workspace.charm.clear();
  workspace.scratch.clear();
  for (std::size_t index = 0; index < workspace.active.size(); ++index) {
    const std::uint8_t category = workspace.tagCategories[index];
    if (category == openingTagCharm) {
      workspace.charm.push_back(workspace.active[index]);
    } else if (category == openingTagLocked) {
      workspace.scratch.push_back(workspace.active[index]);
    }
  }

  int resample = 2;
  while (!workspace.scratch.empty() && resample <= 1000) {
    const std::string key = std::string(tagKey) + "_resample"
        + std::to_string(resample);
    vectorFreshRolls<Backend>(workspace.seeds, workspace.scratch, key,
                              workspace.rolls, nullptr,
                              &workspace.tagCategories);
    workspace.active.clear();
    for (std::size_t index = 0; index < workspace.scratch.size(); ++index) {
      const std::uint8_t category = workspace.tagCategories[index];
      if (category == openingTagCharm) {
        workspace.charm.push_back(workspace.scratch[index]);
      } else if (category == openingTagLocked && resample < 1000) {
        workspace.active.push_back(workspace.scratch[index]);
      }
    }
    workspace.scratch.swap(workspace.active);
    ++resample;
  }

  if (workspace.criteria.minimumSoulCount <= 1) {
    vectorSoulFlags<Backend>(workspace.seeds, workspace.charm,
                             workspace.soulCounts);
  } else {
    vectorSoulCounts<Backend>(workspace.seeds, workspace.charm,
                              workspace.soulCounts,
                              workspace.criteria.minimumSoulCount);
  }
  survivors.clear();
  for (std::size_t index = 0; index < workspace.charm.size(); ++index) {
    if (workspace.soulCounts[index]
        >= workspace.criteria.minimumSoulCount) {
      survivors.push_back(
          static_cast<std::uint32_t>(workspace.charm[index]));
    }
  }
  std::sort(survivors.begin(), survivors.end());
}

} // namespace BrainstormOpeningBatchDetail

void collectOpeningCharmSoulPerkeoFirstAvx512(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivors) {
  auto &typed = *static_cast<BrainstormOpeningBatchDetail::Workspace *>(
      workspace);
  BrainstormOpeningBatchDetail::collectPerkeoFirstCandidates<Avx512Backend>(
      typed, startSeedId, count, survivors);
}
