#include "seed_anchor_index.hpp"
#include "seed.hpp"

#include <cstdint>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <utility>
#include <vector>

namespace {

// Frozen identities from the independently verified v2.10 full-domain build.
constexpr std::size_t expectedPerkeoMegaRecords = 1439049;
constexpr std::size_t expectedPerkeoMegaNaneinfRecords = 70;
constexpr const char* expectedPerkeoMegaFnv = "e0bf84e23d4f2856";
constexpr const char* expectedPerkeoMegaNaneinfFnv = "200697665262e061";

using IdLoader = const std::vector<std::uint64_t>& (*)();
using CompleteLoader = bool (*)();

struct LoaderCase {
    const char* environment;
    IdLoader ids;
    CompleteLoader complete;
    std::string mode;
};

void setEnvironmentValue(const char* name, const std::string& value) {
#ifdef _WIN32
    _putenv_s(name, value.c_str());
#else
    setenv(name, value.c_str(), 1);
#endif
}

void writeIds(const std::filesystem::path& path,
              const std::vector<std::uint64_t>& ids) {
    std::ofstream stream(path, std::ios::binary | std::ios::trunc);
    for (std::uint64_t id : ids) {
        for (int byte = 0; byte < 8; ++byte) {
            stream.put(static_cast<char>((id >> (byte * 8)) & 0xffu));
        }
    }
}

LoaderCase selectLoader(std::string mode) {
    constexpr const char* childPrefix = "perkeo_mega_naneinf_";
    constexpr const char* parentPrefix = "perkeo_mega_";
    if (mode.rfind(childPrefix, 0) == 0) {
        return LoaderCase{
            "BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX",
            charmPerkeoMegaNaneinfPlasmaGoldCandidateIds,
            charmPerkeoMegaNaneinfPlasmaGoldIndexComplete,
            mode.substr(std::char_traits<char>::length(childPrefix))};
    }
    if (mode.rfind(parentPrefix, 0) == 0) {
        return LoaderCase{
            "BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX",
            charmPerkeoMegaSpectralAnchorCandidateIds,
            charmPerkeoMegaSpectralAnchorIndexComplete,
            mode.substr(std::char_traits<char>::length(parentPrefix))};
    }
    return LoaderCase{
        "BRAINSTORM_ANCHOR_INDEX",
        perkeoInvisibleAnchorCandidateIds,
        perkeoInvisibleAnchorIndexComplete,
        std::move(mode)};
}

bool packagedManifestMatches(const char* fileName, std::size_t records,
                             const char* fnv) {
    std::ifstream stream(std::filesystem::current_path() / fileName);
    if (!stream) {
        return false;
    }
    const std::string manifest{
        std::istreambuf_iterator<char>(stream),
        std::istreambuf_iterator<char>()};
    return manifest.find(
               "\"record_count\": " + std::to_string(records))
            != std::string::npos
        && manifest.find(
               std::string("\"fnv1a64\": \"") + fnv + "\"")
            != std::string::npos
        && manifest.find("\"complete_domain_coverage\": true")
            != std::string::npos;
}

} // namespace

int main(int argc, char** argv) {
    if (argc != 2) {
        std::cerr << "expected one loader-test mode\n";
        return 1;
    }

    const std::string requestedMode(argv[1]);
    if (requestedMode == "perkeo_mega_packaged") {
        setEnvironmentValue("BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX", "");
        const auto& ids = charmPerkeoMegaSpectralAnchorCandidateIds();
        return charmPerkeoMegaSpectralAnchorIndexComplete()
                && ids.size() == expectedPerkeoMegaRecords
                && packagedManifestMatches(
                    "charm_perkeo_mega_spectral_anchor_v1.manifest.json",
                    expectedPerkeoMegaRecords, expectedPerkeoMegaFnv)
            ? 0
            : 1;
    }
    if (requestedMode == "perkeo_mega_naneinf_packaged") {
        setEnvironmentValue("BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX", "");
        const auto& ids =
            charmPerkeoMegaNaneinfPlasmaGoldCandidateIds();
        return charmPerkeoMegaNaneinfPlasmaGoldIndexComplete()
                && ids.size() == expectedPerkeoMegaNaneinfRecords
                && packagedManifestMatches(
                    "charm_perkeo_mega_naneinf_plasma_gold_v1.manifest.json",
                    expectedPerkeoMegaNaneinfRecords,
                    expectedPerkeoMegaNaneinfFnv)
            ? 0
            : 1;
    }
    const LoaderCase loader = selectLoader(requestedMode);
    const std::string& mode = loader.mode;
    if (mode == "packaged") {
        setEnvironmentValue("BRAINSTORM_ANCHOR_INDEX", "");
        const auto& ids = perkeoInvisibleAnchorCandidateIds();
        return perkeoInvisibleAnchorIndexComplete() && ids.size() == 209798
            ? 0
            : 1;
    }
    if (mode == "derived_packaged") {
        setEnvironmentValue("BRAINSTORM_DERIVED_ANCHOR_INDEX", "");
        const auto& ids =
            perkeoInvisibleAnteTwoInvisibleAnchorCandidateIds();
        return perkeoInvisibleAnteTwoInvisibleAnchorIndexComplete()
                && ids.size() == 2145
            ? 0
            : 1;
    }

    const std::filesystem::path path =
        std::filesystem::temp_directory_path()
        / ("brainstorm_anchor_index_" + requestedMode + ".ids");
    std::error_code ignored;
    std::filesystem::remove(path, ignored);

    std::vector<std::uint64_t> expected;
    if (mode == "valid") {
        expected = {
            0,
            35,
            static_cast<std::uint64_t>(SEED_DOMAIN_SIZE - 1)};
        writeIds(path, expected);
    } else if (mode == "unsorted") {
        writeIds(path, {10, 9});
    } else if (mode == "duplicate") {
        writeIds(path, {10, 10});
    } else if (mode == "out_of_range") {
        writeIds(path, {static_cast<std::uint64_t>(SEED_DOMAIN_SIZE)});
    } else if (mode == "truncated") {
        std::ofstream stream(path, std::ios::binary | std::ios::trunc);
        stream.write("bad", 3);
    } else if (mode == "empty") {
        std::ofstream stream(path, std::ios::binary | std::ios::trunc);
    } else if (mode != "missing" && mode != "disabled") {
        std::cerr << "unknown loader-test mode: " << mode << '\n';
        return 1;
    }

    setEnvironmentValue(
        loader.environment,
        mode == "disabled" ? "0" : path.string());
    const auto& actual = loader.ids();
    const bool complete = loader.complete();
    std::filesystem::remove(path, ignored);
    if (actual == expected && !complete) {
        return 0;
    }

    std::cerr << mode << " loader case returned " << actual.size()
              << " IDs instead of " << expected.size()
              << " (complete=" << complete << ")\n";
    return 1;
}
