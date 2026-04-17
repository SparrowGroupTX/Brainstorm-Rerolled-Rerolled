#include "functions.hpp"
#include"immolate.hpp"
#include "search.hpp"
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <thread>

Item BRAINSTORM_PACK = Item::RETRY;
Item BRAINSTORM_TAG = Item::Charm_Tag;
Item BRAINSTORM_VOUCHER = Item::RETRY;
double BRAINSTORM_SOULS = 1;
bool BRAINSTORM_OBSERVATORY = false;
bool BRAINSTORM_PERKEO = false;
bool BRAINSTORM_EARLYCOPY = false; 
bool BRAINSTORM_RETCON = false;
bool BRAINSTORM_ANTE8_BEAN = false;
bool BRAINSTORM_ANTE6_BURGLAR = false;
customFilters BRAINSTORM_FILTER = customFilters::NO_FILTER;
Item BRAINSTORM_TARGET_RANK = Item::King;
Item BRAINSTORM_TARGET_SUIT = Item::RETRY;
int BRAINSTORM_SPECIFIC_RANK_MIN = 0;
int BRAINSTORM_ANY_RANK_MIN = 0;
unsigned short BRAINSTORM_TARGET_RANK_MASK = 0;

enum class BrainstormRankTargetMode {
    Single,
    KingsOrQueens,
    Royals,
};

BrainstormRankTargetMode BRAINSTORM_TARGET_RANK_MODE =
    BrainstormRankTargetMode::Single;

int rankToCardIndex(Item rank) {
    switch (rank) {
        case Item::_2:
            return 0;
        case Item::_3:
            return 1;
        case Item::_4:
            return 2;
        case Item::_5:
            return 3;
        case Item::_6:
            return 4;
        case Item::_7:
            return 5;
        case Item::_8:
            return 6;
        case Item::_9:
            return 7;
        case Item::Ace:
            return 8;
        case Item::Jack:
            return 9;
        case Item::King:
            return 10;
        case Item::Queen:
            return 11;
        case Item::_10:
            return 12;
        default:
            return -1;
    }
}

int suitToCardIndex(Item suit) {
    switch (suit) {
        case Item::Clubs:
            return 0;
        case Item::Diamonds:
            return 1;
        case Item::Hearts:
            return 2;
        case Item::Spades:
            return 3;
        default:
            return -1;
    }
}

int clampErraticCardIndex(double roll) {
    if (std::isnan(roll)) {
        return 51;
    }

    int cardIndex = static_cast<int>(std::floor(roll * 52.0));
    if (cardIndex < 0) {
        return 0;
    }
    if (cardIndex > 51) {
        return 51;
    }
    return cardIndex;
}

double nextErraticNode(double erraticNode) {
    return round13(fract(erraticNode * 1.72431234 + 2.134453429141));
}

int nextErraticCardIndex(double& erraticNode, double hashedSeed) {
    erraticNode = nextErraticNode(erraticNode);
    LuaRandom rng((erraticNode + hashedSeed) / 2.0);
    return clampErraticCardIndex(rng.random());
}

bool isRoyalRankIndex(int rankIndex) {
    return rankIndex == 8 || rankIndex == 9 || rankIndex == 10
        || rankIndex == 11 || rankIndex == 12;
}

bool matchesSpecificRankTarget(int rankIndex) {
    return rankIndex >= 0
        && (BRAINSTORM_TARGET_RANK_MASK & (1u << rankIndex)) != 0;
}

void setBrainstormTargetRank(const std::string& targetRank) {
    if (targetRank == "Kings or Queens") {
        BRAINSTORM_TARGET_RANK_MODE = BrainstormRankTargetMode::KingsOrQueens;
        BRAINSTORM_TARGET_RANK = Item::King;
        BRAINSTORM_TARGET_RANK_MASK =
            (1u << rankToCardIndex(Item::King))
            | (1u << rankToCardIndex(Item::Queen));
        return;
    }
    if (targetRank == "Royals") {
        BRAINSTORM_TARGET_RANK_MODE = BrainstormRankTargetMode::Royals;
        BRAINSTORM_TARGET_RANK = Item::King;
        BRAINSTORM_TARGET_RANK_MASK =
            (1u << rankToCardIndex(Item::Ace))
            | (1u << rankToCardIndex(Item::Jack))
            | (1u << rankToCardIndex(Item::King))
            | (1u << rankToCardIndex(Item::Queen))
            | (1u << rankToCardIndex(Item::_10));
        return;
    }

    BRAINSTORM_TARGET_RANK_MODE = BrainstormRankTargetMode::Single;
    BRAINSTORM_TARGET_RANK = stringToItem(targetRank);
    const int rankIndex = rankToCardIndex(BRAINSTORM_TARGET_RANK);
    BRAINSTORM_TARGET_RANK_MASK = rankIndex >= 0 ? (1u << rankIndex) : 0;
}

