#include "functions.hpp"

#include <array>
#include <cstddef>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

namespace {

struct Scenario {
  const char *label;
  long long startSeedId;
  std::size_t count;
  Item deck;
  Item stake;
  bool magicTrick;
};

bool sameJoker(const JokerData &left, const JokerData &right) {
  return left.joker == right.joker
      && left.rarity == right.rarity
      && left.edition == right.edition
      && left.stickers.eternal == right.stickers.eternal
      && left.stickers.perishable == right.stickers.perishable
      && left.stickers.rental == right.stickers.rental;
}

bool sameJokerIdentity(const JokerData &left, const JokerData &right) {
  return left.joker == right.joker
      && left.rarity == right.rarity
      && left.edition == right.edition;
}

bool hasSticker(const JokerData &joker) {
  return joker.stickers.eternal
      || joker.stickers.perishable
      || joker.stickers.rental;
}

bool sameJokers(const std::vector<JokerData> &left,
                const std::vector<JokerData> &right) {
  if (left.size() != right.size()) {
    return false;
  }
  for (std::size_t index = 0; index < left.size(); ++index) {
    if (!sameJoker(left[index], right[index])) {
      return false;
    }
  }
  return true;
}

bool isBuffoon(Item item) {
  return item == Item::Buffoon_Pack
      || item == Item::Jumbo_Buffoon_Pack
      || item == Item::Mega_Buffoon_Pack;
}

bool fail(const Scenario &scenario, Seed &seed, int ante,
          const char *description) {
  std::cerr << "Joker-only shop mismatch in " << scenario.label
            << " at seed " << seed.tostring()
            << ", ante " << ante << ": " << description << std::endl;
  return false;
}

bool compareScenario(const Scenario &scenario) {
  Seed genericSeed(normalizeSeedId(scenario.startSeedId));
  Seed specializedSeed(normalizeSeedId(scenario.startSeedId));
  std::size_t seedsWithSkippedIdentityNodes = 0;

  for (std::size_t offset = 0; offset < scenario.count; ++offset) {
    Instance generic(genericSeed);
    Instance specialized(specializedSeed);
    generic.initLocks(1, false, true);
    specialized.initLocks(1, false, true);
    generic.setDeck(scenario.deck);
    specialized.setDeck(scenario.deck);
    generic.setStake(scenario.stake);
    specialized.setStake(scenario.stake);
    if (scenario.magicTrick) {
      generic.activateVoucher(Item::Magic_Trick);
      specialized.activateVoucher(Item::Magic_Trick);
    }

    // Locked consumables exercise generic randchoice resampling. The
    // specialized path may skip those private streams, but all observable
    // Joker/timeline state must remain identical.
    generic.lock(Item::The_Fool);
    specialized.lock(Item::The_Fool);
    generic.lock(Item::Pluto);
    specialized.lock(Item::Pluto);

    for (int ante = 1; ante <= 8; ++ante) {
      if (ante > 1) {
        generic.initUnlocks(ante, false);
        specialized.initUnlocks(ante, false);
      }
      const int windowSize = 2
          + (generic.isVoucherActive(Item::Overstock) ? 1 : 0)
          + (generic.isVoucherActive(Item::Overstock_Plus) ? 1 : 0);

      for (int shop = 0; shop < 3; ++shop) {
        std::array<Item, 4> genericTransient{};
        std::array<Item, 4> specializedTransient{};
        int genericTransientCount = 0;
        int specializedTransientCount = 0;

        for (int card = 0; card < windowSize; ++card) {
          const ShopItem full = generic.nextShopItem(ante, true);
          JokerData jokerOnly;
          const bool foundJoker = specialized.nextShopJokerOnly(
              ante, true, jokerOnly);
          if ((full.type == Item::T_Joker) != foundJoker) {
            return fail(
                scenario, genericSeed, ante, "card-type/Joker decision");
          }
          if (foundJoker && !sameJoker(full.jokerData, jokerOnly)) {
            return fail(scenario, genericSeed, ante, "JokerData");
          }
          if (foundJoker && !generic.params.showman) {
            generic.lockTransient(full.jokerData.joker);
            specialized.lockTransient(jokerOnly.joker);
            genericTransient[genericTransientCount++] =
                full.jokerData.joker;
            specializedTransient[specializedTransientCount++] =
                jokerOnly.joker;
          }
        }
        for (int index = 0; index < genericTransientCount; ++index) {
          generic.unlockTransient(genericTransient[index]);
        }
        for (int index = 0; index < specializedTransientCount; ++index) {
          specialized.unlockTransient(specializedTransient[index]);
        }
        if (generic.locked != specialized.locked) {
          return fail(scenario, genericSeed, ante, "post-shop locks");
        }

        for (int packIndex = 0; packIndex < 2; ++packIndex) {
          const Item genericPack = generic.nextPack(ante);
          const Item specializedPack = specialized.nextPack(ante);
          if (genericPack != specializedPack) {
            return fail(scenario, genericSeed, ante, "pack stream");
          }
          if (isBuffoon(genericPack)) {
            const int size = packInfo(genericPack).size;
            if (!sameJokers(
                    generic.nextBuffoonPack(size, ante),
                    specialized.nextBuffoonPack(size, ante))) {
              return fail(
                  scenario, genericSeed, ante, "Buffoon Joker stream");
            }
          }
        }
      }
    }

    if (generic.cache.nodes.size() > specialized.cache.nodes.size()) {
      ++seedsWithSkippedIdentityNodes;
    }
    if (generic.locked != specialized.locked
        || generic.cache.generatedFirstPack
            != specialized.cache.generatedFirstPack) {
      return fail(scenario, genericSeed, 8, "final timeline state");
    }

    if (!sameJoker(
            generic.nextJoker(ItemSource::Shop, 8, true),
            specialized.nextJoker(ItemSource::Shop, 8, true))) {
      return fail(scenario, genericSeed, 8, "subsequent shop Joker stream");
    }
    if (!sameJoker(
            generic.nextJoker(ItemSource::Buffoon_Pack, 8, true),
            specialized.nextJoker(ItemSource::Buffoon_Pack, 8, true))) {
      return fail(
          scenario, genericSeed, 8, "subsequent Buffoon Joker stream");
    }
    if (generic.nextPack(8) != specialized.nextPack(8)) {
      return fail(scenario, genericSeed, 8, "subsequent pack stream");
    }
    if (generic.nextVoucher(8) != specialized.nextVoucher(8)) {
      return fail(scenario, genericSeed, 8, "subsequent voucher stream");
    }
    if (generic.nextTag(8) != specialized.nextTag(8)) {
      return fail(scenario, genericSeed, 8, "subsequent tag stream");
    }

    const ShopItem finalFull = generic.nextShopItem(8, true);
    JokerData finalJoker;
    const bool finalFound = specialized.nextShopJokerOnly(
        8, true, finalJoker);
    if ((finalFull.type == Item::T_Joker) != finalFound
        || (finalFound && !sameJoker(finalFull.jokerData, finalJoker))) {
      return fail(scenario, genericSeed, 8, "subsequent shop draw");
    }

    genericSeed.next();
    specializedSeed.next();
  }

  if (seedsWithSkippedIdentityNodes == 0) {
    std::cerr << "Joker-only shop test did not skip an identity node in "
              << scenario.label << std::endl;
    return false;
  }
  std::cout << "Joker-only shop exact in " << scenario.label << ": "
            << scenario.count << " seeds; skipped identities in "
            << seedsWithSkippedIdentityNodes << std::endl;
  return true;
}

bool compareStickerElisionTimeline() {
  Seed fullSeed(normalizeSeedId(918273645));
  Seed elidedSeed(normalizeSeedId(918273645));
  std::size_t suppressedStickerJokers = 0;
  std::size_t smallerNodeCaches = 0;

  for (std::size_t offset = 0; offset < 4096; ++offset) {
    Instance full(fullSeed);
    Instance elided(elidedSeed);
    full.initLocks(1, false, true);
    elided.initLocks(1, false, true);
    full.setDeck(Item::Plasma_Deck);
    elided.setDeck(Item::Plasma_Deck);
    full.setStake(Item::Gold_Stake);
    elided.setStake(Item::Gold_Stake);
    full.activateVoucher(Item::Overstock);
    elided.activateVoucher(Item::Overstock);

    for (int ante = 1; ante <= 4; ++ante) {
      if (ante > 1) {
        full.initUnlocks(ante, false);
        elided.initUnlocks(ante, false);
      }
      for (int shop = 0; shop < 3; ++shop) {
        std::array<Item, 4> fullTransient{};
        std::array<Item, 4> elidedTransient{};
        int fullTransientCount = 0;
        int elidedTransientCount = 0;

        for (int card = 0; card < 3; ++card) {
          JokerData fullJoker;
          JokerData elidedJoker;
          const bool fullFound =
              full.nextShopJokerOnly(ante, true, fullJoker);
          const bool elidedFound =
              elided.nextShopJokerOnly(
                  ante, JokerStickerGeneration::None, elidedJoker);
          if (fullFound != elidedFound
              || (fullFound
                  && !sameJokerIdentity(fullJoker, elidedJoker))) {
            std::cerr << "Sticker elision changed shop identity at seed "
                      << fullSeed.tostring() << ", ante " << ante
                      << std::endl;
            return false;
          }
          if (fullFound) {
            if (hasSticker(fullJoker)) {
              ++suppressedStickerJokers;
            }
            if (hasSticker(elidedJoker)) {
              std::cerr << "Sticker-free shop draw produced a sticker"
                        << std::endl;
              return false;
            }
            full.lockTransient(fullJoker.joker);
            elided.lockTransient(elidedJoker.joker);
            fullTransient[fullTransientCount++] = fullJoker.joker;
            elidedTransient[elidedTransientCount++] = elidedJoker.joker;
          }
        }
        for (int index = 0; index < fullTransientCount; ++index) {
          full.unlockTransient(fullTransient[index]);
        }
        for (int index = 0; index < elidedTransientCount; ++index) {
          elided.unlockTransient(elidedTransient[index]);
        }
        if (full.locked != elided.locked) {
          std::cerr << "Sticker elision changed transient shop locks"
                    << std::endl;
          return false;
        }

        for (int packIndex = 0; packIndex < 2; ++packIndex) {
          const Item fullPack = full.nextPack(ante);
          const Item elidedPack = elided.nextPack(ante);
          if (fullPack != elidedPack) {
            std::cerr << "Sticker elision changed displayed packs"
                      << std::endl;
            return false;
          }
          if (!isBuffoon(fullPack)) {
            continue;
          }

          std::array<Item, 8> fullPackTransient{};
          std::array<Item, 8> elidedPackTransient{};
          int fullPackTransientCount = 0;
          int elidedPackTransientCount = 0;
          const int size = packInfo(fullPack).size;
          for (int card = 0; card < size; ++card) {
            const JokerData fullJoker =
                full.nextJoker(ItemSource::Buffoon_Pack, ante, true);
            const JokerData elidedJoker =
                elided.nextJoker(
                    ItemSource::Buffoon_Pack, ante,
                    JokerStickerGeneration::None);
            if (!sameJokerIdentity(fullJoker, elidedJoker)) {
              std::cerr << "Sticker elision changed Buffoon identity"
                        << std::endl;
              return false;
            }
            if (hasSticker(fullJoker)) {
              ++suppressedStickerJokers;
            }
            if (hasSticker(elidedJoker)) {
              std::cerr << "Sticker-free Buffoon draw produced a sticker"
                        << std::endl;
              return false;
            }
            full.lockTransient(fullJoker.joker);
            elided.lockTransient(elidedJoker.joker);
            fullPackTransient[fullPackTransientCount++] = fullJoker.joker;
            elidedPackTransient[elidedPackTransientCount++] =
                elidedJoker.joker;
          }
          for (int index = 0; index < fullPackTransientCount; ++index) {
            full.unlockTransient(fullPackTransient[index]);
          }
          for (int index = 0; index < elidedPackTransientCount; ++index) {
            elided.unlockTransient(elidedPackTransient[index]);
          }
          if (full.locked != elided.locked) {
            std::cerr << "Sticker elision changed transient Buffoon locks"
                      << std::endl;
            return false;
          }
        }
      }
    }

    if (full.cache.nodes.size() > elided.cache.nodes.size()) {
      ++smallerNodeCaches;
    }

    // Sticker streams intentionally have different positions. Every other
    // keyed stream used after the timeline must remain identical.
    if (full.nextPack(8) != elided.nextPack(8)
        || full.nextVoucher(8) != elided.nextVoucher(8)
        || full.nextTag(8) != elided.nextTag(8)) {
      std::cerr << "Sticker elision changed an independent future RNG stream"
                << std::endl;
      return false;
    }
    JokerData fullFutureShop;
    JokerData elidedFutureShop;
    const bool fullFutureFound =
        full.nextShopJokerOnly(8, false, fullFutureShop);
    const bool elidedFutureFound =
        elided.nextShopJokerOnly(8, false, elidedFutureShop);
    if (fullFutureFound != elidedFutureFound
        || (fullFutureFound
            && !sameJokerIdentity(fullFutureShop, elidedFutureShop))) {
      std::cerr << "Sticker elision changed a future shop identity"
                << std::endl;
      return false;
    }
    if (!sameJokerIdentity(
            full.nextJoker(ItemSource::Buffoon_Pack, 8, false),
            elided.nextJoker(ItemSource::Buffoon_Pack, 8, false))) {
      std::cerr << "Sticker elision changed a future Buffoon identity"
                << std::endl;
      return false;
    }

    fullSeed.next();
    elidedSeed.next();
  }

  if (suppressedStickerJokers == 0 || smallerNodeCaches == 0) {
    std::cerr << "Sticker elision coverage did not observe suppressed state"
              << std::endl;
    return false;
  }
  std::cout << "Sticker elision exact across 4096 Gold-stake timelines; "
            << suppressedStickerJokers << " stickers suppressed"
            << std::endl;
  return true;
}

bool compareEternalOnlyStickerMode() {
  Seed fullSeed(normalizeSeedId(192837465));
  Seed eternalOnlySeed(normalizeSeedId(192837465));
  std::size_t omittedSupplementalStickers = 0;

  for (std::size_t offset = 0; offset < 4096; ++offset) {
    Instance full(fullSeed);
    Instance eternalOnly(eternalOnlySeed);
    full.initLocks(1, false, true);
    eternalOnly.initLocks(1, false, true);
    full.setStake(Item::Gold_Stake);
    eternalOnly.setStake(Item::Gold_Stake);

    for (int ante = 1; ante <= 8; ++ante) {
      if (ante > 1) {
        full.initUnlocks(ante, false);
        eternalOnly.initUnlocks(ante, false);
      }
      for (const std::string *source :
           {&ItemSource::Shop, &ItemSource::Buffoon_Pack}) {
        const JokerData fullJoker = full.nextJoker(*source, ante, true);
        const JokerData eternalOnlyJoker = eternalOnly.nextJoker(
            *source, ante, JokerStickerGeneration::EternalOnly);
        if (!sameJokerIdentity(fullJoker, eternalOnlyJoker)
            || fullJoker.stickers.eternal
                != eternalOnlyJoker.stickers.eternal) {
          std::cerr << "Eternal-only mode changed an Eternal decision at seed "
                    << fullSeed.tostring() << ", ante " << ante
                    << std::endl;
          return false;
        }
        if (eternalOnlyJoker.stickers.perishable
            || eternalOnlyJoker.stickers.rental) {
          std::cerr << "Eternal-only mode retained an unused sticker"
                    << std::endl;
          return false;
        }
        if (fullJoker.stickers.perishable
            || fullJoker.stickers.rental) {
          ++omittedSupplementalStickers;
        }
      }
    }

    // Eternal-only mode advances exactly the same Eternal/Perishable poll
    // nodes. Only the independent rental nodes are intentionally omitted.
    if (full.random(RandomType::Eternal_Perishable + anteToString(8))
            != eternalOnly.random(
                RandomType::Eternal_Perishable + anteToString(8))
        || full.random(
               RandomType::Eternal_Perishable_Pack + anteToString(8))
            != eternalOnly.random(
                RandomType::Eternal_Perishable_Pack + anteToString(8))
        || full.nextPack(8) != eternalOnly.nextPack(8)
        || full.nextVoucher(8) != eternalOnly.nextVoucher(8)
        || full.nextTag(8) != eternalOnly.nextTag(8)) {
      std::cerr << "Eternal-only mode changed required future RNG state"
                << std::endl;
      return false;
    }

    fullSeed.next();
    eternalOnlySeed.next();
  }

  if (omittedSupplementalStickers == 0) {
    std::cerr << "Eternal-only coverage omitted no supplemental stickers"
              << std::endl;
    return false;
  }
  std::cout << "Eternal-only sticker decisions exact across 4096 seeds; "
            << omittedSupplementalStickers
            << " supplemental stickers omitted" << std::endl;
  return true;
}

} // namespace

int main() {
  const std::array<Scenario, 5> scenarios = {{
      {"Red/White base range", 0, 4096,
       Item::Red_Deck, Item::White_Stake, false},
      {"Ghost/Gold mixed shop", 1234567890123ll, 4096,
       Item::Ghost_Deck, Item::Gold_Stake, false},
      {"Zodiac/Orange carry", idCoeff[0] - 2048, 4096,
       Item::Zodiac_Deck, Item::Orange_Stake, false},
      {"Plasma/Black domain wrap", SEED_DOMAIN_SIZE - 2048, 4096,
       Item::Plasma_Deck, Item::Black_Stake, false},
      {"Magic Trick playing cards", -1024, 2048,
       Item::Magic_Deck, Item::Gold_Stake, true},
  }};

  bool passed = true;
  for (const Scenario &scenario : scenarios) {
    passed &= compareScenario(scenario);
  }
  passed &= compareStickerElisionTimeline();
  passed &= compareEternalOnlyStickerMode();
  return passed ? EXIT_SUCCESS : EXIT_FAILURE;
}
