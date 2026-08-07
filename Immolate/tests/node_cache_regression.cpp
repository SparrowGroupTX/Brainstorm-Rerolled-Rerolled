#include "instance.hpp"

#include <bit>
#include <cstdint>
#include <iostream>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace {

struct ReferenceInstance {
  Seed& seed;
  double hashedSeed;
  std::unordered_map<std::string, double> nodes;

  explicit ReferenceInstance(Seed& source)
      : seed(source), hashedSeed(source.pseudohash(0)) {
    nodes.reserve(128);
  }

  double getNode(const std::string& id) {
    auto iterator = nodes.find(id);
    if (iterator == nodes.end()) {
      iterator = nodes.emplace(
          id, pseudohash_from(
                  id, seed.pseudohash(static_cast<int>(id.length())))).first;
    }
    iterator->second = round13(
        fractPositive(iterator->second * 1.72431234 + 2.134453429141));
    return (iterator->second + hashedSeed) / 2;
  }
};

bool compareNode(Instance& actual, ReferenceInstance& expected,
                 const std::string& key) {
  const std::uint64_t expectedBits =
      std::bit_cast<std::uint64_t>(expected.getNode(key));
  const std::uint64_t actualBits =
      std::bit_cast<std::uint64_t>(actual.get_node(key));
  if (actualBits == expectedBits) {
    return true;
  }
  std::cerr << "node value differs for key length " << key.size() << '\n';
  return false;
}

std::vector<std::string> makeInstanceKeys() {
  std::vector<std::string> keys;
  keys.reserve(600);
  for (int index = 0; index < 600; ++index) {
    std::string key = "node_" + std::to_string(index) + "_a_"
        + std::to_string(index % 9) + "_";
    key.append(static_cast<std::size_t>(4 + index % 8),
               static_cast<char>('A' + index % 26));
    if (index % 31 == 0) {
      key.insert(key.begin() + static_cast<std::ptrdiff_t>(key.size() / 2),
                 '\0');
    }
    keys.push_back(std::move(key));
  }
  return keys;
}

bool exerciseInstanceRange(Instance& actual, ReferenceInstance& expected,
                           const std::vector<std::string>& keys,
                           int first, int last, int stride) {
  bool passed = true;
  for (int index = first;
       stride > 0 ? index < last : index > last;
       index += stride) {
    passed &= compareNode(
        actual, expected, keys[static_cast<std::size_t>(index)]);
  }
  return passed;
}

bool instanceMatchesUnorderedReferencePastCompactIndex() {
  Seed seed(1000000000000ll);
  Instance actual(seed);
  ReferenceInstance expected(seed);
  const std::vector<std::string> keys = makeInstanceKeys();
  bool passed = true;

  passed &= exerciseInstanceRange(actual, expected, keys, 0, 600, 1);
  passed &= actual.cache.nodes.size() == 600;
  passed &= exerciseInstanceRange(actual, expected, keys, 599, -1, -1);
  passed &= exerciseInstanceRange(actual, expected, keys, 0, 600, 3);

  Instance copied = actual;
  ReferenceInstance expectedCopied = expected;
  passed &= exerciseInstanceRange(
      copied, expectedCopied, keys, 1, 600, 4);

  Instance moved = std::move(copied);
  ReferenceInstance expectedMoved = std::move(expectedCopied);
  passed &= exerciseInstanceRange(moved, expectedMoved, keys, 2, 600, 5);

  // A moved-from cache remains a valid, empty cache without an explicit clear.
  ReferenceInstance expectedReused(seed);
  passed &= copied.cache.nodes.size() == 0;
  passed &= compareNode(copied, expectedReused, "moved_reuse_dynamic_key_37");

  moved.cache.nodes.clear();
  expectedMoved.nodes.clear();
  passed &= exerciseInstanceRange(moved, expectedMoved, keys, 0, 600, 7);
  return passed;
}

std::vector<std::string> makeArbitraryCacheKeys() {
  std::vector<std::string> keys;
  keys.reserve(700);
  for (int index = 0; index < 700; ++index) {
    std::string key = "arbitrary_" + std::to_string(index) + "_";
    key.append(static_cast<std::size_t>(80 + index % 240),
               static_cast<char>('a' + index % 26));
    if (index % 17 == 0) {
      key.insert(key.begin() + static_cast<std::ptrdiff_t>(key.size() / 3),
                 '\0');
    }
    keys.push_back(std::move(key));
  }
  return keys;
}

bool arbitraryCacheKeysSurviveCollisionsOverflowCopiesAndMoves() {
  const std::vector<std::string> keys = makeArbitraryCacheKeys();
  NodeCache cache;
  std::unordered_map<std::string, double> expected;
  std::size_t initializerCalls = 0;
  bool passed = true;

  for (std::size_t index = 0; index < keys.size(); ++index) {
    const double initial = static_cast<double>(index) + 0.25;
    double& value = cache.lookupOrInsert(keys[index], [&] {
      ++initializerCalls;
      return initial;
    });
    value += 0.5;
    expected.emplace(keys[index], initial + 0.5);
  }
  passed &= cache.size() == keys.size();
  passed &= initializerCalls == keys.size();

  for (std::size_t index = keys.size(); index > 0; --index) {
    const std::string& key = keys[index - 1];
    double& value = cache.lookupOrInsert(key, [&] {
      ++initializerCalls;
      return -1.0;
    });
    passed &= value == expected[key];
  }
  passed &= initializerCalls == keys.size();

  NodeCache copied = cache;
  NodeCache moved = std::move(copied);
  passed &= copied.size() == 0;
  passed &= moved.size() == keys.size();
  for (std::size_t index = 0; index < keys.size(); index += 11) {
    double& value = moved.lookupOrInsert(keys[index], [&] {
      ++initializerCalls;
      return -2.0;
    });
    passed &= value == expected[keys[index]];
  }

  const std::string movedFromKey(4096, 'z');
  double& movedFromValue = copied.lookupOrInsert(
      movedFromKey, [] { return 123.5; });
  passed &= movedFromValue == 123.5;
  passed &= copied.size() == 1;

  moved.clear();
  passed &= moved.size() == 0;
  double& clearedValue = moved.lookupOrInsert(
      keys.front(), [] { return 77.25; });
  passed &= clearedValue == 77.25;
  return passed;
}

} // namespace

int main() {
  const bool passed = instanceMatchesUnorderedReferencePastCompactIndex()
      && arbitraryCacheKeysSurviveCollisionsOverflowCopiesAndMoves();
  if (!passed) {
    std::cerr << "node cache semantic regression failed\n";
    return 1;
  }
  std::cout << "node cache semantics exact through overflow/copy/move/clear\n";
  return 0;
}
