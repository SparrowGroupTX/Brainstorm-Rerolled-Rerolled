#include "arbitrary_negative_batch.hpp"
#include "functions.hpp"
#include "seed.hpp"

#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <string_view>
#include <vector>

namespace {

inline constexpr unsigned int soulSource = 1u << 0;
inline constexpr unsigned int judgementSource = 1u << 1;
inline constexpr unsigned int anteSource(int ante) {
  return 1u << static_cast<unsigned int>(ante + 1);
}

int deadline(ArbitraryNegativeWindow window) {
  switch (window) {
    case ArbitraryNegativeWindow::ByAnteTwo: return 2;
    case ArbitraryNegativeWindow::ByAnteThree: return 3;
    case ArbitraryNegativeWindow::ByAnteFour: return 4;
    case ArbitraryNegativeWindow::ByAnteFive: return 5;
    case ArbitraryNegativeWindow::ByAnteSix: return 6;
    case ArbitraryNegativeWindow::ByAnteSeven: return 7;
    case ArbitraryNegativeWindow::ByAnteEight: return 8;
    default: return 0;
  }
}

bool accepts(const ArbitraryNegativeRequirement& requirement,
             unsigned int source, bool allowStartingPack) {
  const bool legendary =
      requirement.rarity == ArbitraryNegativeRarity::Legendary;
  if (source == soulSource) {
    if (!legendary || !allowStartingPack) {
      return false;
    }
    return requirement.window == ArbitraryNegativeWindow::AnteOne
        || requirement.window == ArbitraryNegativeWindow::SoulPack
        || requirement.window == ArbitraryNegativeWindow::SoulOrAnteTwo
        || deadline(requirement.window) > 0;
  }
  if (source == judgementSource) {
    if (legendary || !allowStartingPack) {
      return false;
    }
    return requirement.window == ArbitraryNegativeWindow::SoulPack
        || requirement.window == ArbitraryNegativeWindow::SoulOrAnteTwo
        || deadline(requirement.window) > 0;
  }
  if (legendary) {
    return false;
  }
  int ante = 0;
  for (int candidate = 1; candidate <= 8; ++candidate) {
    if (source == anteSource(candidate)) {
      ante = candidate;
      break;
    }
  }
  const int maximum = deadline(requirement.window);
  if (maximum > 0) {
    return ante > 0 && ante <= maximum;
  }
  switch (requirement.window) {
    case ArbitraryNegativeWindow::AnteOne: return ante == 1;
    case ArbitraryNegativeWindow::AnteTwo: return ante == 2;
    case ArbitraryNegativeWindow::SoulOrAnteTwo: return ante == 2;
    case ArbitraryNegativeWindow::AnteThree: return ante == 3;
    case ArbitraryNegativeWindow::AnteFour: return ante == 4;
    default: return false;
  }
}

ArbitraryNegativeRarity rarityOf(const JokerData& joker) {
  if (joker.rarity == Item::Rare) {
    return ArbitraryNegativeRarity::Rare;
  }
  if (joker.rarity == Item::Uncommon) {
    return ArbitraryNegativeRarity::Uncommon;
  }
  return ArbitraryNegativeRarity::Common;
}

struct ReferenceMatcher {
  const ArbitraryNegativeCriteria& criteria;
  std::array<bool, 1u << BRAINSTORM_ARBITRARY_NEGATIVE_MAX_REQUIREMENTS>
      reachable{};

  explicit ReferenceMatcher(const ArbitraryNegativeCriteria& criteriaRef)
      : criteria(criteriaRef) {
    reachable[0] = true;
  }

  void observe(unsigned int source, ArbitraryNegativeRarity rarity,
               bool negative) {
    if (!negative) {
      return;
    }
    const auto previous = reachable;
    const int subsetCount = 1 << criteria.requirementCount;
    for (int subset = 0; subset < subsetCount; ++subset) {
      if (!previous[static_cast<std::size_t>(subset)]) {
        continue;
      }
      for (int requirement = 0;
           requirement < criteria.requirementCount; ++requirement) {
        const int bit = 1 << requirement;
        const auto& target = criteria.requirements[
            static_cast<std::size_t>(requirement)];
        if ((subset & bit) == 0 && target.rarity == rarity
            && accepts(target, source, criteria.allowStartingPack)) {
          reachable[static_cast<std::size_t>(subset | bit)] = true;
        }
      }
    }
  }

