// Offline, resumable full-domain exact candidate-index builder.
// Including the shared implementation exposes the same internal configured
// filter and batch-prefilter composition used by production search without
// adding or changing a production API.
#include "../src/immolate.cpp"

#include <windows.h>
#include <bcrypt.h>
#include <process.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <ctime>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <mutex>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <thread>
#include <vector>

namespace fs = std::filesystem;

namespace {

using Digest = std::array<std::uint8_t, 32>;

constexpr std::uint64_t kDomainBegin = 0;
constexpr std::uint64_t kDomainEnd =
    static_cast<std::uint64_t>(SEED_DOMAIN_SIZE);
constexpr std::uint64_t kShardSize = std::uint64_t{1} << 30;
constexpr std::uint64_t kScanBlock = std::uint64_t{1} << 20;
constexpr std::size_t kShardHeaderBytes = 128;
constexpr std::size_t kShardFooterBytes = 64;
constexpr std::uint32_t kShardVersion = 1;
constexpr std::string_view kPayloadName =
    "charm_perkeo_mega_spectral_anchor_v1.ids";
constexpr std::string_view kManifestName =
    "charm_perkeo_mega_spectral_anchor_v1.manifest.json";
constexpr std::string_view kDerivedPayloadName =
    "charm_perkeo_mega_naneinf_plasma_gold_v1.ids";
constexpr std::string_view kDerivedManifestName =
    "charm_perkeo_mega_naneinf_plasma_gold_v1.manifest.json";
constexpr std::string_view kManifestMagic =
    "BRAINSTORM_CHARM_PERKEO_MEGA_SPECTRAL_ANCHOR";
constexpr std::string_view kDerivedManifestMagic =
    "BRAINSTORM_CHARM_PERKEO_MEGA_NANEINF_PLASMA_GOLD_DERIVED";
constexpr std::string_view kPredicate =
    "brainstorm.anchor.charm_perkeo_mega_spectral.v1"
    "|domain=[0,2318107019761)"
    "|deck=Plasma Deck|stake=Gold Stake|profile=complete|showman=false"
    "|ante1_tag=Charm Tag lock-aware"
    "|souls=minimum 1 duplicate-souls=false"
    "|target1=Perkeo source Soul any-edition any-sticker"
    "|first_searched_pack=Mega Spectral Pack";
constexpr std::string_view kPublishedPredicate =
    kPredicate;
constexpr std::string_view kPublishedDeckScope =
    "Plasma Deck (parent build provenance; runtime revalidates every hit)";
constexpr std::string_view kDerivedPredicate =
    "brainstorm.anchor.charm_perkeo_mega_naneinf_plasma_gold.v1"
    "|base=brainstorm.anchor.charm_perkeo_mega_spectral.v1"
    "|deck=Plasma Deck|stake=Gold Stake|no-rerolls=true"
    "|target2=Blueprint by_ante_4 any-edition any-sticker"
    "|target3=Brainstorm by_ante_4 any-edition any-sticker"
    "|target4=Baron by_ante_8 any-edition any-sticker"
    "|target5=Mime by_ante_8 any-edition any-sticker";

constexpr std::array<std::uint8_t, 8> kShardMagic = {
    'B', 'S', 'R', 'S', 'H', 'D', '1', 0};
constexpr std::array<std::uint8_t, 16> kShardDoneMagic = {
    'B', 'S', 'R', 'S', 'H', 'A', 'R', 'D', '-', 'D', 'O', 'N', 'E', '1', 0, 0};
constexpr std::array<std::uint64_t, 0> kKnownAnchorHits{};

struct ShardInfo {
  std::uint64_t index = 0;
  std::uint64_t begin = 0;
  std::uint64_t end = 0;
  std::uint64_t openingCandidates = 0;
  std::vector<std::uint64_t> ids;
  Digest payloadDigest{};
};

[[noreturn]] void fail(const std::string &message) {
  throw std::runtime_error(message);
}

std::string windowsError(const char *operation) {
  return std::string(operation) + " failed with Windows error "
      + std::to_string(GetLastError());
}

class Sha256Provider {
public:
  Sha256Provider() {
    const NTSTATUS status = BCryptOpenAlgorithmProvider(
        &algorithm_, BCRYPT_SHA256_ALGORITHM, nullptr, 0);
    if (status < 0) {
      fail("BCryptOpenAlgorithmProvider(SHA-256) failed: "
           + std::to_string(status));
    }
  }

  ~Sha256Provider() {
    if (algorithm_ != nullptr) {
      BCryptCloseAlgorithmProvider(algorithm_, 0);
    }
  }

  Digest hash(const std::uint8_t *data, std::size_t size) const {
    DWORD objectBytes = 0;
    DWORD returned = 0;
    NTSTATUS status = BCryptGetProperty(
        algorithm_, BCRYPT_OBJECT_LENGTH,
        reinterpret_cast<PUCHAR>(&objectBytes), sizeof(objectBytes),
        &returned, 0);
    if (status < 0) {
      fail("BCryptGetProperty failed: " + std::to_string(status));
    }
    std::vector<std::uint8_t> object(objectBytes);
    BCRYPT_HASH_HANDLE handle = nullptr;
    status = BCryptCreateHash(
        algorithm_, &handle, object.data(), objectBytes,
        nullptr, 0, 0);
    if (status < 0) {
      fail("BCryptCreateHash failed: " + std::to_string(status));
    }
    std::size_t offset = 0;
    while (offset < size) {
      const ULONG block = static_cast<ULONG>(std::min<std::size_t>(
          size - offset, std::numeric_limits<ULONG>::max()));
      status = BCryptHashData(
          handle, const_cast<PUCHAR>(data + offset), block, 0);
      if (status < 0) {
        BCryptDestroyHash(handle);
        fail("BCryptHashData failed: " + std::to_string(status));
      }
      offset += block;
    }
    Digest result{};
    status = BCryptFinishHash(
        handle, result.data(), static_cast<ULONG>(result.size()), 0);
    BCryptDestroyHash(handle);
    if (status < 0) {
      fail("BCryptFinishHash failed: " + std::to_string(status));
    }
    return result;
  }

  Digest hash(std::string_view value) const {
    return hash(reinterpret_cast<const std::uint8_t *>(value.data()),
                value.size());
  }

