#include "items.hpp"
#include "seed.hpp"
#include "util.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <functional>
#include <string>
#include <string_view>
#include <utility>
#include <vector>
#pragma once

enum class JokerStickerGeneration {
  None,
  EternalOnly,
  EternalPerishableOnly,
  Full,
};

struct NodeCacheEntry {
  std::size_t hash = 0;
  std::string id;
  double value = 0.0;
};

struct NodeCache {
  // Values stay densely packed so timeline branch copies need one allocation
  // instead of one unordered-map node allocation per key. The byte index is
  // only an accelerator: hashes and complete strings remain authoritative.
  std::vector<NodeCacheEntry> entries;
  std::array<std::uint8_t, 256> buckets{};

  NodeCache() { entries.reserve(128); }
  NodeCache(const NodeCache&) = default;
  NodeCache& operator=(const NodeCache&) = default;
  NodeCache(NodeCache&& other) noexcept
      : entries(std::move(other.entries)), buckets(other.buckets) {
    other.clear();
  }
  NodeCache& operator=(NodeCache&& other) noexcept {
    if (this != &other) {
      entries = std::move(other.entries);
      buckets = other.buckets;
      other.clear();
    }
    return *this;
  }

  void clear() {
    entries.clear();
    buckets.fill(0);
  }

  std::size_t size() const { return entries.size(); }

  template <class Initializer>
  double& lookupOrInsert(const std::string& id, Initializer&& initializer) {
    const std::size_t hash = std::hash<std::string_view>{}(id);
    std::size_t bucket = hash & (buckets.size() - 1);
    for (std::size_t probe = 0; probe < buckets.size(); ++probe) {
      const std::uint8_t encoded = buckets[bucket];
      if (encoded == 0) {
        // uint8_t encodes dense entry indices 0..254 as 1..255. Larger
        // arbitrary caches use the exact linear overflow path below.
        if (entries.size() < 255) {
          entries.push_back(NodeCacheEntry{
              hash, id, std::forward<Initializer>(initializer)()});
          buckets[bucket] = static_cast<std::uint8_t>(entries.size());
          return entries.back().value;
        }
        break;
      }
      NodeCacheEntry& entry = entries[encoded - 1];
      if (entry.hash == hash && entry.id == id) {
        return entry.value;
      }
      bucket = (bucket + 1) & (buckets.size() - 1);
    }

    // Once the compact index is full, preserve exact behavior for any number
    // of long or dynamically generated keys. Full strings resolve both bucket
    // and hash collisions.
    for (NodeCacheEntry& entry : entries) {
      if (entry.hash == hash && entry.id == id) {
        return entry.value;
      }
    }
    entries.push_back(NodeCacheEntry{
        hash, id, std::forward<Initializer>(initializer)()});
    return entries.back().value;
  }
};

struct Cache {
  NodeCache nodes;
  bool generatedFirstPack = false;
};

struct InstParams {
  Item deck;
  Item stake;
  bool showman;
  int sixesFactor;
  long version;
  bool vouchers[32] = {false};
  InstParams() {
    deck = Item::Red_Deck;
    stake = Item::White_Stake;
    showman = false;
    sixesFactor = 1;
    version = 10103; // 1.0.1c
  }
  InstParams(Item d, Item s, bool show, long v) {
    deck = d;
    stake = s;
    showman = show;
    sixesFactor = 1;
    version = v;
  }
};

struct ArcanaSoulPackResult {
  int soulCount = 0;
  std::vector<JokerData> soulJokers;
};

struct BuffoonPackScanResult {
  bool foundBlueprint = false;
  bool foundNegativeBlueprint = false;
  bool foundBrainstorm = false;
  bool foundMoney = false;
  bool foundNegativeBaseball = false;
};

