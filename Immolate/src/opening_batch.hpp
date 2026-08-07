#ifndef BRAINSTORM_OPENING_BATCH_HPP
#define BRAINSTORM_OPENING_BATCH_HPP

#include <cstddef>
#include <cstdint>
#include <vector>

enum class OpeningCharmSoulBackend {
  Auto,
  Scalar,
  Avx2,
  Avx512,
};

struct OpeningCharmSoulCriteria {
  int minimumSoulCount = 1;
  // Index into LEGENDARY_JOKERS. -1 means that only the Soul count is a
  // necessary condition and identities remain entirely authoritative-scalar.
  int legendaryIndex = -1;
};

struct OpeningTagCriteria {
  // Index into TAGS. The tag is evaluated with fresh-run Ante-1 locks and
  // the same bounded resampling sequence as Instance::nextTag(1).
  int tagIndex = -1;
};

OpeningCharmSoulBackend selectedOpeningCharmSoulBackend();
bool openingCharmSoulVectorBackendAvailable();
bool openingCharmSoulBackendAvailable(OpeningCharmSoulBackend backend);
const char *openingCharmSoulBackendName(OpeningCharmSoulBackend backend);

// Search and estimator workers own one reusable context for their lifetime,
// avoiding allocator contention and dynamic TLS teardown in MinGW DLLs.
std::uint64_t encodeOpeningCharmSoulCriteria(
    OpeningCharmSoulCriteria criteria);
void *createOpeningCharmSoulBatchContext(std::uint64_t configuration);
void destroyOpeningCharmSoulBatchContext(void *context);
void collectOpeningCharmSoulCandidatesWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);

// Writes offsets in ascending order. Every returned offset is in [0, count)
// and identifies a seed that passes the exact Charm/Soul necessary gate. Seed
// wraparound at SEED_DOMAIN_SIZE is preserved.
void collectOpeningCharmSoulCandidates(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningCharmSoulCriteria criteria);

// Explicit backend selection supports differential tests and diagnostics.
// Unsupported vector backends safely fall back to scalar execution.
void collectOpeningCharmSoulCandidatesWithBackend(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningCharmSoulCriteria criteria, OpeningCharmSoulBackend backend);

// Tag-only searches reuse the initial SIMD tag stage without touching the
// Soul or legendary streams. Their configuration has a distinct mode bit so
// it can never be decoded through the Soul-count clamp.
std::uint64_t encodeOpeningTagCriteria(OpeningTagCriteria criteria);
void *createOpeningTagBatchContext(std::uint64_t configuration);
void destroyOpeningTagBatchContext(void *context);
void collectOpeningTagCandidatesWithContext(
    void *context, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets);
void collectOpeningTagCandidates(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningTagCriteria criteria);
void collectOpeningTagCandidatesWithBackend(
    long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    OpeningTagCriteria criteria, OpeningCharmSoulBackend backend);

#if defined(BRAINSTORM_OPENING_BATCH_TESTING) \
    && defined(BRAINSTORM_OPENING_BATCH_AVX2)
void collectOpeningCharmSoulAvx2ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    bool sharedInitialHashes);
void collectOpeningCharmSoulInitialHashesAvx2ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<double> &hashedSeeds, std::vector<double> &tagSeedHashes);
void round13PositiveAvx2ForTesting(
    const std::vector<double> &inputs, std::vector<double> &outputs);
#endif

#if defined(BRAINSTORM_OPENING_BATCH_TESTING) \
    && defined(BRAINSTORM_OPENING_BATCH_AVX512)
void collectOpeningCharmSoulAvx512ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<std::uint32_t> &survivorOffsets,
    bool sharedInitialHashes);
void collectOpeningCharmSoulInitialHashesAvx512ForTesting(
    void *workspace, long long startSeedId, std::size_t count,
    std::vector<double> &hashedSeeds, std::vector<double> &tagSeedHashes);
void round13PositiveAvx512ForTesting(
    const std::vector<double> &inputs, std::vector<double> &outputs);
#endif

#endif // BRAINSTORM_OPENING_BATCH_HPP
