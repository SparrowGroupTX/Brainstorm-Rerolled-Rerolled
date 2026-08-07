#include "immolate.hpp"

#include <algorithm>
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

constexpr char fieldSeparator = 0x1f;
constexpr char editionSeparator = 0x1e;

void setEnvironment(const char* name, const std::string& value) {
#ifdef _WIN32
    if (_putenv_s(name, value.c_str()) != 0) {
        throw std::runtime_error(std::string("Could not set ") + name);
    }
#else
    if (setenv(name, value.c_str(), 1) != 0) {
        throw std::runtime_error(std::string("Could not set ") + name);
    }
#endif
}

long long scaledLimit(long long normalLimit) {
    const char* rawScale = std::getenv("BRAINSTORM_PGO_TRAINING_SCALE");
    if (rawScale == nullptr || rawScale[0] == '\0') {
        return normalLimit;
    }

    char* parsedEnd = nullptr;
    const double scale = std::strtod(rawScale, &parsedEnd);
    if (parsedEnd == rawScale || *parsedEnd != '\0' || scale <= 0.0) {
        throw std::runtime_error(
            "BRAINSTORM_PGO_TRAINING_SCALE must be a positive number");
    }
    return std::max(1LL, static_cast<long long>(normalLimit * scale));
}

std::string takeResult(const char* rawResult) {
    if (rawResult == nullptr) {
        throw std::runtime_error("Brainstorm returned a null result");
    }
    const std::string result(rawResult);
    free_result(rawResult);
    return result;
}

void runUserSearch(
    const char* startSeed, int observatoryDeadline, const char* label) {
    const std::string jokers =
        std::string("Perkeo") + fieldSeparator
        + "Invisible Joker" + fieldSeparator
        + "Invisible Joker";
    const std::string locations =
        std::string("soul_pack") + fieldSeparator
        + "soul_pack" + fieldSeparator
        + "ante_2";

    setEnvironment(
        "BRAINSTORM_SEARCH_LIMIT", std::to_string(scaledLimit(20000000)));
    const std::string result = takeResult(brainstorm_v7(
        startSeed, "Telescope", "", "Charm Tag", 1, true,
        observatoryDeadline, false, false, false, false, false,
        "No Filter", "King",
        "Any Suit", 0, 0, jokers.c_str(), "Plasma Deck",
        locations.c_str(), 8));
    std::cout << "  " << label << " start " << startSeed
              << (result.empty() ? ": range exhausted" : ": match found")
              << '\n';
}

void runNegativeTimelineSearch() {
    // Multiple Negative requirements prevent a premature match while still
    // training the costly edition-aware shop/pack timeline that motivated this
    // workload.
    const std::string jokers =
        std::string("Blueprint") + editionSeparator + "N"
        + fieldSeparator + "Invisible Joker" + editionSeparator + "N"
        + fieldSeparator + "Invisible Joker" + editionSeparator + "N"
        + fieldSeparator + "Invisible Joker" + editionSeparator + "N"
        + fieldSeparator + "Invisible Joker" + editionSeparator + "N";
    const std::string locations =
        std::string("by_ante_8") + fieldSeparator
        + "by_ante_8" + fieldSeparator + "by_ante_8" + fieldSeparator
        + "by_ante_8" + fieldSeparator + "by_ante_8";

    setEnvironment(
        "BRAINSTORM_SEARCH_LIMIT", std::to_string(scaledLimit(100000)));
    const std::string result = takeResult(brainstorm_v7(
        "C7H31111", "", "", "", 0, false, 0,
        false, false, false, false, false, "No Filter", "King",
        "Any Suit", 0, 0, jokers.c_str(), "Red Deck",
        locations.c_str(), 8));
    std::cout << "  negative-timeline"
              << (result.empty() ? ": range exhausted" : ": match found")
              << '\n';
}

void runForcedCharmNegativeSearch() {
    // Train the composition used when the opening Charm/Soul SIMD gate owns
    // the batch slot and the general Negative necessary-condition filter runs
    // only on its survivors.
    const std::string jokers =
        std::string("Perkeo") + fieldSeparator
        + "Invisible Joker" + editionSeparator + "N";
    const std::string locations =
        std::string("soul_pack") + fieldSeparator + "by_ante_4";

    setEnvironment(
        "BRAINSTORM_SEARCH_LIMIT", std::to_string(scaledLimit(20000000)));
    const std::string result = takeResult(brainstorm_v7(
        "CHRMNEG1", "", "", "Charm Tag", 1, false, 0,
        false, false, false, false, false, "No Filter", "King",
        "Any Suit", 0, 0, jokers.c_str(), "Plasma Deck",
        locations.c_str(), 8));
    std::cout << "  forced-charm-negative"
              << (result.empty() ? ": range exhausted" : ": match found")
              << '\n';
}