bool passesRankCountFilters(Seed& seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::RankPrefilter);
    auto finish = [](bool result) {
        BrainstormPerfStats::instance().noteRankPrefilter(result);
        return result;
    };

    const bool specificFilterEnabled = BRAINSTORM_SPECIFIC_RANK_MIN > 0;
    const bool anyRankFilterEnabled = BRAINSTORM_ANY_RANK_MIN > 0;
    if (!specificFilterEnabled && !anyRankFilterEnabled) {
        return finish(true);
    }

    const int targetSuitIndex = suitToCardIndex(BRAINSTORM_TARGET_SUIT);
    const bool specificFilterPossible =
        specificFilterEnabled && BRAINSTORM_TARGET_RANK_MASK != 0;
    if (!specificFilterPossible && !anyRankFilterEnabled) {
        return finish(false);
    }

    const double hashedSeed = seed.pseudohash(0);
    double erraticNode = pseudohash_from(RandomType::Erratic, seed.pseudohash((int)RandomType::Erratic.size()));
    uint8_t rankCounts[13] = { 0 };
    int specificCount = 0;
    int bestAnyRankCount = 0;
    const bool anySuitTarget = targetSuitIndex < 0;
    for (int i = 0; i < 52; i++) {
        int cardIndex = nextErraticCardIndex(erraticNode, hashedSeed);
        int rankIndex = cardIndex % 13;

        rankCounts[rankIndex]++;
        if (rankCounts[rankIndex] > bestAnyRankCount) {
            bestAnyRankCount = rankCounts[rankIndex];
        }

        if (specificFilterPossible && matchesSpecificRankTarget(rankIndex)) {
            if (anySuitTarget) {
                specificCount++;
            } else {
                int suitIndex = cardIndex / 13;
                if (targetSuitIndex == suitIndex) {
                    specificCount++;
                }
            }
        }

        if (specificFilterPossible && specificCount >= BRAINSTORM_SPECIFIC_RANK_MIN) {
            return finish(true);
        }
        if (anyRankFilterEnabled && bestAnyRankCount >= BRAINSTORM_ANY_RANK_MIN) {
            return finish(true);
        }

        const int remainingCards = 51 - i;
        const bool specificStillPossible = specificFilterPossible
            && specificCount + remainingCards >= BRAINSTORM_SPECIFIC_RANK_MIN;
        const bool anyRankStillPossible = anyRankFilterEnabled
            && bestAnyRankCount + remainingCards >= BRAINSTORM_ANY_RANK_MIN;
        if (!specificStillPossible && !anyRankStillPossible) {
            return finish(false);
        }
    }

    return finish(false);
}

int normalizeBrainstormSearchThreads(unsigned int detectedThreads) {
    if (detectedThreads == 0) {
        return 12;
    }
    if (detectedThreads > 24) {
        detectedThreads -= 4;
    }
    return static_cast<int>(detectedThreads);
}

int getBrainstormSearchThreads() {
    const char* envValue = std::getenv("BRAINSTORM_THREADS");
    if (envValue != nullptr) {
        char* end = nullptr;
        long parsed = std::strtol(envValue, &end, 10);
        if (end != envValue && *end == '\0' && parsed > 0 && parsed <= std::numeric_limits<int>::max()) {
            return static_cast<int>(parsed);
        }
    }

    return normalizeBrainstormSearchThreads(std::thread::hardware_concurrency());
}

long long parsePositiveEnvLongLong(const char* name, long long defaultValue) {
    const char* envValue = std::getenv(name);
    if (envValue != nullptr) {
        char* end = nullptr;
        long long parsed = std::strtoll(envValue, &end, 10);
        if (end != envValue && *end == '\0' && parsed > 0) {
            return parsed;
        }
    }

    return defaultValue;
}