struct Instance {
  static constexpr std::size_t LOCK_WORD_COUNT =
      (static_cast<std::size_t>(Item::ITEMS_END) + 63) / 64;
  std::array<std::uint64_t, LOCK_WORD_COUNT> locked{};
  Seed &seed;
  double hashedSeed;
  Cache cache;
  InstParams params;
  // A seed-only prefilter can prove rejection before touching any run state.
  // In that case the already-clean maps/locks/params can be carried into the
  // next seed instead of redundantly clearing and rebuilding them.
  bool preserveCleanRunStateOnNext = false;
  void clearRunState() {
    locked.fill(0);
    params = InstParams();
    cache.nodes.clear();
    cache.generatedFirstPack = false;
  }
  Instance(Seed &s) : seed(s) {
    hashedSeed = s.pseudohash(0);
    clearRunState();
  };
  void reset(Seed &s) { // This is slow, use next() unless necessary
    seed = s;
    hashedSeed = s.pseudohash(0);
    clearRunState();
  };
  void next() {
    seed.next();
    hashedSeed = seed.pseudohash(0);
    if (preserveCleanRunStateOnNext) {
      preserveCleanRunStateOnNext = false;
    } else {
      clearRunState();
    }
  }
  double get_node(const std::string &ID) {
    double& value = cache.nodes.lookupOrInsert(
        ID,
        [&] {
          return pseudohash_from(
              ID, seed.pseudohash(static_cast<int>(ID.length())));
        });
    value = round13(fractPositive(value * 1.72431234 + 2.134453429141));
    return (value + hashedSeed) / 2;
  }
  double random(const std::string &ID) {
    return lua_random_from_seed(get_node(ID));
  }
  int randint(const std::string &ID, int min, int max) {
    return lua_randint_from_seed(get_node(ID), min, max);
  }
  template <std::size_t N>
  Item randchoice(const std::string &ID, const std::array<Item, N> &items) {
    Item item = items[lua_randint_from_seed(
        get_node(ID), 0, static_cast<int>(items.size()) - 1)];
    if ((params.showman == false && isLocked(item)) || item == Item::RETRY) {
      int resample = 2;
      while (true) {
        Item item = items[lua_randint_from_seed(
            get_node(ID + "_resample" + anteToString(resample)), 0,
            static_cast<int>(items.size()) - 1)];
        resample++;
        if ((item != Item::RETRY && !isLocked(item)) || resample > 1000)
          return item;
      }
    }
    return item;
  }
  template <std::size_t N>
  Item randweightedchoice(const std::string &ID,
                          const std::array<WeightedItem, N> &items) {
    double poll = lua_random_from_seed(get_node(ID)) * items[0].weight;
    int idx = 1;
    double weight = 0;
    while (weight < poll) {
      weight += items[idx].weight;
      idx++;
    }
    return items[idx - 1].item;
  }

  // Functions defined in functions.hpp
  void lock(Item item);
  void lockTransient(Item item);
  void unlock(Item item);
  void unlockTransient(Item item);
  bool isLocked(Item item);
  void initLocks(int ante, bool freshProfile, bool freshRun);
  void initUnlocks(int ante, bool freshProfile);
  Item nextTarot(const std::string &source, int ante, bool soulable,
                 bool allowDuplicateSoul = false);
  Item nextPlanet(const std::string &source, int ante, bool soulable);
  Item nextSpectral(const std::string &source, int ante, bool soulable,
                    bool allowDuplicateSoul = false);
  JokerData nextJoker(const std::string &source, int ante, bool hasStickers);
  JokerData nextJoker(const std::string &source, int ante,
                      JokerStickerGeneration stickerGeneration);
  ShopInstance getShopInstance();
  ShopItem nextShopItem(int ante, bool jokerHasStickers = true);
  // Advance cdt<ante> exactly once. A Joker is generated in full and returned
  // through jokerOut. For a non-Joker draw, return false without generating
  // an identity that a Joker-only caller has explicitly promised not to use.
  bool nextShopJokerOnly(int ante, bool jokerHasStickers,
                         JokerData &jokerOut);
  bool nextShopJokerOnly(int ante,
                         JokerStickerGeneration stickerGeneration,
                         JokerData &jokerOut);
  std::vector<ShopItem> nextShopItems(int count, int ante,
                                      bool jokerHasStickers = true);
  Item nextPack(int ante);
  std::vector<Item> nextArcanaPack(int size, int ante);
  ArcanaSoulPackResult scanArcanaPackForSoulJokers(
      int size, int ante, bool allowDuplicateSouls = false);
  std::vector<Item> nextCelestialPack(int size, int ante);
  std::vector<Item> nextSpectralPack(int size, int ante);
  std::vector<JokerData> nextBuffoonPack(int size, int ante);
  BuffoonPackScanResult scanBuffoonPack(int size, int ante);
  std::vector<Card> nextStandardPack(int size, int ante);
  Card nextStandardCard(int ante);
  bool isVoucherActive(Item voucher);
  void activateVoucher(Item voucher);
  Item nextVoucher(int ante);
  void setDeck(Item deck);
  void setStake(Item stake);
  Item nextTag(int ante);
  Item nextBoss(int ante);
};