  Digest hash(const std::vector<std::uint8_t> &value) const {
    return hash(value.data(), value.size());
  }

private:
  BCRYPT_ALG_HANDLE algorithm_ = nullptr;
};

std::string hexDigest(const Digest &digest) {
  std::ostringstream output;
  output << std::hex << std::setfill('0');
  for (std::uint8_t byte : digest) {
    output << std::setw(2) << static_cast<unsigned>(byte);
  }
  return output.str();
}

std::uint64_t fnv1a64(const std::vector<std::uint8_t> &bytes) {
  std::uint64_t hash = 14695981039346656037ull;
  for (std::uint8_t byte : bytes) {
    hash ^= byte;
    hash *= 1099511628211ull;
  }
  return hash;
}

std::string hex64(std::uint64_t value) {
  std::ostringstream output;
  output << std::hex << std::nouppercase << std::setfill('0')
         << std::setw(16) << value;
  return output.str();
}

void appendLe32(std::vector<std::uint8_t> &output, std::uint32_t value) {
  for (int byte = 0; byte < 4; ++byte) {
    output.push_back(static_cast<std::uint8_t>(value >> (byte * 8)));
  }
}

void appendLe64(std::vector<std::uint8_t> &output, std::uint64_t value) {
  for (int byte = 0; byte < 8; ++byte) {
    output.push_back(static_cast<std::uint8_t>(value >> (byte * 8)));
  }
}

std::uint32_t readLe32(const std::uint8_t *input) {
  std::uint32_t value = 0;
  for (int byte = 0; byte < 4; ++byte) {
    value |= static_cast<std::uint32_t>(input[byte]) << (byte * 8);
  }
  return value;
}

std::uint64_t readLe64(const std::uint8_t *input) {
  std::uint64_t value = 0;
  for (int byte = 0; byte < 8; ++byte) {
    value |= static_cast<std::uint64_t>(input[byte]) << (byte * 8);
  }
  return value;
}

std::vector<std::uint8_t> encodeIds(
    const std::vector<std::uint64_t> &ids) {
  std::vector<std::uint8_t> bytes;
  bytes.reserve(ids.size() * sizeof(std::uint64_t));
  for (std::uint64_t id : ids) {
    appendLe64(bytes, id);
  }
  return bytes;
}

std::vector<std::uint8_t> readFile(const fs::path &path) {
  std::ifstream input(path, std::ios::binary | std::ios::ate);
  if (!input) {
    fail("cannot open " + path.string());
  }
  const std::streamoff end = input.tellg();
  if (end < 0) {
    fail("cannot determine size of " + path.string());
  }
  std::vector<std::uint8_t> bytes(static_cast<std::size_t>(end));
  input.seekg(0);
  if (!bytes.empty()) {
    input.read(reinterpret_cast<char *>(bytes.data()),
               static_cast<std::streamsize>(bytes.size()));
  }
  if (!input) {
    fail("cannot read " + path.string());
  }
  return bytes;
}

void flushFile(const fs::path &path) {
  HANDLE handle = CreateFileW(
      path.c_str(), GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ,
      nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (handle == INVALID_HANDLE_VALUE) {
    fail(windowsError("CreateFileW for flush"));
  }
  if (!FlushFileBuffers(handle)) {
    const std::string error = windowsError("FlushFileBuffers");
    CloseHandle(handle);
    fail(error);
  }
  CloseHandle(handle);
}

void atomicReplace(const fs::path &temporary, const fs::path &finalPath) {
  if (!MoveFileExW(
          temporary.c_str(), finalPath.c_str(),
          MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
    fail(windowsError("MoveFileExW"));
  }
}

void writeBytesAtomically(const fs::path &finalPath,
                          const std::vector<std::uint8_t> &bytes,
                          std::string_view suffix) {
  const fs::path temporary = finalPath.string() + ".tmp."
      + std::to_string(_getpid()) + "." + std::string(suffix);
  {
    std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
    if (!output) {
      fail("cannot create " + temporary.string());
    }
    if (!bytes.empty()) {
      output.write(reinterpret_cast<const char *>(bytes.data()),
                   static_cast<std::streamsize>(bytes.size()));
    }
    output.flush();
    if (!output) {
      fail("cannot write " + temporary.string());
    }
  }
  flushFile(temporary);
  atomicReplace(temporary, finalPath);
}

fs::path shardPath(const fs::path &root, std::uint64_t index) {
  std::ostringstream name;
  name << "shard-" << std::setw(4) << std::setfill('0') << index
       << ".complete";
  return root / "shards" / name.str();
}

Digest predicateDigest(const Sha256Provider &sha) {
  return sha.hash(kPredicate);
}

Digest publishedPredicateDigest(const Sha256Provider &sha) {
  return sha.hash(kPublishedPredicate);
}

std::vector<std::uint8_t> encodeShard(const ShardInfo &shard,
                                      const Digest &predicateSha,
                                      const Sha256Provider &sha) {
  const std::vector<std::uint8_t> payload = encodeIds(shard.ids);
  const Digest payloadSha = sha.hash(payload);
  std::vector<std::uint8_t> output;
  output.reserve(kShardHeaderBytes + payload.size() + kShardFooterBytes);
  output.insert(output.end(), kShardMagic.begin(), kShardMagic.end());
  appendLe32(output, kShardVersion);
  appendLe32(output, static_cast<std::uint32_t>(kShardHeaderBytes));
  appendLe64(output, shard.index);
  appendLe64(output, shard.begin);
  appendLe64(output, shard.end);
  appendLe64(output, shard.ids.size());
  appendLe64(output, shard.openingCandidates);
  output.insert(output.end(), predicateSha.begin(), predicateSha.end());
  output.insert(output.end(), payloadSha.begin(), payloadSha.end());
  output.resize(kShardHeaderBytes, 0);
  output.insert(output.end(), payload.begin(), payload.end());
  output.insert(output.end(), kShardDoneMagic.begin(), kShardDoneMagic.end());
  appendLe64(output, shard.ids.size());
  appendLe64(output, payload.size());
  output.insert(output.end(), payloadSha.begin(), payloadSha.end());
  if (output.size() != kShardHeaderBytes + payload.size()
                           + kShardFooterBytes) {
    fail("internal shard-size error");
  }
  return output;
}

ShardInfo decodeAndValidateShard(const fs::path &path,
                                 std::uint64_t expectedIndex,
                                 std::uint64_t expectedBegin,
                                 std::uint64_t expectedEnd,
                                 const Digest &predicateSha,
                                 const Sha256Provider &sha) {
  const std::vector<std::uint8_t> bytes = readFile(path);
  if (bytes.size() < kShardHeaderBytes + kShardFooterBytes
      || !std::equal(kShardMagic.begin(), kShardMagic.end(), bytes.begin())
      || readLe32(bytes.data() + 8) != kShardVersion
      || readLe32(bytes.data() + 12) != kShardHeaderBytes) {
    fail("invalid shard header: " + path.string());
  }
  ShardInfo result;
  result.index = readLe64(bytes.data() + 16);
  result.begin = readLe64(bytes.data() + 24);
  result.end = readLe64(bytes.data() + 32);
  const std::uint64_t count = readLe64(bytes.data() + 40);
  result.openingCandidates = readLe64(bytes.data() + 48);
  if (result.index != expectedIndex || result.begin != expectedBegin
      || result.end != expectedEnd
      || !std::equal(predicateSha.begin(), predicateSha.end(),
                     bytes.begin() + 56)) {
    fail("shard metadata mismatch: " + path.string());
  }
  if (count > (std::numeric_limits<std::size_t>::max()
               - kShardHeaderBytes - kShardFooterBytes) / 8
      || bytes.size() != kShardHeaderBytes
                              + static_cast<std::size_t>(count) * 8
                              + kShardFooterBytes) {
    fail("shard length mismatch: " + path.string());
  }
  const std::size_t footer = bytes.size() - kShardFooterBytes;
  if (!std::equal(kShardDoneMagic.begin(), kShardDoneMagic.end(),
                  bytes.begin() + static_cast<std::ptrdiff_t>(footer))
      || readLe64(bytes.data() + footer + 16) != count
      || readLe64(bytes.data() + footer + 24) != count * 8) {
    fail("invalid shard footer: " + path.string());
  }
  std::vector<std::uint8_t> payload(
      bytes.begin() + static_cast<std::ptrdiff_t>(kShardHeaderBytes),
      bytes.begin() + static_cast<std::ptrdiff_t>(footer));
  result.payloadDigest = sha.hash(payload);
  if (!std::equal(result.payloadDigest.begin(), result.payloadDigest.end(),
                  bytes.begin() + 88)
      || !std::equal(result.payloadDigest.begin(), result.payloadDigest.end(),
                     bytes.begin() + static_cast<std::ptrdiff_t>(footer + 32))) {
    fail("shard payload SHA-256 mismatch: " + path.string());
  }
  result.ids.reserve(static_cast<std::size_t>(count));
  for (std::uint64_t index = 0; index < count; ++index) {
    result.ids.push_back(readLe64(
        payload.data() + static_cast<std::size_t>(index) * 8));
  }
  if (!std::is_sorted(result.ids.begin(), result.ids.end())
      || std::adjacent_find(result.ids.begin(), result.ids.end())
             != result.ids.end()) {
    fail("shard IDs are not strictly increasing: " + path.string());
  }
  for (std::uint64_t id : result.ids) {
    if (id < result.begin || id >= result.end) {
      fail("out-of-range shard ID: " + path.string());
    }
  }
  return result;
}

bool configureAnchorPredicateFor(std::string_view deck, int stakeLevel) {
  const std::string targets = "Perkeo";
  const std::string locations = "soul_pack";
  return configureBrainstormSearch(
      "", "Mega Spectral Pack", "Charm Tag", 1, false, 0,
      false, false, false, false, false,
      "No Filter", "King", "Any Suit", 0, 0,
      targets, std::string(deck), locations, true, true, stakeLevel);
}

bool configureAnchorPredicate() {
  return configureAnchorPredicateFor("Plasma Deck", 8);
}

bool configureDerivedPredicate() {
  constexpr char separator = 0x1f;
  const std::string targets = std::string("Perkeo") + separator
      + "Blueprint" + separator + "Brainstorm" + separator
      + "Baron" + separator + "Mime";
  const std::string locations = std::string("soul_pack") + separator
      + "by_ante_4" + separator + "by_ante_4" + separator
      + "by_ante_8" + separator + "by_ante_8";
  return configureBrainstormSearch(
      "", "Mega Spectral Pack", "Charm Tag", 1, false, 0,
      false, false, false, false, false,
      "No Filter", "King", "Any Suit", 0, 0,
      targets, "Plasma Deck", locations, true, true, 8);
}

bool directAuthoritativeMembership(std::uint64_t id) {
  Seed seed(static_cast<long long>(id));
  Instance instance(seed);
  // Deliberately skip the opening pseudohash prefilter. The configured
  // simulator below regenerates the lock-aware tag and full pack, providing
  // an independent membership oracle for tests and final revalidation.
  return filterConfiguredAfterOpeningGate(instance) != 0;
}

bool filteredMembership(std::uint64_t id) {
  Seed seed(static_cast<long long>(id));
  if (!passesFastOpeningCharmSoulPrefilter(seed)) {
    return false;
  }
  return authoritativeConfiguredAfterOpeningSeedFilter(seed) != 0;
}

struct ScanCounters {
  std::atomic<std::uint64_t> seeds{0};
  std::atomic<std::uint64_t> opening{0};
  std::atomic<std::uint64_t> anchors{0};
  std::atomic<std::uint64_t> shards{0};
};

ShardInfo scanRangeWithContext(
    std::uint64_t index, std::uint64_t begin, std::uint64_t end,
    const SeedBatchPrefilter &prefilter, void *context,
    ScanCounters *counters = nullptr) {
  ShardInfo result;
  result.index = index;
  result.begin = begin;
  result.end = end;
  result.ids.reserve(static_cast<std::size_t>((end - begin) / 9000000 + 32));
  std::vector<std::uint32_t> offsets;
  for (std::uint64_t block = begin; block < end; block += kScanBlock) {
    const std::size_t count = static_cast<std::size_t>(
        std::min<std::uint64_t>(kScanBlock, end - block));
    prefilter.collect(context, static_cast<long long>(block), count, offsets);
    result.openingCandidates += offsets.size();
    for (std::uint32_t offset : offsets) {
      const std::uint64_t id = block + offset;
      Seed seed(static_cast<long long>(id));
      if (authoritativeConfiguredAfterOpeningSeedFilter(seed) != 0) {
        result.ids.push_back(id);
      }
    }
    if (counters != nullptr) {
      counters->seeds.fetch_add(count, std::memory_order_relaxed);
      counters->opening.fetch_add(offsets.size(), std::memory_order_relaxed);
    }
  }
  if (!std::is_sorted(result.ids.begin(), result.ids.end())) {
    fail("scan produced unsorted IDs");
  }
  if (counters != nullptr) {
    counters->anchors.fetch_add(result.ids.size(), std::memory_order_relaxed);
  }
  return result;
}

std::vector<std::uint64_t> scanOffsetsFiltered(
    std::uint64_t start, std::uint64_t count) {
  const SeedBatchPrefilter prefilter = openingCharmSoulBatchPrefilter();
  void *context = prefilter.createContext(prefilter.configuration);
  if (context == nullptr) fail("could not create opening context");
  std::vector<std::uint64_t> result;
  std::vector<std::uint32_t> offsets;
  for (std::uint64_t done = 0; done < count; done += kScanBlock) {
    const std::size_t blockCount = static_cast<std::size_t>(
        std::min<std::uint64_t>(kScanBlock, count - done));
    const std::uint64_t blockStart =
        (start + done) % kDomainEnd;
    prefilter.collect(
        context, static_cast<long long>(blockStart), blockCount, offsets);
    for (std::uint32_t offset : offsets) {
      const std::uint64_t id = (blockStart + offset) % kDomainEnd;
      Seed seed(static_cast<long long>(id));
      if (authoritativeConfiguredAfterOpeningSeedFilter(seed) != 0) {
        result.push_back(done + offset);
      }
    }
  }
  prefilter.destroyContext(context);
  return result;
}

std::vector<std::uint64_t> scanOffsetsDirect(
    std::uint64_t start, std::uint64_t count) {
  std::vector<std::uint64_t> result;
  for (std::uint64_t offset = 0; offset < count; ++offset) {
    const std::uint64_t id = (start + offset) % kDomainEnd;
    if (directAuthoritativeMembership(id)) {
      result.push_back(offset);
    }
  }
  return result;
}

void requireEqual(const std::vector<std::uint64_t> &left,
                  const std::vector<std::uint64_t> &right,
                  std::string_view label) {
  if (left != right) {
    fail(std::string(label) + " mismatch: left="
         + std::to_string(left.size()) + " right="
         + std::to_string(right.size()));
  }
}

void selftest(const fs::path &root, const Sha256Provider &sha) {
  if (!configureAnchorPredicate()) {
    fail("anchor configuration rejected");
  }
  std::cout << "selftest predicate_sha256="
            << hexDigest(predicateDigest(sha)) << '\n';

  const auto compareRange = [](std::uint64_t start, std::uint64_t count,
                               std::string_view label) {
    const auto filtered = scanOffsetsFiltered(start, count);
    const auto direct = scanOffsetsDirect(start, count);
    requireEqual(filtered, direct, label);
    std::cout << "selftest range=" << label << " start=" << start
              << " count=" << count << " matches=" << direct.size()
              << " exact\n";
  };
  compareRange(0, 16384, "short-seeds");
  compareRange(1250000, 32768, "mid-domain-sample");
  compareRange(kDomainEnd - 4096, 8192, "domain-wrap");

  // Exercise the rare pack predicate without running the slow independent
  // simulator for every raw seed. The batch route finds candidates first;
  // each emitted candidate is then checked by the independent route.
  constexpr std::uint64_t fixtureWindow = 1ull << 24;
  const std::vector<std::uint64_t> fixtureOffsets =
      scanOffsetsFiltered(0, fixtureWindow);
  if (fixtureOffsets.empty()) {
    fail("fixture window unexpectedly contains no parent anchors");
  }
  for (std::uint64_t id : fixtureOffsets) {
    if (!directAuthoritativeMembership(id) || !filteredMembership(id)) {
      fail("generated anchor fixture failed at ID " + std::to_string(id));
    }
  }
  std::cout << "selftest generated_fixtures=" << fixtureOffsets.size()
            << " window=" << fixtureWindow << " exact\n";

  constexpr std::uint64_t backendStart = 1000000000000ull + 19;
  constexpr std::size_t backendCount = 1u << 20;
  std::vector<std::uint32_t> scalar;
  std::vector<std::uint32_t> avx2;
  std::vector<std::uint32_t> avx512;
  collectOpeningCharmSoulCandidatesWithBackend(
      backendStart, backendCount, scalar, {1, 4},
      OpeningCharmSoulBackend::Scalar);
  collectOpeningCharmSoulCandidatesWithBackend(
      backendStart, backendCount, avx2, {1, 4},
      OpeningCharmSoulBackend::Avx2);
  collectOpeningCharmSoulCandidatesWithBackend(
      backendStart, backendCount, avx512, {1, 4},
      OpeningCharmSoulBackend::Avx512);
  if (scalar != avx2 || scalar != avx512) {
    fail("scalar/AVX2/AVX-512 opening candidates differ");
  }
  std::cout << "selftest opening_backends seeds=" << backendCount
            << " candidates=" << scalar.size() << " exact\n";

  fs::create_directories(root / "selftest");
  const SeedBatchPrefilter prefilter = openingCharmSoulBatchPrefilter();
  void *context = prefilter.createContext(prefilter.configuration);
  if (context == nullptr) fail("could not create selftest context");
  ShardInfo testShard = scanRangeWithContext(
      999999, 1000000, 2000000, prefilter, context);
  prefilter.destroyContext(context);
  const fs::path testPath = root / "selftest" / "roundtrip.complete";
  writeBytesAtomically(
      testPath, encodeShard(testShard, predicateDigest(sha), sha),
      "selftest");
  const ShardInfo decoded = decodeAndValidateShard(
      testPath, testShard.index, testShard.begin, testShard.end,
      predicateDigest(sha), sha);
  if (decoded.ids != testShard.ids
      || decoded.openingCandidates != testShard.openingCandidates) {
    fail("shard roundtrip mismatch");
  }
  std::error_code removeError;
  fs::remove(testPath, removeError);
  std::cout << "selftest shard_roundtrip anchors=" << decoded.ids.size()
            << " exact\nselftest result=PASS\n";
}

std::string isoUtcNow() {
  const std::time_t now = std::time(nullptr);
  std::tm utc{};
  gmtime_s(&utc, &now);
  std::ostringstream output;
  output << std::put_time(&utc, "%Y-%m-%dT%H:%M:%SZ");
  return output.str();
}

std::string jsonEscape(std::string_view input) {
  std::string output;
  for (char character : input) {
    switch (character) {
    case '\\': output += "\\\\"; break;
    case '"': output += "\\\""; break;
    case '\n': output += "\\n"; break;
    case '\r': output += "\\r"; break;
    case '\t': output += "\\t"; break;
    default: output += character; break;
    }
  }
  return output;
}

struct MergeResult {
  std::uint64_t count = 0;
  Digest digest{};
  std::uint64_t fnv = 0;
  std::uint64_t payloadBytes = 0;
};

void writeBaseManifest(const fs::path &root, std::uint64_t recordCount,
                       std::uint64_t payloadBytes,
                       const Digest &payloadSha, std::uint64_t payloadFnv,
                       const Digest &buildPredicateSha,
                       std::uint64_t shardCount, int workers,
                       std::uint64_t reusedShards, double buildSeconds,
                       bool manifestOnlyPublication,
                       const Sha256Provider &sha) {
  const Digest publishedSha = publishedPredicateDigest(sha);
  std::ostringstream manifest;
  manifest << "{\n"
           << "  \"magic\": \"" << kManifestMagic << "\",\n"
           << "  \"version\": 1,\n"
           << "  \"manifest_revision\": 1,\n"
           << "  \"payload_file\": \"" << kPayloadName << "\",\n"
           << "  \"record_format\": \"sorted-little-endian-uint64\",\n"
           << "  \"domain_begin\": " << kDomainBegin << ",\n"
           << "  \"domain_end_exclusive\": " << kDomainEnd << ",\n"
           << "  \"predicate\": \"" << jsonEscape(kPublishedPredicate)
           << "\",\n"
           << "  \"predicate_sha256\": \"" << hexDigest(publishedSha)
           << "\",\n"
           << "  \"build_predicate\": \"" << jsonEscape(kPredicate)
           << "\",\n"
           << "  \"build_predicate_sha256\": \""
           << hexDigest(buildPredicateSha) << "\",\n"
           << "  \"record_count\": " << recordCount << ",\n"
           << "  \"payload_bytes\": " << payloadBytes << ",\n"
           << "  \"payload_sha256\": \"" << hexDigest(payloadSha)
           << "\",\n"
           << "  \"fnv1a64\": \"" << hex64(payloadFnv) << "\",\n"
           << "  \"shard_size\": " << kShardSize << ",\n"
           << "  \"shard_count\": " << shardCount << ",\n"
           << "  \"workers\": " << workers << ",\n"
           << "  \"reused_shards\": " << reusedShards << ",\n"
           << "  \"completion_run_seconds\": " << std::fixed
           << std::setprecision(6) << buildSeconds << ",\n"
           << "  \"manifest_only_publication\": "
           << (manifestOnlyPublication ? "true" : "false") << ",\n"
           << "  \"build_deck_scope\": \""
           << jsonEscape(kPublishedDeckScope) << "\",\n"
           << "  \"complete_domain_coverage\": true,\n"
           << "  \"every_candidate_authoritatively_revalidated\": true,\n"
           << "  \"created_utc\": \"" << isoUtcNow() << "\"\n"
           << "}\n";
  const std::string manifestText = manifest.str();
  writeBytesAtomically(
      root / kManifestName,
      std::vector<std::uint8_t>(manifestText.begin(), manifestText.end()),
      "manifest");
}

MergeResult mergeFinal(const fs::path &root, std::uint64_t shardCount,
                       const Digest &predicateSha,
                       const Sha256Provider &sha, int workers,
                       std::uint64_t reusedShards, double buildSeconds) {
  std::vector<std::uint64_t> allIds;
  std::uint64_t expectedRecords = 0;
  for (std::uint64_t shard = 0; shard < shardCount; ++shard) {
    const std::uint64_t begin = shard * kShardSize;
    const std::uint64_t end = std::min(kDomainEnd, begin + kShardSize);
    ShardInfo info = decodeAndValidateShard(
        shardPath(root, shard), shard, begin, end, predicateSha, sha);
    expectedRecords += info.ids.size();
  }
  allIds.reserve(static_cast<std::size_t>(expectedRecords));
  for (std::uint64_t shard = 0; shard < shardCount; ++shard) {
    const std::uint64_t begin = shard * kShardSize;
    const std::uint64_t end = std::min(kDomainEnd, begin + kShardSize);
    ShardInfo info = decodeAndValidateShard(
        shardPath(root, shard), shard, begin, end, predicateSha, sha);
    if (!allIds.empty() && !info.ids.empty()
        && allIds.back() >= info.ids.front()) {
      fail("global shard order/uniqueness failure");
    }
    allIds.insert(allIds.end(), info.ids.begin(), info.ids.end());
  }
  if (allIds.size() != expectedRecords
      || !std::is_sorted(allIds.begin(), allIds.end())
      || std::adjacent_find(allIds.begin(), allIds.end()) != allIds.end()) {
    fail("merged IDs are not strictly increasing");
  }
  for (std::uint64_t id : allIds) {
    if (id >= kDomainEnd) fail("merged ID out of range");
  }
  const std::vector<std::uint8_t> payload = encodeIds(allIds);
  const Digest payloadSha = sha.hash(payload);
  const std::uint64_t payloadFnv = fnv1a64(payload);
  writeBytesAtomically(root / kPayloadName, payload, "payload");
  writeBaseManifest(
      root, static_cast<std::uint64_t>(allIds.size()),
      static_cast<std::uint64_t>(payload.size()), payloadSha, payloadFnv,
      predicateSha, shardCount, workers, reusedShards, buildSeconds, false,
      sha);
  return MergeResult{
      static_cast<std::uint64_t>(allIds.size()), payloadSha, payloadFnv,
      static_cast<std::uint64_t>(payload.size())};
}

void buildFull(const fs::path &root, int workers,
               const Sha256Provider &sha) {
  if (!configureAnchorPredicate()) fail("anchor configuration rejected");
  fs::create_directories(root / "shards");
  const Digest predicateSha = predicateDigest(sha);
  const std::uint64_t shardCount =
      (kDomainEnd + kShardSize - 1) / kShardSize;
  std::vector<std::uint64_t> pending;
  ScanCounters counters;
  std::uint64_t reusedShards = 0;
  for (std::uint64_t shard = 0; shard < shardCount; ++shard) {
    const std::uint64_t begin = shard * kShardSize;
    const std::uint64_t end = std::min(kDomainEnd, begin + kShardSize);
    const fs::path path = shardPath(root, shard);
    if (!fs::exists(path)) {
      pending.push_back(shard);
      continue;
    }
    try {
      const ShardInfo info = decodeAndValidateShard(
          path, shard, begin, end, predicateSha, sha);
      ++reusedShards;
      counters.shards.fetch_add(1, std::memory_order_relaxed);
      counters.seeds.fetch_add(end - begin, std::memory_order_relaxed);
      counters.opening.fetch_add(
          info.openingCandidates, std::memory_order_relaxed);
      counters.anchors.fetch_add(info.ids.size(), std::memory_order_relaxed);
    } catch (const std::exception &error) {
      std::cerr << "invalid completed shard will be rebuilt: "
                << path.filename().string() << " reason=" << error.what()
                << '\n';
      std::error_code removeError;
      fs::remove(path, removeError);
      if (removeError) {
        fail("cannot remove invalid shard " + path.string() + ": "
             + removeError.message());
      }
      pending.push_back(shard);
    }
  }
  std::cout << "build domain=[0," << kDomainEnd << ") shards="
            << shardCount << " shard_size=" << kShardSize
            << " workers=" << workers << " reused=" << reusedShards
            << " pending=" << pending.size()
            << " predicate_sha256=" << hexDigest(predicateSha) << '\n';

  const std::uint64_t initialSeeds =
      counters.seeds.load(std::memory_order_relaxed);
  const auto started = std::chrono::steady_clock::now();
  std::atomic<std::size_t> nextTask{0};
  std::atomic<bool> failed{false};
  std::mutex errorMutex;
  std::string firstError;
  std::mutex progressMutex;
  std::condition_variable progressCv;
  bool workersDone = false;

  std::thread progress([&]() {
    std::unique_lock lock(progressMutex);
    while (!workersDone) {
      progressCv.wait_for(lock, std::chrono::seconds(10));
      const double seconds = std::chrono::duration<double>(
          std::chrono::steady_clock::now() - started).count();
      const std::uint64_t seeds =
          counters.seeds.load(std::memory_order_relaxed);
      const double rate = seconds > 0
          ? static_cast<double>(seeds - initialSeeds) / seconds : 0.0;
      const double eta = rate > 0 && seeds < kDomainEnd
          ? static_cast<double>(kDomainEnd - seeds) / rate : 0.0;
      std::cout << std::fixed << std::setprecision(3)
                << "progress shards="
                << counters.shards.load(std::memory_order_relaxed)
                << '/' << shardCount << " seeds=" << seeds
                << '/' << kDomainEnd << " opening="
                << counters.opening.load(std::memory_order_relaxed)
                << " anchors="
                << counters.anchors.load(std::memory_order_relaxed)
                << " rate_Mseeds_s=" << rate / 1.0e6
                << " eta_minutes=" << eta / 60.0 << std::endl;
    }
  });

  const SeedBatchPrefilter prefilter = openingCharmSoulBatchPrefilter();
  std::vector<std::thread> threads;
  threads.reserve(static_cast<std::size_t>(workers));
  for (int worker = 0; worker < workers; ++worker) {
    threads.emplace_back([&, worker]() {
      void *context = prefilter.createContext(prefilter.configuration);
      if (context == nullptr) {
        std::lock_guard lock(errorMutex);
        failed.store(true, std::memory_order_relaxed);
        if (firstError.empty()) firstError = "could not create batch context";
        return;
      }
      try {
        while (!failed.load(std::memory_order_relaxed)) {
          const std::size_t task =
              nextTask.fetch_add(1, std::memory_order_relaxed);
          if (task >= pending.size()) break;
          const std::uint64_t shard = pending[task];
          const std::uint64_t begin = shard * kShardSize;
          const std::uint64_t end = std::min(kDomainEnd, begin + kShardSize);
          ShardInfo info = scanRangeWithContext(
              shard, begin, end, prefilter, context, &counters);
          const std::vector<std::uint8_t> encoded =
              encodeShard(info, predicateSha, sha);
          writeBytesAtomically(
              shardPath(root, shard), encoded,
              "worker" + std::to_string(worker));
          // Reopen and verify the atomically installed shard before it counts
          // as restartable progress.
          (void)decodeAndValidateShard(
              shardPath(root, shard), shard, begin, end,
              predicateSha, sha);
          counters.shards.fetch_add(1, std::memory_order_relaxed);
        }
      } catch (const std::exception &error) {
        failed.store(true, std::memory_order_relaxed);
        std::lock_guard lock(errorMutex);
        if (firstError.empty()) firstError = error.what();
      }
      prefilter.destroyContext(context);
    });
  }
  for (std::thread &thread : threads) thread.join();
  {
    std::lock_guard lock(progressMutex);
    workersDone = true;
  }
  progressCv.notify_all();
  progress.join();
  if (failed.load(std::memory_order_relaxed)) {
    fail("build worker failed: " + firstError);
  }
  if (counters.shards.load(std::memory_order_relaxed) != shardCount
      || counters.seeds.load(std::memory_order_relaxed) != kDomainEnd) {
    fail("incomplete shard coverage after workers finished");
  }
  const double buildSeconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - started).count();
  std::cout << "merge validating all shards and constructing raw payload\n";
  const MergeResult merged = mergeFinal(
      root, shardCount, predicateSha, sha, workers, reusedShards,
      buildSeconds);
  std::cout << std::fixed << std::setprecision(6)
            << "build_complete count=" << merged.count
            << " payload_bytes=" << merged.payloadBytes
            << " fnv1a64=" << hex64(merged.fnv)
            << " payload_sha256=" << hexDigest(merged.digest)
            << " build_seconds=" << buildSeconds
            << " payload=" << (root / kPayloadName).string()
            << " manifest=" << (root / kManifestName).string() << '\n';
}

std::vector<std::uint64_t> readAndValidatePayload(
    const fs::path &path, const Sha256Provider &sha, Digest &digestOut) {
  const std::vector<std::uint8_t> bytes = readFile(path);
  if ((bytes.size() % 8) != 0) fail("payload size is not a multiple of 8");
  digestOut = sha.hash(bytes);
  std::vector<std::uint64_t> ids;
  ids.reserve(bytes.size() / 8);
  for (std::size_t offset = 0; offset < bytes.size(); offset += 8) {
    ids.push_back(readLe64(bytes.data() + offset));
  }
  if (!std::is_sorted(ids.begin(), ids.end())
      || std::adjacent_find(ids.begin(), ids.end()) != ids.end()) {
    fail("final payload is not strictly increasing");
  }
  for (std::uint64_t id : ids) {
    if (id >= kDomainEnd) fail("final payload contains out-of-range ID");
  }
  return ids;
}

std::string readTextFile(const fs::path &path) {
  const std::vector<std::uint8_t> bytes = readFile(path);
  return std::string(reinterpret_cast<const char *>(bytes.data()),
                     bytes.size());
}

void requireManifestValues(const std::string &manifest,
                           const std::vector<std::string> &required) {
  for (const std::string &needle : required) {
    if (manifest.find(needle) == std::string::npos) {
      fail("manifest does not contain expected value: " + needle);
    }
  }
}

std::vector<std::uint64_t> filterIdsForCurrentConfiguration(
    const std::vector<std::uint64_t> &source, int workers,
    bool independentDirectRoute) {
  std::vector<std::vector<std::uint64_t>> local(
      static_cast<std::size_t>(workers));
  std::vector<std::thread> threads;
  threads.reserve(static_cast<std::size_t>(workers));
  for (int worker = 0; worker < workers; ++worker) {
    threads.emplace_back([&, worker]() {
      const std::size_t begin = source.size()
          * static_cast<std::size_t>(worker)
          / static_cast<std::size_t>(workers);
      const std::size_t end = source.size()
          * static_cast<std::size_t>(worker + 1)
          / static_cast<std::size_t>(workers);
      std::vector<std::uint64_t> &output =
          local[static_cast<std::size_t>(worker)];
      output.reserve((end - begin) / 50 + 16);
      for (std::size_t index = begin; index < end; ++index) {
        Seed seed(static_cast<long long>(source[index]));
        bool matches = false;
        if (independentDirectRoute) {
          Instance instance(seed);
          matches = filterConfiguredAfterOpeningGate(instance) != 0;
        } else {
          matches = authoritativeConfiguredAfterOpeningSeedFilter(seed) != 0;
        }
        if (matches) output.push_back(source[index]);
      }
    });
  }
  for (std::thread &thread : threads) thread.join();
  std::vector<std::uint64_t> result;
  std::size_t count = 0;
  for (const auto &part : local) count += part.size();
  result.reserve(count);
  for (auto &part : local) {
    result.insert(result.end(), part.begin(), part.end());
  }
  if (!std::is_sorted(result.begin(), result.end())
      || std::adjacent_find(result.begin(), result.end()) != result.end()) {
    fail("bounded postpass produced non-strictly-sorted IDs");
  }
  return result;
}

std::vector<std::uint64_t> computeDerivedResults(
    const std::vector<std::uint64_t> &base, int workers,
    bool independentDirectRoute) {
  if (!configureDerivedPredicate()) {
    fail("NaNEInf derived configuration rejected");
  }
  return filterIdsForCurrentConfiguration(
      base, workers, independentDirectRoute);
}

void deriveBounded(const fs::path &root, int workers,
                   const Sha256Provider &sha) {
  Digest baseDigest{};
  const std::vector<std::uint64_t> base = readAndValidatePayload(
      root / kPayloadName, sha, baseDigest);
  const std::string baseManifest = readTextFile(root / kManifestName);
  requireManifestValues(baseManifest, {
      std::string(kManifestMagic), std::string(kPublishedPredicate),
      hexDigest(publishedPredicateDigest(sha)), std::string(kPredicate),
      hexDigest(predicateDigest(sha)),
      hexDigest(baseDigest),
      "\"record_count\": " + std::to_string(base.size())});

  const auto started = std::chrono::steady_clock::now();
  const std::vector<std::uint64_t> primary =
      computeDerivedResults(base, workers, false);
  const std::vector<std::uint64_t> independent =
      computeDerivedResults(base, workers, true);
  if (primary != independent) {
    fail("bounded postpass differs from second direct-Instance pass");
  }

  const std::vector<std::uint8_t> payload = encodeIds(primary);
  const Digest payloadDigest = sha.hash(payload);
  const std::uint64_t payloadFnv = fnv1a64(payload);
  const Digest derivedPredicateSha = sha.hash(kDerivedPredicate);
  writeBytesAtomically(root / kDerivedPayloadName, payload,
                       "derived-payload");
  std::ostringstream manifest;
  manifest << "{\n"
           << "  \"magic\": \"" << kDerivedManifestMagic << "\",\n"
           << "  \"version\": 1,\n"
           << "  \"payload_file\": \"" << kDerivedPayloadName << "\",\n"
           << "  \"record_format\": \"sorted-little-endian-uint64\",\n"
           << "  \"domain_begin\": " << kDomainBegin << ",\n"
           << "  \"domain_end_exclusive\": " << kDomainEnd << ",\n"
           << "  \"predicate\": \"" << jsonEscape(kDerivedPredicate)
           << "\",\n"
           << "  \"predicate_sha256\": \""
           << hexDigest(derivedPredicateSha) << "\",\n"
           << "  \"source_payload_file\": \"" << kPayloadName << "\",\n"
           << "  \"source_record_count\": " << base.size() << ",\n"
           << "  \"source_payload_sha256\": \"" << hexDigest(baseDigest)
           << "\",\n"
           << "  \"record_count\": " << primary.size() << ",\n"
           << "  \"payload_bytes\": " << payload.size() << ",\n"
           << "  \"payload_sha256\": \"" << hexDigest(payloadDigest)
           << "\",\n"
           << "  \"fnv1a64\": \"" << hex64(payloadFnv) << "\",\n"
           << "  \"workers\": " << workers << ",\n"
           << "  \"second_pass_instance_route_match\": true,\n"
           << "  \"complete_domain_coverage\": true,\n"
           << "  \"complete_relative_to_parent\": true,\n"
           << "  \"postpass_seconds\": " << std::fixed
           << std::setprecision(6)
           << std::chrono::duration<double>(
                  std::chrono::steady_clock::now() - started).count()
           << ",\n"
           << "  \"created_utc\": \"" << isoUtcNow() << "\"\n"
           << "}\n";
  const std::string manifestText = manifest.str();
  writeBytesAtomically(
      root / kDerivedManifestName,
      std::vector<std::uint8_t>(manifestText.begin(), manifestText.end()),
      "derived-manifest");

  Digest installedDigest{};
  const std::vector<std::uint64_t> installed = readAndValidatePayload(
      root / kDerivedPayloadName, sha, installedDigest);
  if (installed != primary || installedDigest != payloadDigest) {
    fail("installed derived payload revalidation failed");
  }
  std::cout << "derive_complete source_count=" << base.size()
            << " child_count=" << primary.size()
            << " payload_bytes=" << payload.size()
            << " fnv1a64=" << hex64(payloadFnv)
            << " payload_sha256=" << hexDigest(payloadDigest)
            << " second_pass_match=true complete_relative_to_parent=true\n";
}

void verifyDerived(const fs::path &root, int workers,
                   const Sha256Provider &sha) {
  Digest baseDigest{};
  const std::vector<std::uint64_t> base = readAndValidatePayload(
      root / kPayloadName, sha, baseDigest);
  Digest derivedDigest{};
  const std::vector<std::uint64_t> derived = readAndValidatePayload(
      root / kDerivedPayloadName, sha, derivedDigest);
  const std::uint64_t derivedFnv = fnv1a64(encodeIds(derived));
  const std::string manifest = readTextFile(root / kDerivedManifestName);
  const std::vector<std::uint64_t> expected =
      computeDerivedResults(base, workers, true);
  if (derived != expected) {
    fail("derived payload is not complete/exact relative to base payload");
  }
  requireManifestValues(manifest, {
      std::string(kDerivedManifestMagic), std::string(kDerivedPredicate),
      hexDigest(sha.hash(kDerivedPredicate)),
      hexDigest(baseDigest), hexDigest(derivedDigest),
      "\"fnv1a64\": \"" + hex64(derivedFnv) + "\"",
      "\"source_record_count\": " + std::to_string(base.size()),
      "\"record_count\": " + std::to_string(derived.size()),
      "\"complete_relative_to_parent\": true",
      "\"second_pass_instance_route_match\": true"});
  std::cout << "verify_derived_complete source_count=" << base.size()
            << " child_count=" << derived.size()
            << " fnv1a64=" << hex64(derivedFnv)
            << " payload_sha256=" << hexDigest(derivedDigest)
            << " exact_complete=true strict_order=true in_range=true"
            << " manifest=true\n";
}

std::vector<std::uint64_t> collectBoundedOpeningCandidates(
    std::uint64_t begin, std::uint64_t count, int workers) {
  const SeedBatchPrefilter prefilter = openingCharmSoulBatchPrefilter();
  std::vector<std::vector<std::uint64_t>> local(
      static_cast<std::size_t>(workers));
  std::vector<std::thread> threads;
  threads.reserve(static_cast<std::size_t>(workers));
  std::atomic<bool> failed{false};
  for (int worker = 0; worker < workers; ++worker) {
    threads.emplace_back([&, worker]() {
      void *context = prefilter.createContext(prefilter.configuration);
      if (context == nullptr) {
        failed.store(true, std::memory_order_relaxed);
        return;
      }
      const std::uint64_t localBegin = count
          * static_cast<std::uint64_t>(worker)
          / static_cast<std::uint64_t>(workers);
      const std::uint64_t localEnd = count
          * static_cast<std::uint64_t>(worker + 1)
          / static_cast<std::uint64_t>(workers);
      std::vector<std::uint64_t> &output =
          local[static_cast<std::size_t>(worker)];
      output.reserve(static_cast<std::size_t>(
          (localEnd - localBegin) / 4500 + 32));
      std::vector<std::uint32_t> offsets;
      for (std::uint64_t offsetBase = localBegin;
           offsetBase < localEnd; offsetBase += kScanBlock) {
        const std::size_t blockCount = static_cast<std::size_t>(
            std::min<std::uint64_t>(kScanBlock, localEnd - offsetBase));
        prefilter.collect(context,
                          static_cast<long long>(begin + offsetBase),
                          blockCount, offsets);
        for (std::uint32_t offset : offsets) {
          output.push_back(begin + offsetBase + offset);
        }
      }
      prefilter.destroyContext(context);
    });
  }
  for (std::thread &thread : threads) thread.join();
  if (failed.load(std::memory_order_relaxed)) {
    fail("could not create deck/stake cross-check opening context");
  }
  std::vector<std::uint64_t> result;
  std::size_t total = 0;
  for (const auto &part : local) total += part.size();
  result.reserve(total);
  for (auto &part : local) {
    result.insert(result.end(), part.begin(), part.end());
  }
  if (!std::is_sorted(result.begin(), result.end())
      || std::adjacent_find(result.begin(), result.end()) != result.end()) {
    fail("deck/stake opening sample is not strictly increasing");
  }
  return result;
}

std::vector<std::uint8_t> currentConfigurationMembershipBits(
    const std::vector<std::uint64_t> &ids, int workers) {
  std::vector<std::uint8_t> bits(ids.size());
  std::vector<std::thread> threads;
  threads.reserve(static_cast<std::size_t>(workers));
  for (int worker = 0; worker < workers; ++worker) {
    threads.emplace_back([&, worker]() {
      const std::size_t begin = ids.size()
          * static_cast<std::size_t>(worker)
          / static_cast<std::size_t>(workers);
      const std::size_t end = ids.size()
          * static_cast<std::size_t>(worker + 1)
          / static_cast<std::size_t>(workers);
      for (std::size_t index = begin; index < end; ++index) {
        Seed seed(static_cast<long long>(ids[index]));
        Instance instance(seed);
        bits[index] = static_cast<std::uint8_t>(
            filterConfiguredAfterOpeningGate(instance) != 0);
      }
    });
  }
  for (std::thread &thread : threads) thread.join();
  return bits;
}

void crosscheckDeckStakeIndependence(const fs::path &root, int workers,
                                     const Sha256Provider &sha) {
  Digest baseDigest{};
  const std::vector<std::uint64_t> base = readAndValidatePayload(
      root / kPayloadName, sha, baseDigest);
  if (!configureAnchorPredicate()) fail("baseline configuration rejected");
  const std::vector<std::uint64_t> sample =
      collectBoundedOpeningCandidates(0, kShardSize, workers);
  if (sample.size() < 100000) {
    fail("deck/stake opening-candidate sample unexpectedly small");
  }
  const std::vector<std::uint8_t> baseline =
      currentConfigurationMembershipBits(sample, workers);
  std::vector<std::uint64_t> baselineMatches;
  for (std::size_t index = 0; index < sample.size(); ++index) {
    if (baseline[index] != 0) baselineMatches.push_back(sample[index]);
  }
  const auto baseEnd = std::lower_bound(base.begin(), base.end(), kShardSize);
  const std::vector<std::uint64_t> expectedBasePrefix(base.begin(), baseEnd);
  if (baselineMatches != expectedBasePrefix) {
    fail("deck/stake baseline sample differs from finalized base index");
  }
  for (std::uint64_t id : kKnownAnchorHits) {
    if (!std::binary_search(sample.begin(), sample.end(), id)
        || !std::binary_search(baselineMatches.begin(),
                               baselineMatches.end(), id)) {
      fail("known hit absent from deck/stake sample: "
           + std::to_string(id));
    }
  }

  constexpr std::array<std::string_view, 15> decks = {
      "Red Deck", "Blue Deck", "Yellow Deck", "Green Deck", "Black Deck",
      "Magic Deck", "Nebula Deck", "Ghost Deck", "Abandoned Deck",
      "Checkered Deck", "Zodiac Deck", "Painted Deck", "Anaglyph Deck",
      "Plasma Deck", "Erratic Deck"};
  constexpr std::array<int, 3> stakes = {1, 4, 8};
  std::uint64_t configurations = 0;
  const auto started = std::chrono::steady_clock::now();
  for (std::string_view deck : decks) {
    for (int stake : stakes) {
      if (!configureAnchorPredicateFor(deck, stake)) {
        fail("deck/stake cross-check configuration rejected: "
             + std::string(deck) + " stake=" + std::to_string(stake));
      }
      const std::vector<std::uint8_t> actual =
          currentConfigurationMembershipBits(sample, workers);
      if (actual != baseline) {
        const auto mismatch = std::mismatch(
            baseline.begin(), baseline.end(), actual.begin());
        const std::size_t index = static_cast<std::size_t>(
            mismatch.first - baseline.begin());
        fail("deck/stake anchor membership mismatch: deck="
             + std::string(deck) + " stake=" + std::to_string(stake)
             + " id=" + std::to_string(sample[index])
             + " baseline=" + std::to_string(baseline[index])
             + " actual=" + std::to_string(actual[index]));
      }
      ++configurations;
    }
  }
  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - started).count();
  std::cout << std::fixed << std::setprecision(6)
            << "crosscheck_deck_stake_complete configurations="
            << configurations << " decks=" << decks.size()
            << " stakes=White,Black,Gold raw_sample=" << kShardSize
            << " opening_candidates=" << sample.size()
            << " anchor_matches=" << baselineMatches.size()
            << " known_hits=" << kKnownAnchorHits.size()
            << " exact_membership_equality=true seconds=" << seconds
            << '\n';
}

void verifyFinal(const fs::path &root, int workers,
                 const Sha256Provider &sha) {
  if (!configureAnchorPredicate()) fail("anchor configuration rejected");
  Digest digest{};
  const std::vector<std::uint64_t> ids = readAndValidatePayload(
      root / kPayloadName, sha, digest);
  const std::vector<std::uint8_t> manifestBytes =
      readFile(root / kManifestName);
  const std::string manifest(
      reinterpret_cast<const char *>(manifestBytes.data()),
      manifestBytes.size());
  const std::string hash = hexDigest(digest);
  const std::uint64_t payloadFnv = fnv1a64(encodeIds(ids));
  const std::vector<std::string> required = {
      std::string(kManifestMagic), std::string(kPublishedPredicate),
      hexDigest(publishedPredicateDigest(sha)), std::string(kPredicate),
      hexDigest(predicateDigest(sha)), hash,
      "\"fnv1a64\": \"" + hex64(payloadFnv) + "\"",
      "\"domain_begin\": 0",
      "\"domain_end_exclusive\": " + std::to_string(kDomainEnd),
      "\"record_count\": " + std::to_string(ids.size()),
      "\"manifest_revision\": 1",
      "\"complete_domain_coverage\": true",
      "\"every_candidate_authoritatively_revalidated\": true"};
  requireManifestValues(manifest, required);

  // Rebuild the logical merged sequence from independently checksummed shard
  // files. This proves the payload did not omit, insert, or reorder any result
  // from the complete domain scan.
  const Digest predicateSha = predicateDigest(sha);
  const std::uint64_t shardCount =
      (kDomainEnd + kShardSize - 1) / kShardSize;
  std::size_t payloadCursor = 0;
  for (std::uint64_t shard = 0; shard < shardCount; ++shard) {
    const std::uint64_t begin = shard * kShardSize;
    const std::uint64_t end = std::min(kDomainEnd, begin + kShardSize);
    const ShardInfo info = decodeAndValidateShard(
        shardPath(root, shard), shard, begin, end, predicateSha, sha);
    if (info.ids.size() > ids.size() - payloadCursor
        || !std::equal(
            info.ids.begin(), info.ids.end(),
            ids.begin() + static_cast<std::ptrdiff_t>(payloadCursor))) {
      fail("payload differs from completed shard " + std::to_string(shard));
    }
    payloadCursor += info.ids.size();
  }
  if (payloadCursor != ids.size()) {
    fail("payload has records not represented by completed shards");
  }

  std::atomic<std::size_t> next{0};
  std::atomic<std::uint64_t> failures{0};
  std::vector<std::thread> threads;
  const auto started = std::chrono::steady_clock::now();
  for (int worker = 0; worker < workers; ++worker) {
    threads.emplace_back([&]() {
      while (true) {
        const std::size_t index = next.fetch_add(1, std::memory_order_relaxed);
        if (index >= ids.size()) break;
        if (!directAuthoritativeMembership(ids[index])) {
          failures.fetch_add(1, std::memory_order_relaxed);
        }
      }
    });
  }
  for (std::thread &thread : threads) thread.join();
  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - started).count();
  if (failures.load(std::memory_order_relaxed) != 0) {
    fail("authoritative revalidation failures="
         + std::to_string(failures.load(std::memory_order_relaxed)));
  }
  std::cout << std::fixed << std::setprecision(6)
            << "verify_complete count=" << ids.size()
            << " payload_bytes=" << ids.size() * 8
            << " fnv1a64=" << hex64(payloadFnv)
            << " payload_sha256=" << hash
            << " strict_order=true in_range=true manifest=true"
            << " shards_complete=true"
            << " authoritative_failures=0 authoritative_seconds="
            << seconds << '\n';
}