long long getBrainstormSearchLimit() {
    return parsePositiveEnvLongLong("BRAINSTORM_SEARCH_LIMIT", 2318107019761ll);
}

long long getBrainstormPrintDelay() {
    return parsePositiveEnvLongLong("BRAINSTORM_PRINT_DELAY", 0ll);
}

bool isBuffoonPackType(Item packType) {
    return packType == Item::Buffoon_Pack
        || packType == Item::Jumbo_Buffoon_Pack
        || packType == Item::Mega_Buffoon_Pack;
}

struct FastNodeState {
    double value = 0.0;
    bool initialized = false;
};

struct FastChoiceNodeState {
    FastNodeState base;
    std::vector<FastNodeState> resamples;

    FastChoiceNodeState() { resamples.reserve(6); }
};

struct ExactCharmObservatoryEval {
    Seed &seed;
    double hashedSeed;
    FastChoiceNodeState tagState;
    FastNodeState soulTarotState;
    FastChoiceNodeState tarotState;
    FastChoiceNodeState legendaryJokerState;
    FastChoiceNodeState voucher1State;
    FastChoiceNodeState voucher2State;
    std::array<Item, 5> drawnTarots{};
    int drawnTarotCount = 0;
    bool telescopeLocked = false;

    explicit ExactCharmObservatoryEval(Seed &seedRef)
        : seed(seedRef), hashedSeed(seedRef.pseudohash(0)) {}

    static const std::string& tagKey() {
        static const std::string key = RandomType::Tags + anteToString(1);
        return key;
    }

    static const std::string& soulTarotKey() {
        static const std::string key =
            RandomType::Soul + RandomType::Tarot + anteToString(1);
        return key;
    }

    static const std::string& arcanaTarotKey() {
        static const std::string key =
            RandomType::Tarot + ItemSource::Arcana_Pack + anteToString(1);
        return key;
    }

    static const std::string& legendaryJokerKey() {
        static const std::string key = RandomType::Joker_Legendary;
        return key;
    }

    static const std::string& voucher1Key() {
        static const std::string key = RandomType::Voucher + anteToString(1);
        return key;
    }

    static const std::string& voucher2Key() {
        static const std::string key = RandomType::Voucher + anteToString(2);
        return key;
    }

    double nextNode(FastNodeState &state, const std::string &id) {
        if (!state.initialized) {
            state.value = pseudohash_from(id, seed.pseudohash((int)id.length()));
            state.initialized = true;
        }
        state.value = round13(fract(state.value * 1.72431234 + 2.134453429141));
        return (state.value + hashedSeed) / 2.0;
    }

    double nextChoiceNode(FastChoiceNodeState &state, const std::string &baseId,
                          int resampleNumber) {
        if (resampleNumber <= 1) {
            return nextNode(state.base, baseId);
        }

        const size_t index = static_cast<size_t>(resampleNumber - 2);
        if (index >= state.resamples.size()) {
            state.resamples.resize(index + 1);
        }
        std::string id = baseId + "_resample" + anteToString(resampleNumber);
        return nextNode(state.resamples[index], id);
    }

    template <std::size_t N, typename IsLocked>
    Item drawChoice(FastChoiceNodeState &state, const std::string &baseId,
                    const std::array<Item, N> &items, IsLocked isLocked) {
        int resampleNumber = 1;
        while (true) {
            Item item = items[lua_randint_from_seed(
                nextChoiceNode(state, baseId, resampleNumber),
                0,
                static_cast<int>(items.size()) - 1)];
            if ((item != Item::RETRY && !isLocked(item)) || resampleNumber > 1000) {
                return item;
            }
            resampleNumber++;
        }
    }

    bool isTarotLocked(Item tarot) const {
        for (int i = 0; i < drawnTarotCount; ++i) {
            if (drawnTarots[i] == tarot) {
                return true;
            }
        }
        return false;
    }

    Item nextArcanaTarot() {
        if (!isTarotLocked(Item::The_Soul)
            && lua_random_from_seed(nextNode(soulTarotState, soulTarotKey())) > 0.997) {
            drawnTarots[drawnTarotCount++] = Item::The_Soul;
            return Item::The_Soul;
        }

        Item tarot = drawChoice(
            tarotState, arcanaTarotKey(), TAROTS,
            [this](Item item) { return isTarotLocked(item); });
        drawnTarots[drawnTarotCount++] = tarot;
        return tarot;
    }