  bool complete() const {
    return reachable[static_cast<std::size_t>(
        (1 << criteria.requirementCount) - 1)];
  }
};

Item deckFor(const ArbitraryNegativeCriteria& criteria) {
  switch (criteria.shopRate) {
    case ArbitraryNegativeShopRate::Ghost: return Item::Ghost_Deck;
    case ArbitraryNegativeShopRate::Zodiac: return Item::Zodiac_Deck;
    case ArbitraryNegativeShopRate::Ordinary: return Item::Red_Deck;
  }
  return Item::Red_Deck;
}

bool referencePasses(Seed seed,
                     const ArbitraryNegativeCriteria& criteria) {
  ReferenceMatcher matcher(criteria);
  if (criteria.allowStartingPack) {
    Instance starting(seed);
    starting.initLocks(1, false, true);
    starting.setDeck(deckFor(criteria));
    starting.setStake(Item::Gold_Stake);
    for (int selection = 0; selection < 2; ++selection) {
      const JokerData soul = starting.nextJoker(
          ItemSource::Soul, 1, JokerStickerGeneration::None);
      matcher.observe(
          soulSource, ArbitraryNegativeRarity::Legendary,
          soul.edition == Item::Negative);
    }
    const JokerData judgement = starting.nextJoker(
        ItemSource::Judgement, 1, JokerStickerGeneration::None);
    matcher.observe(
        judgementSource, rarityOf(judgement),
        judgement.edition == Item::Negative);
  }

  Instance instance(seed);
  instance.initLocks(1, false, true);
  instance.setDeck(deckFor(criteria));
  instance.setStake(Item::Gold_Stake);
  for (int ante = 1; ante <= criteria.maximumAnte; ++ante) {
    if (ante >= 2) {
      instance.initUnlocks(ante, false);
    }
    const int shopCount = ante == 1 ? criteria.anteOneShops : 3;
    for (int shop = 0; shop < shopCount; ++shop) {
      for (int card = 0; card < criteria.stockSize; ++card) {
        JokerData joker;
        if (instance.nextShopJokerOnly(
                ante, JokerStickerGeneration::None, joker)) {
          matcher.observe(
              anteSource(ante), rarityOf(joker),
              joker.edition == Item::Negative);
        }
      }
      for (int displayed = 0; displayed < 2; ++displayed) {
        const Pack pack = packInfo(instance.nextPack(ante));
        if (pack.type != Item::Buffoon_Pack
            && pack.type != Item::Jumbo_Buffoon_Pack
            && pack.type != Item::Mega_Buffoon_Pack) {
          continue;
        }
        for (int card = 0; card < pack.size; ++card) {
          const JokerData joker = instance.nextJoker(
              ItemSource::Buffoon_Pack, ante,
              JokerStickerGeneration::None);
          matcher.observe(
              anteSource(ante), rarityOf(joker),
              joker.edition == Item::Negative);
        }
      }
    }
  }
  return matcher.complete();
}

std::vector<std::uint32_t> referenceRange(
    long long startSeedId, std::size_t count,
    const ArbitraryNegativeCriteria& criteria) {
  std::vector<std::uint32_t> result;
  Seed seed(normalizeSeedId(startSeedId));
  for (std::size_t offset = 0; offset < count; ++offset) {
    if (referencePasses(seed, criteria)) {
      result.push_back(static_cast<std::uint32_t>(offset));
    }
    seed.next();
  }
  return result;
}

bool compareBackend(
    std::string_view label, long long startSeedId, std::size_t count,
    const ArbitraryNegativeCriteria& criteria,
    ArbitraryNegativeBackend backend,
    const std::vector<std::uint32_t>& expected) {
  if (!arbitraryNegativeBackendAvailable(backend)) {
    return true;
  }
  std::vector<std::uint32_t> actual;
  collectArbitraryNegativeCandidatesWithBackend(
      startSeedId, count, actual, criteria, backend);
  if (actual == expected && std::is_sorted(actual.begin(), actual.end())) {
    return true;
  }
  std::cerr << label << ": backend "
            << arbitraryNegativeBackendName(backend)
            << " expected " << expected.size() << " survivors, got "
            << actual.size() << std::endl;
  return false;
}

bool checkRange(std::string_view label, long long startSeedId,
                std::size_t count,
                const ArbitraryNegativeCriteria& criteria) {
  const auto encoded = encodeArbitraryNegativeCriteria(criteria);
  const auto decoded = decodeArbitraryNegativeCriteria(encoded);
  bool passed = encodeArbitraryNegativeCriteria(decoded) == encoded;
  const auto expected = referenceRange(startSeedId, count, criteria);
  for (ArbitraryNegativeBackend backend : {
           ArbitraryNegativeBackend::Scalar,
           ArbitraryNegativeBackend::Avx2,
           ArbitraryNegativeBackend::Avx512,
           ArbitraryNegativeBackend::Auto}) {
    passed &= compareBackend(
        label, startSeedId, count, criteria, backend, expected);
  }
  if (passed) {
    std::cout << label << ": " << count << " seeds, "
              << expected.size() << " survivors" << std::endl;
  }
  return passed;
}

ArbitraryNegativeCriteria one(
    ArbitraryNegativeRarity rarity, ArbitraryNegativeWindow window,
    int maximumAnte, ArbitraryNegativeShopRate rate =
        ArbitraryNegativeShopRate::Ordinary,
    bool starting = false) {
  ArbitraryNegativeCriteria result;
  result.requirements[0] = {rarity, window};
  result.requirementCount = 1;
  result.maximumAnte = maximumAnte;
  result.anteOneShops = starting ? 1 : 2;
  result.stockSize =
      rate == ArbitraryNegativeShopRate::Zodiac ? 3 : 2;
  result.shopRate = rate;
  result.allowStartingPack = starting;
  return result;
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
             + anteToString(1) == "edibuf1"
      && RandomType::Joker_Edition + ItemSource::Soul
             + anteToString(1) == "edisou1"
      && RandomType::Joker_Rarity + anteToString(1)
             + ItemSource::Judgement == "rarity1jud"
      && RandomType::Joker_Edition + ItemSource::Judgement
             + anteToString(1) == "edijud1";
  if (!passed) {
    std::cerr << "arbitrary Negative batch key constants drifted"
              << std::endl;
  }
  return passed;
}

}  // namespace