void showStatus(const fs::path &root, const Sha256Provider &sha) {
  const Digest predicateSha = predicateDigest(sha);
  const std::uint64_t shardCount =
      (kDomainEnd + kShardSize - 1) / kShardSize;
  std::uint64_t valid = 0;
  std::uint64_t covered = 0;
  std::uint64_t opening = 0;
  std::uint64_t anchors = 0;
  for (std::uint64_t shard = 0; shard < shardCount; ++shard) {
    const std::uint64_t begin = shard * kShardSize;
    const std::uint64_t end = std::min(kDomainEnd, begin + kShardSize);
    const fs::path path = shardPath(root, shard);
    if (!fs::exists(path)) continue;
    try {
      const ShardInfo info = decodeAndValidateShard(
          path, shard, begin, end, predicateSha, sha);
      ++valid;
      covered += end - begin;
      opening += info.openingCandidates;
      anchors += info.ids.size();
    } catch (const std::exception &error) {
      std::cout << "invalid_shard=" << shard
                << " reason=" << error.what() << '\n';
    }
  }
  std::cout << "status valid_shards=" << valid << '/' << shardCount
            << " covered_seeds=" << covered << '/' << kDomainEnd
            << " opening=" << opening << " anchors=" << anchors
            << " payload_exists=" << fs::exists(root / kPayloadName)
            << " manifest_exists=" << fs::exists(root / kManifestName)
            << '\n';
}

