#ifndef SEARCH_HPP
#define SEARCH_HPP

#include "instance.hpp"
#include "perf.hpp"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <mutex>
#include <thread>
#include <utility>
#include <vector>

const long long MAX_BLOCK_SIZE = 1000000;
const long long MIN_BLOCK_SIZE = 32768;
const int TARGET_BLOCKS_PER_THREAD = 1;
using SearchFilter = long (*)(Instance &);
using SeedFilter = long (*)(Seed &);

struct SeedBatchPrefilter {
    using CreateContext = void* (*)(std::uint64_t);
    using DestroyContext = void (*)(void*);
    using Collect = void (*)(
        void*, long long, std::size_t, std::vector<std::uint32_t>&);

    CreateContext createContext = nullptr;
    DestroyContext destroyContext = nullptr;
    Collect collect = nullptr;
    std::uint64_t configuration = 0;

    explicit operator bool() const {
        return createContext != nullptr
            && destroyContext != nullptr
            && collect != nullptr;
    }
};

inline long long resolveSearchBlockSize(long long totalSeeds, int totalThreads) {
    const char* envValue = std::getenv("BRAINSTORM_BLOCK_SIZE");
    if (envValue != nullptr) {
        char* end = nullptr;
        long long parsed = std::strtoll(envValue, &end, 10);
        if (end != envValue && *end == '\0' && parsed > 0) {
            return parsed;
        }
    }

    const long long threads = std::max(1, totalThreads);
    long long suggested = totalSeeds / (threads * TARGET_BLOCKS_PER_THREAD);
    if (suggested <= 0) {
        suggested = 1;
    }
    if (totalSeeds > MIN_BLOCK_SIZE) {
        suggested = std::max(MIN_BLOCK_SIZE, suggested);
    }
    return std::min(MAX_BLOCK_SIZE, suggested);
}

class Search {
public:
    std::atomic<long long> seedsProcessed{0};
    std::atomic<long long> highScore{1};
    long long printDelay = 10000000;
    SearchFilter filter;
    std::atomic<bool> found{false}; // Atomic flag to signal when a solution is found
    Seed foundSeed; // Store the found seed
    bool exitOnFind = false;
    long long startSeed;
    int numThreads;
    long long numSeeds;
    long long blockSize;
    std::mutex mtx;
    std::atomic<long long> nextSeedOffset{0}; // Shared offset for the next seed range

    Search(SearchFilter f) {
        filter = f;
        startSeed = 0;
        numThreads = 1;
        numSeeds = SEED_DOMAIN_SIZE;
        blockSize = MAX_BLOCK_SIZE;
    }

    Search(SearchFilter f, int t) {
        filter = f;
        startSeed = 0;
        numThreads = t;
        numSeeds = SEED_DOMAIN_SIZE;
        blockSize = MAX_BLOCK_SIZE;
    }
    
    Search(SearchFilter f, int t, long long n) {
      filter = f;
      startSeed = 0;
      numThreads = t;
      numSeeds = n;
      blockSize = MAX_BLOCK_SIZE;
    };
    Search(SearchFilter f, std::string seed, int t, long long n) {
      filter = f;
      startSeed = Seed(seed).getID();
      numThreads = t;
      numSeeds = n;
      blockSize = MAX_BLOCK_SIZE;
    };

    void flushProcessed(long long& localProcessed) {
        if (localProcessed == 0) {
            return;
        }

        long long previous = seedsProcessed.fetch_add(localProcessed, std::memory_order_relaxed);
        long long current = previous + localProcessed;
        if (printDelay > 0 && previous / printDelay != current / printDelay) {
            for (long long bucket = previous / printDelay + 1; bucket <= current / printDelay; ++bucket) {
                std::cout << "Seeds processed: " << bucket * printDelay << std::endl;
            }
        }
        localProcessed = 0;
    }

    void searchBlock(long long start, long long end) {
        Seed s = Seed(start);
        Instance inst(s);
        long long localProcessed = 0;
        const bool profilingEnabled = BrainstormPerfStats::instance().enabled();
        for (long long i = start; i < end; ++i) {
            if ((localProcessed & 63) == 0
                && found.load(std::memory_order_relaxed)) {
                flushProcessed(localProcessed);
                return; // Exit if a solution is found
            }
            // Perform the search on the seed
            long result = filter(inst);
            if (profilingEnabled) {
                BrainstormPerfStats::instance().noteFilterResult(result != 0);
            }
            // Brainstorm filters return zero for nearly every rejected seed.
            // Avoid touching the shared high-score cache line on that hot
            // path; only positive scores can meet the initial score of one.
            if (result > 0
                && result >= highScore.load(std::memory_order_relaxed)) {
                std::lock_guard<std::mutex> lock(mtx);
                highScore.store(result, std::memory_order_relaxed);
                foundSeed = s;
                std::cout << "Found seed: " << s.tostring() << " (" << result << ")"
                  << std::endl;
                if (exitOnFind) {
                    flushProcessed(localProcessed);
                    found.store(true, std::memory_order_relaxed);
                    return;
                }
            }
            localProcessed++;
            if ((localProcessed & 4095) == 0) {
                flushProcessed(localProcessed);
            }
            inst.next();
        }
        flushProcessed(localProcessed);
    }

