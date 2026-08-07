#include "functions.hpp"
#include "negative_blueprint_batch.hpp"
#include "rng.hpp"
#include "seed.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

namespace {

Item deckForRate(NegativeBlueprintShopRate rate) {
  switch (rate) {
  case NegativeBlueprintShopRate::Ghost:
    return Item::Ghost_Deck;
  case NegativeBlueprintShopRate::Zodiac:
    return Item::Zodiac_Deck;
  case NegativeBlueprintShopRate::Ordinary:
    return Item::Red_Deck;
  }
  return Item::Red_Deck;
}

bool simulatorPasses(Seed &seed,
                     const NegativeBlueprintCriteria &criteria) {
  Instance instance(seed);
  instance.initLocks(1, false, true);
  instance.setDeck(deckForRate(criteria.shopRate));

  const std::vector<ShopItem> shopItems =
      instance.nextShopItems(criteria.shopCards, 1, false);
  for (const ShopItem &item : shopItems) {
    if (item.type == Item::T_Joker
        && (!criteria.requireRare
            || item.jokerData.rarity == Item::Rare)
        && item.jokerData.edition == Item::Negative) {
      return true;
    }
  }

  Pack pack = packInfo(instance.nextPack(1));
  for (int displayed = 0; displayed < criteria.displayedPacks;
       ++displayed) {
    if (pack.type == Item::Buffoon_Pack
        || pack.type == Item::Jumbo_Buffoon_Pack
        || pack.type == Item::Mega_Buffoon_Pack) {
      const std::vector<JokerData> contents =
          instance.nextBuffoonPack(pack.size, 1);
      for (const JokerData &joker : contents) {
        if ((!criteria.requireRare || joker.rarity == Item::Rare)
            && joker.edition == Item::Negative) {
          return true;
        }
      }
    }
    pack = packInfo(instance.nextPack(1));
  }
  return false;
}

std::vector<std::uint32_t> simulatorReference(
    long long startSeedId, std::size_t count,
    const NegativeBlueprintCriteria &criteria) {
  std::vector<std::uint32_t> survivors;
  survivors.reserve(count / 50 + 8);
  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    if (simulatorPasses(seed, criteria)) {
      survivors.push_back(static_cast<std::uint32_t>(offset));
    }
    seed.next();
  }
  return survivors;
}

bool compareBackend(
    long long startSeedId, std::size_t count,
    NegativeBlueprintCriteria criteria,
    NegativeBlueprintBackend backend,
    const std::vector<std::uint32_t> &expected) {
  if (!negativeBlueprintBackendAvailable(backend)) {
    return true;
  }
  std::vector<std::uint32_t> actual;
  collectNegativeBlueprintCandidatesWithBackend(
      startSeedId, count, actual, criteria, backend);
  if (actual == expected
      && std::is_sorted(actual.begin(), actual.end())) {
    return true;
  }
  std::cerr << "negative Blueprint batch mismatch for backend "
            << negativeBlueprintBackendName(backend)
            << " at start " << startSeedId
            << ", expected " << expected.size()
            << " survivors, got " << actual.size()
            << ", shop cards=" << criteria.shopCards
            << ", displayed packs=" << criteria.displayedPacks
            << ", rate=" << static_cast<int>(criteria.shopRate)
            << ", require rare=" << criteria.requireRare
            << std::endl;
  if (actual != expected) {
    const auto mismatch = std::mismatch(
        expected.begin(), expected.end(), actual.begin(), actual.end());
    if (mismatch.first != expected.end()) {
      std::cerr << "first expected offset=" << *mismatch.first << ' ';
    }
    if (mismatch.second != actual.end()) {
      std::cerr << "first actual offset=" << *mismatch.second;
    }
    std::cerr << std::endl;
  }
  return false;
}

bool checkRange(const char *label, long long startSeedId,
                std::size_t count,
                NegativeBlueprintCriteria criteria) {
  const std::vector<std::uint32_t> expected =
      simulatorReference(startSeedId, count, criteria);
  bool passed = true;
  passed &= compareBackend(
      startSeedId, count, criteria,
      NegativeBlueprintBackend::Scalar, expected);
  passed &= compareBackend(
      startSeedId, count, criteria,
      NegativeBlueprintBackend::Avx2, expected);
  passed &= compareBackend(
      startSeedId, count, criteria,
      NegativeBlueprintBackend::Avx512, expected);
  passed &= compareBackend(
      startSeedId, count, criteria,
      NegativeBlueprintBackend::Auto, expected);
  if (passed) {
    std::cout << "negative Blueprint batch range " << label
              << ": " << count << " seeds, "
              << expected.size() << " survivors" << std::endl;
  }
  return passed;
}

