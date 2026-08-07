#include "immolate.hpp"
#include "seed.hpp"

#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>

namespace {

void setEnvironmentValue(const char* name, const std::string& value) {
#ifdef _WIN32
    _putenv_s(name, value.c_str());
#else
    setenv(name, value.c_str(), 1);
#endif
}

std::uint64_t readFirstId(const std::filesystem::path& path) {
    std::ifstream stream(path, std::ios::binary);
    if (!stream) {
        throw std::runtime_error("could not open packaged child index");
    }
    std::uint64_t result = 0;
    for (int byte = 0; byte < 8; ++byte) {
        const int value = stream.get();
        if (value == std::char_traits<char>::eof()) {
            throw std::runtime_error("packaged child index is empty");
        }
        result |= static_cast<std::uint64_t>(
            static_cast<unsigned char>(value)) << (byte * 8);
    }
    return result;
}

void writePriorityOnlyDecoy(const std::filesystem::path& path) {
    std::ofstream stream(path, std::ios::binary | std::ios::trunc);
    for (int byte = 0; byte < 8; ++byte) {
        stream.put(0);
    }
}

std::string takeResult(const char* raw) {
    if (raw == nullptr) {
        return "<null>";
    }
    const std::string result(raw);
    free_result(raw);
    return result;
}

} // namespace

int main(int argc, char** argv) {
    try {
        if (argc != 2) {
            std::cerr << "expected one route-test mode\n";
            return 1;
        }
        const std::string mode(argv[1]);
        const std::filesystem::path childAsset =
            std::filesystem::current_path()
            / "charm_perkeo_mega_naneinf_plasma_gold_v1.ids";
        const std::uint64_t knownId = readFirstId(childAsset);
        const std::string knownSeed =
            Seed(static_cast<long long>(knownId)).tostring();

        const std::filesystem::path fixture =
            std::filesystem::temp_directory_path()
            / ("brainstorm_mega_route_" + mode + ".ids");
        std::error_code ignored;
        std::filesystem::remove(fixture, ignored);
        const bool packagedScopeCase = mode == "later_deadline"
            || mode == "perkeo_later"
            || mode == "white_stake"
            || mode == "non_plasma_deck";
        if (mode == "packaged" || packagedScopeCase) {
            setEnvironmentValue("BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX", "");
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX", "");
        } else if (mode == "child_missing") {
            setEnvironmentValue("BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX", "");
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX", fixture.string());
        } else if (mode == "missing") {
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX", fixture.string());
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX", fixture.string());
        } else if (mode == "disabled") {
            setEnvironmentValue("BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX", "0");
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX", "0");
        } else if (mode == "corrupt") {
            std::ofstream stream(
                fixture, std::ios::binary | std::ios::trunc);
            stream.write("bad", 3);
            stream.close();
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX", fixture.string());
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX", fixture.string());
        } else if (mode == "priority_only") {
            writePriorityOnlyDecoy(fixture);
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX", fixture.string());
            setEnvironmentValue(
                "BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX", fixture.string());
        } else {
            std::cerr << "unknown route-test mode: " << mode << '\n';
            return 1;
        }

        setEnvironmentValue("BRAINSTORM_THREADS", "8");
        setEnvironmentValue("BRAINSTORM_SEARCH_LIMIT", "1");
        setEnvironmentValue("BRAINSTORM_PRINT_DELAY", "0");
        setEnvironmentValue("BRAINSTORM_ANCHOR_PRIORITY", "1");

        constexpr char separator = 0x1f;
        const std::string jokers = std::string("Perkeo") + separator
            + "Blueprint" + separator + "Brainstorm" + separator
            + "Baron" + separator + "Mime";
        std::string locations = std::string("soul_pack") + separator
            + "by_ante_4" + separator + "by_ante_4" + separator
            + "by_ante_8" + separator + "by_ante_8";
        std::string deck = "Plasma Deck";
        int stakeLevel = 8;
        bool expectKnownSeed = true;
        std::string expectedIndex;
        if (mode == "packaged") {
            expectedIndex =
                "index_name=Charm/Perkeo/Mega five-Joker Plasma/Gold";
        } else if (mode == "child_missing" || mode == "later_deadline") {
            // A later deadline broadens the five-Joker child population, but
            // the exact opening-pack parent remains a safe complete superset.
            expectedIndex = "index_name=Charm/Perkeo/Mega Spectral";
            if (mode == "later_deadline") {
                locations = std::string("soul_pack") + separator
                    + "by_ante_6" + separator + "by_ante_4" + separator
                    + "by_ante_8" + separator + "by_ante_8";
            }
        } else if (mode == "perkeo_later") {
            // Requiring Perkeo only by a later ante does not imply that the
            // opening Soul contains Perkeo, so neither index is admissible.
            locations = std::string("by_ante_2") + separator
                + "by_ante_4" + separator + "by_ante_4" + separator
                + "by_ante_8" + separator + "by_ante_8";
            expectKnownSeed = false;
        } else if (mode == "white_stake") {
            stakeLevel = 1;
            expectKnownSeed = false;
        } else if (mode == "non_plasma_deck") {
            deck = "Red Deck";
            expectKnownSeed = false;
        }

        std::string result;
        if (expectKnownSeed) {
            result = takeResult(brainstorm_v7(
                knownSeed.c_str(), "", "Mega Spectral Pack", "Charm Tag", 1,
                false, 0, false, false, false, false, false, "No Filter",
                "King", "Any Suit", 0, 0, jokers.c_str(), deck.c_str(),
                locations.c_str(), stakeLevel));
        }
        const std::string estimate = takeResult(brainstorm_estimate_v3(
            "", "Mega Spectral Pack", "Charm Tag", 1, false, 0,
            false, false, false, false, false, "No Filter", "King",
            "Any Suit", 0, 0, jokers.c_str(), deck.c_str(),
            locations.c_str(), 25, stakeLevel));
        std::filesystem::remove(fixture, ignored);
        if (expectKnownSeed && result != knownSeed) {
            std::cerr << mode << " returned '" << result << "' instead of '"
                      << knownSeed << "' for indexed ID " << knownId << '\n';
            return 1;
        }
        if ((!expectedIndex.empty()
                && estimate.find(expectedIndex) == std::string::npos)
            || (expectedIndex.empty()
                && estimate.find("index_name=") != std::string::npos)) {
            std::cerr << mode << " used an unexpected estimate route: "
                      << estimate << '\n';
            return 1;
        }
        if (expectKnownSeed) {
            std::cout << mode << " route returned authoritative seed "
                      << knownSeed << " (ID " << knownId << ")\n";
        } else {
            std::cout << mode
                      << " correctly rejected the packaged mega indexes\n";
        }
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "mega-index route regression failed: "
                  << error.what() << '\n';
        return 2;
    }
}
