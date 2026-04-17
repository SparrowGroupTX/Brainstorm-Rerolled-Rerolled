#ifndef SEARCH_HPP
#define SEARCH_HPP

#include "instance.hpp"
#include "perf.hpp"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <mutex>
#include <thread>
#include <vector>

const long long MAX_BLOCK_SIZE = 1000000;
const long long MIN_BLOCK_SIZE = 32768;
const int TARGET_BLOCKS_PER_THREAD = 1;
using SearchFilter = long (*)(Instance &);
using SeedFilter = long (*)(Seed &);

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
        numSeeds = 2318107019761;
        blockSize = MAX_BLOCK_SIZE;
    }

    Search(SearchFilter f, int t) {
        filter = f;
        startSeed = 0;
        numThreads = t;
        numSeeds = 2318107019761;
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
            if (result >= highScore.load(std::memory_order_relaxed)) {
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
        for (int t = 0; t < numThreads; t++) {
            threads.emplace_back([this]() {
                while (true) {
                    long long offset = nextSeedOffset.fetch_add(
                        blockSize, std::memory_order_relaxed);
                    if (offset >= numSeeds) break;
                    long long start = startSeed + offset;
                    long long end = std::min(start + blockSize, numSeeds + startSeed);
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
            if (result >= highScore.load(std::memory_order_relaxed)) {
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

    std::string search() {
        BrainstormPerfStats::instance().reset();
        seedsProcessed.store(0, std::memory_order_relaxed);
        found.store(false, std::memory_order_relaxed);
        nextSeedOffset.store(0, std::memory_order_relaxed);
        foundSeed = Seed();
        blockSize = resolveSearchBlockSize(numSeeds, numThreads);
        const auto searchStart = std::chrono::steady_clock::now();
        std::vector<std::thread> threads;
        for (int t = 0; t < numThreads; t++) {
            threads.emplace_back([this]() {
                while (true) {
                    long long offset = nextSeedOffset.fetch_add(
                        blockSize, std::memory_order_relaxed);
                    if (offset >= numSeeds) break;
                    long long start = startSeed + offset;
                    long long end = std::min(start + blockSize, numSeeds + startSeed);
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

#endif