bool exactNegativeBlueprintFixture(const char *seedText) {
  Seed seed(seedText);
  Instance instance(seed);
  instance.initLocks(1, false, true);
  instance.setDeck(Item::Red_Deck);
  for (const ShopItem &item : instance.nextShopItems(4, 1, false)) {
    if (item.type == Item::T_Joker
        && item.jokerData.joker == Item::Blueprint
        && item.jokerData.edition == Item::Negative) {
      return true;
    }
  }
  Pack pack = packInfo(instance.nextPack(1));
  for (int displayed = 0; displayed < 4; ++displayed) {
    if (pack.type == Item::Buffoon_Pack
        || pack.type == Item::Jumbo_Buffoon_Pack
        || pack.type == Item::Mega_Buffoon_Pack) {
      for (const JokerData &joker :
           instance.nextBuffoonPack(pack.size, 1)) {
        if (joker.joker == Item::Blueprint
            && joker.edition == Item::Negative) {
          return true;
        }
      }
    }
    pack = packInfo(instance.nextPack(1));
  }
  return false;
}

bool checkFixture(const char *label, const char *seedText,
                  NegativeBlueprintCriteria criteria) {
  Seed seed(seedText);
  const std::vector<std::uint32_t> expected{0};
  bool passed = exactNegativeBlueprintFixture(seedText);
  for (NegativeBlueprintBackend backend : {
           NegativeBlueprintBackend::Scalar,
           NegativeBlueprintBackend::Avx2,
           NegativeBlueprintBackend::Avx512,
           NegativeBlueprintBackend::Auto}) {
    passed &= compareBackend(
        seed.getID(), 1, criteria, backend, expected);
  }
  if (!passed) {
    std::cerr << "known fixture rejected: " << label
              << " (" << seedText << ')' << std::endl;
  }
  return passed;
}

bool checkRuntimeKeys() {
  const bool passed =
      RandomType::Card_Type + anteToString(1) == "cdt1"
      && RandomType::Joker_Rarity + anteToString(1)
             + ItemSource::Shop == "rarity1sho"
      && RandomType::Joker_Edition + ItemSource::Shop
             + anteToString(1) == "edisho1"
      && RandomType::Shop_Pack + anteToString(1) == "shop_pack1"
      && RandomType::Joker_Rarity + anteToString(1)
             + ItemSource::Buffoon_Pack == "rarity1buf"
      && RandomType::Joker_Edition + ItemSource::Buffoon_Pack
             + anteToString(1) == "edibuf1";
  if (!passed) {
    std::cerr << "negative Blueprint SIMD key constants drifted"
              << std::endl;
  }
  return passed;
}

} // namespace

int main() {
  bool passed = checkRuntimeKeys();
  const NegativeBlueprintCriteria ordinaryEdition{
      4, 4, NegativeBlueprintShopRate::Ordinary, false};
  const NegativeBlueprintCriteria ordinaryRare{
      4, 4, NegativeBlueprintShopRate::Ordinary, true};
  const NegativeBlueprintCriteria combinedRare{
      2, 3, NegativeBlueprintShopRate::Ordinary, true};
  const NegativeBlueprintCriteria ghostRare{
      4, 4, NegativeBlueprintShopRate::Ghost, true};
  const NegativeBlueprintCriteria zodiacRare{
      4, 4, NegativeBlueprintShopRate::Zodiac, true};

  passed &= checkFixture(
      "shop Negative Blueprint edition", "JW111111", ordinaryEdition);
  passed &= checkFixture(
      "Buffoon Negative Blueprint edition", "K4U31111", ordinaryEdition);
  passed &= checkFixture(
      "shop Negative Blueprint rare", "JW111111", ordinaryRare);
  passed &= checkFixture(
      "Buffoon Negative Blueprint rare", "K4U31111", ordinaryRare);

  // The primary differential alone exceeds one million consecutive seeds.
  // The additional configurations protect both legacy scan shapes and every
  // supported fresh-run shop-rate denominator.
  passed &= checkRange(
      "ordinary edition", 1000000000000ll,
      (1u << 18) + 13, ordinaryEdition);
  passed &= checkRange(
      "ordinary rare", 1000000000000ll,
      (1u << 20) + 13, ordinaryRare);
  passed &= checkRange(
      "combined rare", 1000000000777ll,
      (1u << 18) + 5, combinedRare);
  passed &= checkRange(
      "ghost rare", 1000000001777ll,
      (1u << 18) + 7, ghostRare);
  passed &= checkRange(
      "zodiac rare", 1000000002777ll,
      (1u << 18) + 9, zodiacRare);

  passed &= checkRange(
      "domain wrap edition", SEED_DOMAIN_SIZE - 37,
      91, ordinaryEdition);
  passed &= checkRange(
      "domain wrap rare", SEED_DOMAIN_SIZE - 37, 91, ordinaryRare);
  passed &= checkRange(
      "negative start rare", -11, 137, combinedRare);

  constexpr std::array<std::size_t, 12> awkwardCounts = {
      1, 2, 3, 7, 8, 9, 31, 255, 4093, 4096, 4099, 65537};
  for (std::size_t count : awkwardCounts) {
    passed &= checkRange(
        "awkward count edition", 1234567890123ll,
        count, ordinaryEdition);
    passed &= checkRange(
        "awkward count rare", 1234567890123ll,
        count, ordinaryRare);
  }

  if (!passed) {
    return EXIT_FAILURE;
  }
  std::cout << "negative Blueprint batch regression passed" << std::endl;
  return EXIT_SUCCESS;
}
