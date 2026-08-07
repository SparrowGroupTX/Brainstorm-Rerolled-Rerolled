#include "immolate.hpp"

#include <chrono>
#include <cstdlib>
#include <iomanip>
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

std::string takeResult(const char* rawResult) {
    if (rawResult == nullptr) {
        throw std::runtime_error("Brainstorm returned a null result");
    }
    const std::string result(rawResult);
    free_result(rawResult);
    return result;
}

std::string negativeJoker(const char* name) {
    return std::string(name) + editionSeparator + "N";
}

struct BenchmarkConfiguration {
    std::string voucher;
    std::string pack;
    std::string tag;
    int souls = 0;
    bool observatory = false;
    int observatoryDeadline = 0;
    bool perkeo = false;
    bool copymoney = false;
    bool retcon = false;
    bool bean = false;
    bool burglar = false;
    std::string customFilter = "No Filter";
    std::string targetRank = "King";
    std::string targetSuit = "Any Suit";
    int specificRankMin = 0;
    int anyRankMin = 0;
    std::string targetJokers;
    std::string deck = "Red Deck";
    std::string locations;
    int stakeLevel = 8;
};

BenchmarkConfiguration configurationFor(const std::string& name) {
    BenchmarkConfiguration config;
    if (name == "mega-naneinf") {
        config.pack = "Mega Spectral Pack";
        config.tag = "Charm Tag";
        config.souls = 1;
        config.targetJokers =
            std::string("Perkeo") + fieldSeparator
            + "Blueprint" + fieldSeparator + "Brainstorm" + fieldSeparator
            + "Baron" + fieldSeparator + "Mime";
        config.locations =
            std::string("soul_pack") + fieldSeparator
            + "by_ante_4" + fieldSeparator + "by_ante_4" + fieldSeparator
            + "by_ante_8" + fieldSeparator + "by_ante_8";
        config.deck = "Plasma Deck";
        config.stakeLevel = 8;
        return config;
    }
    if (name == "original-user") {
        config.voucher = "Telescope";
        config.tag = "Charm Tag";
        config.souls = 1;
        config.observatory = true;
        config.observatoryDeadline = 2;
        config.targetJokers =
            std::string("Perkeo") + fieldSeparator
            + "Invisible Joker" + fieldSeparator
            + "Invisible Joker";
        config.locations =
            std::string("soul_pack") + fieldSeparator
            + "soul_pack" + fieldSeparator
            + "ante_2";
        config.deck = "Plasma Deck";
        return config;
    }
    if (name == "opening-heavy") {
        config.tag = "Charm Tag";
        config.souls = 1;
        config.targetJokers =
            negativeJoker("Perkeo") + fieldSeparator
            + negativeJoker("Blueprint") + fieldSeparator
            + negativeJoker("Invisible Joker") + fieldSeparator
            + negativeJoker("Brainstorm") + fieldSeparator
            + negativeJoker("Baron");
        config.locations =
            std::string("soul_pack") + fieldSeparator
            + "by_ante_2" + fieldSeparator
            + "by_ante_4" + fieldSeparator
            + "by_ante_6" + fieldSeparator
            + "by_ante_8";
        return config;
    }
    if (name == "user-deadline") {
        config.tag = "Charm Tag";
        config.souls = 1;
        config.observatory = true;
        config.observatoryDeadline = 5;
        config.targetJokers =
            std::string("Perkeo") + fieldSeparator
            + negativeJoker("Invisible Joker") + fieldSeparator
            + negativeJoker("Blueprint") + fieldSeparator
            + negativeJoker("Brainstorm") + fieldSeparator
            + negativeJoker("Baron");
        config.locations =
            std::string("soul_pack") + fieldSeparator
            + "by_ante_2" + fieldSeparator
            + "by_ante_4" + fieldSeparator
            + "by_ante_6" + fieldSeparator
            + "by_ante_8";
        return config;
    }
    if (name == "four-souls") {
        config.tag = "Charm Tag";
        config.souls = 4;
        return config;
    }
    if (name == "canio") {
        config.tag = "Charm Tag";
        config.souls = 1;
        config.targetJokers =
            negativeJoker("Canio") + fieldSeparator
            + negativeJoker("Invisible Joker") + fieldSeparator
            + negativeJoker("Blueprint") + fieldSeparator
            + negativeJoker("Brainstorm") + fieldSeparator
            + negativeJoker("Baron");
        config.locations =
            std::string("soul_pack") + fieldSeparator
            + "by_ante_2" + fieldSeparator
            + "by_ante_4" + fieldSeparator
            + "by_ante_6" + fieldSeparator
            + "by_ante_8";
        return config;
    }
    if (name == "negative-blueprint") {
        config.customFilter = "Negative Blueprint";
        config.targetJokers =
            negativeJoker("Invisible Joker") + fieldSeparator
            + negativeJoker("Brainstorm") + fieldSeparator
            + negativeJoker("Baron");
        config.locations =
            std::string("by_ante_4") + fieldSeparator
            + "by_ante_6" + fieldSeparator
            + "by_ante_8";
        return config;
    }
    if (name == "negative-blueprint-only") {
        config.customFilter = "Negative Blueprint";
        return config;
    }
    if (name == "timeline-any" || name == "timeline-negative") {
        const bool negative = name == "timeline-negative";
        const auto target = [negative](const char* joker) {
            return negative ? negativeJoker(joker) : std::string(joker);
        };
        config.targetJokers =
            target("Blueprint") + fieldSeparator
            + target("Invisible Joker") + fieldSeparator
            + target("Brainstorm") + fieldSeparator
            + target("Baron") + fieldSeparator
            + target("DNA");
        config.locations =
            std::string("by_ante_8") + fieldSeparator
            + "by_ante_8" + fieldSeparator
            + "by_ante_8" + fieldSeparator
            + "by_ante_8" + fieldSeparator
            + "by_ante_8";
        return config;
    }
    if (name == "timeline-invisible-duplicates"
        || name == "timeline-eternal-duplicates"
        || name == "timeline-eternal-negative-duplicates") {
        const bool invisible = name == "timeline-invisible-duplicates";
        const bool negative =
            name == "timeline-eternal-negative-duplicates";
        const char* joker = invisible
            ? "Invisible Joker"
            : "Reserved Parking";
        const std::string target = negative
            ? negativeJoker(joker)
            : std::string(joker);
        config.targetJokers =
            target + fieldSeparator + target + fieldSeparator
            + target + fieldSeparator + target + fieldSeparator + target;
        config.locations =
            std::string("by_ante_2") + fieldSeparator
            + "by_ante_4" + fieldSeparator
            + "by_ante_6" + fieldSeparator
            + "by_ante_8" + fieldSeparator
            + "by_ante_8";
        return config;
    }
    throw std::runtime_error("Unknown benchmark case: " + name);
}

} // namespace

