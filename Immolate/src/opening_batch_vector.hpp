#ifndef BRAINSTORM_OPENING_BATCH_VECTOR_HPP
#define BRAINSTORM_OPENING_BATCH_VECTOR_HPP

#include "items.hpp"
#include "opening_batch.hpp"
#include "seed.hpp"
#include "util.hpp"

#include <algorithm>
#include <array>
#include <cassert>
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace BrainstormOpeningBatchDetail {

#if defined(__GNUC__)
#define BRAINSTORM_VECTOR_ALWAYS_INLINE inline __attribute__((always_inline))
#else
#define BRAINSTORM_VECTOR_ALWAYS_INLINE inline
#endif

#if !defined(BRAINSTORM_FRESH_ROLL_PIPELINE_WIDTH)
#define BRAINSTORM_FRESH_ROLL_PIPELINE_WIDTH 4
#endif
static_assert(BRAINSTORM_FRESH_ROLL_PIPELINE_WIDTH >= 1);

inline constexpr std::uint64_t allBits = ~std::uint64_t{0};
inline constexpr std::uint64_t randomMantissa = 4503599627370495ull;
inline constexpr std::uint64_t oneExponent = 4607182418800017408ull;
inline constexpr double luaPi = 3.14159265358979323846;
inline constexpr double luaE = 2.7182818284590452354;
inline constexpr double hashA = 1.1239285023;
inline constexpr double hashPi = 3.141592653589793116;
inline constexpr double nodeMultiplier = 1.72431234;
inline constexpr double nodeAddend = 2.134453429141;
inline constexpr double round13Precision = 10000000000000.0;
inline constexpr double soulThreshold = 0.997;
inline constexpr std::string_view tagKey = "Tag1";
inline constexpr std::string_view soulTarotKey = "soul_Tarot1";
inline constexpr std::string_view legendaryKey = "Joker4";
inline constexpr std::size_t preferredChunkSize = 4096;
inline constexpr std::uint8_t openingTagOther = 0;
inline constexpr std::uint8_t openingTagLocked = 1;
inline constexpr std::uint8_t openingTagCharm = 2;
inline constexpr std::uint8_t openingTagAmbiguous = 0xff;

static_assert(TAGS.size() == 24 && TAGS[10] == Item::Charm_Tag);
static_assert(LEGENDARY_JOKERS.size() == 5
              && LEGENDARY_JOKERS[4] == Item::Perkeo);

inline bool isAnteOneLockedTagIndex(int index) {
  const Item tag = TAGS[static_cast<std::size_t>(index)];
  return tag == Item::Negative_Tag || tag == Item::Standard_Tag
      || tag == Item::Meteor_Tag || tag == Item::Buffoon_Tag
      || tag == Item::Handy_Tag || tag == Item::Garbage_Tag
      || tag == Item::Ethereal_Tag || tag == Item::Top_up_Tag
      || tag == Item::Orbital_Tag;
}

inline constexpr std::uint8_t openingTagCategory(int index) {
  return index == 10
      ? openingTagCharm
      : (index == 2 || index == 9 || index == 11 || index == 12
             || index == 13 || index == 14 || index == 15 || index == 20
             || index == 22
         ? openingTagLocked
         : openingTagOther);
}

// A Lua random() result is a 52-bit mantissa divided by 2^52. The top nine
// bits alone identify the opening-tag category for 505 of their 512 possible
// values. Only prefixes whose mantissa interval crosses a Charm/lock category
// boundary require the remaining 43 bits. Building this table with integer
// interval endpoints keeps the staged decision exact. Nine bits cost the same
// GF(2) shift terms as eight here while halving the exact fallback rate.
inline constexpr std::array<std::uint8_t, 512>
buildOpeningTagPrefixCategories() {
  std::array<std::uint8_t, 512> result{};
  constexpr std::uint64_t suffixWidth = std::uint64_t{1} << 43u;
  constexpr std::uint64_t randomRange = std::uint64_t{1} << 52u;
  for (std::uint64_t prefix = 0; prefix < result.size(); ++prefix) {
    const std::uint64_t minimumMantissa = prefix * suffixWidth;
    const std::uint64_t maximumMantissa =
        minimumMantissa + suffixWidth - 1;
    const int minimumTag = static_cast<int>(
        minimumMantissa * TAGS.size() / randomRange);
    const int maximumTag = static_cast<int>(
        maximumMantissa * TAGS.size() / randomRange);
    const std::uint8_t minimumCategory = openingTagCategory(minimumTag);
    result[static_cast<std::size_t>(prefix)] =
        minimumCategory == openingTagCategory(maximumTag)
        ? minimumCategory
        : openingTagAmbiguous;
  }
  return result;
}

inline constexpr auto openingTagPrefixCategories =
    buildOpeningTagPrefixCategories();
static_assert(openingTagPrefixCategories[42] == openingTagAmbiguous);
static_assert(openingTagPrefixCategories[213] == openingTagAmbiguous);
static_assert(openingTagPrefixCategories[234] == openingTagAmbiguous);

struct CompactSeed {
  std::array<std::uint8_t, 8> digits{};
  std::uint64_t packedCharacters = 0;
  int length = 0;

  explicit CompactSeed(long long rawId) {
    const std::uint64_t initialCharacter = static_cast<unsigned char>(
        seedChars[0]);
    for (int position = 0; position < 8; ++position) {
      packedCharacters |= initialCharacter << (position * 8);
    }

    long long id = normalizeSeedId(rawId);
    for (int position = 0; position < 8; ++position) {
      if (id <= 0) {
        break;
      }
      ++length;
      digits[static_cast<std::size_t>(position)] =
          static_cast<std::uint8_t>(
              (id - 1) / idCoeff[static_cast<std::size_t>(position)]);
      setPackedCharacter(
          position, digits[static_cast<std::size_t>(position)]);
      id -= 1
          + static_cast<long long>(
                digits[static_cast<std::size_t>(position)])
              * idCoeff[static_cast<std::size_t>(position)];
    }
  }

  void setPackedCharacter(int position, std::uint8_t digit) {
    const int shift = position * 8;
    const std::uint64_t mask = std::uint64_t{0xff} << shift;
    packedCharacters = (packedCharacters & ~mask)
        | (static_cast<std::uint64_t>(static_cast<unsigned char>(
               seedChars[digit]))
           << shift);
  }

  void next() {
    if (length < 8) {
      digits[static_cast<std::size_t>(length++)] = 0;
      return;
    }
    for (int position = 7; position >= 0; --position) {
      std::uint8_t &digit = digits[static_cast<std::size_t>(position)];
      if (digit == 34) {
        digit = 0;
        setPackedCharacter(position, digit);
        --length;
      } else {
        ++digit;
        setPackedCharacter(position, digit);
        break;
      }
    }
  }
};

struct ChunkSeeds {
  // All eight seed characters occupy one word. The sentinel word and length
  // padding make the backend's unaligned four-byte gathers safe at the end of
  // a partial chunk.
  std::vector<std::uint64_t> packedCharacters;
  std::vector<std::uint8_t> lengths;
  std::vector<double> hashedSeeds;
  // Consecutive eight-character seeds change only their final stored digit.
  // These reusable buffers map those seeds to the shared seven-digit prefix
  // used by the initial hashed-seed and Tag1 computations.
  std::vector<int> sharedGroupStarts;
  std::vector<int> eightCharacterSeedIndices;
  std::vector<int> eightCharacterGroupIndices;
  std::vector<double> sharedPrefix0;
  std::vector<double> sharedPrefix4;
  std::vector<double> sharedPrefix14;
  std::vector<double> resampleHash14;

  void resize(std::size_t count) {
    packedCharacters.resize(count + 1);
    packedCharacters[count] = 0;
    lengths.resize(count + 4);
    std::fill(lengths.begin() + static_cast<std::ptrdiff_t>(count),
              lengths.end(), std::uint8_t{0});
    hashedSeeds.resize(count);
    resampleHash14.resize(count);
  }
};

struct Workspace {
  ChunkSeeds seeds;
  std::vector<int> active;
  std::vector<int> scratch;
  std::vector<int> charm;
  std::vector<double> rolls;
  std::vector<std::uint8_t> soulCounts;
  std::vector<std::uint8_t> tagCategories;
  OpeningCharmSoulCriteria criteria;

  void prepare(std::size_t count) {
    seeds.resize(count);
    const std::size_t sharedGroupCapacity = count / 32 + 8;
    seeds.sharedGroupStarts.reserve(sharedGroupCapacity);
    seeds.eightCharacterSeedIndices.reserve(count);
    seeds.eightCharacterGroupIndices.reserve(count);
    seeds.sharedPrefix0.reserve(sharedGroupCapacity);
    seeds.sharedPrefix4.reserve(sharedGroupCapacity);
    seeds.sharedPrefix14.reserve(sharedGroupCapacity);
    active.reserve(count);
    scratch.reserve(count);
    charm.reserve(count / 8 + 8);
    rolls.reserve(count);
    soulCounts.reserve(count);
    tagCategories.reserve(count);
  }
};

struct TagWorkspace {
  Workspace vectorWorkspace;
  int targetTagIndex = -1;
};

inline void fillChunk(ChunkSeeds &chunk, long long startSeedId,
                      std::size_t count) {
  CompactSeed seed(startSeedId);
  for (std::size_t index = 0; index < count; ++index) {
    chunk.lengths[index] = static_cast<std::uint8_t>(seed.length);
    chunk.packedCharacters[index] = seed.packedCharacters;
    seed.next();
  }
}

inline double characterAt(const ChunkSeeds &seeds, std::size_t index,
                          int position) {
  return static_cast<std::uint8_t>(
      seeds.packedCharacters[index] >> (position * 8));
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE typename Backend::DoubleVector vectorFractPositive(
    typename Backend::DoubleVector value) {
  return Backend::sub(value, Backend::floor(value));
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE typename Backend::DoubleVector vectorPseudostep(
    typename Backend::DoubleVector value,
    typename Backend::DoubleVector character, double position) {
  auto next = Backend::div(Backend::set1(hashA), value);
  next = Backend::mul(next, character);
  next = Backend::mul(next, Backend::set1(hashPi));
  next = Backend::add(next, Backend::set1(hashPi * position));
  return vectorFractPositive<Backend>(next);
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE typename Backend::DoubleVector vectorSeedPseudohash(
    const ChunkSeeds &seeds, const int *indices, int valid,
    int prefixLength) {
  using D = typename Backend::DoubleVector;
  const auto gatherIndices = Backend::indices(indices, valid);
  const D lengths = Backend::gatherByte(
      seeds.lengths.data(), gatherIndices);
  D value = Backend::set1(1.0);
  for (int position = 0; position < 8; ++position) {
    const D character = Backend::gatherCharacter(
        seeds.packedCharacters.data(), gatherIndices, position);
    D next = Backend::div(Backend::set1(hashA), value);
    next = Backend::mul(next, character);
    next = Backend::mul(next, Backend::set1(hashPi));
    const D hashPosition = Backend::add(
        Backend::set1(static_cast<double>(prefixLength - position)), lengths);
    next = Backend::add(
        next, Backend::mul(Backend::set1(hashPi), hashPosition));
    const D advanced = vectorFractPositive<Backend>(next);
    value = Backend::select(
        Backend::greater(
            lengths, Backend::set1(static_cast<double>(position))),
        value, advanced);
  }
  return value;
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE typename Backend::DoubleVector vectorPseudohashFrom(
    std::string_view key, typename Backend::DoubleVector value) {
  for (std::size_t index = key.size(); index > 0; --index) {
    auto next = Backend::div(Backend::set1(hashA), value);
    next = Backend::mul(
        next, Backend::set1(
                  static_cast<unsigned char>(key[index - 1])));
    next = Backend::mul(next, Backend::set1(hashPi));
    next = Backend::add(
        next, Backend::set1(hashPi * static_cast<double>(index)));
    value = vectorFractPositive<Backend>(next);
  }
  return value;
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE typename Backend::DoubleVector vectorRound13Positive(
    typename Backend::DoubleVector value) {
  using D = typename Backend::DoubleVector;

  // Node fractions are finite values in [0, 1). In that domain, rounding
  // away from zero is floor(y) plus one exactly when fract(y) >= 0.5.
  // Avoid floor(y + 0.5): the addition can itself round across the boundary.
  const D scaled = Backend::mul(
      value, Backend::set1(round13Precision));
  const D truncated = Backend::floor(scaled);
  const D scaledFraction = Backend::sub(scaled, truncated);
  const D normalNumerator = Backend::add(
      truncated,
      Backend::select(
          Backend::greaterEqual(
              scaledFraction, Backend::set1(0.5)),
          Backend::set1(0.0), Backend::set1(1.0)));

  const auto divideNumerator = [](D numerator) {
    if constexpr (requires(D input) {
                    Backend::round13Divide(input);
                  }) {
      return Backend::round13Divide(numerator);
    } else {
      return Backend::div(
          numerator, Backend::set1(round13Precision));
    }
  };

  // For x in [0, 1), x - prev(x) <= 2^-53. Multiplication by 1e13
  // separates the exact products by at most 0.001111; both rounded products
  // are below 2^44 and add at most two half-ULPs (0.001953 total). Thus the
  // rounded integer can differ only when fract(scaled) is in
  // [0.5, 0.503064). The wider [0.5, 0.51) gate is conservative and lets the
  // overwhelmingly common vectors skip the entire predecessor calculation.
  const int possibleAmbiguityMask = Backend::maskBits(
      Backend::greaterEqual(scaledFraction, Backend::set1(0.5)))
      & Backend::maskBits(
          Backend::greater(Backend::set1(0.51), scaledFraction));
  if (possibleAmbiguityMask == 0) {
    return divideNumerator(normalNumerator);
  }

  // For positive IEEE-754 doubles, nextafter(x, -1) is the preceding bit
  // pattern. At +0, the true predecessor is a negative subnormal whose
  // rounded result is -0; substituting +0 preserves both the equality test
  // and round13's returned +0 normal case.
  const auto previousBits = Backend::subtractInteger(
      Backend::asInteger(value), Backend::set1Integer(1));
  const D previous = Backend::select(
      Backend::greater(value, Backend::set1(0.0)),
      value, Backend::asDouble(previousBits));
  const D previousScaled = Backend::mul(
      previous, Backend::set1(round13Precision));
  const D previousTruncated = Backend::floor(previousScaled);
  const D previousNumerator = Backend::add(
      previousTruncated,
      Backend::select(
          Backend::greaterEqual(
              Backend::sub(previousScaled, previousTruncated),
              Backend::set1(0.5)),
          Backend::set1(0.0), Backend::set1(1.0)));

  D result = divideNumerator(normalNumerator);
  const int ambiguousMask = Backend::maskBits(
      Backend::notEqual(normalNumerator, previousNumerator));
  if (ambiguousMask != 0) {
    alignas(64) double inputs[Backend::lanes];
    alignas(64) double outputs[Backend::lanes];
    Backend::store(inputs, value);
    Backend::store(outputs, result);
    for (int lane = 0; lane < Backend::lanes; ++lane) {
      if ((ambiguousMask & (1 << lane)) != 0) {
        outputs[lane] = round13(inputs[lane]);
      }
    }
    result = Backend::load(outputs);
  }
  return result;
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE typename Backend::DoubleVector vectorAdvanceNode(
    typename Backend::DoubleVector value) {
  value = Backend::add(
      Backend::mul(value, Backend::set1(nodeMultiplier)),
      Backend::set1(nodeAddend));
  value = vectorFractPositive<Backend>(value);
  return vectorRound13Positive<Backend>(value);
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE typename Backend::DoubleVector vectorRandom(
    typename Backend::DoubleVector seed) {
  using D = typename Backend::DoubleVector;
  using I = typename Backend::IntegerVector;
  D value = seed;
  value = Backend::add(
      Backend::mul(value, Backend::set1(luaPi)), Backend::set1(luaE));
  I state0 = Backend::asInteger(value);
  value = Backend::add(
      Backend::mul(value, Backend::set1(luaPi)), Backend::set1(luaE));
  I state1 = Backend::asInteger(value);
  value = Backend::add(
      Backend::mul(value, Backend::set1(luaPi)), Backend::set1(luaE));
  I state2 = Backend::asInteger(value);
  value = Backend::add(
      Backend::mul(value, Backend::set1(luaPi)), Backend::set1(luaE));
  I state3 = Backend::asInteger(value);

  // These node seeds are ordinary non-negative doubles, so their bit patterns
  // are far above Lua's tiny per-word repair minima. Backends may implement
  // the fixed eleven-step GF(2) transform directly, but must return the exact
  // mantissa bits with the exponent for [1, 2) already installed.
  I bits;
  if constexpr (requires(I a, I b, I c, I d) {
                  Backend::luaRandomBits(a, b, c, d);
                }) {
    bits = Backend::luaRandomBits(state0, state1, state2, state3);
  } else {
    for (int step = 0; step < 11; ++step) {
      state0 = Backend::template advance<31, 45, 18, 1>(state0);
      state1 = Backend::template advance<19, 30, 28, 6>(state1);
      state2 = Backend::template advance<24, 48, 7, 9>(state2);
      state3 = Backend::template advance<21, 39, 8, 17>(state3);
    }
    bits = Backend::bitOr(
        Backend::bitAnd(
            Backend::bitXor(Backend::bitXor(state0, state1),
                            Backend::bitXor(state2, state3)),
            Backend::set1Integer(randomMantissa)),
        Backend::set1Integer(oneExponent));
  }
  return Backend::sub(Backend::asDouble(bits), Backend::set1(1.0));
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE bool vectorRandomHighPrefixes(
    typename Backend::DoubleVector seed, std::uint16_t *output, int valid) {
  using D = typename Backend::DoubleVector;
  using I = typename Backend::IntegerVector;

  if constexpr (requires(I a, I b, I c, I d, std::uint64_t *lanes) {
                  Backend::luaRandomHighPrefix(a, b, c, d);
                  Backend::storeInteger(lanes, a);
                }) {
    alignas(64) std::uint64_t prefixLanes[Backend::lanes];
    D value = seed;
    value = Backend::add(
        Backend::mul(value, Backend::set1(luaPi)), Backend::set1(luaE));
    const I state0 = Backend::asInteger(value);
    value = Backend::add(
        Backend::mul(value, Backend::set1(luaPi)), Backend::set1(luaE));
    const I state1 = Backend::asInteger(value);
    value = Backend::add(
        Backend::mul(value, Backend::set1(luaPi)), Backend::set1(luaE));
    const I state2 = Backend::asInteger(value);
    value = Backend::add(
        Backend::mul(value, Backend::set1(luaPi)), Backend::set1(luaE));
    const I state3 = Backend::asInteger(value);

    Backend::storeInteger(
        prefixLanes,
        Backend::luaRandomHighPrefix(state0, state1, state2, state3));
    for (int lane = 0; lane < valid; ++lane) {
      output[lane] = static_cast<std::uint16_t>(
          prefixLanes[lane] >> 43u);
    }
    return true;
  }
  return false;
}

template <class Backend>
BRAINSTORM_VECTOR_ALWAYS_INLINE void vectorOpeningTagCategories(
    typename Backend::DoubleVector seed, std::uint8_t *output, int valid) {
  alignas(64) std::uint16_t prefixes[Backend::lanes];
  if (vectorRandomHighPrefixes<Backend>(seed, prefixes, valid)) {
    alignas(64) double seedLanes[Backend::lanes];
    bool needsExactFallback = false;
    for (int lane = 0; lane < valid; ++lane) {
      output[lane] = openingTagPrefixCategories[prefixes[lane]];
      needsExactFallback |= output[lane] == openingTagAmbiguous;
    }
    if (needsExactFallback) {
      // Keep the ordinary path store-free. Only about 1.37% of individual
      // prefixes cross a category boundary, so materialize the node seeds
      // solely for vectors that actually need an authoritative lane repair.
      Backend::store(seedLanes, seed);
      for (int lane = 0; lane < valid; ++lane) {
        if (output[lane] != openingTagAmbiguous) {
          continue;
        }
        const int tag = static_cast<int>(
            lua_random_from_seed(seedLanes[lane]) * TAGS.size());
        output[lane] = openingTagCategory(tag);
      }
    }
  } else {
    alignas(64) double rolls[Backend::lanes];
    Backend::store(rolls, vectorRandom<Backend>(seed));
    for (int lane = 0; lane < valid; ++lane) {
      output[lane] = openingTagCategory(
          static_cast<int>(rolls[lane] * TAGS.size()));
    }
  }
}

template <class Backend, bool precomputedSeedHash = false>
void vectorFreshRolls(const ChunkSeeds &seeds,
                      const std::vector<int> &active,
                      std::string_view key, std::vector<double> &rolls,
                      const std::vector<double> *seedHashes = nullptr,
                      std::vector<std::uint8_t> *tagCategories = nullptr) {
  assert(!precomputedSeedHash || seedHashes != nullptr);
  if (tagCategories == nullptr) {
    rolls.resize(active.size());
  } else {
    tagCategories->resize(active.size());
  }
  constexpr int pipelineWidth = BRAINSTORM_FRESH_ROLL_PIPELINE_WIDTH;
  constexpr std::size_t pipelineLanes =
      static_cast<std::size_t>(Backend::lanes * pipelineWidth);
  using D = typename Backend::DoubleVector;
  using G = typename Backend::GatherIndices;
  alignas(64) double output[Backend::lanes];
  for (std::size_t offset = 0; offset < active.size();
       offset += pipelineLanes) {
    const int vectorCount = static_cast<int>(std::min<std::size_t>(
        pipelineWidth,
        (active.size() - offset + Backend::lanes - 1)
            / Backend::lanes));
    D values[pipelineWidth];
    D lengths[pipelineWidth];
    D hashed[pipelineWidth];
    G gatherIndices[pipelineWidth];
    int valids[pipelineWidth];

    for (int vector = 0; vector < vectorCount; ++vector) {
      const std::size_t vectorOffset = offset
          + static_cast<std::size_t>(vector * Backend::lanes);
      const int valid = static_cast<int>(std::min<std::size_t>(
          Backend::lanes, active.size() - vectorOffset));
      valids[vector] = valid;
      gatherIndices[vector] = Backend::indices(
          active.data() + vectorOffset, valid);
      hashed[vector] = Backend::gather(
          seeds.hashedSeeds.data(), gatherIndices[vector]);
      if constexpr (precomputedSeedHash) {
        values[vector] = Backend::gather(
            seedHashes->data(), gatherIndices[vector]);
      } else {
        lengths[vector] = Backend::gatherByte(
            seeds.lengths.data(), gatherIndices[vector]);
        values[vector] = Backend::set1(1.0);
      }
    }

    if constexpr (!precomputedSeedHash) {
      const int prefixLength = static_cast<int>(key.size());
      for (int position = 0; position < 8; ++position) {
        for (int vector = 0; vector < vectorCount; ++vector) {
          const D character = Backend::gatherCharacter(
              seeds.packedCharacters.data(), gatherIndices[vector], position);
          D next = Backend::div(Backend::set1(hashA), values[vector]);
          next = Backend::mul(next, character);
          next = Backend::mul(next, Backend::set1(hashPi));
          const D hashPosition = Backend::add(
              Backend::set1(static_cast<double>(prefixLength - position)),
              lengths[vector]);
          next = Backend::add(
              next, Backend::mul(Backend::set1(hashPi), hashPosition));
          const D advanced = vectorFractPositive<Backend>(next);
          values[vector] = Backend::select(
              Backend::greater(
                  lengths[vector],
                  Backend::set1(static_cast<double>(position))),
              values[vector], advanced);
        }
      }
    }

    for (std::size_t keyIndex = key.size(); keyIndex > 0; --keyIndex) {
      const D character = Backend::set1(
          static_cast<unsigned char>(key[keyIndex - 1]));
      for (int vector = 0; vector < vectorCount; ++vector) {
        values[vector] = vectorPseudostep<Backend>(
            values[vector], character, static_cast<double>(keyIndex));
      }
    }

    for (int vector = 0; vector < vectorCount; ++vector) {
      auto value = vectorAdvanceNode<Backend>(values[vector]);
      value = Backend::mul(
          Backend::add(value, hashed[vector]), Backend::set1(0.5));
      const std::size_t vectorOffset = offset
          + static_cast<std::size_t>(vector * Backend::lanes);
      if (tagCategories == nullptr) {
        Backend::store(output, vectorRandom<Backend>(value));
        for (int lane = 0; lane < valids[vector]; ++lane) {
          rolls[vectorOffset + static_cast<std::size_t>(lane)] =
              output[lane];
        }
      } else {
        alignas(64) std::uint8_t categories[Backend::lanes];
        vectorOpeningTagCategories<Backend>(
            value, categories, valids[vector]);
        for (int lane = 0; lane < valids[vector]; ++lane) {
          (*tagCategories)[vectorOffset + static_cast<std::size_t>(lane)] =
              categories[lane];
        }
      }
    }
  }
}

inline double scalarPositivePseudostep(double value, double character,
                                       double position) {
  return fractPositive(
      hashA / value * character * hashPi + hashPi * position);
}

inline double scalarSeedHashFromColumns(const ChunkSeeds &seeds,
                                        std::size_t index,
                                        int prefixLength) {
  const int length = static_cast<int>(seeds.lengths[index]);
  double value = 1.0;
  for (int position = 0; position < length; ++position) {
    value = scalarPositivePseudostep(
        value, characterAt(seeds, index, position),
        static_cast<double>(prefixLength + length - position));
  }
  return value;
}

inline double scalarPseudohashFromPositive(std::string_view key,
                                           double value) {
  for (std::size_t index = key.size(); index > 0; --index) {
    value = scalarPositivePseudostep(
        value, static_cast<unsigned char>(key[index - 1]),
        static_cast<double>(index));
  }
  return value;
}

inline double scalarAdvanceNode(double value) {
  return round13(fractPositive(value * nodeMultiplier + nodeAddend));
}

// The seed enumerator emits runs of 35 eight-character seeds in which only
// character seven changes. Compute the first seven pseudosteps once per run,
// then pack the final steps across run boundaries to keep every SIMD lane
// useful. The sparse short seeds produced by carries retain an exact scalar
// path, including the empty-seed/domain-wrap case.
template <class Backend>
void vectorInitialTagRollsShared(
    ChunkSeeds &seeds, std::size_t count, std::vector<double> &rolls,
    std::vector<double> *tagSeedHashes = nullptr,
    std::vector<std::uint8_t> *tagCategories = nullptr) {
  if (tagCategories == nullptr) {
    rolls.resize(count);
  } else {
    tagCategories->resize(count);
  }
  if (tagSeedHashes != nullptr) {
    tagSeedHashes->resize(count);
  }
  seeds.sharedGroupStarts.clear();
  seeds.eightCharacterSeedIndices.clear();
  seeds.eightCharacterGroupIndices.clear();

  alignas(64) double prefix0Lanes[Backend::lanes];
  alignas(64) double prefix4Lanes[Backend::lanes];
  alignas(64) double tagSeedLanes[Backend::lanes];

  std::size_t index = 0;
  while (index < count) {
    if (seeds.lengths[index] != 8) {
      const double hashed = scalarSeedHashFromColumns(seeds, index, 0);
      double tagValue = scalarSeedHashFromColumns(seeds, index, 4);
      if (tagSeedHashes != nullptr) {
        (*tagSeedHashes)[index] = tagValue;
      }
      tagValue = scalarPseudohashFromPositive(tagKey, tagValue);
      tagValue = scalarAdvanceNode(tagValue);
      seeds.hashedSeeds[index] = hashed;
      const double random = lua_random_from_seed((tagValue + hashed) * 0.5);
      if (tagCategories == nullptr) {
        rolls[index] = random;
      } else {
        (*tagCategories)[index] = openingTagCategory(
            static_cast<int>(random * TAGS.size()));
      }
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
  seeds.sharedPrefix4.resize(groupCount);
  seeds.sharedPrefix14.resize(groupCount);
  for (std::size_t groupOffset = 0; groupOffset < groupCount;
       groupOffset += Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Backend::lanes, groupCount - groupOffset));
    const auto groupStarts = Backend::indices(
        seeds.sharedGroupStarts.data() + groupOffset, valid);
    auto prefix0 = Backend::set1(1.0);
    auto prefix4 = Backend::set1(1.0);
    auto prefix14 = Backend::set1(1.0);
    for (std::size_t position = 0; position < 7; ++position) {
      const auto character = Backend::gatherCharacter(
          seeds.packedCharacters.data(), groupStarts,
          static_cast<int>(position));
      prefix0 = vectorPseudostep<Backend>(
          prefix0, character, static_cast<double>(8 - position));
      prefix4 = vectorPseudostep<Backend>(
          prefix4, character, static_cast<double>(12 - position));
      prefix14 = vectorPseudostep<Backend>(
          prefix14, character, static_cast<double>(22 - position));
    }
    Backend::store(prefix0Lanes, prefix0);
    Backend::store(prefix4Lanes, prefix4);
    Backend::store(tagSeedLanes, prefix14);
    for (int lane = 0; lane < valid; ++lane) {
      const std::size_t outputIndex =
          groupOffset + static_cast<std::size_t>(lane);
      seeds.sharedPrefix0[outputIndex] = prefix0Lanes[lane];
      seeds.sharedPrefix4[outputIndex] = prefix4Lanes[lane];
      seeds.sharedPrefix14[outputIndex] = tagSeedLanes[lane];
    }
  }

  const std::size_t eightCharacterCount =
      seeds.eightCharacterSeedIndices.size();
  constexpr int pipelineWidth = 4;
  constexpr std::size_t pipelineSeeds =
      static_cast<std::size_t>(Backend::lanes * pipelineWidth);
  using D = typename Backend::DoubleVector;
  for (std::size_t offset = 0; offset < eightCharacterCount;
       offset += pipelineSeeds) {
    const int vectorCount = static_cast<int>(std::min<std::size_t>(
        pipelineWidth,
        (eightCharacterCount - offset + Backend::lanes - 1)
            / Backend::lanes));
    D hashed[pipelineWidth];
    D tagValues[pipelineWidth];
    D rawTagValues[pipelineWidth];
    int valids[pipelineWidth];

    for (int vector = 0; vector < vectorCount; ++vector) {
      const std::size_t vectorOffset = offset
          + static_cast<std::size_t>(vector * Backend::lanes);
      const int valid = static_cast<int>(std::min<std::size_t>(
          Backend::lanes, eightCharacterCount - vectorOffset));
      valids[vector] = valid;
      const auto seedIndices = Backend::indices(
          seeds.eightCharacterSeedIndices.data() + vectorOffset, valid);
      const auto groupIndices = Backend::indices(
          seeds.eightCharacterGroupIndices.data() + vectorOffset, valid);
      const auto character = Backend::gatherCharacter(
          seeds.packedCharacters.data(), seedIndices, 7);
      const auto prefix0 = Backend::gather(
          seeds.sharedPrefix0.data(), groupIndices);
      const auto prefix4 = Backend::gather(
          seeds.sharedPrefix4.data(), groupIndices);
      hashed[vector] = vectorPseudostep<Backend>(
          prefix0, character, 1.0);
      tagValues[vector] = vectorPseudostep<Backend>(
          prefix4, character, 5.0);
      rawTagValues[vector] = tagValues[vector];
    }

    // Advance the same Tag1 character across several independent vectors
    // before moving to the next character. This preserves each lane's exact
    // operation order while exposing enough independent divisions to hide
    // their latency on wide out-of-order CPUs.
    for (std::size_t keyIndex = tagKey.size(); keyIndex > 0; --keyIndex) {
      const double character = static_cast<unsigned char>(
          tagKey[keyIndex - 1]);
      for (int vector = 0; vector < vectorCount; ++vector) {
        tagValues[vector] = vectorPseudostep<Backend>(
            tagValues[vector], Backend::set1(character),
            static_cast<double>(keyIndex));
      }
    }

    for (int vector = 0; vector < vectorCount; ++vector) {
      auto tagValue = vectorAdvanceNode<Backend>(tagValues[vector]);
      tagValue = Backend::mul(
          Backend::add(tagValue, hashed[vector]), Backend::set1(0.5));
      Backend::store(prefix0Lanes, hashed[vector]);
      alignas(64) std::uint8_t categories[Backend::lanes];
      if (tagCategories == nullptr) {
        Backend::store(prefix4Lanes, vectorRandom<Backend>(tagValue));
      } else {
        vectorOpeningTagCategories<Backend>(
            tagValue, categories, valids[vector]);
      }
      if (tagSeedHashes != nullptr) {
        Backend::store(tagSeedLanes, rawTagValues[vector]);
      }
      const std::size_t vectorOffset = offset
          + static_cast<std::size_t>(vector * Backend::lanes);
      for (int lane = 0; lane < valids[vector]; ++lane) {
        const std::size_t packedIndex =
            vectorOffset + static_cast<std::size_t>(lane);
        const std::size_t seedIndex = static_cast<std::size_t>(
            seeds.eightCharacterSeedIndices[packedIndex]);
        seeds.hashedSeeds[seedIndex] = prefix0Lanes[lane];
        if (tagCategories == nullptr) {
          rolls[seedIndex] = prefix4Lanes[lane];
        } else {
          (*tagCategories)[seedIndex] = categories[lane];
        }
        if (tagSeedHashes != nullptr) {
          (*tagSeedHashes)[seedIndex] = tagSeedLanes[lane];
        }
      }
    }
  }
}

// Tag1_resample2 through Tag1_resample9 all use a 14-character key, hence
// the same seed pseudohash. Materialize that hash only for initially locked
// candidates: seven shared prefix steps were already computed per 35-seed
// run, leaving one SIMD final-character step. Sparse short seeds retain the
// scalar reference path.
template <class Backend>
void cacheResample14SeedHashes(
    ChunkSeeds &seeds, const std::vector<int> &candidates) {
  if (candidates.empty()) {
    return;
  }
  alignas(64) int groupLanes[Backend::lanes];
  alignas(64) double output[Backend::lanes];
  for (std::size_t offset = 0; offset < candidates.size();
       offset += Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Backend::lanes, candidates.size() - offset));
    const auto seedIndices = Backend::indices(
        candidates.data() + offset, valid);
    bool hasEightCharacterSeed = false;
    for (int lane = 0; lane < valid; ++lane) {
      const int seedIndex = candidates[
          offset + static_cast<std::size_t>(lane)];
      if (seeds.lengths[static_cast<std::size_t>(seedIndex)] != 8) {
        groupLanes[lane] = 0;
        continue;
      }
      hasEightCharacterSeed = true;
      const auto groupEnd = std::upper_bound(
          seeds.sharedGroupStarts.begin(), seeds.sharedGroupStarts.end(),
          seedIndex);
      assert(groupEnd != seeds.sharedGroupStarts.begin());
      groupLanes[lane] = static_cast<int>(
          std::distance(seeds.sharedGroupStarts.begin(), groupEnd) - 1);
    }
    for (int lane = valid; lane < Backend::lanes; ++lane) {
      groupLanes[lane] = groupLanes[valid - 1];
    }

    if (hasEightCharacterSeed) {
      const auto groupIndices = Backend::indices(
          groupLanes, Backend::lanes);
      const auto prefix14 = Backend::gather(
          seeds.sharedPrefix14.data(), groupIndices);
      const auto finalCharacter = Backend::gatherCharacter(
          seeds.packedCharacters.data(), seedIndices, 7);
      Backend::store(
          output, vectorPseudostep<Backend>(
                      prefix14, finalCharacter, 15.0));
    }
    for (int lane = 0; lane < valid; ++lane) {
      const std::size_t seedIndex = static_cast<std::size_t>(candidates[
          offset + static_cast<std::size_t>(lane)]);
      seeds.resampleHash14[seedIndex] = seeds.lengths[seedIndex] == 8
          ? output[lane]
          : scalarSeedHashFromColumns(seeds, seedIndex, 14);
    }
  }
}

template <class Backend>
void vectorSoulFlags(const ChunkSeeds &seeds,
                     const std::vector<int> &active,
                     std::vector<std::uint8_t> &foundSoul) {
  foundSoul.assign(active.size(), 0);
  alignas(64) double rolls[Backend::lanes];
  for (std::size_t offset = 0; offset < active.size();
       offset += Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Backend::lanes, active.size() - offset));
    const int *indices = active.data() + offset;
    auto state = vectorSeedPseudohash<Backend>(
        seeds, indices, valid, static_cast<int>(soulTarotKey.size()));
    state = vectorPseudohashFrom<Backend>(soulTarotKey, state);
    const auto gatherIndices = Backend::indices(indices, valid);
    const auto hashed = Backend::gather(
        seeds.hashedSeeds.data(), gatherIndices);
    for (int card = 0; card < 5; ++card) {
      state = vectorAdvanceNode<Backend>(state);
      const auto input = Backend::mul(
          Backend::add(state, hashed), Backend::set1(0.5));
      Backend::store(rolls, vectorRandom<Backend>(input));
      for (int lane = 0; lane < valid; ++lane) {
        if (rolls[lane] > soulThreshold) {
          foundSoul[offset + static_cast<std::size_t>(lane)] = 1;
        }
      }
    }
  }
}

template <class Backend>
void vectorSoulCounts(const ChunkSeeds &seeds,
                      const std::vector<int> &active,
                      std::vector<std::uint8_t> &soulCounts,
                      int minimumSoulCount) {
  soulCounts.assign(active.size(), 0);
  alignas(64) double rolls[Backend::lanes];
  for (std::size_t offset = 0; offset < active.size();
       offset += Backend::lanes) {
    const int valid = static_cast<int>(std::min<std::size_t>(
        Backend::lanes, active.size() - offset));
    const int *indices = active.data() + offset;
    auto state = vectorSeedPseudohash<Backend>(
        seeds, indices, valid, static_cast<int>(soulTarotKey.size()));
    state = vectorPseudohashFrom<Backend>(soulTarotKey, state);
    const auto gatherIndices = Backend::indices(indices, valid);
    const auto hashed = Backend::gather(
        seeds.hashedSeeds.data(), gatherIndices);
    for (int card = 0; card < 5; ++card) {
      state = vectorAdvanceNode<Backend>(state);
      const auto input = Backend::mul(
          Backend::add(state, hashed), Backend::set1(0.5));
      Backend::store(rolls, vectorRandom<Backend>(input));
      for (int lane = 0; lane < valid; ++lane) {
        if (rolls[lane] > soulThreshold) {
          std::uint8_t &count =
              soulCounts[offset + static_cast<std::size_t>(lane)];
          if (minimumSoulCount <= 1) {
            count = 1;
          } else {
            ++count;
          }
        }
      }
    }
  }
}

// A requested Legendary identity rejects four fifths of seeds and is keyed
// independently from the Tag and Soul streams.  On AVX-512, evaluating that
// inexpensive conjunction first avoids most locked-tag resample work.  Share
// the first seven H0/H6 seed steps across each natural 35-seed run just as the
// tag-first path shares H0/H4.
template <class Backend>
void vectorInitialLegendaryRollsShared(
    ChunkSeeds &seeds, std::size_t count, std::vector<double> &rolls) {
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
  // This scratch column normally holds H4.  The tag stage below recomputes H4
  // only for the surviving fifth, so use it for the shared H6 prefix here.
  seeds.sharedPrefix4.resize(groupCount);
  alignas(64) double hashLanes[Backend::lanes];
  alignas(64) double valueLanes[Backend::lanes];
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
    Backend::store(valueLanes, prefix6);
    for (int lane = 0; lane < valid; ++lane) {
      const std::size_t output = groupOffset + static_cast<std::size_t>(lane);
      seeds.sharedPrefix0[output] = hashLanes[lane];
      seeds.sharedPrefix4[output] = valueLanes[lane];
    }
  }

  constexpr int pipelineWidth = BRAINSTORM_FRESH_ROLL_PIPELINE_WIDTH;
  constexpr std::size_t pipelineSeeds =
      static_cast<std::size_t>(Backend::lanes * pipelineWidth);
  using D = typename Backend::DoubleVector;
  const std::size_t eightCharacterCount =
      seeds.eightCharacterSeedIndices.size();
  for (std::size_t offset = 0; offset < eightCharacterCount;
       offset += pipelineSeeds) {
    const int vectorCount = static_cast<int>(std::min<std::size_t>(
        pipelineWidth,
        (eightCharacterCount - offset + Backend::lanes - 1)
            / Backend::lanes));
    D hashed[pipelineWidth];
    D values[pipelineWidth];
    int valids[pipelineWidth];
    for (int vector = 0; vector < vectorCount; ++vector) {
      const std::size_t vectorOffset = offset
          + static_cast<std::size_t>(vector * Backend::lanes);
      const int valid = static_cast<int>(std::min<std::size_t>(
          Backend::lanes, eightCharacterCount - vectorOffset));
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
      const auto character = Backend::set1(
          static_cast<unsigned char>(legendaryKey[keyIndex - 1]));
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
      Backend::store(valueLanes, vectorRandom<Backend>(value));
      const std::size_t vectorOffset = offset
          + static_cast<std::size_t>(vector * Backend::lanes);
      for (int lane = 0; lane < valids[vector]; ++lane) {
        const std::size_t packedIndex = vectorOffset
            + static_cast<std::size_t>(lane);
        const std::size_t seedIndex = static_cast<std::size_t>(
            seeds.eightCharacterSeedIndices[packedIndex]);
        seeds.hashedSeeds[seedIndex] = hashLanes[lane];
        rolls[seedIndex] = valueLanes[lane];
      }
    }
  }
}

// Exact specific-Legendary path for AVX-512.  All three tests are a pure
// conjunction of independently keyed streams, so this changes evaluation
// order only; final candidates are still restored to canonical seed order.
template <class Backend>
void collectVectorCandidatesLegendaryFirst(
    Workspace &workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivors) {
  assert(workspace.criteria.legendaryIndex >= 0);
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

template <class Backend, bool sharedInitialHashes = true>
void collectVectorCandidates(Workspace &workspace, long long startSeedId,
                             std::size_t count,
                             std::vector<std::uint32_t> &survivors) {
  workspace.prepare(count);
  fillChunk(workspace.seeds, startSeedId, count);

  workspace.active.resize(count);
  for (std::size_t index = 0; index < count; ++index) {
    workspace.active[index] = static_cast<int>(index);
  }

  if constexpr (sharedInitialHashes) {
    vectorInitialTagRollsShared<Backend>(
        workspace.seeds, count, workspace.rolls, nullptr,
        &workspace.tagCategories);
  } else {
    alignas(64) double hashLanes[Backend::lanes];
    for (std::size_t offset = 0; offset < count;
         offset += Backend::lanes) {
      const int valid = static_cast<int>(std::min<std::size_t>(
          Backend::lanes, count - offset));
      const auto hash = vectorSeedPseudohash<Backend>(
          workspace.seeds, workspace.active.data() + offset, valid, 0);
      Backend::store(hashLanes, hash);
      for (int lane = 0; lane < valid; ++lane) {
        workspace.seeds.hashedSeeds[
            offset + static_cast<std::size_t>(lane)] = hashLanes[lane];
      }
    }
    vectorFreshRolls<Backend>(workspace.seeds, workspace.active, tagKey,
                              workspace.rolls, nullptr,
                              &workspace.tagCategories);
  }
  workspace.charm.clear();
  workspace.scratch.clear();
  for (std::size_t index = 0; index < count; ++index) {
    const std::uint8_t category = workspace.tagCategories[index];
    if (category == openingTagCharm) {
      workspace.charm.push_back(static_cast<int>(index));
    } else if (category == openingTagLocked) {
      workspace.scratch.push_back(static_cast<int>(index));
    }
  }
  if constexpr (sharedInitialHashes) {
    cacheResample14SeedHashes<Backend>(
        workspace.seeds, workspace.scratch);
  }

  int resample = 2;
  while (!workspace.scratch.empty() && resample <= 1000) {
    const std::string key = std::string(tagKey) + "_resample"
        + std::to_string(resample);
    if constexpr (sharedInitialHashes) {
      if (resample < 10) {
        vectorFreshRolls<Backend, true>(
            workspace.seeds, workspace.scratch, key, workspace.rolls,
            &workspace.seeds.resampleHash14, &workspace.tagCategories);
      } else {
        vectorFreshRolls<Backend>(
            workspace.seeds, workspace.scratch, key, workspace.rolls,
            nullptr, &workspace.tagCategories);
      }
    } else {
      vectorFreshRolls<Backend>(
          workspace.seeds, workspace.scratch, key, workspace.rolls,
          nullptr, &workspace.tagCategories);
    }
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
  workspace.active.clear();
  for (std::size_t index = 0; index < workspace.charm.size(); ++index) {
    if (workspace.soulCounts[index]
        >= workspace.criteria.minimumSoulCount) {
      workspace.active.push_back(workspace.charm[index]);
    }
  }

  survivors.clear();
  assert(workspace.active.size() <= count);
  assert(workspace.seeds.lengths.size() >= count);
  assert(workspace.seeds.hashedSeeds.size() == count);
  assert(workspace.seeds.packedCharacters.size() >= count);
#ifndef NDEBUG
  for (int candidate : workspace.active) {
    assert(candidate >= 0
           && static_cast<std::size_t>(candidate) < count);
  }
#endif
  if (workspace.criteria.legendaryIndex < 0) {
    for (int candidate : workspace.active) {
      survivors.push_back(static_cast<std::uint32_t>(candidate));
    }
    std::sort(survivors.begin(), survivors.end());
    return;
  }

  vectorFreshRolls<Backend>(workspace.seeds, workspace.active,
                            legendaryKey, workspace.rolls);
  for (std::size_t index = 0; index < workspace.active.size(); ++index) {
    if (static_cast<int>(workspace.rolls[index]
                         * LEGENDARY_JOKERS.size())
        == workspace.criteria.legendaryIndex) {
      survivors.push_back(
          static_cast<std::uint32_t>(workspace.active[index]));
    }
  }
  // Locked-tag resamples group candidates by the draw on which Charm was
  // accepted. Restore the original seed order before authoritative checking.
  std::sort(survivors.begin(), survivors.end());
}

// Reuse only the compact seed materialization and shared initial Tag1 stage.
// Locked Ante-1 tags follow randchoice's independent resample-key sequence;
// Soul and legendary streams are deliberately never initialized here.
template <class Backend>
void collectVectorTagCandidates(Workspace &workspace, long long startSeedId,
                                std::size_t count, int targetTagIndex,
                                std::vector<std::uint32_t> &survivors) {
  workspace.prepare(count);
  fillChunk(workspace.seeds, startSeedId, count);
  workspace.active.resize(count);
  for (std::size_t index = 0; index < count; ++index) {
    workspace.active[index] = static_cast<int>(index);
  }
  vectorInitialTagRollsShared<Backend>(
      workspace.seeds, count, workspace.rolls);

  survivors.clear();
  workspace.scratch.clear();
  for (std::size_t index = 0; index < count; ++index) {
    const int tag = static_cast<int>(workspace.rolls[index] * TAGS.size());
    if (isAnteOneLockedTagIndex(tag)) {
      workspace.scratch.push_back(static_cast<int>(index));
    } else if (tag == targetTagIndex) {
      survivors.push_back(static_cast<std::uint32_t>(index));
    }
  }
  cacheResample14SeedHashes<Backend>(
      workspace.seeds, workspace.scratch);

  int resample = 2;
  while (!workspace.scratch.empty() && resample <= 1000) {
    const std::string key = std::string(tagKey) + "_resample"
        + std::to_string(resample);
    if (resample < 10) {
      vectorFreshRolls<Backend, true>(
          workspace.seeds, workspace.scratch, key, workspace.rolls,
          &workspace.seeds.resampleHash14);
    } else {
      vectorFreshRolls<Backend>(
          workspace.seeds, workspace.scratch, key, workspace.rolls);
    }
    workspace.active.clear();
    for (std::size_t index = 0; index < workspace.scratch.size(); ++index) {
      const int tag =
          static_cast<int>(workspace.rolls[index] * TAGS.size());
      if (isAnteOneLockedTagIndex(tag) && resample < 1000) {
        workspace.active.push_back(workspace.scratch[index]);
      } else if (tag == targetTagIndex) {
        survivors.push_back(
            static_cast<std::uint32_t>(workspace.scratch[index]));
      }
    }
    workspace.scratch.swap(workspace.active);
    ++resample;
  }
  // Resample rounds group accepted seeds by their successful draw. Restore
  // domain order before the authoritative scalar survivor check.
  std::sort(survivors.begin(), survivors.end());
}

} // namespace BrainstormOpeningBatchDetail

#undef BRAINSTORM_VECTOR_ALWAYS_INLINE

#endif // BRAINSTORM_OPENING_BATCH_VECTOR_HPP
