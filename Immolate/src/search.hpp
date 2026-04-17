#ifndef SEARCH_HPP
#define SEARCH_HPP

#include "instance.hpp"
#include <atomic>
#include <functional>
#include <iostream>
#include <mutex>
#include <thread>
#include <vector>

const long long BLOCK_SIZE = 1000000;

class Search {
public:
    std::atomic<long long> seedsProcessed{0};
    std::atomic<long long> highScore{1};
    long long printDelay = 10000000;
    std::function<int(Instance)> filter;
    std::atomic<bool> found{false}; // Atomic flag to signal when a solution is found
    Seed foundSeed; // Store the found seed
    bool exitOnFind = false;
    long long startSeed;
    int numThreads;
    long long numSeeds;
    std::mutex mtx;
    std::atomic<long long> nextBlock{0}; // Shared index for the next block to be processed

    Search(std::function<int(Instance)> f) {
        filter = f;
        startSeed = 0;
        numThreads = 1;
        numSeeds = 2318107019761;
    }

    Search(std::function<int(Instance)> f, int t) {
        filter = f;
        startSeed = 0;
        numThreads = t;
        numSeeds = 2318107019761;
    }
    
    Search(std::function<int(Instance)> f, int t, long long n) {
      filter = f;
      startSeed = 0;
      numThreads = t;
      numSeeds = n;
    };
    Search(std::function<int(Instance)> f, std::string seed, int t, long long n) {
      filter = f;
      startSeed = Seed(seed).getID();
      numThreads = t;
      numSeeds = n;
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
        for (long long i = start; i < end; ++i) {
            if (found) {
                flushProcessed(localProcessed);
                return; // Exit if a solution is found
            }
            // Perform the search on the seed
            int result = filter(inst);
            if (result >= highScore.load(std::memory_order_relaxed)) {
                std::lock_guard<std::mutex> lock(mtx);
                highScore = result;
                foundSeed = s;
                std::cout << "Found seed: " << s.tostring() << " (" << result << ")"
                  << std::endl;
                if (exitOnFind) {
                    flushProcessed(localProcessed);
                    found = true;
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
        std::vector<std::thread> threads;
        long long totalBlocks = (numSeeds + BLOCK_SIZE - 1) / BLOCK_SIZE;
        for (int t = 0; t < numThreads; t++) {
            threads.emplace_back([this, totalBlocks]() {
                while (true) {
                    long long block = nextBlock.fetch_add(1);
                    if (block >= totalBlocks) break;
                    long long start = block * BLOCK_SIZE + startSeed;
                    long long end = std::min(start + BLOCK_SIZE, numSeeds + startSeed);
                    searchBlock(start, end);
                }
            });
        }

        for (auto& thread : threads) {
            thread.join();
        }

        return foundSeed.tostring();
    }
};

#endif