int parseWorkers(const char *text) {
  try {
    const int value = std::stoi(text);
    if (value < 1 || value > 256) fail("worker count must be 1..256");
    return value;
  } catch (const std::exception &) {
    fail("invalid worker count: " + std::string(text));
  }
}

void usage(const char *program) {
  std::cerr << "usage: " << program
            << " selftest | build [workers=36] | status | verify [workers=36]"
            << " | derive [workers=36] | verify-derived [workers=36]"
            << " | crosscheck-decks [workers=36]\n";
}

} // namespace

int main(int argc, char **argv) {
  try {
    if (argc < 2) {
      usage(argv[0]);
      return 1;
    }
    const fs::path root = fs::current_path();
    const Sha256Provider sha;
    const std::string command = argv[1];
    if (command == "selftest") {
      selftest(root, sha);
    } else if (command == "build") {
      const int workers = argc >= 3 ? parseWorkers(argv[2]) : 36;
      buildFull(root, workers, sha);
    } else if (command == "status") {
      showStatus(root, sha);
    } else if (command == "verify") {
      const int workers = argc >= 3 ? parseWorkers(argv[2]) : 36;
      verifyFinal(root, workers, sha);
    } else if (command == "derive") {
      const int workers = argc >= 3 ? parseWorkers(argv[2]) : 36;
      deriveBounded(root, workers, sha);
    } else if (command == "verify-derived") {
      const int workers = argc >= 3 ? parseWorkers(argv[2]) : 36;
      verifyDerived(root, workers, sha);
    } else if (command == "crosscheck-decks") {
      const int workers = argc >= 3 ? parseWorkers(argv[2]) : 36;
      crosscheckDeckStakeIndependence(root, workers, sha);
    } else {
      usage(argv[0]);
      return 1;
    }
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "anchor index builder failed: " << error.what() << '\n';
    return 2;
  }
}
