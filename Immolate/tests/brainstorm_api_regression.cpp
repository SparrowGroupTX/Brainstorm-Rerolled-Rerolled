#include "immolate.hpp"
#include "items.hpp"
#include "search.hpp"

#include <array>
#include <cstdlib>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>

namespace {

std::vector<long long> instanceSearchVisits;
std::vector<long long> seedSearchVisits;

long captureInstanceSearchSeed(Instance& instance) {
    instanceSearchVisits.push_back(instance.seed.getID());
    return 0;
}

long captureSeedSearchSeed(Seed& seed) {
    seedSearchVisits.push_back(seed.getID());
    return 0;
}

void* createPassThroughBatchContext(std::uint64_t) {
    return new int(0);
}

void destroyPassThroughBatchContext(void* context) {
    delete static_cast<int*>(context);
}

void collectPassThroughBatch(
    void*, long long, std::size_t count,
    std::vector<std::uint32_t>& survivors) {
    survivors.resize(count);
    for (std::size_t offset = 0; offset < count; ++offset) {
        survivors[offset] = static_cast<std::uint32_t>(offset);
    }
}

bool expectEqual(const std::string& actual, const std::string& expected,
                 const char* description) {
    if (actual == expected) {
        return true;
    }
    std::cerr << description << ": expected '" << expected << "', got '"
              << actual << "'" << std::endl;
    return false;
}

bool expectEqual(const std::vector<long long>& actual,
                 const std::vector<long long>& expected,
                 const char* description) {
    if (actual == expected) {
        return true;
    }
    std::cerr << description << ": seed visit order differed" << std::endl;
    return false;
}

bool expectContains(const std::string& actual, const std::string& expected,
                    const char* description) {
    if (actual.find(expected) != std::string::npos) {
        return true;
    }
    std::cerr << description << ": expected to find '" << expected
              << "' in '" << actual << "'" << std::endl;
    return false;
}

bool workerSelectionAdaptsToDetectedHardware() {
    struct WorkerCase {
        unsigned int detected;
        int balanced;
        int maximum;
    };
    constexpr std::array<WorkerCase, 10> cases{{
        {0, 1, 1},
        {1, 1, 1},
        {2, 1, 2},
        {4, 3, 4},
        {8, 7, 8},
        {16, 14, 16},
        {24, 21, 24},
        {32, 28, 32},
        {256, 252, 256},
        {257, 252, 256},
    }};
    for (const WorkerCase& test : cases) {
        const int balanced = normalizeBrainstormSearchThreads(test.detected);
        const int maximum =
            normalizeBrainstormMaximumSearchThreads(test.detected);
        if (balanced != test.balanced || maximum != test.maximum) {
            std::cerr << "worker policy mismatch for detected="
                      << test.detected << ": expected balanced="
                      << test.balanced << " maximum=" << test.maximum
                      << ", got balanced=" << balanced
                      << " maximum=" << maximum << std::endl;
            return false;
        }
    }
    return true;
}

bool readEstimateField(const std::string& estimate, const char* key,
                       double& value) {
    const std::string prefix = std::string(key) + "=";
    const std::size_t start = estimate.find(prefix);
    if (start == std::string::npos) {
        return false;
    }
    const std::size_t valueStart = start + prefix.size();
    const std::size_t valueEnd = estimate.find('\t', valueStart);
    const std::string text = estimate.substr(
        valueStart, valueEnd == std::string::npos
            ? std::string::npos
            : valueEnd - valueStart);
    char* parsedEnd = nullptr;
    value = std::strtod(text.c_str(), &parsedEnd);
    return parsedEnd != text.c_str() && *parsedEnd == '\0';
}

bool expectSingleCharmTagInStagedBase(const std::string& estimate) {
    double baseTested = 0.0;
    double baseHits = 0.0;
    double conditionalBaseTested = 0.0;
    double conditionalBaseHits = 0.0;
    if (!readEstimateField(estimate, "base_tested", baseTested)
        || !readEstimateField(estimate, "base_hits", baseHits)
        || !readEstimateField(
            estimate, "conditional_base_tested", conditionalBaseTested)
        || !readEstimateField(
            estimate, "conditional_base_hits", conditionalBaseHits)
        || baseTested <= 0.0 || conditionalBaseTested <= 0.0
        || conditionalBaseHits <= 0.0) {
        std::cerr << "staged Charm-route estimate omitted usable base probes: "
                  << estimate << std::endl;
        return false;
    }

    const double baseProbability = baseHits / baseTested;
    const double conditionalBaseProbability =
        conditionalBaseHits / conditionalBaseTested;
    const double charmTagFactor =
        baseProbability / conditionalBaseProbability;

    // The unconditioned base must differ from the Charm-conditioned base by
    // one tag draw (roughly 1/15), not by two consecutive Charm draws
    // (roughly 1/15 squared). Keep the bounds deliberately wide so this
    // semantic regression is insensitive to the estimator's time budget.
    if (charmTagFactor >= 0.02 && charmTagFactor <= 0.20) {
        return true;
    }
    std::cerr << "staged Charm-route base used an unexpected tag factor: "
              << charmTagFactor << " in '" << estimate << "'" << std::endl;
    return false;
}

void setTestEnvironment() {
#ifdef _WIN32
    _putenv_s("BRAINSTORM_THREADS", "1");
    _putenv_s("BRAINSTORM_SEARCH_LIMIT", "1");
    _putenv_s("BRAINSTORM_PRINT_DELAY", "0");
#else
    setenv("BRAINSTORM_THREADS", "1", 1);
    setenv("BRAINSTORM_SEARCH_LIMIT", "1", 1);
    setenv("BRAINSTORM_PRINT_DELAY", "0", 1);
#endif
}

void setWrapTestBlockSize(const char* value) {
#ifdef _WIN32
    _putenv_s("BRAINSTORM_BLOCK_SIZE", value);
#else
    if (value[0] == '\0') {
        unsetenv("BRAINSTORM_BLOCK_SIZE");
    } else {
        setenv("BRAINSTORM_BLOCK_SIZE", value, 1);
    }
#endif
}

void setOpeningBatchEnabled(bool enabled) {
#ifdef _WIN32
    _putenv_s("BRAINSTORM_OPENING_BATCH", enabled ? "1" : "0");
#else
    setenv("BRAINSTORM_OPENING_BATCH", enabled ? "1" : "0", 1);
#endif
}

bool searchWrapsAcrossSeedDomain() {
    static_assert(SEED_DOMAIN_SIZE == 2318107019761LL);

    Seed startingSeed(SEED_DOMAIN_SIZE - 2);
    const std::vector<long long> expected = {
        SEED_DOMAIN_SIZE - 2, SEED_DOMAIN_SIZE - 1, 0, 1};

    setWrapTestBlockSize("2");

    instanceSearchVisits.clear();
    Search instanceSearch(
        captureInstanceSearchSeed, startingSeed.tostring(), 1, 4);
    instanceSearch.printDelay = 0;
    instanceSearch.search();

    seedSearchVisits.clear();
    SeedSearch seedSearch(captureSeedSearchSeed, startingSeed.tostring(), 1, 4);
    seedSearch.printDelay = 0;
    seedSearch.search();

    setWrapTestBlockSize("");

    bool passed = true;
    passed &= expectEqual(
        instanceSearchVisits, expected,
        "Search wraps block starts into the valid seed domain");
    passed &= expectEqual(
        seedSearchVisits, expected,
        "SeedSearch wraps block starts into the valid seed domain");
    passed &= instanceSearch.seedsProcessed.load(std::memory_order_relaxed) == 4;
    passed &= seedSearch.seedsProcessed.load(std::memory_order_relaxed) == 4;

    setWrapTestBlockSize("4");

    instanceSearchVisits.clear();
    Search straddlingInstanceSearch(
        captureInstanceSearchSeed, startingSeed.tostring(), 1, 4);
    straddlingInstanceSearch.printDelay = 0;
    straddlingInstanceSearch.search();

    seedSearchVisits.clear();
    SeedSearch straddlingSeedSearch(
        captureSeedSearchSeed, startingSeed.tostring(), 1, 4);
    straddlingSeedSearch.printDelay = 0;
    straddlingSeedSearch.search();

    setWrapTestBlockSize("");

    passed &= expectEqual(
        instanceSearchVisits, expected,
        "Search wraps within one block that straddles the seed domain");
    passed &= expectEqual(
        seedSearchVisits, expected,
        "SeedSearch wraps within one block that straddles the seed domain");
    passed &= straddlingInstanceSearch.seedsProcessed.load(
                  std::memory_order_relaxed) == 4;
    passed &= straddlingSeedSearch.seedsProcessed.load(
                  std::memory_order_relaxed) == 4;

    seedSearchVisits.clear();
    SeedSearch straddlingBatchSearch(
        captureSeedSearchSeed, startingSeed.tostring(), 1, 4);
    straddlingBatchSearch.printDelay = 0;
    straddlingBatchSearch.batchPrefilter.createContext =
        createPassThroughBatchContext;
    straddlingBatchSearch.batchPrefilter.destroyContext =
        destroyPassThroughBatchContext;
    straddlingBatchSearch.batchPrefilter.collect =
        collectPassThroughBatch;
    straddlingBatchSearch.search();

    passed &= expectEqual(
        seedSearchVisits, expected,
        "batched SeedSearch wraps within a straddling seed block");
    passed &= straddlingBatchSearch.seedsProcessed.load(
                  std::memory_order_relaxed) == 4;
    return passed;
}

std::string takeResult(const char* result) {
    if (result == nullptr) {
        return "<null>";
    }
    const std::string copied(result);
    free_result(result);
    return copied;
}

std::string runV2At(const char* seed, const char* tag, int soulCount,
                    const char* targetJokers) {
    return takeResult(brainstorm_v2(
        seed, "", "", tag, soulCount, false, false, false, false, false,
        false, "No Filter", "King", "Any Suit", 0, 0, targetJokers));
}

std::string runV2CustomAt(const char* seed, int soulCount,
                          const char* customFilter,
                          const char* targetJokers) {
    return takeResult(brainstorm_v2(
        seed, "", "", "", soulCount, false, false, false, false, false,
        false, customFilter, "King", "Any Suit", 0, 0, targetJokers));
}

std::string runV2(const char* targetJokers) {
    return runV2At("JW111111", "", 0, targetJokers);
}

std::string runV3At(const char* seed, const char* voucher, const char* tag,
                    int soulCount, const char* targetJokers,
                    const char* deck) {
    return takeResult(brainstorm_v3(
        seed, voucher, "", tag, soulCount, false, false, false, false, false,
        false, "No Filter", "King", "Any Suit", 0, 0, targetJokers, deck));
}

std::string runV4At(const char* seed, int soulCount,
                    const char* targetJokers,
                    const char* targetJokerLocations,
                    const char* tag = "") {
    return takeResult(brainstorm_v4(
        seed, "", "", tag, soulCount, false, false, false, false, false,
        false, "No Filter", "King", "Any Suit", 0, 0, targetJokers,
        "Red Deck", targetJokerLocations));
}

std::string runV5At(const char* seed, int soulCount,
                    const char* targetJokers,
                    const char* targetJokerLocations,
                    const char* tag = "",
                    bool observatory = false) {
    return takeResult(brainstorm_v5(
        seed, "", "", tag, soulCount, observatory, false, false, false, false,
        false, "No Filter", "King", "Any Suit", 0, 0, targetJokers,
        "Red Deck", targetJokerLocations));
}

std::string runV6At(const char* seed, int soulCount,
                    const char* targetJokers,
                    const char* targetJokerLocations,
                    const char* tag = "",
                    bool observatory = false,
                    int observatoryDeadline = 0,
                    const char* deck = "Red Deck",
                    const char* voucher = "",
                    bool retcon = false) {
    return takeResult(brainstorm_v6(
        seed, voucher, "", tag, soulCount, observatory,
        observatoryDeadline, false, false, retcon, false, false,
        "No Filter", "King", "Any Suit", 0, 0, targetJokers,
        deck, targetJokerLocations));
}

std::string runV7At(const char* seed, int soulCount,
                    const char* targetJokers,
                    const char* targetJokerLocations,
                    int stakeLevel,
                    const char* tag = "",
                    bool observatory = false,
                    int observatoryDeadline = 0,
                    const char* deck = "Red Deck",
                    const char* voucher = "",
                    bool retcon = false) {
    return takeResult(brainstorm_v7(
        seed, voucher, "", tag, soulCount, observatory,
        observatoryDeadline, false, false, retcon, false, false,
        "No Filter", "King", "Any Suit", 0, 0, targetJokers,
        deck, targetJokerLocations, stakeLevel));
}

std::string runV5CustomAt(const char* seed, const char* customFilter,
                          const char* targetJokers,
                          const char* targetJokerLocations) {
    return takeResult(brainstorm_v5(
        seed, "", "", "", 0, false, false, false, false, false, false,
        customFilter, "King", "Any Suit", 0, 0, targetJokers, "Red Deck",
        targetJokerLocations));
}

std::string runEstimate(
    const char* targetJokers = "",
    const char* targetJokerLocations = "",
    int souls = 0,
    const char* deck = "Red Deck",
    const char* targetRank = "King",
    const char* targetSuit = "Any Suit",
    int specificRankMinimum = 0,
    int budgetMs = 25) {
    return takeResult(brainstorm_estimate_v1(
        "", "", "", souls, false, false, false, false, false, false,
        "No Filter", targetRank, targetSuit, specificRankMinimum, 0,
        targetJokers, deck, targetJokerLocations, budgetMs));
}

std::string runEstimateV2(
    const char* targetJokers,
    const char* targetJokerLocations,
    int observatoryDeadline = 0,
    int budgetMs = 25) {
    return takeResult(brainstorm_estimate_v2(
        "", "", "", 0, false, observatoryDeadline, false, false,
        false, false, false, "No Filter", "King", "Any Suit", 0, 0,
        targetJokers, "Red Deck", targetJokerLocations, budgetMs));
}

std::string runEstimateV3(
    const char* targetJokers,
    const char* targetJokerLocations,
    int stakeLevel,
    int observatoryDeadline = 0,
    int budgetMs = 25,
    const char* deck = "Red Deck",
    const char* targetRank = "King",
    const char* targetSuit = "Any Suit",
    int specificRankMinimum = 0) {
    return takeResult(brainstorm_estimate_v3(
        "", "", "", 0, false, observatoryDeadline, false, false,
        false, false, false, "No Filter", targetRank, targetSuit,
        specificRankMinimum, 0, targetJokers, deck,
        targetJokerLocations, budgetMs, stakeLevel));
}

std::string runRankDeckAt(const char* seed, const char* deck,
                          const char* rank, const char* suit,
                          int specificMinimum, int anyRankMinimum = 0) {
    return takeResult(brainstorm_v3(
        seed, "", "", "", 0, false, false, false, false, false, false,
        "No Filter", rank, suit, specificMinimum, anyRankMinimum, "", deck));
}

std::string runRankAt(const char* seed, const char* rank, const char* suit,
                      int minimum) {
    return runRankDeckAt(
        seed, "Erratic Deck", rank, suit, minimum);
}

bool jokerRangeRoundTrips(Item first, Item last) {
    bool passed = true;
    for (int value = static_cast<int>(first) + 1;
         value < static_cast<int>(last); value++) {
        const Item joker = static_cast<Item>(value);
        const std::string name = itemToString(joker);
        if (stringToItem(name) != joker) {
            std::cerr << "Joker name does not round-trip: " << name
                      << std::endl;
            passed = false;
        }
    }
    return passed;
}

bool oneShotLuaRandomMatchesStateful() {
    // The one-shot helper is allowed to skip LuaRandom's ten warm-up rounds,
    // but it must remain bit-for-bit identical to the stateful reference.
    // Exercise both hand-picked boundaries and a deterministic spread of
    // positive finite node values used by the game.
    const double boundaries[] = {
        0.0, 1.0, 0.5, 0.25, 0.75,
        0x1p-52, 0x1.fffffffffffffp-1,
        123456.789, 0x1.fffffffffffffp+20};
    for (double seed : boundaries) {
        LuaRandom reference(seed);
        if (reference.random() != lua_random_from_seed(seed)) {
            std::cerr << "one-shot Lua RNG differs at boundary seed "
                      << seed << std::endl;
            return false;
        }
    }

    uint64_t state = 0x6a09e667f3bcc909ull;
    for (int sample = 0; sample < 131072; ++sample) {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        dbllong value;
        value.ulong = (state & 0x000fffffffffffffull)
                      | 0x3ff0000000000000ull;
        const double seed = value.dbl - 1.0;
        LuaRandom reference(seed);
        if (reference.random() != lua_random_from_seed(seed)) {
            std::cerr << "one-shot Lua RNG differs at randomized sample "
                      << sample << std::endl;
            return false;
        }
    }
    return true;
}

bool positiveFractMatchesGeneral() {
    uint64_t state = 0xbb67ae8584caa73bull;
    for (int sample = 0; sample < 131072; ++sample) {
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;
        const uint64_t exponent = state % 0x7ffull;
        state ^= state << 13;
        state ^= state >> 7;
        state ^= state << 17;

        dbllong input;
        input.ulong = (exponent << 52)
                      | (state & 0x000fffffffffffffull);
        dbllong general;
        dbllong positive;
        general.dbl = fract(input.dbl);
        positive.dbl = fractPositive(input.dbl);
        if (general.ulong != positive.ulong) {
            std::cerr << "positive fractional-part helper differs at sample "
                      << sample << std::endl;
            return false;
        }
    }
    return true;
}

double referencePseudostep(char character, int position, double value) {
    return fract(
        1.1239285023 / value * character * 3.141592653589793116
        + 3.141592653589793116 * position);
}

double referenceSeedPseudohash(const Seed& seed, int prefixLength) {
    double value = 1.0;
    for (int position = 0; position < seed.length; ++position) {
        value = referencePseudostep(
            seedChars[static_cast<std::size_t>(seed.seed[position])],
            prefixLength + seed.length - position, value);
    }
    return value;
}

double referencePseudohashFrom(const std::string& key, double value) {
    for (std::size_t index = key.size(); index > 0; --index) {
        value = referencePseudostep(
            key[index - 1], static_cast<int>(index), value);
    }
    return value;
}

bool sameDoubleBits(double left, double right) {
    dbllong leftBits;
    dbllong rightBits;
    leftBits.dbl = left;
    rightBits.dbl = right;
    return leftBits.ulong == rightBits.ulong;
}

bool positivePseudohashesMatchGeneral() {
    const std::array<std::string, 12> keys = {
        "Tag1", "soul_Tarot1", "Joker4", "shop_voucher1",
        "shop_pack1", "cdt1", "rarity1sho", "edi1sho",
        "edi1buf", "Tag1_resample2", "Voucher8_resample17",
        "rarity6sho_resample1000"};
    constexpr std::array<int, 8> prefixLengths = {
        0, 1, 4, 6, 11, 17, 31, 40};

    std::uint64_t checkedSeeds = 0;
    std::uint64_t checkedKeys = 0;
    const auto checkRange = [&](long long startId, int count) {
        Seed seed(normalizeSeedId(startId));
        for (int sample = 0; sample < count; ++sample) {
            const int prefix = prefixLengths[
                static_cast<std::size_t>(sample)
                % prefixLengths.size()];
            const double expectedSeed =
                referenceSeedPseudohash(seed, prefix);
            const double actualSeed = seed.pseudohash(prefix);
            if (!sameDoubleBits(expectedSeed, actualSeed)) {
                std::cerr << "positive seed pseudohash differs at id "
                          << seed.getID() << ", prefix " << prefix
                          << std::endl;
                return false;
            }
            ++checkedSeeds;

            const std::string& key = keys[
                static_cast<std::size_t>(sample) % keys.size()];
            const int keyPrefix = static_cast<int>(key.size());
            const double expectedKeySeed =
                referenceSeedPseudohash(seed, keyPrefix);
            const double actualKeySeed = seed.pseudohash(keyPrefix);
            if (!sameDoubleBits(expectedKeySeed, actualKeySeed)) {
                std::cerr << "positive key-prefix seed hash differs at id "
                          << seed.getID() << ", key " << key << std::endl;
                return false;
            }
            ++checkedSeeds;

            const double expectedKey =
                referencePseudohashFrom(key, expectedKeySeed);
            const double actualKey =
                pseudohash_from(key, actualKeySeed);
            if (!sameDoubleBits(expectedKey, actualKey)) {
                std::cerr << "positive key pseudohash differs at id "
                          << seed.getID() << ", key " << key << std::endl;
                return false;
            }
            ++checkedKeys;
            seed.next();
        }
        return true;
    };

    if (!checkRange(1000000000000ll, 1000000)
        || !checkRange(0, 500000)
        || !checkRange(SEED_DOMAIN_SIZE - 500000, 500000)) {
        return false;
    }
    if (checkedSeeds != 4000000 || checkedKeys != 2000000) {
        std::cerr << "positive pseudohash differential coverage changed"
                  << std::endl;
        return false;
    }
    return true;
}

} // namespace

