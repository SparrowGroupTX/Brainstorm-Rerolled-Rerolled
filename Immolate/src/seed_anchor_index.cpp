#include "seed_anchor_index.hpp"

#include "seed.hpp"

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <string>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace {

// Each index has a separate bounded allowance. The reusable Perkeo + Mega
// parent is expected to be roughly 11 MiB, while the older opening-pair index
// is under 2 MiB. Keeping these bounds per asset prevents a bad override from
// causing an unbounded resident allocation.
constexpr std::uintmax_t maximumSmallIndexBytes =
    8ull * 1024ull * 1024ull;
constexpr std::uintmax_t maximumPerkeoMegaIndexBytes =
    32ull * 1024ull * 1024ull;

// Filled from the independently verified full-domain builder output before a
// release is packaged. A zero pair keeps a structurally valid development
// fixture in priority-only mode, with the exhaustive fallback retained.
constexpr std::size_t expectedPairRecordCount = 209798;
constexpr std::uint64_t expectedPairFnv1a64 = 0x276e186a7fb8c54dull;
constexpr std::size_t expectedAnteTwoRecordCount = 2145;
constexpr std::uint64_t expectedAnteTwoFnv1a64 = 0xd3947298245256a8ull;
// Frozen identities from the independently verified v2.10 full-domain build.
constexpr std::size_t expectedPerkeoMegaRecordCount = 1439049;
constexpr std::uint64_t expectedPerkeoMegaFnv1a64 =
    0xe0bf84e23d4f2856ull;
constexpr std::size_t expectedPerkeoMegaNaneinfRecordCount = 70;
constexpr std::uint64_t expectedPerkeoMegaNaneinfFnv1a64 =
    0x200697665262e061ull;

struct LoadedAnchorIndex {
  std::vector<std::uint64_t> ids;
  bool complete = false;
};

std::filesystem::path moduleDirectory() {
#if defined(_WIN32)
  MEMORY_BASIC_INFORMATION information{};
  const auto address = reinterpret_cast<const void*>(
      &perkeoInvisibleAnchorCandidateIds);
  if (VirtualQuery(address, &information, sizeof(information)) != 0) {
    std::wstring buffer(32768, L'\0');
    const DWORD length = GetModuleFileNameW(
        static_cast<HMODULE>(information.AllocationBase),
        buffer.data(), static_cast<DWORD>(buffer.size()));
    if (length > 0 && length < buffer.size()) {
      buffer.resize(length);
      return std::filesystem::path(buffer).parent_path();
    }
  }
#else
  Dl_info information{};
  if (dladdr(
          reinterpret_cast<const void*>(
              &perkeoInvisibleAnchorCandidateIds),
          &information) != 0
      && information.dli_fname != nullptr) {
    return std::filesystem::path(information.dli_fname).parent_path();
  }
#endif
  std::error_code error;
  const std::filesystem::path current = std::filesystem::current_path(error);
  return error ? std::filesystem::path{} : current;
}

std::filesystem::path configuredIndexPath(
    const char* environmentName, const char* fileName) {
  const char* overridePath = std::getenv(environmentName);
  if (overridePath != nullptr && overridePath[0] != '\0') {
    if (overridePath[0] == '0' && overridePath[1] == '\0') {
      return {};
    }
    return std::filesystem::path(overridePath);
  }
  const std::filesystem::path directory = moduleDirectory();
  return directory.empty() ? std::filesystem::path{}
                           : directory / fileName;
}

std::uint64_t fnv1a64(const std::vector<unsigned char>& bytes) {
  std::uint64_t result = 14695981039346656037ull;
  for (unsigned char byte : bytes) {
    result ^= static_cast<std::uint64_t>(byte);
    result *= 1099511628211ull;
  }
  return result;
}

LoadedAnchorIndex loadIndex(
    const char* environmentName, const char* fileName,
    const char* description, std::size_t expectedRecordCount,
    std::uint64_t expectedFingerprint, std::uintmax_t maximumBytes) {
  const std::filesystem::path path =
      configuredIndexPath(environmentName, fileName);
  if (path.empty()) {
    return LoadedAnchorIndex{};
  }

  std::ifstream stream(path, std::ios::binary | std::ios::ate);
  if (!stream) {
    return LoadedAnchorIndex{};
  }
  const std::streamoff signedSize = stream.tellg();
  if (signedSize <= 0) {
    return LoadedAnchorIndex{};
  }
  const std::uintmax_t byteCount = static_cast<std::uintmax_t>(signedSize);
  if (byteCount > maximumBytes || byteCount % sizeof(std::uint64_t) != 0) {
    std::cerr << "Ignoring invalid Brainstorm anchor index size: "
              << path.string() << std::endl;
    return LoadedAnchorIndex{};
  }

  std::vector<unsigned char> bytes(static_cast<std::size_t>(byteCount));
  stream.seekg(0, std::ios::beg);
  stream.read(
      reinterpret_cast<char*>(bytes.data()),
      static_cast<std::streamsize>(bytes.size()));
  if (!stream) {
    std::cerr << "Ignoring unreadable Brainstorm anchor index: "
              << path.string() << std::endl;
    return LoadedAnchorIndex{};
  }

  LoadedAnchorIndex result;
  result.ids.resize(bytes.size() / sizeof(std::uint64_t));
  for (std::size_t index = 0; index < result.ids.size(); ++index) {
    std::uint64_t value = 0;
    for (int byte = 0; byte < 8; ++byte) {
      value |= static_cast<std::uint64_t>(
                   bytes[index * 8 + static_cast<std::size_t>(byte)])
               << (byte * 8);
    }
    if (value >= static_cast<std::uint64_t>(SEED_DOMAIN_SIZE)
        || (index > 0 && value <= result.ids[index - 1])) {
      std::cerr << "Ignoring unsorted or out-of-range Brainstorm anchor index: "
                << path.string() << std::endl;
      return LoadedAnchorIndex{};
    }
    result.ids[index] = value;
  }

  result.complete = expectedRecordCount > 0
      && expectedFingerprint != 0
      && result.ids.size() == expectedRecordCount
      && fnv1a64(bytes) == expectedFingerprint;
  std::cout << "Loaded Brainstorm " << description << " anchor index: "
            << result.ids.size() << " candidates ("
            << (result.complete ? "complete" : "priority-only") << ")"
            << std::endl;
  return result;
}

const LoadedAnchorIndex& pairIndex() {
  static const LoadedAnchorIndex index = loadIndex(
      "BRAINSTORM_ANCHOR_INDEX",
      "perkeo_invisible_anchor_v1.ids",
      "Perkeo/Invisible", expectedPairRecordCount,
      expectedPairFnv1a64, maximumSmallIndexBytes);
  return index;
}

const LoadedAnchorIndex& anteTwoIndex() {
  static const LoadedAnchorIndex index = loadIndex(
      "BRAINSTORM_DERIVED_ANCHOR_INDEX",
      "perkeo_invisible_ante2_invisible_anchor_v1.ids",
      "Perkeo/Invisible/Ante-2 Invisible", expectedAnteTwoRecordCount,
      expectedAnteTwoFnv1a64, maximumSmallIndexBytes);
  return index;
}

const LoadedAnchorIndex& perkeoMegaIndex() {
  static const LoadedAnchorIndex index = loadIndex(
      "BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX",
      "charm_perkeo_mega_spectral_anchor_v1.ids",
      "Charm/Perkeo/Mega Spectral", expectedPerkeoMegaRecordCount,
      expectedPerkeoMegaFnv1a64, maximumPerkeoMegaIndexBytes);
  return index;
}

const LoadedAnchorIndex& perkeoMegaNaneinfIndex() {
  static const LoadedAnchorIndex index = loadIndex(
      "BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX",
      "charm_perkeo_mega_naneinf_plasma_gold_v1.ids",
      "Charm/Perkeo/Mega five-Joker Plasma/Gold",
      expectedPerkeoMegaNaneinfRecordCount,
      expectedPerkeoMegaNaneinfFnv1a64, maximumSmallIndexBytes);
  return index;
}

} // namespace

const std::vector<std::uint64_t>& perkeoInvisibleAnchorCandidateIds() {
  return pairIndex().ids;
}

bool perkeoInvisibleAnchorIndexComplete() {
  return pairIndex().complete;
}

const std::vector<std::uint64_t>&
perkeoInvisibleAnteTwoInvisibleAnchorCandidateIds() {
  return anteTwoIndex().ids;
}

bool perkeoInvisibleAnteTwoInvisibleAnchorIndexComplete() {
  return anteTwoIndex().complete;
}

const std::vector<std::uint64_t>&
charmPerkeoMegaSpectralAnchorCandidateIds() {
  return perkeoMegaIndex().ids;
}

bool charmPerkeoMegaSpectralAnchorIndexComplete() {
  return perkeoMegaIndex().complete;
}

const std::vector<std::uint64_t>&
charmPerkeoMegaNaneinfPlasmaGoldCandidateIds() {
  return perkeoMegaNaneinfIndex().ids;
}

bool charmPerkeoMegaNaneinfPlasmaGoldIndexComplete() {
  return perkeoMegaNaneinfIndex().complete;
}