    std::string search() {
        BrainstormPerfStats::instance().reset();
        seedsProcessed.store(0, std::memory_order_relaxed);
        found.store(false, std::memory_order_relaxed);
        nextSeedOffset.store(0, std::memory_order_relaxed);
        foundSeed = Seed();
        blockSize = resolveSearchBlockSize(numSeeds, numThreads);
        const auto searchStart = std::chrono::steady_clock::now();
        std::vector<std::thread> threads;
        threads.reserve(numThreads);
        for (int t = 0; t < numThreads; t++) {
            threads.emplace_back([this]() {
                while (true) {
                    long long offset = nextSeedOffset.fetch_add(
                        blockSize, std::memory_order_relaxed);
                    if (offset >= numSeeds) break;
                    const long long seedsInBlock =
                        std::min(blockSize, numSeeds - offset);
                    const long long start = normalizeSeedId(
                        startSeed + normalizeSeedId(offset));
                    const long long end = start + seedsInBlock;
                    searchBlock(start, end);
                }
            });
        }

        for (auto& thread : threads) {
            thread.join();
        }

        const auto searchEnd = std::chrono::steady_clock::now();
        const auto elapsedNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                                   searchEnd - searchStart)
                                   .count();
        BrainstormPerfStats::instance().printSummary(
            seedsProcessed.load(std::memory_order_relaxed), elapsedNs);
        return foundSeed.tostring();
    }
};

class SeedSearch {
public:
    std::atomic<long long> seedsProcessed{0};
    std::atomic<long long> highScore{1};
    long long printDelay = 10000000;
    SeedFilter filter;
    // Optional exact necessary-condition gate. It returns sorted offsets of
    // seeds that still require the authoritative scalar filter.
    SeedBatchPrefilter batchPrefilter{};
    long long batchChunkSize = 4096;
    std::atomic<bool> found{false};
    Seed foundSeed;
    bool exitOnFind = false;
    long long startSeed;
    int numThreads;
    long long numSeeds;
    long long blockSize;
    std::mutex mtx;
    std::atomic<long long> nextSeedOffset{0};

    SeedSearch(SeedFilter f, std::string seed, int t, long long n) {
        filter = f;
        startSeed = Seed(seed).getID();
        numThreads = t;
        numSeeds = n;
        blockSize = MAX_BLOCK_SIZE;
    };

    void flushProcessed(long long& localProcessed) {
        if (localProcessed == 0) {
            return;
        }

        long long previous =
            seedsProcessed.fetch_add(localProcessed, std::memory_order_relaxed);
        long long current = previous + localProcessed;
        if (printDelay > 0 && previous / printDelay != current / printDelay) {
            for (long long bucket = previous / printDelay + 1;
                 bucket <= current / printDelay; ++bucket) {
                std::cout << "Seeds processed: " << bucket * printDelay << std::endl;
            }
        }
        localProcessed = 0;
    }

    void searchBlock(long long start, long long end) {
        Seed s = Seed(start);
        long long localProcessed = 0;
        const bool profilingEnabled = BrainstormPerfStats::instance().enabled();
        for (long long i = start; i < end; ++i) {
            if ((localProcessed & 63) == 0
                && found.load(std::memory_order_relaxed)) {
                flushProcessed(localProcessed);
                return;
            }

            long result = filter(s);
            if (profilingEnabled) {
                BrainstormPerfStats::instance().noteFilterResult(result != 0);
            }
            if (result > 0
                && result >= highScore.load(std::memory_order_relaxed)) {
                std::lock_guard<std::mutex> lock(mtx);
                highScore.store(result, std::memory_order_relaxed);
                foundSeed = s;
                std::cout << "Found seed: " << s.tostring() << " (" << result << ")"
                          << std::endl;
                if (exitOnFind) {
                    flushProcessed(localProcessed);
                    found.store(true, std::memory_order_relaxed);
                    return;
                }
            }
            localProcessed++;
            if ((localProcessed & 4095) == 0) {
                flushProcessed(localProcessed);
            }
            s.next();
        }
        flushProcessed(localProcessed);
    }