int main() {
    setTestEnvironment();
    bool passed = true;
    passed &= workerSelectionAdaptsToDetectedHardware();
    passed &= oneShotLuaRandomMatchesStateful();
    passed &= positiveFractMatchesGeneral();
    passed &= positivePseudohashesMatchGeneral();
    passed &= searchWrapsAcrossSeedDomain();

    const std::string immediateEstimate = runEstimate();
    passed &= expectContains(
        immediateEstimate, "status=ok\tmethod=exact_sample",
        "estimator directly samples a common configuration");
    passed &= expectContains(
        immediateEstimate, "\tseeds_per_second=",
        "estimator reports measured multithread throughput");
    passed &= expectContains(
        immediateEstimate, "\tmedian_low_seconds=",
        "exact estimator reports its 95-percent range");
    passed &= expectContains(
        runEstimate(
            "", "", 0, "Plasma Deck", "King", "Any Suit", 4),
        "status=always\tmethod=deterministic",
        "estimator identifies deterministic fixed-deck success");
    passed &= expectContains(
        runEstimate(
            "", "", 0, "Plasma Deck", "King", "Any Suit", 5),
        "status=impossible\tmethod=deterministic",
        "estimator identifies deterministic fixed-deck failure");

    const std::string estimateSeparator(
        1, static_cast<char>(0x1f));
    const std::string duplicateLegendary =
        std::string("Perkeo") + estimateSeparator + "Perkeo";
    const std::string duplicateLegendaryLocations =
        std::string("soul_pack") + estimateSeparator + "soul_pack";
    passed &= expectEqual(
        runEstimateV3(
            duplicateLegendary.c_str(),
            duplicateLegendaryLocations.c_str(), 1),
        runEstimateV2(
            duplicateLegendary.c_str(),
            duplicateLegendaryLocations.c_str()),
        "v3 estimator preserves v2 White-stake ABI behavior");
    passed &= expectContains(
        runEstimate(
            duplicateLegendary.c_str(),
            duplicateLegendaryLocations.c_str()),
        "status=impossible\tmethod=deterministic",
        "estimator rejects an unobtainable duplicate Legendary");

    const std::string fourSoulEstimate =
        runEstimate("", "", 4);
    passed &= expectContains(
        fourSoulEstimate, "status=ok\tmethod=staged_heuristic",
        "estimator models a zero-hit four-Soul search");
    passed &= expectContains(
        fourSoulEstimate, "\texact_hits=0",
        "staged estimate preserves exact zero-hit evidence");
    passed &= expectContains(
        fourSoulEstimate, "\texpected_full_space_matches=",
        "staged estimate reports modeled full-space availability");

    const std::string indexedJokers =
        std::string("Perkeo") + estimateSeparator
        + "Invisible Joker" + estimateSeparator + "Invisible Joker";
    const std::string indexedLocations =
        std::string("soul_pack") + estimateSeparator
        + "soul_pack" + estimateSeparator + "ante_2";
    const std::string indexedEstimate = takeResult(brainstorm_estimate_v3(
        "Telescope", "", "Charm Tag", 1, true, 2, false, false,
        false, false, false, "No Filter", "King", "Any Suit", 0, 0,
        indexedJokers.c_str(), "Plasma Deck", indexedLocations.c_str(),
        1000, 8));
    passed &= expectContains(
        indexedEstimate, "status=ok\tmethod=exact_index",
        "estimator selects the complete derived anchor index");
    passed &= expectContains(
        indexedEstimate,
        "\tindexed_total=2145\tindexed_tested=2145\tindexed_hits=17",
        "indexed estimator measures the complete derived population");

    // The derived child was exhaustively built for exactly three occurrences.
    // An extra acquired Joker before Ante 2 can change pool locks and
    // resampling, so broader routes must use the complete parent instead of
    // allowing a child miss to prove that no seed exists.
    const std::string broaderIndexedJokers =
        std::string("Perkeo") + estimateSeparator
        + "Invisible Joker" + estimateSeparator
        + "Blueprint" + estimateSeparator + "Invisible Joker";
    const std::string broaderIndexedLocations =
        std::string("soul_pack") + estimateSeparator
        + "soul_pack" + estimateSeparator
        + "ante_1" + estimateSeparator + "ante_2";
    const std::string broaderIndexedEstimate =
        takeResult(brainstorm_estimate_v3(
            "", "", "Charm Tag", 1, false, 0, false, false,
            false, false, false, "No Filter", "King", "Any Suit", 0, 0,
            broaderIndexedJokers.c_str(), "Plasma Deck",
            broaderIndexedLocations.c_str(), 25, 8));
    passed &= expectContains(
        broaderIndexedEstimate, "\tindexed_total=209798\t",
        "broader Joker routes use the complete parent anchor index");

    // This relaxed base temporarily removes the four-Soul requirement while
    // preserving its forced starting-Charm route. It must still consume one
    // Charm Tag, but must not fall through and require a second consecutive
    // Charm Tag merely because the temporary Soul count is zero.
    const std::string forcedCharmRouteEstimate =
        takeResult(brainstorm_estimate_v2(
            "", "", "Charm Tag", 4, true, 5, false, false, false,
            false, false, "No Filter", "King", "Any Suit", 0, 0,
            "", "Red Deck", "", 100));
    passed &= expectContains(
        forcedCharmRouteEstimate,
        "status=ok\tmethod=staged_heuristic",
        "forced Charm-route estimate uses the staged model");
    passed &= expectSingleCharmTagInStagedBase(
        forcedCharmRouteEstimate);

    // This seed's second shop item is a Negative Blueprint, while none of its
    // first four pack slots contains one. It specifically catches comparing a
    // ShopItem category with Item::Joker instead of Item::T_Joker.
    passed &= expectEqual(
        takeResult(brainstorm(
            "JW111111", "", "", "", 0.0, false, false, false, false,
            false, false, "Negative Blueprint", "King", "Any Suit", 0, 0)),
        "JW111111", "legacy Negative Blueprint shop filter");
    passed &= expectEqual(
        takeResult(brainstorm(
            "JW111111", "", "", "Charm Tag", 0.0, false, false,
            false, false, false, false, "Negative Blueprint", "King",
            "Any Suit", 0, 0)),
        "", "custom Negative Blueprint also requires the selected tag");
    passed &= expectEqual(
        takeResult(brainstorm(
            "JW111111", "", "", "Juggle Tag", 0.0, false, false,
            false, false, false, false, "Negative Blueprint", "King",
            "Any Suit", 0, 0)),
        "JW111111",
        "custom Negative Blueprint preserves a matching selected tag");
    passed &= expectEqual(
        runV2CustomAt(
            "K4U31111", 0, "Negative Blueprint", ""),
        "K4U31111",
        "custom Negative Blueprint matches a Buffoon pack edition");

    passed &= expectEqual(
        runV2("Reserved Parking"), "JW111111",
        "v2 early Ante 1 shop Joker target");

    passed &= expectEqual(
        runV3At(
            "JW111111", "", "", 0, "Reserved Parking", "Zodiac Deck"),
        "", "v3 Zodiac shop rates change the early Joker window");
    passed &= expectEqual(
        runV3At("61111111", "Observatory", "", 0, "", "Red Deck"),
        "", "Observatory is locked without a starting Telescope");
    passed &= expectEqual(
        runV3At("61111111", "Observatory", "", 0, "", "Nebula Deck"),
        "61111111", "v3 applies the Nebula starting Telescope");
    passed &= expectEqual(
        runV3At("JW111111", "", "", 0, "", "Modded Deck"),
        "", "v3 rejects unsupported deck names");
    passed &= expectEqual(
        runV3At(
            "JW111111", "", "", 0, "Reserved Parking", "Challenge Deck"),
        "", "v3 rejects Joker searches with unmodeled Challenge bans");
    passed &= expectEqual(
        runV3At("JW111111", "", "", 0, "", "Challenge Deck"),
        "", "v3 rejects all searches with unmodeled Challenge rules");
    passed &= expectEqual(
        runV2("Reserved Parking"), "JW111111",
        "v2 resets to its historical Red Deck default after v3 calls");

    const std::string duplicateTargets =
        std::string("Reserved Parking") + static_cast<char>(0x1f)
        + "Reserved Parking";
    passed &= expectEqual(
        runV2(duplicateTargets.c_str()), "JW111111",
        "duplicate Joker targets are deduplicated");

    const std::string negativeBlueprint =
        std::string("Blueprint") + static_cast<char>(0x1e) + "N";
    passed &= expectEqual(
        runV2(negativeBlueprint.c_str()), "JW111111",
        "Negative Joker target matches a shop Joker's edition");
    // This seed has its Negative Blueprint in a Buffoon pack, not in the four
    // inspected shop items, so the pack path must carry the full JokerData.
    passed &= expectEqual(
        runV2At("K4U31111", "", 0, negativeBlueprint.c_str()),
        "K4U31111", "Negative Joker target matches a Buffoon pack edition");
    passed &= expectEqual(
        runV2At("3111111", "", 0, "Blueprint"), "3111111",
        "name-only Joker target accepts any edition");
    passed &= expectEqual(
        runV2At("3111111", "", 0, negativeBlueprint.c_str()), "",
        "Negative Joker target rejects a non-Negative edition");

    const std::string anyThenNegativeBlueprint =
        std::string("Blueprint") + static_cast<char>(0x1f)
        + negativeBlueprint;
    const std::string negativeThenAnyBlueprint =
        negativeBlueprint + static_cast<char>(0x1f) + "Blueprint";
    passed &= expectEqual(
        runV2At(
            "3111111", "", 0, anyThenNegativeBlueprint.c_str()),
        "", "duplicate Joker target merges to the strictest edition");
    passed &= expectEqual(
        runV2At(
            "3111111", "", 0, negativeThenAnyBlueprint.c_str()),
        "", "Any Edition duplicate cannot weaken a Negative target");

    const std::string malformedEdition =
        std::string("Blueprint") + static_cast<char>(0x1e) + "F";
    passed &= expectEqual(
        runV2At("JW111111", "", 0, malformedEdition.c_str()), "",
        "unknown Joker edition suffix is rejected");

    passed &= expectEqual(
        runV2("Not a Joker"), "", "invalid Joker target is rejected");

    const std::string tooManyTargets =
        std::string("Joker") + static_cast<char>(0x1f) + "Greedy Joker"
        + static_cast<char>(0x1f) + "Lusty Joker"
        + static_cast<char>(0x1f) + "Wrathful Joker"
        + static_cast<char>(0x1f) + "Gluttonous Joker"
        + static_cast<char>(0x1f) + "Jolly Joker";
    passed &= expectEqual(
        runV2(tooManyTargets.c_str()), "",
        "more than five unique Joker targets are rejected");

    const std::string legendaryTargets =
        std::string("Yorick") + static_cast<char>(0x1f) + "Perkeo";
    passed &= expectEqual(
        runV2At("I1L21111", "", 2, legendaryTargets.c_str()),
        "I1L21111",
        "two collectible Soul outcomes satisfy two legendary targets");

    const std::string negativePerkeo =
        std::string("Perkeo") + static_cast<char>(0x1e) + "N";
    passed &= expectEqual(
        runV2At("GPDJ3111", "", 0, negativePerkeo.c_str()),
        "GPDJ3111", "Negative legendary target matches its Soul outcome");
    passed &= expectEqual(
        runV3At(
            "KLF2111", "Telescope", "Charm Tag", 1, "Perkeo",
            "Red Deck"),
        "KLF2111", "Any Edition Perkeo retains its exact fast path");

    // The SIMD gate is only a necessary condition. Its compacted survivors
    // must retain the exact scalar result for both the specialized voucher
    // route and a general cumulative-Joker route.
    setOpeningBatchEnabled(false);
    const std::string scalarTelescope = runV3At(
        "KLF2111", "Telescope", "Charm Tag", 1, "Perkeo", "Red Deck");
    const std::string scalarCumulativePerkeo = runV6At(
        "GPDJ3111", 0, "Perkeo", "by_ante_6");
    const std::string scalarYorick = runV2At(
        "6P111111", "", 1, "Yorick");
    const std::string scalarTwoSouls = runV2At(
        "I1L21111", "", 2, legendaryTargets.c_str());
    const std::string scalarGoldPerkeo = runV7At(
        "GPDJ3111", 0, "Perkeo", "by_ante_6", 8);
    passed &= expectEqual(
        scalarYorick, "6P111111",
        "scalar arbitrary-Legendary fixture remains a hit");
    passed &= expectEqual(
        scalarTwoSouls, "I1L21111",
        "scalar two-Soul fixture remains a hit");
    setOpeningBatchEnabled(true);
    passed &= expectEqual(
        runV3At(
            "KLF2111", "Telescope", "Charm Tag", 1, "Perkeo",
            "Red Deck"),
        scalarTelescope,
        "batched Telescope route matches scalar authoritative search");
    passed &= expectEqual(
        runV6At("GPDJ3111", 0, "Perkeo", "by_ante_6"),
        scalarCumulativePerkeo,
        "batched cumulative Perkeo route matches scalar authoritative search");
    passed &= expectEqual(
        runV2At("6P111111", "", 1, "Yorick"),
        scalarYorick,
        "batched arbitrary-Legendary route matches scalar search");
    passed &= expectEqual(
        runV2At("I1L21111", "", 2, legendaryTargets.c_str()),
        scalarTwoSouls,
        "batched two-Soul route matches scalar authoritative search");
    passed &= expectEqual(
        runV7At("GPDJ3111", 0, "Perkeo", "by_ante_6", 8),
        scalarGoldPerkeo,
        "Gold search matches across scalar and batched Soul routes");
    passed &= expectEqual(
        runV3At(
            "KLF2111", "Telescope", "Charm Tag", 1,
            negativePerkeo.c_str(), "Red Deck"),
        "", "Negative Perkeo does not use the edition-agnostic fast path");

    // The custom filter's implicit Negative Perkeo and the explicit Canio
    // require two distinct collectible Soul outcomes in this pack.
    passed &= expectEqual(
        runV2CustomAt(
            "9CISW211", 0, "Negative Perkeo", "Canio"),
        "9CISW211",
        "custom filter counts its implicit Perkeo beside another legendary");
    const std::string canioAndPerkeo =
        std::string("Canio") + static_cast<char>(0x1f) + "Perkeo";
    passed &= expectEqual(
        runV2CustomAt(
            "9CISW211", 0, "Negative Perkeo",
            canioAndPerkeo.c_str()),
        "9CISW211",
        "explicit Perkeo is deduplicated from the custom filter requirement");
    const std::string canioAndYorick =
        std::string("Canio") + static_cast<char>(0x1f) + "Yorick";
    passed &= expectEqual(
        runV2CustomAt(
            "9CISW211", 0, "Negative Perkeo",
            canioAndYorick.c_str()),
        "", "three distinct required legendary Jokers are not collectible");
    // The unfiltered tag roll for this seed is the Ante-1-locked Meteor Tag.
    // Resampling the new-run tag pool produces Charm Tag and its pack has a
    // Soul, so a souls-only search must evaluate the locked pool.
    passed &= expectEqual(
        runV2At("6P111111", "", 1, ""), "6P111111",
        "souls-only search applies Ante 1 tag locks");
    passed &= expectEqual(
        runV2At(
            "I1L21111", "Voucher Tag", 2, legendaryTargets.c_str()),
        "", "a conflicting configured tag cannot open the Charm pack");

    const std::string threeLegendaryTargets =
        std::string("Canio") + static_cast<char>(0x1f) + "Yorick"
        + static_cast<char>(0x1f) + "Perkeo";
    passed &= expectEqual(
        runV2At("I1L21111", "", 3, threeLegendaryTargets.c_str()),
        "", "more than two legendary targets are not collectible");
    passed &= expectEqual(
        runV2At("51111111", "", 0, "Cavendish"), "",
        "run-gated Jokers are excluded from the Ante 1 target window");

    const std::string locationSeparator(1, static_cast<char>(0x1f));
    const std::string chicotAndSmiley =
        std::string("Chicot") + locationSeparator + "Smiley Face";
    const std::string anteOneAndSoulPack =
        std::string("ante_1") + locationSeparator + "soul_pack";
    passed &= expectEqual(
        runV4At(
            "8I611111", 1, chicotAndSmiley.c_str(),
            anteOneAndSoulPack.c_str()),
        "8I611111",
        "v4 Judgement supplies Joker 2 from the starting Soul pack");
    passed &= expectEqual(
        runV5At(
            "8I611111", 1, chicotAndSmiley.c_str(),
            anteOneAndSoulPack.c_str()),
        runV4At(
            "8I611111", 1, chicotAndSmiley.c_str(),
            anteOneAndSoulPack.c_str()),
        "v5 preserves the legacy distinct-target early-search window");
    passed &= expectEqual(
        runV4At(
            "8I611111", 1, chicotAndSmiley.c_str(),
            (std::string("ante_1") + locationSeparator
             + "soul_or_ante_2").c_str()),
        "8I611111",
        "the combined route accepts Joker 2 from the starting Soul pack");
    passed &= expectEqual(
        runV4At(
            "8I611111", 1, chicotAndSmiley.c_str(),
            (std::string("ante_1") + locationSeparator + "ante_2").c_str()),
        "",
        "starting-pack Judgement does not satisfy an Ante 2-only target");

    const std::string yorickAndEightBall =
        std::string("Yorick") + locationSeparator + "8 Ball";
    const std::string anteOneAndSoulOrAnteTwo =
        std::string("ante_1") + locationSeparator + "soul_or_ante_2";
    passed &= expectEqual(
        runV4At(
            "6P111111", 1, yorickAndEightBall.c_str(),
            anteOneAndSoulOrAnteTwo.c_str()),
        "6P111111",
        "v4 Joker 2 can appear in the second natural Ante 2 shop");
    passed &= expectEqual(
        runV4At(
            "6P111111", 1, yorickAndEightBall.c_str(),
            (std::string("ante_1") + locationSeparator + "ante_1").c_str()),
        "",
        "an Ante 2 Joker does not satisfy the legacy Ante 1 source");
    passed &= expectEqual(
        runV3At(
            "6P111111", "", "", 1, yorickAndEightBall.c_str(),
            "Red Deck"),
        "",
        "v3 retains its Ante 1-only default Joker timing");
    passed &= expectEqual(
        runV4At("JW111111", 0, "Reserved Parking", ""),
        "JW111111",
        "empty v4 location data preserves the v3 default");

    const std::string negativePopcorn =
        std::string("Popcorn") + static_cast<char>(0x1e) + "N";
    const std::string chicotAndNegativePopcorn =
        std::string("Chicot") + locationSeparator + negativePopcorn;
    passed &= expectEqual(
        runV4At(
            "725E1111", 1, chicotAndNegativePopcorn.c_str(),
            anteOneAndSoulPack.c_str()),
        "725E1111",
        "v4 preserves Negative edition matching for Judgement");

    const std::string blankThenEightBall =
        locationSeparator + std::string("8 Ball");
    const std::string blankThenAnteTwo =
        std::string("ante_1") + locationSeparator + "ante_2";
    passed &= expectEqual(
        runV4At(
            "6P111111", 0, blankThenEightBall.c_str(),
            blankThenAnteTwo.c_str()),
        "",
        "special Joker 2 timing requires a Legendary Joker 1");
    const std::string fiveSlotTargets =
        yorickAndEightBall + locationSeparator + locationSeparator
        + locationSeparator;
    const std::string fiveSlotLocations =
        std::string("ante_1") + locationSeparator + "ante_2"
        + locationSeparator + locationSeparator + locationSeparator;
    passed &= expectEqual(
        runV4At(
            "6P111111", 1, fiveSlotTargets.c_str(),
            fiveSlotLocations.c_str()),
        "6P111111",
        "five aligned location tokens preserve trailing blank slots");
    const std::string duplicateAfterBlank =
        yorickAndEightBall + locationSeparator + locationSeparator
        + "8 Ball";
    const std::string duplicateAfterBlankLocations =
        anteOneAndSoulOrAnteTwo + locationSeparator + "ante_1"
        + locationSeparator + "ante_1";
    passed &= expectEqual(
        runV4At(
            "6P111111", 1, duplicateAfterBlank.c_str(),
            duplicateAfterBlankLocations.c_str()),
        "6P111111",
        "dedup retains the first target's slot-aligned location across blanks");
    passed &= expectEqual(
        runV4At(
            "6P111111", 1, yorickAndEightBall.c_str(),
            (std::string("ante_1") + locationSeparator + "not_a_place").c_str()),
        "",
        "v4 rejects an unknown Joker location token");
    const std::string blankThenYorick =
        locationSeparator + std::string("Yorick");
    passed &= expectEqual(
        runV4At(
            "6P111111", 0, blankThenYorick.c_str(),
            blankThenAnteTwo.c_str()),
        "",
        "v4 rejects a Legendary Joker constrained only to Ante 2");
    const std::string yorickBlankEightBall =
        std::string("Yorick") + locationSeparator + locationSeparator
        + "8 Ball";
    const std::string specialThirdSlot =
        std::string("ante_1") + locationSeparator + "ante_1"
        + locationSeparator + "ante_2";
    passed &= expectEqual(
        runV4At(
            "6P111111", 1, yorickBlankEightBall.c_str(),
            specialThirdSlot.c_str()),
        "",
        "special timing is rejected outside Joker slot 2");

    const std::string threeCharmJokers =
        std::string("Canio") + locationSeparator + "Lusty Joker"
        + locationSeparator + "Chicot";
    const std::string threeCharmLocations =
        std::string("ante_1") + locationSeparator + "soul_pack"
        + locationSeparator + "ante_1";
    const std::string canioAndChicot =
        std::string("Canio") + locationSeparator + "Chicot";
    passed &= expectEqual(
        runV4At(
            "CTKB2111", 2, canioAndChicot.c_str(),
            anteOneAndSoulPack.c_str()),
        "CTKB2111",
        "two Soul selections remain collectible from a Mega Arcana pack");
    const std::string canioAndLusty =
        std::string("Canio") + locationSeparator + "Lusty Joker";
    passed &= expectEqual(
        runV4At(
            "CTKB2111", 2, canioAndLusty.c_str(),
            anteOneAndSoulPack.c_str()),
        "CTKB2111",
        "one Soul plus Judgement fits the two-choice limit");
    passed &= expectEqual(
        runV4At(
            "CTKB2111", 2, threeCharmJokers.c_str(),
            threeCharmLocations.c_str()),
        "",
        "Charm pack cannot collect two Soul Jokers plus Judgement");

    const std::string duplicateReservedParking =
        std::string("Reserved Parking") + locationSeparator
        + "Reserved Parking";
    const std::string duplicateAnteOne =
        std::string("ante_1") + locationSeparator + "ante_1";
    passed &= expectEqual(
        runV5At(
            "YWON1111", 0, "Reserved Parking", "ante_1"),
        "YWON1111",
        "v5 retains a single natural Ante 1 occurrence");
    passed &= expectEqual(
        runV5At(
            "YWON1111", 0, duplicateReservedParking.c_str(),
            duplicateAnteOne.c_str()),
        "",
        "one generated Joker cannot satisfy two v5 occurrences");
    passed &= expectEqual(
        runV5At(
            "WYIBD111", 0, duplicateReservedParking.c_str(),
            duplicateAnteOne.c_str()),
        "WYIBD111",
        "v5 sells a generic first occurrence before a later duplicate");
    for (int stakeLevel = 1; stakeLevel <= 3; stakeLevel++) {
        passed &= expectEqual(
            runV7At(
                "WYIBD111", 0, duplicateReservedParking.c_str(),
                duplicateAnteOne.c_str(), stakeLevel),
            "WYIBD111",
            "pre-Black stakes keep the duplicate Joker sellable");
    }
    for (int stakeLevel = 4; stakeLevel <= 8; stakeLevel++) {
        passed &= expectEqual(
            runV7At(
                "WYIBD111", 0, duplicateReservedParking.c_str(),
                duplicateAnteOne.c_str(), stakeLevel),
            "",
            "Black-and-higher stakes reject an Eternal duplicate route");
    }
    passed &= expectEqual(
        runV7At(
            "1C111111", 0, duplicateReservedParking.c_str(),
            duplicateAnteOne.c_str(), 8),
        "1C111111",
        "Gold rental/perishable Jokers remain sellable when non-Eternal");
    const std::string whiteDuplicateEstimate = runEstimateV3(
        duplicateReservedParking.c_str(), duplicateAnteOne.c_str(),
        1, 0, 1000);
    const std::string goldDuplicateEstimate = runEstimateV3(
        duplicateReservedParking.c_str(), duplicateAnteOne.c_str(),
        8, 0, 1000);
    double whiteEstimateHits = 0.0;
    double whiteEstimateTested = 0.0;
    double goldEstimateHits = 0.0;
    double goldEstimateTested = 0.0;
    const bool estimateStakeFieldsPresent =
        readEstimateField(
            whiteDuplicateEstimate, "exact_hits", whiteEstimateHits)
        && readEstimateField(
            whiteDuplicateEstimate, "exact_tested", whiteEstimateTested)
        && readEstimateField(
            goldDuplicateEstimate, "exact_hits", goldEstimateHits)
        && readEstimateField(
            goldDuplicateEstimate, "exact_tested", goldEstimateTested);
    passed &= expectContains(
        whiteDuplicateEstimate, "status=ok\tmethod=exact_sample",
        "White duplicate estimator gathers exact stake-aware samples");
    passed &= expectContains(
        goldDuplicateEstimate, "status=ok\tmethod=exact_sample",
        "Gold duplicate estimator gathers exact stake-aware samples");
    passed &= estimateStakeFieldsPresent
        && whiteEstimateTested > 0.0 && goldEstimateTested > 0.0
        && goldEstimateHits / goldEstimateTested
            < whiteEstimateHits / whiteEstimateTested;
    if (!(estimateStakeFieldsPresent
          && whiteEstimateTested > 0.0 && goldEstimateTested > 0.0
          && goldEstimateHits / goldEstimateTested
              < whiteEstimateHits / whiteEstimateTested)) {
        std::cerr << "Gold estimator did not reflect Eternal duplicate "
                     "rejection: White='"
                  << whiteDuplicateEstimate << "', Gold='"
                  << goldDuplicateEstimate << "'" << std::endl;
    }
    const std::string showmanAndDuplicateJoker =
        std::string("Showman") + locationSeparator + "Joker"
        + locationSeparator + "Joker";
    const std::string showmanDuplicateLocations =
        std::string("ante_1") + locationSeparator + "ante_2"
        + locationSeparator + "ante_2";
    passed &= expectEqual(
        runV5At(
            "I5WF111", 0, showmanAndDuplicateJoker.c_str(),
            showmanDuplicateLocations.c_str()),
        "I5WF111",
        "owned Showman permits a later duplicate without pool culling");
    passed &= expectEqual(
        runV7At(
            "I5WF111", 0, showmanAndDuplicateJoker.c_str(),
            showmanDuplicateLocations.c_str(), 8),
        "I5WF111",
        "a later Showman permits the Gold-stake duplicate route");

    passed &= expectEqual(
        runV5At("WQYV4111", 0, "8 Ball", "ante_3"),
        "WQYV4111", "v5 scans natural no-reroll Ante 3 windows");
    passed &= expectEqual(
        runV5At("TQCB2111", 0, "8 Ball", "ante_4"),
        "TQCB2111", "v5 scans natural no-reroll Ante 4 windows");
    passed &= expectEqual(
        runV4At("WQYV4111", 0, "8 Ball", "ante_3"),
        "", "v4 rejects v5-only timing tokens");

    passed &= expectEqual(
        runV6At("YWON1111", 0, "Reserved Parking", "by_ante_8"),
        "YWON1111",
        "v6 cumulative timing accepts an earlier natural occurrence");
    passed &= expectEqual(
        runV7At(
            "YWON1111", 0, "Reserved Parking", "by_ante_8", 1),
        runV6At(
            "YWON1111", 0, "Reserved Parking", "by_ante_8"),
        "v7 search preserves v6 White-stake ABI behavior");
    passed &= expectEqual(
        runV7At(
            "YWON1111", 0, "Reserved Parking", "by_ante_8", 0),
        "", "v7 rejects stake level zero");
    passed &= expectEqual(
        runV7At(
            "YWON1111", 0, "Reserved Parking", "by_ante_8", 9),
        "", "v7 rejects stake levels above Gold");
    passed &= expectContains(
        runEstimateV3("Reserved Parking", "by_ante_8", 0),
        "status=invalid\tmethod=none",
        "v3 estimator rejects stake level zero");
    passed &= expectContains(
        runEstimateV3("Reserved Parking", "by_ante_8", 9),
        "status=invalid\tmethod=none",
        "v3 estimator rejects stake levels above Gold");
    passed &= expectEqual(
        runV5At("YWON1111", 0, "Reserved Parking", "by_ante_8"),
        "", "v5 rejects v6-only cumulative timing tokens");
    passed &= expectEqual(
        runV6At("8I611111", 0, "Smiley Face", "by_ante_2"),
        "8I611111",
        "v6 cumulative timing includes optional starting-pack Judgement");
    passed &= expectEqual(
        runV6At("GPDJ3111", 0, "Perkeo", "by_ante_6"),
        "GPDJ3111",
        "v6 cumulative timing includes a starting-pack Soul outcome");

    passed &= expectEqual(
        runV5At("A4111111", 0, "", "", "", true),
        "A4111111",
        "v5 Observatory ABI retains exact Ante 1/Ante 2 behavior");
    passed &= expectEqual(
        runV6At("A4111111", 0, "", "", "", true, 0),
        "A4111111",
        "v6 legacy Observatory switch defaults its deadline to Ante 2");
    passed &= expectEqual(
        runV6At("T2111111", 0, "", "", "", false, 4),
        "", "Observatory deadline rejects a pair completed after Ante 4");
    passed &= expectEqual(
        runV6At("T2111111", 0, "", "", "", false, 5),
        "T2111111",
        "Observatory deadline accepts ordered vouchers completed by Ante 5");
    passed &= expectEqual(
        runV6At("T2111111", 0, "", "", "", true, 5),
        "T2111111",
        "an explicit Observatory deadline overrides the legacy switch");
    passed &= expectEqual(
        runV6At(
            "T2111111", 0, "", "", "", false, 5,
            "Red Deck", "Hone"),
        "",
        "v6 rejects a different Voucher Search beside Observatory");
    passed &= expectEqual(
        runV6At(
            "T2111111", 0, "", "", "", false, 5,
            "Red Deck", "", true),
        "",
        "v6 rejects independently simulated Retcon plus Observatory");
    passed &= expectEqual(
        runV6At(
            "61111111", 0, "", "", "", false, 2,
            "Nebula Deck"),
        "61111111",
        "v6 Observatory deadlines honor a deck-start Telescope");
    passed &= expectContains(
        runEstimateV2("Reserved Parking", "by_ante_2", 5),
        "status=ok",
        "v2 estimator accepts cumulative Joker and Observatory deadlines");

    const std::string duplicateInvisible =
        std::string("Invisible Joker") + locationSeparator
        + "Invisible Joker";
    const std::string invisibleAnteTwoThenFour =
        std::string("ante_2") + locationSeparator + "ante_4";
    passed &= expectEqual(
        runV5At(
            "K1NL3111", 0, duplicateInvisible.c_str(),
            invisibleAnteTwoThenFour.c_str()),
        "K1NL3111",
        "v5 ages and sells Invisible before its later occurrence");
    passed &= expectEqual(
        runV7At(
            "K1NL3111", 0, duplicateInvisible.c_str(),
            invisibleAnteTwoThenFour.c_str(), 8),
        "K1NL3111",
        "Gold stake preserves Invisible Joker's Eternal exemption");
    passed &= expectEqual(
        runV6At(
            "K1NL3111", 0, duplicateInvisible.c_str(),
            (std::string("by_ante_2") + locationSeparator
             + "by_ante_4").c_str()),
        "K1NL3111",
        "v6 cumulative duplicate timing preserves Invisible maturation");
    passed &= expectEqual(
        runV6At(
            "K1NL3111", 0, duplicateInvisible.c_str(),
            (std::string("by_ante_2") + locationSeparator
             + "by_ante_3").c_str()),
        "", "a cumulative deadline cannot bypass Invisible maturation");
    passed &= expectEqual(
        runV5At(
            "K1NL3111", 0, duplicateInvisible.c_str(),
            (std::string("ante_2") + locationSeparator
             + "ante_2").c_str()),
        "", "the second Invisible cannot reuse its locked Ante 2 stock");
    passed &= expectEqual(
        runV5At(
            "K1NL3111", 0, duplicateInvisible.c_str(),
            (std::string("ante_2") + locationSeparator
             + "ante_3").c_str()),
        "", "Invisible must complete two blinds before a later occurrence");
    passed &= expectEqual(
        runV5At(
            "K1NL3111", 0, duplicateInvisible.c_str(),
            (std::string("ante_2") + locationSeparator
             + "soul_or_ante_2").c_str()),
        "", "v5 rejects ambiguous flexible duplicate timing");
    passed &= expectEqual(
        runV5At("K1NL3111", 0, "Perkeo", "ante_3"),
        "", "v5 rejects a Legendary Joker in a natural later ante");
    const std::string twoJudgementTargets =
        std::string("Smiley Face") + locationSeparator + "Popcorn";
    const std::string twoSoulPackLocations =
        std::string("soul_pack") + locationSeparator + "soul_pack";
    passed &= expectEqual(
        runV5At(
            "8I611111", 0, twoJudgementTargets.c_str(),
            twoSoulPackLocations.c_str()),
        "", "one Judgement cannot supply two non-Legendary Soul-pack targets");
    const std::string forcedFlexibleJudgements =
        std::string("Blueprint") + locationSeparator + "Smiley Face"
        + locationSeparator + "Invisible Joker" + locationSeparator
        + "Invisible Joker";
    const std::string forcedFlexibleJudgementLocations =
        std::string("soul_or_ante_2") + locationSeparator + "soul_pack"
        + locationSeparator + "ante_2" + locationSeparator + "ante_3";
    passed &= expectEqual(
        runV5At(
            "8I611111", 0, forcedFlexibleJudgements.c_str(),
            forcedFlexibleJudgementLocations.c_str()),
        "",
        "ordered timing cannot force two Jokers through one Judgement");
    const std::string forcedThirdStartingChoice =
        std::string("Blueprint") + locationSeparator + "Perkeo"
        + locationSeparator + "Canio" + locationSeparator
        + "Invisible Joker" + locationSeparator + "Invisible Joker";
    const std::string forcedThirdStartingChoiceLocations =
        std::string("soul_or_ante_2") + locationSeparator + "ante_1"
        + locationSeparator + "ante_1" + locationSeparator + "ante_2"
        + locationSeparator + "ante_3";
    passed &= expectEqual(
        runV5At(
            "8I611111", 0, forcedThirdStartingChoice.c_str(),
            forcedThirdStartingChoiceLocations.c_str()),
        "",
        "ordered timing cannot force a third starting-pack selection");
    const std::string implicitPerkeoThirdChoice =
        std::string("Blueprint") + locationSeparator + "Canio"
        + locationSeparator + "Invisible Joker" + locationSeparator
        + "Invisible Joker";
    const std::string implicitPerkeoThirdChoiceLocations =
        std::string("soul_or_ante_2") + locationSeparator + "ante_1"
        + locationSeparator + "ante_2" + locationSeparator + "ante_3";
    passed &= expectEqual(
        runV5CustomAt(
            "8I611111", "Negative Perkeo",
            implicitPerkeoThirdChoice.c_str(),
            implicitPerkeoThirdChoiceLocations.c_str()),
        "",
        "implicit custom-filter Perkeo counts against ordered pack choices");

    // Fixed-composition decks are deterministic and should return or reject
    // the starting seed without applying Erratic's seeded card generator.
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Red Deck", "King", "Any Suit", 4),
        "JW111111", "standard deck has four copies of each rank");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Red Deck", "King", "Any Suit", 5),
        "", "standard deck cannot have five copies of one rank");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Plasma Deck", "King", "Any Suit", 4),
        "JW111111", "Plasma uses the standard 52-card composition");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Plasma Deck", "King", "Any One Suit", 2),
        "", "standard deck has one target rank in each individual suit");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Plasma Deck", "King", "Hearts", 1),
        "JW111111", "standard deck fixed-suit rank count");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Plasma Deck", "King", "Any Suit", 0, 4),
        "JW111111", "standard deck Any Rank threshold");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Plasma Deck", "King", "Any Suit", 0, 5),
        "", "standard deck Any Rank rejects a fifth copy");

    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Checkered Deck", "King", "Any Suit", 4),
        "JW111111", "Checkered combined-suit rank count");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Checkered Deck", "King", "Any One Suit", 2),
        "JW111111", "Checkered Any One Suit finds a doubled suit");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Checkered Deck", "King", "Hearts", 2),
        "JW111111", "Checkered has two Hearts of each rank");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Checkered Deck", "King", "Spades", 2),
        "JW111111", "Checkered has two Spades of each rank");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Checkered Deck", "King", "Clubs", 1),
        "", "Checkered has no Clubs");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Checkered Deck", "King", "Diamonds", 1),
        "", "Checkered has no Diamonds");

    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Abandoned Deck", "King", "Any Suit", 1),
        "", "Abandoned removes Kings");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Abandoned Deck", "Kings or Queens", "Any Suit", 1),
        "", "Abandoned removes both selected face ranks");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Abandoned Deck", "Royals", "Any Suit", 4),
        "JW111111", "Abandoned Royals still includes Aces and Tens");
    passed &= expectEqual(
        runRankDeckAt(
            "JW111111", "Abandoned Deck", "King", "Any Suit", 1, 4),
        "JW111111", "deterministic specific and Any Rank filters remain ORed");

    // "Any Suit" pools copies of the target rank across all suits. "Any One
    // Suit" instead requires the threshold within one unspecified suit. These
    // fixtures remain seed-dependent because Erratic rolls 52 random cards.
    passed &= expectEqual(
        runRankAt("JW111111", "King", "Any Suit", 3), "JW111111",
        "combined Any Suit target count");
    passed &= expectEqual(
        runRankAt("JW111111", "King", "Any One Suit", 3), "",
        "Any One Suit does not combine target cards from different suits");
    passed &= expectEqual(
        runRankAt("11111111", "King", "Any One Suit", 2), "11111111",
        "Any One Suit accepts whichever single suit reaches the target count");
    passed &= expectEqual(
        runRankAt("11111111", "King", "Hearts", 2), "",
        "specific suit still rejects a different matching suit");
    passed &= expectEqual(
        runRankAt("11111111", "King", "Spades", 2), "11111111",
        "specific suit behavior remains unchanged");

    passed &= itemToString(Item::Riff_raff) == "Riff-Raff";
    passed &= stringToItem("Riff-Raff") == Item::Riff_raff;
    passed &= stringToItem("Riff-raff") == Item::Riff_raff;
    passed &= itemToString(Item::Seance) == "S\xC3\xA9" "ance";
    passed &= stringToItem("S\xC3\xA9" "ance") == Item::Seance;
    passed &= jokerRangeRoundTrips(Item::J_C_BEGIN, Item::J_C_END);
    passed &= jokerRangeRoundTrips(Item::J_U_BEGIN, Item::J_U_END);
    passed &= jokerRangeRoundTrips(Item::J_R_BEGIN, Item::J_R_END);
    passed &= jokerRangeRoundTrips(Item::J_L_BEGIN, Item::J_L_END);

    return passed ? EXIT_SUCCESS : EXIT_FAILURE;
}
