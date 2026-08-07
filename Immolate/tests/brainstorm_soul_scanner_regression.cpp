#include "functions.hpp"

#include <cstdlib>
#include <iostream>

namespace {

bool check(bool condition, const char* description) {
    if (!condition) {
        std::cerr << "failed: " << description << std::endl;
    }
    return condition;
}

} // namespace

int main() {
    bool passed = true;

    const std::array<Item, 2> distinctEternalTargets = {
        Item::Reserved_Parking, Item::Blueprint};
    const std::array<Item, 2> duplicateEternalTargets = {
        Item::Reserved_Parking, Item::Reserved_Parking};
    const std::array<Item, 3> duplicateInvisibleTargets = {
        Item::Invisible_Joker, Item::Blueprint, Item::Invisible_Joker};
    passed &= check(
        !jokerTargetsMayNeedEternalAwareSelling(
            distinctEternalTargets.data(), distinctEternalTargets.size(),
            Item::Gold_Stake),
        "distinct targets do not need timeline sticker generation");
    passed &= check(
        !jokerTargetsMayNeedEternalAwareSelling(
            duplicateEternalTargets.data(), duplicateEternalTargets.size(),
            Item::White_Stake),
        "White stake never needs Eternal-aware duplicate selling");
    passed &= check(
        jokerTargetsMayNeedEternalAwareSelling(
            duplicateEternalTargets.data(), duplicateEternalTargets.size(),
            Item::Gold_Stake),
        "Gold duplicate Eternal-compatible targets retain sticker generation");
    passed &= check(
        !jokerTargetsMayNeedEternalAwareSelling(
            duplicateInvisibleTargets.data(),
            duplicateInvisibleTargets.size(), Item::Gold_Stake),
        "duplicate Invisible Joker remains safe for sticker elision");

    Seed vanillaSeed("6EB11111");
    Instance vanilla(vanillaSeed);
    const ArcanaSoulPackResult vanillaPack =
        vanilla.scanArcanaPackForSoulJokers(5, 1, false);
    passed &= check(
        vanillaPack.soulCount == 1,
        "vanilla Soul lock permits only the first natural Soul roll");
    passed &= check(
        vanillaPack.soulJokers.size() == 1
            && vanillaPack.soulJokers[0].joker == Item::Chicot,
        "the first Soul has the expected ordered legendary outcome");

    Seed duplicateSeed("6EB11111");
    Instance duplicateSouls(duplicateSeed);
    const ArcanaSoulPackResult duplicatePack =
        duplicateSouls.scanArcanaPackForSoulJokers(5, 1, true);
    passed &= check(
        duplicatePack.soulCount == 2,
        "the filtered Charm pack preserves a second natural Soul roll");
    passed &= check(
        duplicatePack.soulJokers.size() == 2,
        "one ordered legendary outcome is generated per Soul");
    passed &= check(
        duplicatePack.soulJokers[0].joker == Item::Chicot
            && duplicatePack.soulJokers[1].joker == Item::Canio,
        "legendary outcomes advance in Soul-use order");
    passed &= check(
        duplicatePack.soulJokers[0].joker
            != duplicatePack.soulJokers[1].joker,
        "the first legendary is locked before the second draw");

    Seed rawShopSeed("68111111");
    Instance rawShop(rawShopSeed);
    rawShop.initLocks(1, false, true);
    ShopItem rawShopItems[4];
    for (ShopItem& item : rawShopItems) {
        item = rawShop.nextShopItem(1, false);
    }
    passed &= check(
        rawShopItems[2].type == Item::T_Joker
            && rawShopItems[3].type == Item::T_Joker
            && rawShopItems[2].jokerData.joker == Item::Popcorn
            && rawShopItems[3].jokerData.joker == Item::Popcorn,
        "the fixture forces a duplicate Joker in one visible shop window");

    Seed standardShopSeed("68111111");
    Instance standardShop(standardShopSeed);
    standardShop.initLocks(1, false, true);
    const std::vector<ShopItem> standardShopItems =
        standardShop.nextShopItems(4, 1, false);
    passed &= check(
        standardShopItems.size() == 4
            && standardShopItems[2].jokerData.joker == Item::Popcorn
            && standardShopItems[3].jokerData.joker == Item::Lusty_Joker,
        "visible Jokers are transiently locked within a two-card shop");
    passed &= check(
        !standardShop.isLocked(Item::Popcorn)
            && !standardShop.isLocked(Item::Lusty_Joker),
        "shop-window Joker locks are cleared after generation");

    Seed rerollBoundarySeed("33111111");
    Instance rerollBoundary(rerollBoundarySeed);
    rerollBoundary.initLocks(1, false, true);
    const std::vector<ShopItem> rerollBoundaryItems =
        rerollBoundary.nextShopItems(4, 1, false);
    passed &= check(
        rerollBoundaryItems[1].jokerData.joker == Item::Popcorn
            && rerollBoundaryItems[2].jokerData.joker == Item::Popcorn,
        "a reroll clears locks from the preceding two-card shop");

    Seed overstockSeed("33111111");
    Instance overstockShop(overstockSeed);
    overstockShop.initLocks(1, false, true);
    overstockShop.activateVoucher(Item::Overstock);
    const std::vector<ShopItem> overstockItems =
        overstockShop.nextShopItems(4, 1, false);
    passed &= check(
        overstockItems[1].jokerData.joker == Item::Popcorn
            && overstockItems[2].jokerData.joker == Item::Lusty_Joker,
        "Overstock expands the visible shop window to three cards");

    Seed eternalShopSeed("WYIBD111");
    Instance eternalShop(eternalShopSeed);
    eternalShop.initLocks(1, false, true);
    eternalShop.setStake(Item::Gold_Stake);
    const JokerData eternalShopJoker =
        eternalShop.nextJoker(ItemSource::Shop, 1, true);
    passed &= check(
        eternalShopJoker.joker == Item::Reserved_Parking
            && eternalShopJoker.stickers.eternal
            && !eternalShopJoker.stickers.perishable
            && !eternalShopJoker.stickers.rental,
        "Gold shop Jokers use the shop Eternal/sticker RNG source");

    Seed sellableShopSeed("1C111111");
    Instance sellableShop(sellableShopSeed);
    sellableShop.initLocks(1, false, true);
    sellableShop.setStake(Item::Gold_Stake);
    const JokerData sellableShopJoker =
        sellableShop.nextJoker(ItemSource::Shop, 1, true);
    passed &= check(
        sellableShopJoker.joker == Item::Reserved_Parking
            && !sellableShopJoker.stickers.eternal
            && sellableShopJoker.stickers.perishable
            && sellableShopJoker.stickers.rental,
        "Gold shop Jokers retain independent perishable and rental stickers");

    Seed buffoonStickerSeed("");
    Instance buffoonSticker(buffoonStickerSeed);
    buffoonSticker.initLocks(1, false, true);
    buffoonSticker.setStake(Item::Gold_Stake);
    const JokerData buffoonStickerJoker =
        buffoonSticker.nextJoker(ItemSource::Buffoon_Pack, 1, true);
    passed &= check(
        buffoonStickerJoker.joker == Item::Even_Steven
            && !buffoonStickerJoker.stickers.eternal
            && buffoonStickerJoker.stickers.perishable
            && !buffoonStickerJoker.stickers.rental,
        "Gold Buffoon Jokers use the pack-specific sticker RNG source");

    Seed invisibleExemptionSeed("U1611111");
    Instance invisiblePoll(invisibleExemptionSeed);
    const double invisibleEternalPoll = invisiblePoll.random(
        RandomType::Eternal_Perishable_Pack + anteToString(1));
    Instance invisibleExemption(invisibleExemptionSeed);
    invisibleExemption.initLocks(1, false, true);
    invisibleExemption.setStake(Item::Gold_Stake);
    const JokerData invisibleJoker =
        invisibleExemption.nextJoker(
            ItemSource::Buffoon_Pack, 1, true);
    passed &= check(
        invisibleJoker.joker == Item::Invisible_Joker
            && invisibleEternalPoll > 0.7
            && !invisibleJoker.stickers.eternal,
        "Invisible Joker remains exempt from Eternal at Gold stake");

    Seed stickerFreeSeed("WYIBD111");
    Instance soulSource(stickerFreeSeed);
    soulSource.setStake(Item::Gold_Stake);
    const JokerData soulJoker =
        soulSource.nextJoker(ItemSource::Soul, 1, false);
    Instance judgementSource(stickerFreeSeed);
    judgementSource.setStake(Item::Gold_Stake);
    const JokerData judgementJoker =
        judgementSource.nextJoker(ItemSource::Judgement, 1, false);
    passed &= check(
        !soulJoker.stickers.eternal
            && !soulJoker.stickers.perishable
            && !soulJoker.stickers.rental
            && !judgementJoker.stickers.eternal
            && !judgementJoker.stickers.perishable
            && !judgementJoker.stickers.rental,
        "Soul and Judgement Joker creation remains sticker-free");

    return passed ? EXIT_SUCCESS : EXIT_FAILURE;
}