    void searchBatchBlock(long long start, long long count,
                          void* batchContext) {
        long long localProcessed = 0;
        const bool profilingEnabled = BrainstormPerfStats::instance().enabled();
        std::vector<std::uint32_t> survivors;
        survivors.reserve(static_cast<std::size_t>(count / 4096 + 8));

        for (long long chunkOffset = 0; chunkOffset < count;
             chunkOffset += batchChunkSize) {
            if (found.load(std::memory_order_relaxed)) {
                flushProcessed(localProcessed);
                return;
            }

            const long long seedsInChunk =
                std::min(batchChunkSize, count - chunkOffset);
            const long long chunkStart = normalizeSeedId(
                start + normalizeSeedId(chunkOffset));
            batchPrefilter.collect(
                batchContext, chunkStart,
                static_cast<std::size_t>(seedsInChunk), survivors);

            // The gate has evaluated the complete chunk even if a survivor
            // near its beginning becomes the final result.
            localProcessed += seedsInChunk;
            if (profilingEnabled) {
                const long long rejected = seedsInChunk
                    - static_cast<long long>(survivors.size());
                for (long long i = 0; i < rejected; ++i) {
                    BrainstormPerfStats::instance().noteFilterResult(false);
                }
            }

            for (std::uint32_t survivorOffset : survivors) {
                Seed seed(normalizeSeedId(
                    chunkStart + static_cast<long long>(survivorOffset)));
                const long result = filter(seed);
                if (profilingEnabled) {
                    BrainstormPerfStats::instance().noteFilterResult(
                        result != 0);
                }
                if (result > 0
                    && result >= highScore.load(std::memory_order_relaxed)) {
                    std::lock_guard<std::mutex> lock(mtx);
                    highScore.store(result, std::memory_order_relaxed);
                    foundSeed = seed;
                    std::cout << "Found seed: " << seed.tostring() << " ("
                              << result << ")" << std::endl;
                    if (exitOnFind) {
                        flushProcessed(localProcessed);
                        found.store(true, std::memory_order_relaxed);
                        return;
                    }
                }
            }

            if (localProcessed >= 4096) {
                flushProcessed(localProcessed);
            }
        }
        flushProcessed(localProcessed);
    }

