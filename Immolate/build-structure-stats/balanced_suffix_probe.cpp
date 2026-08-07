#include "../src/opening_batch.hpp"
#include "../src/seed.hpp"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace {

struct Job {
  int width = 0;
  int rightmost = 0;
  int secondRightmost = -1;
  int fold = 0;
  std::uint64_t start = 0;
  std::uint64_t count = 0;
};

struct Result {
  std::uint64_t charm = 0;
  std::uint64_t soul = 0;
  std::uint64_t perkeo = 0;
};

Result runJob(const Job &job, void *tagContext, void *soulContext,
              void *perkeoContext) {
  constexpr std::uint64_t chunkSize = 1u << 20;
  Result result;
  std::vector<std::uint32_t> offsets;
  for (std::uint64_t done = 0; done < job.count;) {
    const std::size_t count = static_cast<std::size_t>(
        std::min(chunkSize, job.count - done));
    const long long start = static_cast<long long>(job.start + done);
    collectOpeningTagCandidatesWithContext(
        tagContext, start, count, offsets);
    result.charm += offsets.size();
    collectOpeningCharmSoulCandidatesWithContext(
        soulContext, start, count, offsets);
    result.soul += offsets.size();
    collectOpeningCharmSoulCandidatesWithContext(
        perkeoContext, start, count, offsets);
    result.perkeo += offsets.size();
    done += count;
  }
  return result;
}

int parseThreadCount(const char *text) {
  if (text == nullptr || std::string(text) == "auto") {
    const unsigned int detected = std::thread::hardware_concurrency();
    return static_cast<int>(std::clamp(detected == 0 ? 1u : detected,
                                       1u, 256u));
  }
  return std::clamp(std::stoi(text), 1, 256);
}

}  // namespace

int main(int argc, char **argv) {
  if (argc < 2 || argc > 3) {
    std::cerr << "usage: balanced_suffix_probe <output-dir> [threads=auto]\n";
    return 2;
  }
  const std::filesystem::path outputDir = argv[1];
  const int threadCount = parseThreadCount(argc >= 3 ? argv[2] : nullptr);
  std::filesystem::create_directories(outputDir);

  constexpr std::uint64_t suffix1Count = 20000000;
  constexpr std::array<std::uint64_t, 2> suffix1Offsets = {
      5000000000ull, 45000000000ull};
  constexpr std::uint64_t suffix2Count = 1000000;
  constexpr std::array<std::uint64_t, 2> suffix2Offsets = {
      100000000ull, 1000000000ull};

  std::vector<Job> jobs;
  for (int rightmost = 0; rightmost < 35; ++rightmost) {
    const std::uint64_t root = 1
        + static_cast<std::uint64_t>(rightmost) * idCoeff[0];
    for (int fold = 0; fold < 2; ++fold) {
      jobs.push_back(Job{1, rightmost, -1, fold,
                         root + suffix1Offsets[fold], suffix1Count});
    }
  }
  for (int rightmost = 0; rightmost < 35; ++rightmost) {
    for (int second = 0; second < 35; ++second) {
      const std::uint64_t root = 2
          + static_cast<std::uint64_t>(rightmost) * idCoeff[0]
          + static_cast<std::uint64_t>(second) * idCoeff[1];
      for (int fold = 0; fold < 2; ++fold) {
        jobs.push_back(Job{2, rightmost, second, fold,
                           root + suffix2Offsets[fold], suffix2Count});
      }
    }
  }

  std::vector<Result> results(jobs.size());
  std::atomic<std::size_t> nextJob{0};
  std::atomic<std::uint64_t> finishedSeeds{0};
  std::mutex progressMutex;
  const std::uint64_t totalSeeds = 35ull * 2 * suffix1Count
      + 35ull * 35 * 2 * suffix2Count;
  const auto begin = std::chrono::steady_clock::now();

  std::vector<std::thread> workers;
  workers.reserve(threadCount);
  for (int worker = 0; worker < threadCount; ++worker) {
    workers.emplace_back([&] {
      void *tagContext = createOpeningTagBatchContext(
          encodeOpeningTagCriteria({10}));
      void *soulContext = createOpeningCharmSoulBatchContext(
          encodeOpeningCharmSoulCriteria({1, -1}));
      void *perkeoContext = createOpeningCharmSoulBatchContext(
          encodeOpeningCharmSoulCriteria({1, 4}));
      while (true) {
        const std::size_t index = nextJob.fetch_add(1);
        if (index >= jobs.size()) break;
        results[index] = runJob(
            jobs[index], tagContext, soulContext, perkeoContext);
        const std::uint64_t done =
            finishedSeeds.fetch_add(jobs[index].count) + jobs[index].count;
        if (done % 250000000ull < jobs[index].count) {
          const double seconds = std::chrono::duration<double>(
              std::chrono::steady_clock::now() - begin).count();
          std::lock_guard<std::mutex> lock(progressMutex);
          std::cerr << "progress " << done << '/' << totalSeeds << ", "
                    << std::fixed << std::setprecision(1)
                    << done / seconds / 1.0e6 << " Mseed/s\n";
        }
      }
      destroyOpeningTagBatchContext(tagContext);
      destroyOpeningCharmSoulBatchContext(soulContext);
      destroyOpeningCharmSoulBatchContext(perkeoContext);
    });
  }
  for (auto &worker : workers) worker.join();

  std::ofstream suffix1(outputDir / "suffix1.csv");
  std::ofstream suffix2(outputDir / "suffix2.csv");
  suffix1 << "fold,rightmost,start,seeds,charm,charm_soul,charm_soul_perkeo\n";
  suffix2 << "fold,rightmost,second_rightmost,start,seeds,charm,charm_soul,charm_soul_perkeo\n";
  for (std::size_t index = 0; index < jobs.size(); ++index) {
    const Job &job = jobs[index];
    const Result &result = results[index];
    if (job.width == 1) {
      suffix1 << job.fold << ',' << seedChars[job.rightmost] << ','
              << job.start << ',' << job.count << ',' << result.charm << ','
              << result.soul << ',' << result.perkeo << '\n';
    } else {
      suffix2 << job.fold << ',' << seedChars[job.rightmost] << ','
              << seedChars[job.secondRightmost] << ',' << job.start << ','
              << job.count << ',' << result.charm << ',' << result.soul << ','
              << result.perkeo << '\n';
    }
  }

  const double seconds = std::chrono::duration<double>(
      std::chrono::steady_clock::now() - begin).count();
  std::cout << "completed " << totalSeeds << " balanced suffix probes in "
            << std::fixed << std::setprecision(3) << seconds << " seconds ("
            << totalSeeds / seconds / 1.0e6 << " Mseed/s), backend="
            << openingCharmSoulBackendName(selectedOpeningCharmSoulBackend())
            << std::endl;
  return 0;
}