    bool passesCharmSoulPerkeo() {
        Item tag = drawChoice(
            tagState, tagKey(), TAGS,
            [](Item) { return false; });
        if (tag != Item::Charm_Tag) {
            return false;
        }

        bool foundSoul = false;
        for (int i = 0; i < 5; ++i) {
            if (nextArcanaTarot() == Item::The_Soul) {
                foundSoul = true;
            }
        }
        if (!foundSoul) {
            return false;
        }

        Item legendary = drawChoice(
            legendaryJokerState, legendaryJokerKey(), LEGENDARY_JOKERS,
            [](Item) { return false; });
        return legendary == Item::Perkeo;
    }

    Item nextVoucher(FastChoiceNodeState &state, const std::string &key) {
        return drawChoice(
            state, key, VOUCHERS,
            [this](Item item) {
                return telescopeLocked && item == Item::Telescope;
            });
    }

    bool passesObservatory() {
        Item firstVoucher = nextVoucher(voucher1State, voucher1Key());
        if (firstVoucher != Item::Telescope) {
            return false;
        }
        telescopeLocked = true;
        Item secondVoucher = nextVoucher(voucher2State, voucher2Key());
        return secondVoucher == Item::Observatory;
    }
};

bool isRankOnlySearch() {
    const bool rankFiltersEnabled =
        BRAINSTORM_SPECIFIC_RANK_MIN > 0 || BRAINSTORM_ANY_RANK_MIN > 0;
    if (!rankFiltersEnabled) {
        return false;
    }

    return BRAINSTORM_PACK == Item::RETRY
        && BRAINSTORM_TAG == Item::RETRY
        && BRAINSTORM_VOUCHER == Item::RETRY
        && BRAINSTORM_SOULS <= 0
        && !BRAINSTORM_OBSERVATORY
        && !BRAINSTORM_PERKEO
        && !BRAINSTORM_EARLYCOPY
        && !BRAINSTORM_RETCON
        && !BRAINSTORM_ANTE8_BEAN
        && !BRAINSTORM_ANTE6_BURGLAR
        && BRAINSTORM_FILTER == customFilters::NO_FILTER;
}

long rankOnlyFilter(Seed &seed) {
    return passesRankCountFilters(seed) ? 1 : 0;
}

bool hasRankCountFiltersEnabled() {
    return BRAINSTORM_SPECIFIC_RANK_MIN > 0 || BRAINSTORM_ANY_RANK_MIN > 0;
}

long filterConfigured(Instance &inst);

bool isExactCharmPerkeoObservatorySearch() {
    return BRAINSTORM_FILTER == customFilters::NO_FILTER
        && BRAINSTORM_PACK == Item::RETRY
        && BRAINSTORM_TAG == Item::Charm_Tag
        && BRAINSTORM_VOUCHER == Item::RETRY
        && BRAINSTORM_SOULS == 1
        && BRAINSTORM_OBSERVATORY
        && BRAINSTORM_PERKEO
        && !BRAINSTORM_EARLYCOPY
        && !BRAINSTORM_RETCON
        && !BRAINSTORM_ANTE8_BEAN
        && !BRAINSTORM_ANTE6_BURGLAR;
}

long exactCharmPerkeoObservatoryFilter(Seed &seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    if (hasRankCountFiltersEnabled() && !passesRankCountFilters(seed)) {
        return 0;
    }
    Seed configuredSeed = seed;
    Instance inst(configuredSeed);
    return filterConfigured(inst);
}

