#include "search.hpp"

#include <algorithm>
#include <cstdint>
#include <iostream>
#include <vector>

namespace {

std::vector<long long> acceptedIds;

long acceptConfiguredIds(Seed& seed) {
    return std::binary_search(
        acceptedIds.begin(), acceptedIds.end(), seed.getID())
        ? 1
        : 0;
}

bool expectResult(const char* label, long long startId, long long limit,
                  std::vector<std::uint64_t> candidates,
                  std::vector<long long> accepted,
                  long long expectedId) {
    acceptedIds = std::move(accepted);
    std::sort(acceptedIds.begin(), acceptedIds.end());

    SeedSearch search(
        acceptConfiguredIds, Seed(startId).tostring(), 8, limit);
    search.exitOnFind = true;
    search.printDelay = 0;
    const std::string result = search.searchCandidateIds(candidates);
    const bool found = search.found.load(std::memory_order_relaxed);
    const std::string expected = expectedId < 0
        ? std::string{}
        : Seed(expectedId).tostring();
    if (result == expected && found == (expectedId >= 0)) {
        return true;
    }

    std::cerr << label << " returned '" << result << "' instead of '"
              << expected << "' (found=" << found << ")\n";
    return false;
}

} // namespace

int main() {
    bool passed = true;

    // Multiple worker blocks may discover later matches first. Exercise more
    // than two 64-candidate blocks and still require the smallest cyclic
    // offset from the requested starting seed.
    std::vector<std::uint64_t> manyCandidates;
    for (std::uint64_t id = 1000; id < 1193; ++id) {
        manyCandidates.push_back(id);
    }
    passed &= expectResult(
        "multi-block ordering", 1000, 500,
        std::move(manyCandidates), {1050, 1120, 1190}, 1050);

    // Search ranges wrap at the end of the canonical seed domain. Ordering is
    // relative to the requested start, not the numeric order in the file.
    passed &= expectResult(
        "wrapped ordering", SEED_DOMAIN_SIZE - 5, 20,
        {3, 8,
         static_cast<std::uint64_t>(SEED_DOMAIN_SIZE - 2)},
        {3, 8, SEED_DOMAIN_SIZE - 2}, SEED_DOMAIN_SIZE - 2);

    // Search windows are start-inclusive and end-exclusive.
    passed &= expectResult(
        "half-open range", 3000, 10,
        {3000, 3009, 3010}, {3000, 3009, 3010}, 3000);
    passed &= expectResult(
        "exclusive endpoint", 3000, 10,
        {3010}, {3010}, -1);

    // Out-of-range IDs and candidates outside the caller's search window are
    // ignored, and every in-range hint still has to pass the real filter.
    passed &= expectResult(
        "authoritative rejection", 2000, 10,
        {2001, 2004, 2012,
         static_cast<std::uint64_t>(SEED_DOMAIN_SIZE)},
        {2012}, -1);

    // ID zero serializes as an empty string, so success must be carried by the
    // explicit found flag rather than inferred from string emptiness.
    passed &= expectResult(
        "empty seed", SEED_DOMAIN_SIZE - 1, 2,
        {0, static_cast<std::uint64_t>(SEED_DOMAIN_SIZE - 1)},
        {0}, 0);

    if (!passed) {
        return 1;
    }
    std::cout << "Candidate seed priority regression checks passed.\n";
    return 0;
}