int main(int argc, char** argv) {
    try {
        if (argc == 4 && std::string(argv[2]) == "estimate") {
            const std::string caseName(argv[1]);
            const int budgetMs = std::stoi(argv[3]);
            const BenchmarkConfiguration config = configurationFor(caseName);
            const auto started = std::chrono::steady_clock::now();
            const std::string result = takeResult(brainstorm_estimate_v3(
                config.voucher.c_str(), config.pack.c_str(), config.tag.c_str(),
                config.souls, config.observatory,
                config.observatoryDeadline, config.perkeo, config.copymoney,
                config.retcon, config.bean, config.burglar,
                config.customFilter.c_str(), config.targetRank.c_str(),
                config.targetSuit.c_str(), config.specificRankMin,
                config.anyRankMin, config.targetJokers.c_str(),
                config.deck.c_str(), config.locations.c_str(), budgetMs,
                config.stakeLevel));
            const auto finished = std::chrono::steady_clock::now();
            const double elapsedSeconds =
                std::chrono::duration<double>(finished - started).count();
            std::cout << std::fixed << std::setprecision(6)
                      << "case=" << caseName
                      << " estimate_budget_ms=" << budgetMs
                      << " elapsed_seconds=" << elapsedSeconds
                      << " result=" << result << '\n';
            return EXIT_SUCCESS;
        }

        if (argc < 4 || argc > 5) {
            std::cerr
                << "usage: benchmark_brainstorm_v6 <case> <threads> <seeds> "
                   "[start-seed]\n"
                   "   or: benchmark_brainstorm_v6 <case> estimate "
                   "<budget-ms>\n";
            return EXIT_FAILURE;
        }

        const std::string caseName(argv[1]);
        const int threads = std::stoi(argv[2]);
        const long long seedLimit = std::stoll(argv[3]);
        const std::string startSeed = argc == 5 ? argv[4] : "11111111";
        const BenchmarkConfiguration config = configurationFor(caseName);

        setEnvironment("BRAINSTORM_THREADS", std::to_string(threads));
        setEnvironment("BRAINSTORM_SEARCH_LIMIT", std::to_string(seedLimit));
        setEnvironment("BRAINSTORM_PRINT_DELAY", "0");
        // Keep ordinary timings instrumentation-free, while allowing an
        // explicitly requested diagnostic profile to reach the DLL.
        if (std::getenv("BRAINSTORM_PROFILE") == nullptr) {
            setEnvironment("BRAINSTORM_PROFILE", "0");
        }

        const auto started = std::chrono::steady_clock::now();
        const std::string result = takeResult(brainstorm_v7(
            startSeed.c_str(), config.voucher.c_str(), config.pack.c_str(),
            config.tag.c_str(), config.souls, config.observatory,
            config.observatoryDeadline, config.perkeo, config.copymoney,
            config.retcon, config.bean, config.burglar,
            config.customFilter.c_str(), config.targetRank.c_str(),
            config.targetSuit.c_str(), config.specificRankMin,
            config.anyRankMin, config.targetJokers.c_str(),
            config.deck.c_str(), config.locations.c_str(),
            config.stakeLevel));
        const auto finished = std::chrono::steady_clock::now();
        const double elapsedSeconds =
            std::chrono::duration<double>(finished - started).count();
        const double nominalSeedsPerSecond = elapsedSeconds > 0.0
            ? static_cast<double>(seedLimit) / elapsedSeconds
            : 0.0;

        std::cout << std::fixed << std::setprecision(6)
                  << "case=" << caseName
                  << " threads=" << threads
                  << " limit=" << seedLimit
                  << " elapsed_seconds=" << elapsedSeconds
                  << " nominal_seeds_per_second=" << nominalSeedsPerSecond
                  << " result=" << (result.empty() ? "<none>" : result)
                  << '\n';
        return EXIT_SUCCESS;
    } catch (const std::exception& error) {
        std::cerr << "benchmark failed: " << error.what() << '\n';
        return EXIT_FAILURE;
    }
}