long filterConfigured(Instance &inst) {
    switch (BRAINSTORM_FILTER) {
        case customFilters::NO_FILTER: {
            if (BRAINSTORM_PACK != Item::RETRY) {
                inst.cache.generatedFirstPack = true; //we don't care about Pack 1
                if (inst.nextPack(1) != BRAINSTORM_PACK) {
                    return 0;
                }
            }

            if (BRAINSTORM_VOUCHER != Item::RETRY && !BRAINSTORM_OBSERVATORY) {
                if (inst.nextVoucher(1) != BRAINSTORM_VOUCHER) {
                    return 0;
                }
            }

            if (BRAINSTORM_TAG != Item::RETRY) {
                if (inst.nextTag(1) != BRAINSTORM_TAG) {
                    return 0;
                }
            }
            if (BRAINSTORM_SOULS > 0) {
                for (int i = 1; i <= BRAINSTORM_SOULS; i++) {
                    auto soulPack = inst.scanArcanaPackForSoulJoker(5, 1); // Mega Arcana Pack, assumed from a Charm Tag
                    if (!soulPack.foundSoul) {
                        return 0;
                    }
                    if (BRAINSTORM_PERKEO && soulPack.soulJoker.joker != Item::Perkeo) {
                        return 0; // If Perkeo is required but not found, return 0
                    }
                }
            }
            if (BRAINSTORM_OBSERVATORY) {
                if (inst.nextVoucher(1) == Item::Telescope) {
                    inst.activateVoucher(Item::Telescope);
                    if (inst.nextVoucher(2) != Item::Observatory) {
                        return 0;
                    }
                }
                else return 0;
            }
            if (BRAINSTORM_EARLYCOPY) {
                bool money = false;
                bool bstorm = false;
                bool bprint = false;
                Pack pack = packInfo(inst.nextPack(1));
                for (int p = 0; p <= 3; p++) {
                    if (pack.type == Item::Buffoon_Pack || pack.type == Item::Jumbo_Buffoon_Pack) {
                        auto packContents = inst.nextBuffoonPack(pack.size, 1);
                        for (int x = 0; x < pack.size; x++) {
                            if (packContents[x].joker == Item::Blueprint && !bprint) {
                                bprint = true;
                                break;
                            }
                            if ((packContents[x].joker == Item::Mail_In_Rebate || packContents[x].joker == Item::Reserved_Parking || packContents[x].joker == Item::Business_Card || packContents[x].joker == Item::To_Do_List || packContents[x].joker == Item::Midas_Mask || packContents[x].joker == Item::Trading_Card) && !money) {
                                money = true;
                                break;
                            }
                            if (packContents[x].joker == Item::Brainstorm && !bstorm) {
                                bstorm = true;
                                break;
                            }
                        }
                    }
                    if (pack.type == Item::Mega_Buffoon_Pack) {
                        auto packContents = inst.nextBuffoonPack(pack.size, 1);
                        for (int x = 0; x < pack.size; x++) {
                            if (packContents[x].joker == Item::Blueprint) {
                                bprint = true;
                            }
                            if ((packContents[x].joker == Item::Mail_In_Rebate || packContents[x].joker == Item::Reserved_Parking || packContents[x].joker == Item::Business_Card || packContents[x].joker == Item::To_Do_List || packContents[x].joker == Item::Midas_Mask || packContents[x].joker == Item::Trading_Card) && !money) {
                                money = true;
                            }
                            if (packContents[x].joker == Item::Brainstorm) {
                                bstorm = true;
                            }
                        }
                    }
                    pack = packInfo(inst.nextPack(1));
                }
                for (int i = 0; i < 4; i++) {
                    ShopItem item = inst.nextShopItem(1, false);
                    if (item.item == Item::Blueprint && !bprint && i > 1) {
                        bprint = true;
                    }
                    if (i > 1 && (item.item == Item::Mail_In_Rebate || item.item == Item::Reserved_Parking || item.item == Item::Business_Card || item.item == Item::To_Do_List || item.item == Item::Midas_Mask || item.item == Item::Trading_Card) && !money) {
                        money = true;
                    }
                    if (item.item == Item::Brainstorm && !bstorm && i > 1) {
                        bstorm = true;
                    }
                    if (!bprint || !money || !bstorm) {
                        return 0; // If any of the required items are not found, return 0
                    }


                }
            }
            if (BRAINSTORM_ANTE8_BEAN) {
                bool bean = false;
                for (int i = 0; i < 150; i++) {
                    if (inst.nextShopItem(8, false).item == Item::Turtle_Bean) {
                        bean = true;
                        break;
                    }
                }
                if (!bean) {
                    return 0; // If Turtle Bean is not found, return 0
                }
            }
            if (BRAINSTORM_ANTE6_BURGLAR) {
                bool burglar = false;
                for (int i = 0; i < 50; i++) {
                    if (inst.nextShopItem(6, false).item == Item::Burglar) {
                        burglar = true;
                        break;
                    }
                }
                if (!burglar) {
                    for (int i = 0; i < 100; i++) {
                        if (inst.nextShopItem(7, false).item == Item::Burglar) {
                            burglar = true;
                            break;
                        }
                    }
                }
                if (!burglar) {
                    for (int i = 0; i < 100; i++) {
                        if (inst.nextShopItem(8, false).item == Item::Burglar) {
                            burglar = true;
                            break;
                        }
                    }
                }
                if (!burglar) {
                    return 0; // If Burglar is not found, return 0
                }
            }
            if (BRAINSTORM_RETCON) {
                inst.initLocks(1, false, true);
                bool directorsCut = false;
                bool retcon = false;
                for (int i = 1; i < 9; i++) {
                    auto voucher = inst.nextVoucher(i);
                    inst.activateVoucher(voucher);
                    if (voucher == Item::Directors_Cut || directorsCut) {
                        directorsCut = true;
                        if (voucher == Item::Retcon) {
                            retcon = true;
                        }
                    }
                }
                if (!retcon) {
                    return 0; // If Retcon is not found, return 0
                }
            }

            return 1; // Return a score of 1 if all conditions are met
        }
        case customFilters::NEGATIVE_BLUEPRINT: {
            bool bprint = false;
            for (int i = 0; i < 4; i++) {
                ShopItem item = inst.nextShopItem(1, false);
                if (item.type == Item::Joker) {
                    if (item.jokerData.joker == Item::Blueprint && item.jokerData.edition == Item::Negative) {
                        bprint = true;
                    }
                }
            }
            if (bprint) {
                return 1; // Return a score of 1 if a negative blueprint is found
            }
            Pack pack = packInfo(inst.nextPack(1));
            for (int p = 0; p <= 3; p++) {
                if (isBuffoonPackType(pack.type)) {
                    auto packScan = inst.scanBuffoonPack(pack.size, 1);
                    if (packScan.foundNegativeBlueprint) {
                        bprint = true;
                    }
                }
                pack = packInfo(inst.nextPack(1));
            }
            if (bprint) {
                return 1; // Return a score of 1 if a negative blueprint is found
            }
            return 0; // Return 0 if no negative blueprint is found 
        }
        case customFilters::NEGATIVE_PERKEO: {
			bool negativePerkeo = false;
            if (inst.nextTag(1) != Item::Charm_Tag) {
                return 0;
            }
            auto soulPack = inst.scanArcanaPackForSoulJoker(5, 1); // Mega Arcana Pack, assumed from a Charm Tag
            if (soulPack.foundSoul && soulPack.soulJoker.joker == Item::Perkeo
                && soulPack.soulJoker.edition == Item::Negative) {
                negativePerkeo = true;
            }
            if (!negativePerkeo) {
                return 0; // If Perkeo is required but not found, return 0
            }
            
			return 1; // Return a score of 1 if a negative Perkeo is found

        }
        case customFilters::NEGATIVE_PERKEO_BLUEPRINT: {
            bool negativePerkeo = false;
            if (inst.nextTag(1) != Item::Charm_Tag) {
                return 0;
            }
            auto soulPack = inst.scanArcanaPackForSoulJoker(5, 1); // Mega Arcana Pack, assumed from a Charm Tag
            if (soulPack.foundSoul && soulPack.soulJoker.joker == Item::Perkeo
                && soulPack.soulJoker.edition == Item::Negative) {
                negativePerkeo = true;
            }
            if (!negativePerkeo) {
                return 0; // If Perkeo is required but not found, return 0
			}
            bool bprint = false;
            for (int i = 0; i < 2; i++) {
                ShopItem item = inst.nextShopItem(1, false);
                if (item.type == Item::Joker) {
                    if (item.jokerData.joker == Item::Blueprint && item.jokerData.edition == Item::Negative) {
                        bprint = true;
                    }
                }
            }
            if (bprint) {
                return 1; // Return a score of 1 if a negative blueprint is found
            }
            Pack pack = packInfo(inst.nextPack(1));
            for (int p = 0; p <= 2; p++) {
                if (isBuffoonPackType(pack.type)) {
                    auto packScan = inst.scanBuffoonPack(pack.size, 1);
                    if (packScan.foundNegativeBlueprint) {
                        bprint = true;
                    }
                }
                pack = packInfo(inst.nextPack(1));
            }
            if (bprint) {
                return 1; // Return a score of 1 if a negative blueprint is found
            }

            return 0; // Return 0 if no negative blueprint is found 
        }
        case customFilters::PERKEO_BASEBALL: {
            bool perkeo = false;
            if (inst.nextTag(1) != Item::Charm_Tag) {
                return 0;
            }
            auto soulPack = inst.scanArcanaPackForSoulJoker(5, 1); // Mega Arcana Pack, assumed from a Charm Tag
            if (soulPack.foundSoul && soulPack.soulJoker.joker == Item::Perkeo) {
                perkeo = true;
            }
            if (!perkeo) {
                return 0; // If Perkeo is required but not found, return 0
            }
            Pack pack = packInfo(inst.nextPack(1));
            auto packScan = inst.scanBuffoonPack(pack.size, 1);
            if (packScan.foundNegativeBaseball) {
				return 1; // Return a score of 1 if a negative Baseball Card is found
            }
			return 0; // Return 0 if no negative Baseball Card is found
        }
        default:
            return 1;
    }
    
}