void runNegativeBlueprintSearch() {
    // Exercise the SIMD Negative-edition gate and its rare authoritative
    // survivors without allowing the training search to stop early.
    const std::string jokers =
        std::string("Invisible Joker") + editionSeparator + "N"
        + fieldSeparator + "Brainstorm" + editionSeparator + "N"
        + fieldSeparator + "Baron" + editionSeparator + "N";
    const std::string locations =
        std::string("by_ante_8") + fieldSeparator
        + "by_ante_8" + fieldSeparator + "by_ante_8";

    setEnvironment(
        "BRAINSTORM_SEARCH_LIMIT", std::to_string(scaledLimit(500000)));
    const std::string result = takeResult(brainstorm_v7(
        "11111111", "", "", "", 0, false, 0,
        false, false, false, false, false, "Negative Blueprint", "King",
        "Any Suit", 0, 0, jokers.c_str(), "Red Deck",
        locations.c_str(), 8));
    std::cout << "  negative-blueprint"
              << (result.empty() ? ": range exhausted" : ": match found")
              << '\n';
}

void runFourSoulLegendarySearch() {
    // Exercise the four-Soul opening path and arbitrary non-Perkeo Legendary
    // targets in the same starting Mega Arcana Pack.
    const std::string jokers =
        std::string("Canio") + fieldSeparator + "Triboulet";
    const std::string locations =
        std::string("soul_pack") + fieldSeparator + "soul_pack";

    setEnvironment(
        "BRAINSTORM_SEARCH_LIMIT", std::to_string(scaledLimit(5000000)));
    const std::string result = takeResult(brainstorm_v7(
        "F4UR1111", "", "", "Charm Tag", 4, false, 0,
        false, false, false, false, false, "No Filter", "King",
        "Any Suit", 0, 0, jokers.c_str(), "Plasma Deck",
        locations.c_str(), 8));
    std::cout << "  four-soul-legendaries"
              << (result.empty() ? ": range exhausted" : ": match found")
              << '\n';
}

void runErraticRankSearch() {
    setEnvironment(
        "BRAINSTORM_SEARCH_LIMIT", std::to_string(scaledLimit(2000000)));
    const std::string result = takeResult(brainstorm_v7(
        "R9X61111", "", "", "", 0, false, 0,
        false, false, false, false, false, "No Filter", "King",
        "Any One Suit", 13, 0, "", "Erratic Deck", "", 8));
    std::cout << "  erratic-rank"
              << (result.empty() ? ": range exhausted" : ": match found")
              << '\n';
}

} // namespace

int main() {
    try {
        std::cout << std::unitbuf;
        setEnvironment("BRAINSTORM_THREADS", "1");
        setEnvironment("BRAINSTORM_PRINT_DELAY", "0");
        setEnvironment("BRAINSTORM_PROFILE", "0");
        // Regression tests already exercise the exact-index planner before
        // training.  Force the longer mixed workloads through the raw path so
        // a newly installed complete index cannot collapse PGO training into
        // a handful of candidate checks and starve the fallback hot loops.
        setEnvironment("BRAINSTORM_ANCHOR_INDEX", "0");
        setEnvironment("BRAINSTORM_DERIVED_ANCHOR_INDEX", "0");
        setEnvironment("BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX", "0");
        setEnvironment("BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX", "0");

        std::cout << "Training Brainstorm's mixed native workload...\n";
        // The first pair is the user's literal Gold-stake route. The second
        // pair deliberately relaxes only the Observatory deadline.
        runUserSearch("11111111", 2, "literal-user-deadline-2");
        runUserSearch("MZZZZZZZ", 2, "literal-user-deadline-2");
        runUserSearch("11111111", 5, "relaxed-observatory-deadline-5");
        runUserSearch("MZZZZZZZ", 5, "relaxed-observatory-deadline-5");
        runNegativeTimelineSearch();
        runForcedCharmNegativeSearch();
        runNegativeBlueprintSearch();
        runFourSoulLegendarySearch();
        runErraticRankSearch();
        std::cout << "PGO training complete.\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "PGO training failed: " << error.what() << '\n';
        return 1;
    }
}