int main() {
  bool passed = checkRuntimeKeys();
  passed &= checkRange(
      "common ante one", 1000000000000ll, (1u << 17) + 13,
      one(ArbitraryNegativeRarity::Common,
          ArbitraryNegativeWindow::AnteOne, 1));
  passed &= checkRange(
      "rare by ante four Ghost", 1000000200003ll, (1u << 15) + 7,
      one(ArbitraryNegativeRarity::Rare,
          ArbitraryNegativeWindow::ByAnteFour, 4,
          ArbitraryNegativeShopRate::Ghost));
  passed &= checkRange(
      "uncommon by ante eight Zodiac", 1000000400007ll,
      (1u << 14) + 9,
      one(ArbitraryNegativeRarity::Uncommon,
          ArbitraryNegativeWindow::ByAnteEight, 8,
          ArbitraryNegativeShopRate::Zodiac));
  passed &= checkRange(
      "legendary starting Soul", 1000000600011ll, (1u << 16) + 5,
      one(ArbitraryNegativeRarity::Legendary,
          ArbitraryNegativeWindow::SoulPack, 1,
          ArbitraryNegativeShopRate::Ordinary, true));
  passed &= checkRange(
      "rare Judgement or ante two", 1000000800013ll, (1u << 16) + 3,
      one(ArbitraryNegativeRarity::Rare,
          ArbitraryNegativeWindow::SoulOrAnteTwo, 2,
          ArbitraryNegativeShopRate::Ordinary, true));

  ArbitraryNegativeCriteria multiple = one(
      ArbitraryNegativeRarity::Rare,
      ArbitraryNegativeWindow::ByAnteFour, 6,
      ArbitraryNegativeShopRate::Ghost);
  multiple.requirements[1] = {
      ArbitraryNegativeRarity::Uncommon,
      ArbitraryNegativeWindow::ByAnteSix};
  multiple.requirementCount = 2;
  passed &= checkRange(
      "two distinct Negative events", 1000001000017ll,
      (1u << 15) + 11, multiple);

  const auto awkward = one(
      ArbitraryNegativeRarity::Rare,
      ArbitraryNegativeWindow::ByAnteTwo, 2);
  for (std::size_t count : {
           std::size_t{0}, std::size_t{1}, std::size_t{3},
           std::size_t{7}, std::size_t{8}, std::size_t{9},
           std::size_t{4093}, std::size_t{4096},
           std::size_t{4099}}) {
    passed &= checkRange(
        "awkward count", SEED_DOMAIN_SIZE - 37, count, awkward);
  }
  passed &= checkRange(
      "negative start", -11, 137, awkward);

  if (!passed) {
    return EXIT_FAILURE;
  }
  std::cout << "arbitrary Negative batch regression passed" << std::endl;
  return EXIT_SUCCESS;
}