long filterWithRankPrefilter(Instance &inst) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    if (!passesRankCountFilters(inst.seed)) {
        return 0;
    }
    return filterConfigured(inst);
}

long filterWithoutRankPrefilter(Instance &inst) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    return filterConfigured(inst);
}

std::string brainstorm_cpp(std::string seed, std::string voucher, std::string pack, std::string tag, double souls, bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, std::string customFilter, std::string targetRank, std::string targetSuit, int specificRankMin, int anyRankMin) {
    BRAINSTORM_PACK = stringToItem(pack);
    BRAINSTORM_TAG = stringToItem(tag);
    BRAINSTORM_VOUCHER = stringToItem(voucher);
	BRAINSTORM_FILTER = stringToFilter(customFilter);
    BRAINSTORM_SOULS = souls;
    BRAINSTORM_OBSERVATORY = observatory;
    BRAINSTORM_PERKEO = perkeo;
	BRAINSTORM_EARLYCOPY = copymoney;
	BRAINSTORM_RETCON = retcon;
	BRAINSTORM_ANTE6_BURGLAR = burglar;
	BRAINSTORM_ANTE8_BEAN = bean;
    setBrainstormTargetRank(targetRank);
    if (targetSuit == "Any Suit") {
        BRAINSTORM_TARGET_SUIT = Item::RETRY;
    } else {
        BRAINSTORM_TARGET_SUIT = stringToItem(targetSuit);
    }
    BRAINSTORM_SPECIFIC_RANK_MIN = specificRankMin > 0 ? specificRankMin : 0;
    BRAINSTORM_ANY_RANK_MIN = anyRankMin > 0 ? anyRankMin : 0;
    const int numThreads = getBrainstormSearchThreads();
    const long long searchLimit = getBrainstormSearchLimit();
    if (isExactCharmPerkeoObservatorySearch()) {
        SeedSearch search(exactCharmPerkeoObservatoryFilter, seed, numThreads, searchLimit);
        search.exitOnFind = true;
        search.printDelay = getBrainstormPrintDelay();
        return search.search();
    }
    if (isRankOnlySearch()) {
        SeedSearch search(rankOnlyFilter, seed, numThreads, searchLimit);
        search.exitOnFind = true;
        search.printDelay = getBrainstormPrintDelay();
        return search.search();
    }

    SearchFilter selectedFilter = hasRankCountFiltersEnabled()
        ? filterWithRankPrefilter
        : filterWithoutRankPrefilter;
    Search search(selectedFilter, seed, numThreads, searchLimit);
    search.exitOnFind = true;
    search.printDelay = getBrainstormPrintDelay();
    return search.search();
}

extern "C" {
    const char* brainstorm(const char* seed, const char* voucher, const char* pack, const char* tag, double souls, bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin) {
        std::string cpp_seed(seed);
        std::string cpp_pack(pack);
        std::string cpp_voucher(voucher);
        std::string cpp_tag(tag);
        std::string cpp_filter(customFilter);
        std::string cpp_target_rank(targetRank);
        std::string cpp_target_suit(targetSuit);
        std::string result = brainstorm_cpp(cpp_seed, cpp_voucher, cpp_pack, cpp_tag, souls, observatory, perkeo, copymoney, retcon, bean, burglar, cpp_filter, cpp_target_rank, cpp_target_suit, specificRankMin, anyRankMin);

        char* c_result = (char*)malloc(result.length() + 1);
        strcpy(c_result, result.c_str());

        return c_result;
    }

    void free_result(const char* result) {
        free((void*)result);
    }
}