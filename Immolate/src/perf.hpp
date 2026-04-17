#ifndef PERF_HPP
#define PERF_HPP

#include <array>
#include <atomic>
#include <chrono>
#include <cstdlib>
#include <iomanip>
#include <iostream>

enum class BrainstormPerfMetric {
  RankPrefilter,
  Filter,
  NextPack,
  NextVoucher,
  NextArcanaPack,
  NextBuffoonPack,
  NextJoker,
  NextShopItem,
  Count
};

struct BrainstormPerfCounter {
  std::atomic<long long> calls{0};
  std::atomic<long long> totalNs{0};
};

class BrainstormPerfStats {
public:
  static BrainstormPerfStats &instance() {
    static BrainstormPerfStats stats;
    return stats;
  }

  bool enabled() const { return enabled_; }

  void reset() {
    if (!enabled_) {
      return;
    }

    for (auto &counter : counters_) {
      counter.calls.store(0, std::memory_order_relaxed);
      counter.totalNs.store(0, std::memory_order_relaxed);
    }
    rankPrefilterPassed_.store(0, std::memory_order_relaxed);
    rankPrefilterRejected_.store(0, std::memory_order_relaxed);
    filterMatches_.store(0, std::memory_order_relaxed);
    filterMisses_.store(0, std::memory_order_relaxed);
  }

  void record(BrainstormPerfMetric metric, long long elapsedNs) {
    if (!enabled_) {
      return;
    }

    auto &counter = counters_[static_cast<size_t>(metric)];
    counter.calls.fetch_add(1, std::memory_order_relaxed);
    counter.totalNs.fetch_add(elapsedNs, std::memory_order_relaxed);
  }

  void noteRankPrefilter(bool passed) {
    if (!enabled_) {
      return;
    }

    if (passed) {
      rankPrefilterPassed_.fetch_add(1, std::memory_order_relaxed);
    } else {
      rankPrefilterRejected_.fetch_add(1, std::memory_order_relaxed);
    }
  }

  void noteFilterResult(bool matched) {
    if (!enabled_) {
      return;
    }

    if (matched) {
      filterMatches_.fetch_add(1, std::memory_order_relaxed);
    } else {
      filterMisses_.fetch_add(1, std::memory_order_relaxed);
    }
  }

  void printSummary(long long seedsProcessed, long long elapsedNs) const {
    if (!enabled_) {
      return;
    }

    const double elapsedMs = static_cast<double>(elapsedNs) / 1000000.0;
    const double seedsPerSecond =
        elapsedNs > 0
            ? static_cast<double>(seedsProcessed) * 1000000000.0 /
                  static_cast<double>(elapsedNs)
            : 0.0;
    const long long rankPassed =
        rankPrefilterPassed_.load(std::memory_order_relaxed);
    const long long rankRejected =
        rankPrefilterRejected_.load(std::memory_order_relaxed);
    const long long filterMatches =
        filterMatches_.load(std::memory_order_relaxed);
    const long long filterMisses =
        filterMisses_.load(std::memory_order_relaxed);

    std::cout << "=== Brainstorm profile ===" << std::endl;
    std::cout << "Seeds processed: " << seedsProcessed << std::endl;
    std::cout << "Elapsed ms: " << std::fixed << std::setprecision(3)
              << elapsedMs << std::endl;
    std::cout << "Seeds/sec: " << std::fixed << std::setprecision(2)
              << seedsPerSecond << std::endl;
    std::cout << "Rank prefilter passed: " << rankPassed << std::endl;
    std::cout << "Rank prefilter rejected: " << rankRejected << std::endl;
    std::cout << "Filter matches: " << filterMatches << std::endl;
    std::cout << "Filter misses: " << filterMisses << std::endl;

    printCounter("rankPrefilter",
                 counters_[static_cast<size_t>(BrainstormPerfMetric::RankPrefilter)],
                 elapsedNs);
    printCounter("filter",
                 counters_[static_cast<size_t>(BrainstormPerfMetric::Filter)],
                 elapsedNs);
    printCounter("nextPack",
                 counters_[static_cast<size_t>(BrainstormPerfMetric::NextPack)],
                 elapsedNs);
    printCounter("nextVoucher",
                 counters_[static_cast<size_t>(BrainstormPerfMetric::NextVoucher)],
                 elapsedNs);
    printCounter("nextArcanaPack",
                 counters_[static_cast<size_t>(BrainstormPerfMetric::NextArcanaPack)],
                 elapsedNs);
    printCounter("nextBuffoonPack",
                 counters_[static_cast<size_t>(BrainstormPerfMetric::NextBuffoonPack)],
                 elapsedNs);
    printCounter("nextJoker",
                 counters_[static_cast<size_t>(BrainstormPerfMetric::NextJoker)],
                 elapsedNs);
    printCounter("nextShopItem",
                 counters_[static_cast<size_t>(BrainstormPerfMetric::NextShopItem)],
                 elapsedNs);
  }

private:
  BrainstormPerfStats() : enabled_(envFlagEnabled("BRAINSTORM_PROFILE")) {}

  static bool envFlagEnabled(const char *name) {
    const char *value = std::getenv(name);
    return value != nullptr && value[0] != '\0' && value[0] != '0';
  }

  static void printCounter(const char *label,
                           const BrainstormPerfCounter &counter,
                           long long wallElapsedNs) {
    const long long calls = counter.calls.load(std::memory_order_relaxed);
    const long long totalNs = counter.totalNs.load(std::memory_order_relaxed);
    const double totalMs = static_cast<double>(totalNs) / 1000000.0;
    const double avgNs =
        calls > 0 ? static_cast<double>(totalNs) / static_cast<double>(calls)
                  : 0.0;
    const double wallPct =
        wallElapsedNs > 0
            ? (static_cast<double>(totalNs) / static_cast<double>(wallElapsedNs)) *
                  100.0
            : 0.0;

    std::cout << "  " << label << ": calls=" << calls
              << " total_ms=" << std::fixed << std::setprecision(3) << totalMs
              << " avg_ns=" << std::fixed << std::setprecision(1) << avgNs
              << " wall_pct=" << std::fixed << std::setprecision(2) << wallPct
              << std::endl;
  }

  bool enabled_;
  std::array<BrainstormPerfCounter,
             static_cast<size_t>(BrainstormPerfMetric::Count)>
      counters_{};
  std::atomic<long long> rankPrefilterPassed_{0};
  std::atomic<long long> rankPrefilterRejected_{0};
  std::atomic<long long> filterMatches_{0};
  std::atomic<long long> filterMisses_{0};
};

class BrainstormScopedPerfTimer {
public:
  explicit BrainstormScopedPerfTimer(BrainstormPerfMetric metric)
      : stats_(nullptr), metric_(metric) {
    auto &stats = BrainstormPerfStats::instance();
    if (stats.enabled()) {
      stats_ = &stats;
      start_ = std::chrono::steady_clock::now();
    }
  }

  ~BrainstormScopedPerfTimer() {
    if (stats_ == nullptr) {
      return;
    }

    const auto end = std::chrono::steady_clock::now();
    const auto elapsed =
        std::chrono::duration_cast<std::chrono::nanoseconds>(end - start_)
            .count();
    stats_->record(metric_, elapsed);
  }

private:
  BrainstormPerfStats *stats_;
  BrainstormPerfMetric metric_;
  std::chrono::steady_clock::time_point start_{};
};

#endif // PERF_HPP