    // Try a reusable, strictly increasing list of promising seed IDs before
    // falling back to exhaustive enumeration. Every entry still runs the
    // authoritative filter, so an incomplete, stale, or merely heuristic list
    // can affect performance but can never return an invalid seed. This method
    // is a first-hit operation; production callers set exitOnFind=true.
    std::string searchCandidateIds(
        const std::vector<std::uint64_t>& sortedCandidateIds) {
        if (sortedCandidateIds.empty() || numSeeds <= 0) {
            return "";
        }

        const auto lowerIndex = [&](long long id) {
            return static_cast<std::size_t>(std::lower_bound(
                sortedCandidateIds.begin(), sortedCandidateIds.end(),
                static_cast<std::uint64_t>(id))
                - sortedCandidateIds.begin());
        };
        const std::size_t startIndex = lowerIndex(startSeed);
        std::size_t firstBegin = startIndex;
        std::size_t firstEnd = startIndex;
        std::size_t secondEnd = 0;
        const long long seedsUntilDomainEnd =
            SEED_DOMAIN_SIZE - startSeed;
        if (numSeeds <= seedsUntilDomainEnd) {
            firstEnd = lowerIndex(startSeed + numSeeds);
        } else {
            firstEnd = sortedCandidateIds.size();
            secondEnd = lowerIndex(numSeeds - seedsUntilDomainEnd);
        }
        const std::size_t firstCount = firstEnd - firstBegin;
        const std::size_t candidateCount = firstCount + secondEnd;
        if (candidateCount == 0) {
            return "";
        }

        const auto candidateAt = [&](std::size_t position) {
            const std::size_t sourceIndex = position < firstCount
                ? firstBegin + position
                : position - firstCount;
            const long long id = static_cast<long long>(
                sortedCandidateIds[sourceIndex]);
            const long long offset = id >= startSeed
                ? id - startSeed
                : SEED_DOMAIN_SIZE - startSeed + id;
            return std::pair<long long, long long>{offset, id};
        };

        BrainstormPerfStats::instance().reset();
        seedsProcessed.store(0, std::memory_order_relaxed);
        found.store(false, std::memory_order_relaxed);
        foundSeed = Seed();
        std::atomic<std::size_t> nextCandidate{0};
        std::atomic<long long> bestOffset{numSeeds};
        constexpr std::size_t candidateBlockSize = 64;
        const std::size_t candidateBlockCount =
            (candidateCount + candidateBlockSize - 1) / candidateBlockSize;
        const int workerCount = static_cast<int>(std::min<std::size_t>(
            static_cast<std::size_t>(std::max(1, numThreads)),
            candidateBlockCount));
        const auto searchStart = std::chrono::steady_clock::now();
        std::vector<std::thread> threads;
        threads.reserve(workerCount);
        for (int thread = 0; thread < workerCount; ++thread) {
            threads.emplace_back([&, this]() {
                long long localProcessed = 0;
                const bool profilingEnabled =
                    BrainstormPerfStats::instance().enabled();
                while (true) {
                    const std::size_t begin = nextCandidate.fetch_add(
                        candidateBlockSize, std::memory_order_relaxed);
                    if (begin >= candidateCount
                        || candidateAt(begin).first
                            >= bestOffset.load(std::memory_order_relaxed)) {
                        break;
                    }
                    const std::size_t end = std::min(
                        begin + candidateBlockSize, candidateCount);
                    for (std::size_t index = begin; index < end; ++index) {
                        const auto [candidateOffset, candidateId] =
                            candidateAt(index);
                        if (candidateOffset
                            >= bestOffset.load(std::memory_order_relaxed)) {
                            break;
                        }
                        Seed seed(candidateId);
                        const long result = filter(seed);
                        ++localProcessed;
                        if (profilingEnabled) {
                            BrainstormPerfStats::instance().noteFilterResult(
                                result != 0);
                        }
                        if (result <= 0) {
                            continue;
                        }

                        long long previous = bestOffset.load(
                            std::memory_order_relaxed);
                        while (candidateOffset < previous
                               && !bestOffset.compare_exchange_weak(
                                   previous, candidateOffset,
                                   std::memory_order_relaxed,
                                   std::memory_order_relaxed)) {
                        }
                        if (candidateOffset
                            == bestOffset.load(std::memory_order_relaxed)) {
                            std::lock_guard<std::mutex> lock(mtx);
                            if (candidateOffset == bestOffset.load(
                                    std::memory_order_relaxed)) {
                                foundSeed = seed;
                                found.store(true, std::memory_order_relaxed);
                            }
                        }
                    }
                }
                flushProcessed(localProcessed);
            });
        }
        for (std::thread& thread : threads) {
            thread.join();
        }

        const auto searchEnd = std::chrono::steady_clock::now();
        const auto elapsedNs =
            std::chrono::duration_cast<std::chrono::nanoseconds>(
                searchEnd - searchStart).count();
        BrainstormPerfStats::instance().printSummary(
            seedsProcessed.load(std::memory_order_relaxed), elapsedNs);
        if (found.load(std::memory_order_relaxed)) {
            std::cout << "Found indexed seed: " << foundSeed.tostring()
                      << std::endl;
        }
        return foundSeed.tostring();
    }

    std::string search() {
        BrainstormPerfStats::instance().reset();
        seedsProcessed.store(0, std::memory_order_relaxed);
        found.store(false, std::memory_order_relaxed);
        nextSeedOffset.store(0, std::memory_order_relaxed);
        foundSeed = Seed();
        blockSize = resolveSearchBlockSize(numSeeds, numThreads);
        const auto searchStart = std::chrono::steady_clock::now();
        std::vector<std::thread> threads;
        threads.reserve(numThreads);
        for (int t = 0; t < numThreads; t++) {
            threads.emplace_back([this]() {
                void* batchContext = batchPrefilter
                    ? batchPrefilter.createContext(
                          batchPrefilter.configuration)
                    : nullptr;
                while (true) {
                    long long offset = nextSeedOffset.fetch_add(
                        blockSize, std::memory_order_relaxed);
                    if (offset >= numSeeds) break;
                    const long long seedsInBlock =
                        std::min(blockSize, numSeeds - offset);
                    const long long start = normalizeSeedId(
                        startSeed + normalizeSeedId(offset));
                    if (batchPrefilter) {
                        searchBatchBlock(start, seedsInBlock, batchContext);
                    } else {
                        const long long end = start + seedsInBlock;
                        searchBlock(start, end);
                    }
                }
                if (batchContext != nullptr) {
                    batchPrefilter.destroyContext(batchContext);
                }
            });
        }

        for (auto& thread : threads) {
            thread.join();
        }

        const auto searchEnd = std::chrono::steady_clock::now();
        const auto elapsedNs = std::chrono::duration_cast<std::chrono::nanoseconds>(
                                   searchEnd - searchStart)
                                   .count();
        BrainstormPerfStats::instance().printSummary(
            seedsProcessed.load(std::memory_order_relaxed), elapsedNs);
        return foundSeed.tostring();
    }
};

#endif
