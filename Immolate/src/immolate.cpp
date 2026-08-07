#include "functions.hpp"
#include"immolate.hpp"
#include "arbitrary_negative_batch.hpp"
#include "negative_blueprint_batch.hpp"
#include "opening_batch.hpp"
#include "search.hpp"
#include "seed_anchor_index.hpp"
#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <iomanip>
#include <iostream>
#include <limits>
#include <numeric>
#include <sstream>
#include <thread>
#include <utility>
#include <vector>

Item BRAINSTORM_PACK = Item::RETRY;
Item BRAINSTORM_TAG = Item::Charm_Tag;
Item BRAINSTORM_VOUCHER = Item::RETRY;
Item BRAINSTORM_DECK = Item::Red_Deck;
Item BRAINSTORM_STAKE = Item::White_Stake;
int BRAINSTORM_SOULS = 1;
bool BRAINSTORM_OBSERVATORY = false;
int BRAINSTORM_OBSERVATORY_DEADLINE = 0;
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

constexpr std::size_t BRAINSTORM_MAX_JOKER_TARGETS = 5;
constexpr char BRAINSTORM_JOKER_TARGET_SEPARATOR = 0x1f;
constexpr char BRAINSTORM_JOKER_EDITION_SEPARATOR = 0x1e;

enum class BrainstormJokerEditionRequirement {
    Any,
    Negative,
};

enum class BrainstormJokerLocationRequirement {
    AnteOne,
    SoulPack,
    AnteTwo,
    SoulOrAnteTwo,
    AnteThree,
    AnteFour,
    ByAnteTwo,
    ByAnteThree,
    ByAnteFour,
    ByAnteFive,
    ByAnteSix,
    ByAnteSeven,
    ByAnteEight,
};

enum class BrainstormJokerObservationSource {
    Soul,
    Judgement,
    AnteOne,
    AnteTwo,
    AnteThree,
    AnteFour,
    AnteFive,
    AnteSix,
    AnteSeven,
    AnteEight,
};

std::array<Item, BRAINSTORM_MAX_JOKER_TARGETS> BRAINSTORM_TARGET_JOKERS{};
std::array<BrainstormJokerEditionRequirement,
           BRAINSTORM_MAX_JOKER_TARGETS>
    BRAINSTORM_TARGET_JOKER_EDITIONS{};
std::array<BrainstormJokerLocationRequirement,
           BRAINSTORM_MAX_JOKER_TARGETS>
    BRAINSTORM_TARGET_JOKER_LOCATIONS{};
std::array<std::size_t, BRAINSTORM_MAX_JOKER_TARGETS>
    BRAINSTORM_TARGET_JOKER_SLOTS{};
std::size_t BRAINSTORM_TARGET_JOKER_COUNT = 0;
bool BRAINSTORM_TARGET_JOKERS_VALID = true;
bool BRAINSTORM_V5_OCCURRENCE_MODE = false;
bool BRAINSTORM_V5_ORDERED_MODE = false;
bool BRAINSTORM_V6_DEADLINE_MODE = false;
std::atomic<int> BRAINSTORM_SEARCH_THREAD_MODE{0};
// Estimation probes need to preserve the skipped-Small-Blind Charm route
// without waiting for extremely rare Soul counts to occur in every relaxed
// subquery. Normal searches always reset this to false.
bool BRAINSTORM_FORCE_CHARM_ROUTE = false;
bool BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG = false;

int brainstormJokerLocationDeadline(
    BrainstormJokerLocationRequirement location) {
    switch (location) {
        case BrainstormJokerLocationRequirement::ByAnteTwo:
            return 2;
        case BrainstormJokerLocationRequirement::ByAnteThree:
            return 3;
        case BrainstormJokerLocationRequirement::ByAnteFour:
            return 4;
        case BrainstormJokerLocationRequirement::ByAnteFive:
            return 5;
        case BrainstormJokerLocationRequirement::ByAnteSix:
            return 6;
        case BrainstormJokerLocationRequirement::ByAnteSeven:
            return 7;
        case BrainstormJokerLocationRequirement::ByAnteEight:
            return 8;
        default:
            return 0;
    }
}

int brainstormJokerObservationAnte(
    BrainstormJokerObservationSource source) {
    switch (source) {
        case BrainstormJokerObservationSource::AnteOne:
            return 1;
        case BrainstormJokerObservationSource::AnteTwo:
            return 2;
        case BrainstormJokerObservationSource::AnteThree:
            return 3;
        case BrainstormJokerObservationSource::AnteFour:
            return 4;
        case BrainstormJokerObservationSource::AnteFive:
            return 5;
        case BrainstormJokerObservationSource::AnteSix:
            return 6;
        case BrainstormJokerObservationSource::AnteSeven:
            return 7;
        case BrainstormJokerObservationSource::AnteEight:
            return 8;
        case BrainstormJokerObservationSource::Soul:
        case BrainstormJokerObservationSource::Judgement:
            return 0;
    }
    return 0;
}

bool brainstormHasDeadlineJokerTarget() {
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (brainstormJokerLocationDeadline(
                BRAINSTORM_TARGET_JOKER_LOCATIONS[i]) > 0) {
            return true;
        }
    }
    return false;
}

bool isVanillaJoker(Item item) {
    return (item > Item::J_C_BEGIN && item < Item::J_C_END)
        || (item > Item::J_U_BEGIN && item < Item::J_U_END)
        || (item > Item::J_R_BEGIN && item < Item::J_R_END)
        || (item > Item::J_L_BEGIN && item < Item::J_L_END);
}

bool isLegendaryJoker(Item item) {
    return item > Item::J_L_BEGIN && item < Item::J_L_END;
}

bool isSupportedBrainstormDeck(Item item) {
    return item > Item::D_BEGIN && item < Item::D_END;
}

Item parseJokerTargetName(const std::string& name) {
    // These are the two canonical in-game spellings that differ from the
    // legacy strings in items.hpp.
    if (name == "Riff-Raff") {
        return Item::Riff_raff;
    }
    if (name == "S\xC3\xA9" "ance") {
        return Item::Seance;
    }
    return stringToItem(name);
}

bool addBrainstormJokerTarget(
    Item target, BrainstormJokerEditionRequirement editionRequirement,
    BrainstormJokerLocationRequirement locationRequirement,
    std::size_t sourceSlot, bool deduplicateTargets) {
    if (!isVanillaJoker(target)) {
        return false;
    }
    if (deduplicateTargets) {
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (BRAINSTORM_TARGET_JOKERS[i] == target) {
                // Legacy APIs collapse duplicate targets to one slot. Never
                // let an Any Edition duplicate weaken an existing Negative
                // requirement.
                if (editionRequirement
                    == BrainstormJokerEditionRequirement::Negative) {
                    BRAINSTORM_TARGET_JOKER_EDITIONS[i] = editionRequirement;
                }
                // The first occurrence owns the target's source slot and
                // location in v4 and earlier.
                return true;
            }
        }
    } else {
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (BRAINSTORM_TARGET_JOKERS[i] == target) {
                BRAINSTORM_V5_ORDERED_MODE = true;
                break;
            }
        }
    }
    if (BRAINSTORM_TARGET_JOKER_COUNT >= BRAINSTORM_MAX_JOKER_TARGETS) {
        return false;
    }
    BRAINSTORM_TARGET_JOKERS[BRAINSTORM_TARGET_JOKER_COUNT] = target;
    BRAINSTORM_TARGET_JOKER_EDITIONS[BRAINSTORM_TARGET_JOKER_COUNT] =
        editionRequirement;
    BRAINSTORM_TARGET_JOKER_LOCATIONS[BRAINSTORM_TARGET_JOKER_COUNT] =
        locationRequirement;
    BRAINSTORM_TARGET_JOKER_SLOTS[BRAINSTORM_TARGET_JOKER_COUNT] = sourceSlot;
    BRAINSTORM_TARGET_JOKER_COUNT++;
    return true;
}

bool parseBrainstormJokerLocationToken(
    const std::string& token,
    BrainstormJokerLocationRequirement& parsedLocation,
    bool allowExtendedAnteLocations,
    bool allowDeadlineLocations) {
    if (token.empty() || token == "ante_1") {
        parsedLocation = BrainstormJokerLocationRequirement::AnteOne;
        return true;
    }
    if (token == "soul_pack") {
        parsedLocation = BrainstormJokerLocationRequirement::SoulPack;
        return true;
    }
    if (token == "ante_2") {
        parsedLocation = BrainstormJokerLocationRequirement::AnteTwo;
        return true;
    }
    if (token == "soul_or_ante_2") {
        parsedLocation = BrainstormJokerLocationRequirement::SoulOrAnteTwo;
        return true;
    }
    if (allowExtendedAnteLocations && token == "ante_3") {
        parsedLocation = BrainstormJokerLocationRequirement::AnteThree;
        return true;
    }
    if (allowExtendedAnteLocations && token == "ante_4") {
        parsedLocation = BrainstormJokerLocationRequirement::AnteFour;
        return true;
    }
    if (allowDeadlineLocations && token == "by_ante_2") {
        parsedLocation = BrainstormJokerLocationRequirement::ByAnteTwo;
        return true;
    }
    if (allowDeadlineLocations && token == "by_ante_3") {
        parsedLocation = BrainstormJokerLocationRequirement::ByAnteThree;
        return true;
    }
    if (allowDeadlineLocations && token == "by_ante_4") {
        parsedLocation = BrainstormJokerLocationRequirement::ByAnteFour;
        return true;
    }
    if (allowDeadlineLocations && token == "by_ante_5") {
        parsedLocation = BrainstormJokerLocationRequirement::ByAnteFive;
        return true;
    }
    if (allowDeadlineLocations && token == "by_ante_6") {
        parsedLocation = BrainstormJokerLocationRequirement::ByAnteSix;
        return true;
    }
    if (allowDeadlineLocations && token == "by_ante_7") {
        parsedLocation = BrainstormJokerLocationRequirement::ByAnteSeven;
        return true;
    }
    if (allowDeadlineLocations && token == "by_ante_8") {
        parsedLocation = BrainstormJokerLocationRequirement::ByAnteEight;
        return true;
    }
    return false;
}

bool parseBrainstormJokerLocations(
    const std::string& serializedLocations,
    std::array<BrainstormJokerLocationRequirement,
               BRAINSTORM_MAX_JOKER_TARGETS>& parsedLocations,
    bool allowExtendedAnteLocations,
    bool allowDeadlineLocations) {
    parsedLocations.fill(BrainstormJokerLocationRequirement::AnteOne);
    if (serializedLocations.empty()) {
        return true;
    }

    std::size_t sourceSlot = 0;
    std::size_t start = 0;
    while (start <= serializedLocations.size()) {
        if (sourceSlot >= BRAINSTORM_MAX_JOKER_TARGETS) {
            return false;
        }
        const std::size_t end = serializedLocations.find(
            BRAINSTORM_JOKER_TARGET_SEPARATOR, start);
        const std::string token = serializedLocations.substr(
            start, end == std::string::npos ? std::string::npos : end - start);
        if (!parseBrainstormJokerLocationToken(
                token, parsedLocations[sourceSlot],
                allowExtendedAnteLocations, allowDeadlineLocations)) {
            return false;
        }
        sourceSlot++;
        if (end == std::string::npos) {
            break;
        }
        start = end + 1;
    }
    return true;
}

bool parseBrainstormJokerTargets(const std::string& serializedTargets,
                                 bool legacyPerkeo,
                                 const std::string& serializedLocations,
                                 bool retainOccurrences = false,
                                 bool allowDeadlineLocations = false) {
    BRAINSTORM_TARGET_JOKERS.fill(Item::RETRY);
    BRAINSTORM_TARGET_JOKER_EDITIONS.fill(
        BrainstormJokerEditionRequirement::Any);
    BRAINSTORM_TARGET_JOKER_LOCATIONS.fill(
        BrainstormJokerLocationRequirement::AnteOne);
    BRAINSTORM_TARGET_JOKER_SLOTS.fill(0);
    BRAINSTORM_TARGET_JOKER_COUNT = 0;
    BRAINSTORM_V5_ORDERED_MODE = false;

    std::array<BrainstormJokerLocationRequirement,
               BRAINSTORM_MAX_JOKER_TARGETS>
        parsedLocations{};
    if (!parseBrainstormJokerLocations(
            serializedLocations, parsedLocations, retainOccurrences,
            allowDeadlineLocations)) {
        return false;
    }

    std::array<Item, BRAINSTORM_MAX_JOKER_TARGETS> parsedSlotTargets{};
    parsedSlotTargets.fill(Item::RETRY);
    std::size_t sourceSlot = 0;
    std::size_t start = 0;
    while (start <= serializedTargets.size()) {
        if (sourceSlot >= BRAINSTORM_MAX_JOKER_TARGETS) {
            return false;
        }
        const std::size_t end = serializedTargets.find(
            BRAINSTORM_JOKER_TARGET_SEPARATOR, start);
        const std::string targetToken = serializedTargets.substr(
            start, end == std::string::npos ? std::string::npos : end - start);
        if (!targetToken.empty()) {
            std::string targetName = targetToken;
            BrainstormJokerEditionRequirement editionRequirement =
                BrainstormJokerEditionRequirement::Any;
            const std::size_t editionSeparator = targetToken.find(
                BRAINSTORM_JOKER_EDITION_SEPARATOR);
            if (editionSeparator != std::string::npos) {
                // The only versioned suffix currently defined is RS + "N".
                // Reject malformed or future-looking data instead of silently
                // weakening it to Any Edition.
                if (targetToken.find(
                        BRAINSTORM_JOKER_EDITION_SEPARATOR,
                        editionSeparator + 1) != std::string::npos
                    || targetToken.substr(editionSeparator + 1) != "N") {
                    return false;
                }
                targetName = targetToken.substr(0, editionSeparator);
                editionRequirement =
                    BrainstormJokerEditionRequirement::Negative;
            }

            const Item parsedTarget = parseJokerTargetName(targetName);
            if (targetName != "None") {
                parsedSlotTargets[sourceSlot] = parsedTarget;
            }
            if (targetName.empty()
                || (targetName == "None"
                    && editionRequirement
                        != BrainstormJokerEditionRequirement::Any)
                || (targetName != "None"
                    && isLegendaryJoker(parsedTarget)
                    && (parsedLocations[sourceSlot]
                            == BrainstormJokerLocationRequirement::AnteTwo
                        || parsedLocations[sourceSlot]
                            == BrainstormJokerLocationRequirement::AnteThree
                        || parsedLocations[sourceSlot]
                            == BrainstormJokerLocationRequirement::AnteFour))
                || (targetName != "None"
                    && !addBrainstormJokerTarget(
                        parsedTarget, editionRequirement,
                        parsedLocations[sourceSlot], sourceSlot,
                        !retainOccurrences))) {
                return false;
            }
        }
        sourceSlot++;
        if (end == std::string::npos) {
            break;
        }
        start = end + 1;
    }

    if (!retainOccurrences) {
        // The v4 timing control belongs specifically to Joker 2. Its
        // alternate routes are meaningful only when Joker 1 is the Legendary
        // obtained from the starting Charm-pack Soul.
        for (std::size_t slot = 0; slot < BRAINSTORM_MAX_JOKER_TARGETS;
             slot++) {
            if (parsedSlotTargets[slot] == Item::RETRY
                || parsedLocations[slot]
                    == BrainstormJokerLocationRequirement::AnteOne) {
                continue;
            }
            if (slot != 1 || !isLegendaryJoker(parsedSlotTargets[0])) {
                return false;
            }
        }
    }

    if (legacyPerkeo
        && !addBrainstormJokerTarget(
            Item::Perkeo, BrainstormJokerEditionRequirement::Any,
            BrainstormJokerLocationRequirement::AnteOne,
            BRAINSTORM_TARGET_JOKER_COUNT, true)) {
        return false;
    }
    return true;
}

std::size_t brainstormLegendaryTargetCount() {
    std::size_t count = 0;
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (isLegendaryJoker(BRAINSTORM_TARGET_JOKERS[i])) {
            count++;
        }
    }
    return count;
}

bool hasSolePerkeoTarget() {
    return BRAINSTORM_TARGET_JOKERS_VALID
        && BRAINSTORM_TARGET_JOKER_COUNT == 1
        && BRAINSTORM_TARGET_JOKERS[0] == Item::Perkeo
        && BRAINSTORM_TARGET_JOKER_EDITIONS[0]
            == BrainstormJokerEditionRequirement::Any;
}

bool brainstormV5DuplicateLocationsValid() {
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        for (std::size_t j = i + 1;
             j < BRAINSTORM_TARGET_JOKER_COUNT; j++) {
            if (BRAINSTORM_TARGET_JOKERS[i]
                    != BRAINSTORM_TARGET_JOKERS[j]) {
                continue;
            }
            if (BRAINSTORM_TARGET_JOKER_LOCATIONS[i]
                    == BrainstormJokerLocationRequirement::SoulOrAnteTwo
                || BRAINSTORM_TARGET_JOKER_LOCATIONS[j]
                    == BrainstormJokerLocationRequirement::SoulOrAnteTwo) {
                return false;
            }
        }
    }
    return true;
}

enum class BrainstormRankTargetMode {
    Single,
    KingsOrQueens,
    Royals,
};

BrainstormRankTargetMode BRAINSTORM_TARGET_RANK_MODE =
    BrainstormRankTargetMode::Single;

enum class BrainstormSuitTargetMode {
    Combined,
    AnyOne,
    Specific,
};

BrainstormSuitTargetMode BRAINSTORM_TARGET_SUIT_MODE =
    BrainstormSuitTargetMode::Combined;

enum class BrainstormRankFilterEvaluation {
    Disabled,
    SeededErratic,
    DeterministicPass,
    DeterministicFail,
};

BrainstormRankFilterEvaluation BRAINSTORM_RANK_FILTER_EVALUATION =
    BrainstormRankFilterEvaluation::Disabled;

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
    return round13(
        fractPositive(erraticNode * 1.72431234 + 2.134453429141));
}

int nextErraticCardIndex(double& erraticNode, double hashedSeed) {
    erraticNode = nextErraticNode(erraticNode);
    return clampErraticCardIndex(
        lua_random_from_seed((erraticNode + hashedSeed) * 0.5));
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

bool isFaceRankIndex(int rankIndex) {
    return rankIndex == rankToCardIndex(Item::Jack)
        || rankIndex == rankToCardIndex(Item::Queen)
        || rankIndex == rankToCardIndex(Item::King);
}

void setBrainstormTargetSuit(const std::string& targetSuit) {
    if (targetSuit == "Any Suit") {
        BRAINSTORM_TARGET_SUIT_MODE = BrainstormSuitTargetMode::Combined;
        BRAINSTORM_TARGET_SUIT = Item::RETRY;
        return;
    }
    if (targetSuit == "Any One Suit") {
        BRAINSTORM_TARGET_SUIT_MODE = BrainstormSuitTargetMode::AnyOne;
        BRAINSTORM_TARGET_SUIT = Item::RETRY;
        return;
    }

    BRAINSTORM_TARGET_SUIT_MODE = BrainstormSuitTargetMode::Specific;
    BRAINSTORM_TARGET_SUIT = stringToItem(targetSuit);
}

int deterministicSpecificRankCount(int rankIndex) {
    if (BRAINSTORM_DECK == Item::Abandoned_Deck
        && isFaceRankIndex(rankIndex)) {
        return 0;
    }

    if (BRAINSTORM_DECK == Item::Checkered_Deck) {
        if (BRAINSTORM_TARGET_SUIT_MODE
            == BrainstormSuitTargetMode::Combined) {
            return 4;
        }
        if (BRAINSTORM_TARGET_SUIT_MODE
            == BrainstormSuitTargetMode::AnyOne) {
            return 2;
        }
        return BRAINSTORM_TARGET_SUIT == Item::Hearts
                || BRAINSTORM_TARGET_SUIT == Item::Spades
            ? 2
            : 0;
    }

    // Every other supported vanilla deck, including Plasma, starts with one
    // card of each rank/suit combination.
    if (BRAINSTORM_TARGET_SUIT_MODE
        == BrainstormSuitTargetMode::Combined) {
        return 4;
    }
    if (BRAINSTORM_TARGET_SUIT_MODE
        == BrainstormSuitTargetMode::AnyOne) {
        return 1;
    }
    return suitToCardIndex(BRAINSTORM_TARGET_SUIT) >= 0 ? 1 : 0;
}

bool deterministicRankCountFiltersPass() {
    const bool specificFilterEnabled = BRAINSTORM_SPECIFIC_RANK_MIN > 0;
    const bool anyRankFilterEnabled = BRAINSTORM_ANY_RANK_MIN > 0;
    const bool specificFilterPossible =
        specificFilterEnabled && BRAINSTORM_TARGET_RANK_MASK != 0;

    int bestSpecificTargetCount = 0;
    if (specificFilterPossible) {
        for (int rankIndex = 0; rankIndex < 13; rankIndex++) {
            if (matchesSpecificRankTarget(rankIndex)) {
                bestSpecificTargetCount = std::max(
                    bestSpecificTargetCount,
                    deterministicSpecificRankCount(rankIndex));
            }
        }
    }

    // Standard, Checkered, and Abandoned decks all retain four copies of
    // every rank that exists in that deck. Abandoned still has ten ranks.
    constexpr int bestAnyRankCount = 4;
    return (specificFilterPossible
            && bestSpecificTargetCount >= BRAINSTORM_SPECIFIC_RANK_MIN)
        || (anyRankFilterEnabled
            && bestAnyRankCount >= BRAINSTORM_ANY_RANK_MIN);
}

void prepareBrainstormRankFilterEvaluation() {
    if (BRAINSTORM_SPECIFIC_RANK_MIN <= 0
        && BRAINSTORM_ANY_RANK_MIN <= 0) {
        BRAINSTORM_RANK_FILTER_EVALUATION =
            BrainstormRankFilterEvaluation::Disabled;
        return;
    }
    if (BRAINSTORM_DECK == Item::Erratic_Deck) {
        BRAINSTORM_RANK_FILTER_EVALUATION =
            BrainstormRankFilterEvaluation::SeededErratic;
        return;
    }
    BRAINSTORM_RANK_FILTER_EVALUATION =
        deterministicRankCountFiltersPass()
        ? BrainstormRankFilterEvaluation::DeterministicPass
        : BrainstormRankFilterEvaluation::DeterministicFail;
}

bool rankFiltersNeedSeedEvaluation() {
    return BRAINSTORM_RANK_FILTER_EVALUATION
        == BrainstormRankFilterEvaluation::SeededErratic;
}

bool rankFiltersDeterministicallyPass() {
    return BRAINSTORM_RANK_FILTER_EVALUATION
        == BrainstormRankFilterEvaluation::DeterministicPass;
}

bool rankFiltersDeterministicallyFail() {
    return BRAINSTORM_RANK_FILTER_EVALUATION
        == BrainstormRankFilterEvaluation::DeterministicFail;
}

bool passesRankCountFilters(Seed& seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::RankPrefilter);
    auto finish = [](bool result) {
        BrainstormPerfStats::instance().noteRankPrefilter(result);
        return result;
    };

    if (BRAINSTORM_RANK_FILTER_EVALUATION
        == BrainstormRankFilterEvaluation::Disabled
        || BRAINSTORM_RANK_FILTER_EVALUATION
            == BrainstormRankFilterEvaluation::DeterministicPass) {
        return finish(true);
    }
    if (BRAINSTORM_RANK_FILTER_EVALUATION
        == BrainstormRankFilterEvaluation::DeterministicFail) {
        return finish(false);
    }

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

    const bool singleSpecificRankAnySuit =
        specificFilterPossible
        && !anyRankFilterEnabled
        && BRAINSTORM_TARGET_SUIT_MODE == BrainstormSuitTargetMode::Combined
        && BRAINSTORM_TARGET_RANK_MODE == BrainstormRankTargetMode::Single;
    if (singleSpecificRankAnySuit) {
        const int targetRankIndex = rankToCardIndex(BRAINSTORM_TARGET_RANK);
        if (targetRankIndex < 0) {
            return finish(false);
        }

        const double hashedSeed = seed.pseudohash(0);
        double erraticNode = pseudohash_from(
            RandomType::Erratic,
            seed.pseudohash((int)RandomType::Erratic.size()));
        int count = 0;
        for (int i = 0; i < 52; ++i) {
            const int cardIndex = nextErraticCardIndex(erraticNode, hashedSeed);
            if (cardIndex % 13 == targetRankIndex) {
                ++count;
                if (count >= BRAINSTORM_SPECIFIC_RANK_MIN) {
                    return finish(true);
                }
            }

            const int remainingCards = 51 - i;
            if (count + remainingCards < BRAINSTORM_SPECIFIC_RANK_MIN) {
                return finish(false);
            }
        }

        return finish(false);
    }

    const double hashedSeed = seed.pseudohash(0);
    double erraticNode = pseudohash_from(RandomType::Erratic, seed.pseudohash((int)RandomType::Erratic.size()));
    uint8_t rankCounts[13] = { 0 };
    uint8_t suitedRankCounts[4][13] = {};
    int bestSpecificTargetCount = 0;
    int bestAnyRankCount = 0;
    const bool combinedSuitTarget =
        BRAINSTORM_TARGET_SUIT_MODE == BrainstormSuitTargetMode::Combined;
    const bool anyOneSuitTarget =
        BRAINSTORM_TARGET_SUIT_MODE == BrainstormSuitTargetMode::AnyOne;
    for (int i = 0; i < 52; i++) {
        int cardIndex = nextErraticCardIndex(erraticNode, hashedSeed);
        int rankIndex = cardIndex % 13;

        rankCounts[rankIndex]++;
        if (rankCounts[rankIndex] > bestAnyRankCount) {
            bestAnyRankCount = rankCounts[rankIndex];
        }

        if (specificFilterPossible && matchesSpecificRankTarget(rankIndex)) {
            if (combinedSuitTarget) {
                if (rankCounts[rankIndex] > bestSpecificTargetCount) {
                    bestSpecificTargetCount = rankCounts[rankIndex];
                }
            } else {
                int suitIndex = cardIndex / 13;
                if (anyOneSuitTarget || targetSuitIndex == suitIndex) {
                    suitedRankCounts[suitIndex][rankIndex]++;
                    if (suitedRankCounts[suitIndex][rankIndex]
                        > bestSpecificTargetCount) {
                        bestSpecificTargetCount =
                            suitedRankCounts[suitIndex][rankIndex];
                    }
                }
            }
        }

        if (specificFilterPossible
            && bestSpecificTargetCount >= BRAINSTORM_SPECIFIC_RANK_MIN) {
            return finish(true);
        }
        if (anyRankFilterEnabled && bestAnyRankCount >= BRAINSTORM_ANY_RANK_MIN) {
            return finish(true);
        }

        const int remainingCards = 51 - i;
        const bool specificStillPossible = specificFilterPossible
            && bestSpecificTargetCount + remainingCards >= BRAINSTORM_SPECIFIC_RANK_MIN;
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

    if (BRAINSTORM_SEARCH_THREAD_MODE.load(std::memory_order_relaxed) == 1) {
        const unsigned int detected = std::thread::hardware_concurrency();
        if (detected == 0) {
            return 12;
        }
        // This division-heavy search benefits from slight oversubscription
        // on 16-core/32-thread systems while Maximum mode is selected.
        return detected == 32
            ? 36
            : static_cast<int>(detected);
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
    return std::min(
        parsePositiveEnvLongLong(
            "BRAINSTORM_SEARCH_LIMIT", SEED_DOMAIN_SIZE),
        SEED_DOMAIN_SIZE);
}

long long getBrainstormPrintDelay() {
    return parsePositiveEnvLongLong("BRAINSTORM_PRINT_DELAY", 0ll);
}

bool isBuffoonPackType(Item packType) {
    return packType == Item::Buffoon_Pack
        || packType == Item::Jumbo_Buffoon_Pack
        || packType == Item::Mega_Buffoon_Pack;
}

bool isAnteOneLockedTag(Item tag) {
    return tag == Item::Negative_Tag
        || tag == Item::Standard_Tag
        || tag == Item::Meteor_Tag
        || tag == Item::Buffoon_Tag
        || tag == Item::Handy_Tag
        || tag == Item::Garbage_Tag
        || tag == Item::Ethereal_Tag
        || tag == Item::Top_up_Tag
        || tag == Item::Orbital_Tag;
}

bool isFreshRunLockedVoucher(Item voucher) {
    for (std::size_t i = 1; i < VOUCHERS.size(); i += 2) {
        if (VOUCHERS[i] == voucher) {
            return true;
        }
    }
    return false;
}

struct BrainstormJokerTargetMatcher {
    std::array<bool, BRAINSTORM_MAX_JOKER_TARGETS> matched{};

    static bool locationAccepts(
        BrainstormJokerLocationRequirement location,
        BrainstormJokerObservationSource source) {
        const int deadline = brainstormJokerLocationDeadline(location);
        if (deadline > 0) {
            if (source == BrainstormJokerObservationSource::Soul
                || source == BrainstormJokerObservationSource::Judgement) {
                return true;
            }
            const int observedAnte = brainstormJokerObservationAnte(source);
            return observedAnte >= 1 && observedAnte <= deadline;
        }
        switch (location) {
            case BrainstormJokerLocationRequirement::AnteOne:
                // Legacy/default targets may be legendary Soul outcomes, but
                // non-legendary Judgement outcomes were not part of v3.
                return source == BrainstormJokerObservationSource::Soul
                    || source == BrainstormJokerObservationSource::AnteOne;
            case BrainstormJokerLocationRequirement::SoulPack:
                return source == BrainstormJokerObservationSource::Soul
                    || source == BrainstormJokerObservationSource::Judgement;
            case BrainstormJokerLocationRequirement::AnteTwo:
                return source == BrainstormJokerObservationSource::AnteTwo;
            case BrainstormJokerLocationRequirement::SoulOrAnteTwo:
                return source == BrainstormJokerObservationSource::Soul
                    || source == BrainstormJokerObservationSource::Judgement
                    || source == BrainstormJokerObservationSource::AnteTwo;
            case BrainstormJokerLocationRequirement::AnteThree:
                return source == BrainstormJokerObservationSource::AnteThree;
            case BrainstormJokerLocationRequirement::AnteFour:
                return source == BrainstormJokerObservationSource::AnteFour;
            case BrainstormJokerLocationRequirement::ByAnteTwo:
            case BrainstormJokerLocationRequirement::ByAnteThree:
            case BrainstormJokerLocationRequirement::ByAnteFour:
            case BrainstormJokerLocationRequirement::ByAnteFive:
            case BrainstormJokerLocationRequirement::ByAnteSix:
            case BrainstormJokerLocationRequirement::ByAnteSeven:
            case BrainstormJokerLocationRequirement::ByAnteEight:
                return false;
        }
        return false;
    }

    bool observe(const JokerData& joker,
                 BrainstormJokerObservationSource source) {
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            const bool editionMatches =
                BRAINSTORM_TARGET_JOKER_EDITIONS[i]
                    == BrainstormJokerEditionRequirement::Any
                || joker.edition == Item::Negative;
            if (!matched[i]
                && BRAINSTORM_TARGET_JOKERS[i] == joker.joker
                && locationAccepts(
                    BRAINSTORM_TARGET_JOKER_LOCATIONS[i], source)
                && editionMatches) {
                matched[i] = true;
                return true;
            }
        }
        return false;
    }

    bool hasUnmatchedForSource(
        BrainstormJokerObservationSource source) const {
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (!matched[i]
                && locationAccepts(
                    BRAINSTORM_TARGET_JOKER_LOCATIONS[i], source)) {
                return true;
            }
        }
        return false;
    }

    bool complete() const {
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (!matched[i]) {
                return false;
            }
        }
        return true;
    }
};

bool scanEarlyShopJokers(Instance& early,
                         BrainstormJokerTargetMatcher& matcher) {
    constexpr int itemCount = 4;
    const int windowSize = 2
        + (early.isVoucherActive(Item::Overstock) ? 1 : 0)
        + (early.isVoucherActive(Item::Overstock_Plus) ? 1 : 0);
    int generatedCount = 0;

    while (generatedCount < itemCount) {
        const int currentWindowSize = std::min(
            windowSize, itemCount - generatedCount);
        std::array<Item, 4> visibleJokers{};
        int visibleJokerCount = 0;

        for (int i = 0; i < currentWindowSize; i++) {
            const ShopItem shopItem = early.nextShopItem(1, false);
            generatedCount++;
            if (shopItem.type != Item::T_Joker) {
                continue;
            }

            matcher.observe(
                shopItem.jokerData,
                BrainstormJokerObservationSource::AnteOne);
            if (!early.params.showman) {
                early.lockTransient(shopItem.jokerData.joker);
                visibleJokers[visibleJokerCount++] = shopItem.jokerData.joker;
            }
        }

        for (int i = 0; i < visibleJokerCount; i++) {
            early.unlockTransient(visibleJokers[i]);
        }
        if (matcher.complete()) {
            return true;
        }
    }

    return false;
}

bool scanShopWindows(Instance& inst, int ante, int shopCount,
                     BrainstormJokerObservationSource source,
                     BrainstormJokerTargetMatcher& matcher) {
    const int windowSize = 2
        + (inst.isVoucherActive(Item::Overstock) ? 1 : 0)
        + (inst.isVoucherActive(Item::Overstock_Plus) ? 1 : 0);

    for (int shop = 0; shop < shopCount; shop++) {
        std::array<Item, 4> visibleJokers{};
        int visibleJokerCount = 0;
        for (int i = 0; i < windowSize; i++) {
            const ShopItem shopItem = inst.nextShopItem(ante, false);
            if (shopItem.type != Item::T_Joker) {
                continue;
            }
            matcher.observe(shopItem.jokerData, source);
            if (!inst.params.showman) {
                inst.lockTransient(shopItem.jokerData.joker);
                visibleJokers[visibleJokerCount++] =
                    shopItem.jokerData.joker;
            }
        }
        for (int i = 0; i < visibleJokerCount; i++) {
            inst.unlockTransient(visibleJokers[i]);
        }
        if (matcher.complete()) {
            return true;
        }
    }
    return false;
}

bool scanBuffoonPack(Instance& inst, int size, int ante,
                     BrainstormJokerObservationSource source,
                     BrainstormJokerTargetMatcher& matcher) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::NextBuffoonPack);
    std::array<Item, 8> generatedJokers{};
    int generatedCount = 0;

    for (int i = 0; i < size; i++) {
        const JokerData joker =
            inst.nextJoker(ItemSource::Buffoon_Pack, ante, true);
        generatedJokers[generatedCount++] = joker.joker;
        if (!inst.params.showman) {
            inst.lockTransient(joker.joker);
        }
        matcher.observe(joker, source);
        if (matcher.complete()) {
            break;
        }
    }

    if (!inst.params.showman) {
        for (int i = 0; i < generatedCount; i++) {
            inst.unlockTransient(generatedJokers[i]);
        }
    }
    return matcher.complete();
}

bool scanEarlyBuffoonPack(Instance& early, int size,
                          BrainstormJokerTargetMatcher& matcher) {
    return scanBuffoonPack(
        early, size, 1, BrainstormJokerObservationSource::AnteOne, matcher);
}

bool hasCollectibleSoulJoker(const ArcanaSoulPackResult& soulPack,
                             Item target, Item requiredEdition) {
    const std::size_t collectibleSoulCount = std::min<std::size_t>(
        2, soulPack.soulJokers.size());
    for (std::size_t i = 0; i < collectibleSoulCount; i++) {
        const JokerData& joker = soulPack.soulJokers[i];
        if (joker.joker == target
            && (requiredEdition == Item::RETRY
                || joker.edition == requiredEdition)) {
            return true;
        }
    }
    return false;
}

bool customFilterRequiresPerkeo() {
    return BRAINSTORM_FILTER == customFilters::NEGATIVE_PERKEO
        || BRAINSTORM_FILTER == customFilters::NEGATIVE_PERKEO_BLUEPRINT
        || BRAINSTORM_FILTER == customFilters::PERKEO_BASEBALL;
}

std::size_t brainstormRequiredLegendaryTargetCount() {
    std::size_t count = brainstormLegendaryTargetCount();
    if (!customFilterRequiresPerkeo()) {
        return count;
    }

    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (BRAINSTORM_TARGET_JOKERS[i] == Item::Perkeo) {
            return count;
        }
    }
    // Every Soul-based custom filter also requires Perkeo, even when Perkeo
    // was not explicitly selected in a target slot.
    return count + 1;
}

std::size_t brainstormRequiredStartingPackChoiceCount() {
    std::size_t result = brainstormRequiredLegendaryTargetCount();
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (!isLegendaryJoker(BRAINSTORM_TARGET_JOKERS[i])
            && BRAINSTORM_TARGET_JOKER_LOCATIONS[i]
                == BrainstormJokerLocationRequirement::SoulPack) {
            result++;
        }
    }
    return result;
}

std::size_t brainstormSoulPackNonLegendaryTargetCount() {
    std::size_t result = 0;
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (!isLegendaryJoker(BRAINSTORM_TARGET_JOKERS[i])
            && BRAINSTORM_TARGET_JOKER_LOCATIONS[i]
                == BrainstormJokerLocationRequirement::SoulPack) {
            result++;
        }
    }
    return result;
}

bool brainstormV5OrderedStartingChoicesFeasible() {
    if (!BRAINSTORM_V5_ORDERED_MODE) {
        return true;
    }

    // DP state: last effective timing, starting-pack choices used, and
    // non-Legendary Judgement selections used. Timing 0 is the starting
    // Charm pack; timings 1-8 are their respective Antes.
    using TimingChoiceStates =
        std::array<std::array<std::array<bool, 2>, 3>, 9>;
    TimingChoiceStates states{};
    bool hasExplicitPerkeo = false;
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (BRAINSTORM_TARGET_JOKERS[i] == Item::Perkeo) {
            hasExplicitPerkeo = true;
            break;
        }
    }
    const int implicitPerkeoChoices =
        customFilterRequiresPerkeo() && !hasExplicitPerkeo ? 1 : 0;
    states[0][implicitPerkeoChoices][0] = true;

    for (std::size_t requirement = 0;
         requirement < BRAINSTORM_TARGET_JOKER_COUNT; requirement++) {
        std::array<int, 9> timingOptions{};
        std::size_t timingOptionCount = 0;
        const bool legendary =
            isLegendaryJoker(BRAINSTORM_TARGET_JOKERS[requirement]);
        const BrainstormJokerLocationRequirement location =
            BRAINSTORM_TARGET_JOKER_LOCATIONS[requirement];

        const int deadline = brainstormJokerLocationDeadline(location);
        if (legendary
            || location == BrainstormJokerLocationRequirement::SoulPack) {
            timingOptions[timingOptionCount++] = 0;
        } else if (deadline > 0) {
            // A non-Legendary cumulative target may be selected through
            // Judgement in the starting Charm pack or acquired naturally in
            // any no-reroll shop/Buffoon window up to its deadline.
            for (int timing = 0; timing <= deadline; timing++) {
                timingOptions[timingOptionCount++] = timing;
            }
        } else if (
            location
            == BrainstormJokerLocationRequirement::SoulOrAnteTwo) {
            timingOptions[0] = 0;
            timingOptions[1] = 2;
            timingOptionCount = 2;
        } else if (
            location == BrainstormJokerLocationRequirement::AnteTwo) {
            timingOptions[timingOptionCount++] = 2;
        } else if (
            location == BrainstormJokerLocationRequirement::AnteThree) {
            timingOptions[timingOptionCount++] = 3;
        } else if (
            location == BrainstormJokerLocationRequirement::AnteFour) {
            timingOptions[timingOptionCount++] = 4;
        } else {
            timingOptions[timingOptionCount++] = 1;
        }

        TimingChoiceStates nextStates{};
        for (int previousTiming = 0; previousTiming <= 8;
             previousTiming++) {
            for (int choices = 0; choices <= 2; choices++) {
                for (int judgements = 0; judgements <= 1; judgements++) {
                    if (!states[previousTiming][choices][judgements]) {
                        continue;
                    }
                    for (std::size_t option = 0;
                         option < timingOptionCount; option++) {
                        const int timing = timingOptions[option];
                        if (timing < previousTiming) {
                            continue;
                        }
                        const int nextChoices =
                            choices + (timing == 0 ? 1 : 0);
                        const int nextJudgements =
                            judgements
                            + (timing == 0 && !legendary ? 1 : 0);
                        if (nextChoices <= 2 && nextJudgements <= 1) {
                            nextStates[timing][nextChoices][nextJudgements] =
                                true;
                        }
                    }
                }
            }
        }
        states = nextStates;
    }

    for (const auto& timingStates : states) {
        for (const auto& choiceStates : timingStates) {
            for (bool possible : choiceStates) {
                if (possible) {
                    return true;
                }
            }
        }
    }
    return false;
}

bool brainstormNeedsV5ChronologicalJokerScan() {
    if (!BRAINSTORM_V5_OCCURRENCE_MODE) {
        return false;
    }

    // Repeated centers require ownership, selling, and blind-age tracking.
    if (BRAINSTORM_V5_ORDERED_MODE) {
        return true;
    }

    bool jokerOneIsLegendary = false;
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (BRAINSTORM_TARGET_JOKER_SLOTS[i] == 0) {
            jokerOneIsLegendary =
                isLegendaryJoker(BRAINSTORM_TARGET_JOKERS[i]);
            break;
        }
    }

    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        const BrainstormJokerLocationRequirement location =
            BRAINSTORM_TARGET_JOKER_LOCATIONS[i];
        if (brainstormJokerLocationDeadline(location) > 0) {
            return true;
        }
        if (location == BrainstormJokerLocationRequirement::AnteThree
            || location == BrainstormJokerLocationRequirement::AnteFour) {
            return true;
        }
        if (location != BrainstormJokerLocationRequirement::AnteOne
            && (BRAINSTORM_TARGET_JOKER_SLOTS[i] != 1
                || !jokerOneIsLegendary)) {
            return true;
        }
    }
    return false;
}

struct BrainstormCharmPackVisibility {
    int soulCount = 0;
    bool hasJudgement = false;
};

BrainstormCharmPackVisibility scanEarlyCharmPackVisibility(
    Instance& early, int requiredSoulCount) {
    BrainstormCharmPackVisibility result;
    std::array<Item, 5> generatedItems{};
    const bool allowDuplicateSouls = requiredSoulCount > 1;

    for (int i = 0; i < 5; i++) {
        Item packItem;
        if (early.isVoucherActive(Item::Omen_Globe)
            && early.random(RandomType::Omen_Globe) > 0.8) {
            packItem = early.nextSpectral(
                ItemSource::Omen_Globe, 1, true, allowDuplicateSouls);
        } else {
            packItem = early.nextTarot(
                ItemSource::Arcana_Pack, 1, true, allowDuplicateSouls);
        }
        generatedItems[i] = packItem;
        if (packItem == Item::The_Soul) {
            result.soulCount++;
        } else if (packItem == Item::Judgement) {
            result.hasJudgement = true;
        }
        if (!early.params.showman) {
            early.lockTransient(packItem);
        }
    }
    if (!early.params.showman) {
        for (Item item : generatedItems) {
            early.unlockTransient(item);
        }
    }
    return result;
}

int requiredCharmSoulCount() {
    int requiredSoulCount = std::max(
        BRAINSTORM_SOULS,
        static_cast<int>(brainstormRequiredLegendaryTargetCount()));
    if (customFilterRequiresPerkeo()) {
        requiredSoulCount = std::max(requiredSoulCount, 1);
    }
    return requiredSoulCount;
}

bool needsStartingCharmPack() {
    if (BRAINSTORM_FORCE_CHARM_ROUTE) {
        return true;
    }
    if (requiredCharmSoulCount() > 0) {
        return true;
    }
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (BRAINSTORM_TARGET_JOKER_LOCATIONS[i]
                == BrainstormJokerLocationRequirement::SoulPack
            || BRAINSTORM_TARGET_JOKER_LOCATIONS[i]
                == BrainstormJokerLocationRequirement::SoulOrAnteTwo) {
            return true;
        }
    }
    return false;
}

bool scanTargetTimeline(Instance& inst,
                        BrainstormJokerTargetMatcher& matcher) {
    if (matcher.complete()) {
        return true;
    }

    if (matcher.hasUnmatchedForSource(
            BrainstormJokerObservationSource::AnteOne)) {
        if (scanEarlyShopJokers(inst, matcher)) {
            return true;
        }
        for (int i = 0; i < 4; i++) {
            const Pack pack = packInfo(inst.nextPack(1));
            if (isBuffoonPackType(pack.type)
                && scanEarlyBuffoonPack(inst, pack.size, matcher)) {
                return true;
            }
        }
    }

    if (matcher.complete()) {
        return true;
    }
    if (!matcher.hasUnmatchedForSource(
            BrainstormJokerObservationSource::AnteTwo)) {
        return false;
    }

    // The forced first Buffoon pack is generated in the remaining Ante 1
    // shop even when no Ante 1 target requires us to inspect its contents.
    inst.cache.generatedFirstPack = true;
    inst.initUnlocks(2, false);
    if (scanShopWindows(
            inst, 2, 3, BrainstormJokerObservationSource::AnteTwo, matcher)) {
        return true;
    }
    for (int i = 0; i < 6; i++) {
        const Pack pack = packInfo(inst.nextPack(2));
        if (isBuffoonPackType(pack.type)
            && scanBuffoonPack(
                inst, pack.size, 2,
                BrainstormJokerObservationSource::AnteTwo, matcher)) {
            return true;
        }
    }
    return matcher.complete();
}

bool passesEarlyJokerTargets(Instance& early) {
    if (!BRAINSTORM_TARGET_JOKERS_VALID) {
        return false;
    }
    const int requiredSoulCount = requiredCharmSoulCount();
    const bool needsCharmPack = needsStartingCharmPack();
    if (BRAINSTORM_TARGET_JOKER_COUNT == 0 && !needsCharmPack) {
        return true;
    }

    // Ante-one tags and Jokers must respect new-run locks. Profile unlocks are
    // assumed complete, matching the rest of Brainstorm's search behavior.
    early.initLocks(1, false, true);
    early.setDeck(BRAINSTORM_DECK);
    early.setStake(BRAINSTORM_STAKE);
    BrainstormCharmPackVisibility charmPack;
    if (needsCharmPack) {
        if (requiredSoulCount > 4
            || (!BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG
                && early.nextTag(1) != Item::Charm_Tag)) {
            return false;
        }
        charmPack =
            scanEarlyCharmPackVisibility(early, requiredSoulCount);
        if (charmPack.soulCount < requiredSoulCount) {
            return false;
        }
    }

    if (BRAINSTORM_TARGET_JOKER_COUNT == 0) {
        return true;
    }

    // An implicit Perkeo from a Soul-based custom filter consumes one of the
    // same two Mega Arcana selections as an explicit legendary target.
    const int minimumSoulSelections =
        static_cast<int>(brainstormRequiredLegendaryTargetCount());
    const int maximumSoulSelections = std::min(2, charmPack.soulCount);
    bool canUseJudgement = false;
    if (needsCharmPack && charmPack.hasJudgement) {
        BrainstormJokerTargetMatcher emptyMatcher;
        canUseJudgement = emptyMatcher.hasUnmatchedForSource(
            BrainstormJokerObservationSource::Judgement);
    }

    // Try each collectible two-card Charm-pack route on its own Instance copy.
    // A failed optional second Soul or Judgement must not advance RNG or lock a
    // Joker in the independent Ante 2 route.
    for (int soulSelections = minimumSoulSelections;
         soulSelections <= maximumSoulSelections; soulSelections++) {
        for (int judgementSelection = canUseJudgement ? 1 : 0;
             judgementSelection >= 0; judgementSelection--) {
            if (soulSelections + judgementSelection > 2) {
                continue;
            }
            Instance branch = early;
            BrainstormJokerTargetMatcher matcher;
            for (int i = 0; i < soulSelections; i++) {
                const JokerData soulJoker =
                    branch.nextJoker(ItemSource::Soul, 1, false);
                matcher.observe(
                    soulJoker, BrainstormJokerObservationSource::Soul);
                if (!branch.params.showman) {
                    branch.lock(soulJoker.joker);
                }
            }
            if (judgementSelection != 0) {
                const JokerData judgementJoker =
                    branch.nextJoker(ItemSource::Judgement, 1, false);
                matcher.observe(
                    judgementJoker,
                    BrainstormJokerObservationSource::Judgement);
                if (!branch.params.showman) {
                    branch.lock(judgementJoker.joker);
                }
            }
            if (scanTargetTimeline(branch, matcher)) {
                return true;
            }
        }
    }
    return false;
}

struct BrainstormV5JokerMatcher {
    std::array<bool, BRAINSTORM_MAX_JOKER_TARGETS> matched{};

    bool priorRequirementsMatched(std::size_t requirement) const {
        for (std::size_t i = 0; i < requirement; i++) {
            if (!matched[i]
                && (BRAINSTORM_V5_ORDERED_MODE
                    || BRAINSTORM_TARGET_JOKERS[i]
                        == BRAINSTORM_TARGET_JOKERS[requirement])) {
                return false;
            }
        }
        return true;
    }

    bool requirementMatches(
        std::size_t requirement, const JokerData& joker,
        BrainstormJokerObservationSource source) const {
        if (requirement >= BRAINSTORM_TARGET_JOKER_COUNT
            || matched[requirement]
            || !priorRequirementsMatched(requirement)
            || BRAINSTORM_TARGET_JOKERS[requirement] != joker.joker
            || !BrainstormJokerTargetMatcher::locationAccepts(
                BRAINSTORM_TARGET_JOKER_LOCATIONS[requirement], source)) {
            return false;
        }
        return BRAINSTORM_TARGET_JOKER_EDITIONS[requirement]
                == BrainstormJokerEditionRequirement::Any
            || joker.edition == Item::Negative;
    }

    unsigned int matchingRequirementMask(
        const JokerData& joker,
        BrainstormJokerObservationSource source) const {
        unsigned int result = 0;
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (requirementMatches(i, joker, source)) {
                result |= 1u << i;
            }
        }
        return result;
    }

    bool hasUnmatchedForSource(
        BrainstormJokerObservationSource source) const {
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (!matched[i]
                && BrainstormJokerTargetMatcher::locationAccepts(
                    BRAINSTORM_TARGET_JOKER_LOCATIONS[i], source)) {
                return true;
            }
        }
        return false;
    }

    bool hasUnmatched(Item joker) const {
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (!matched[i] && BRAINSTORM_TARGET_JOKERS[i] == joker) {
                return true;
            }
        }
        return false;
    }

    bool complete() const {
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (!matched[i]) {
                return false;
            }
        }
        return true;
    }

    unsigned int matchedMask() const {
        unsigned int result = 0;
        for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
            if (matched[i]) {
                result |= 1u << i;
            }
        }
        return result;
    }
};

struct BrainstormV5OwnedJoker {
    Item joker = Item::RETRY;
    int invisibleAge = 0;
    bool active = false;
    bool eternal = false;
};

struct BrainstormV5VisibleJokers {
    std::array<JokerData, 8> values{};
    std::size_t count = 0;

    void push_back(const JokerData& joker) { values[count++] = joker; }
    std::size_t size() const { return count; }
    const JokerData& operator[](std::size_t index) const {
        return values[index];
    }
};

struct BrainstormV5TimelineState {
    Instance inst;
    BrainstormV5JokerMatcher matcher;
    std::array<BrainstormV5OwnedJoker, 8> ownedJokers{};
    unsigned char ownedJokerCount = 0;
    JokerStickerGeneration stickerGeneration =
        JokerStickerGeneration::Full;

    explicit BrainstormV5TimelineState(
        const Instance& source,
        JokerStickerGeneration requestedStickerGeneration)
        : inst(source), stickerGeneration(requestedStickerGeneration) {}

    void acquireOwnedJoker(const JokerData& joker) {
        if (ownedJokerCount >= ownedJokers.size()) {
            return;
        }
        inst.lock(joker.joker);
        ownedJokers[ownedJokerCount++] =
            BrainstormV5OwnedJoker{
                joker.joker, 0, true, joker.stickers.eternal};
        if (joker.joker == Item::Showman) {
            inst.params.showman = true;
        }
    }

    void acquireRequirement(std::size_t requirement,
                            const JokerData& joker) {
        matcher.matched[requirement] = true;
        acquireOwnedJoker(joker);
    }

    void advanceCompletedBlind() {
        for (std::size_t i = 0; i < ownedJokerCount; i++) {
            BrainstormV5OwnedJoker& owned = ownedJokers[i];
            if (owned.active && owned.joker == Item::Invisible_Joker) {
                owned.invisibleAge++;
            }
        }
    }

    void reapplyOwnedLocks() {
        for (std::size_t i = 0; i < ownedJokerCount; i++) {
            if (ownedJokers[i].active) {
                inst.lock(ownedJokers[i].joker);
            }
        }
    }

    void autoSellOwnedJokersNeededByFutureOccurrences() {
        if (inst.params.showman) {
            return;
        }
        bool soldOne;
        do {
            soldOne = false;
            for (std::size_t i = 0; i < ownedJokerCount; i++) {
                BrainstormV5OwnedJoker& owned = ownedJokers[i];
                if (!owned.active || owned.eternal
                    || !matcher.hasUnmatched(owned.joker)
                    || (owned.joker == Item::Invisible_Joker
                        && owned.invisibleAge < 2)) {
                    continue;
                }
                owned.active = false;
                // Balatro removes the center from used_jokers only after the
                // sold card finishes dissolving. The no-reroll route waits for
                // that removal before opening any still-unopened Buffoon
                // packs.
                bool anotherCopyActive = false;
                for (std::size_t j = 0; j < ownedJokerCount; j++) {
                    if (ownedJokers[j].active
                        && ownedJokers[j].joker == owned.joker) {
                        anotherCopyActive = true;
                        break;
                    }
                }
                if (!anotherCopyActive) {
                    inst.unlock(owned.joker);
                }
                soldOne = true;
                break;
            }
        } while (soldOne);
    }
};

BrainstormJokerObservationSource brainstormObservationSourceForAnte(int ante) {
    switch (ante) {
        case 1:
            return BrainstormJokerObservationSource::AnteOne;
        case 2:
            return BrainstormJokerObservationSource::AnteTwo;
        case 3:
            return BrainstormJokerObservationSource::AnteThree;
        case 4:
            return BrainstormJokerObservationSource::AnteFour;
        case 5:
            return BrainstormJokerObservationSource::AnteFive;
        case 6:
            return BrainstormJokerObservationSource::AnteSix;
        case 7:
            return BrainstormJokerObservationSource::AnteSeven;
        default:
            return BrainstormJokerObservationSource::AnteEight;
    }
}

int brainstormLocationLastAnte(
    BrainstormJokerLocationRequirement location) {
    const int deadline = brainstormJokerLocationDeadline(location);
    if (deadline > 0) {
        return deadline;
    }
    switch (location) {
        case BrainstormJokerLocationRequirement::AnteOne:
        case BrainstormJokerLocationRequirement::SoulPack:
            return 1;
        case BrainstormJokerLocationRequirement::AnteTwo:
        case BrainstormJokerLocationRequirement::SoulOrAnteTwo:
            return 2;
        case BrainstormJokerLocationRequirement::AnteThree:
            return 3;
        case BrainstormJokerLocationRequirement::AnteFour:
            return 4;
        case BrainstormJokerLocationRequirement::ByAnteTwo:
        case BrainstormJokerLocationRequirement::ByAnteThree:
        case BrainstormJokerLocationRequirement::ByAnteFour:
        case BrainstormJokerLocationRequirement::ByAnteFive:
        case BrainstormJokerLocationRequirement::ByAnteSix:
        case BrainstormJokerLocationRequirement::ByAnteSeven:
        case BrainstormJokerLocationRequirement::ByAnteEight:
            return deadline;
    }
    return 1;
}

int brainstormV5MaximumRequestedAnte() {
    int result = 1;
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        result = std::max(
            result,
            brainstormLocationLastAnte(
                BRAINSTORM_TARGET_JOKER_LOCATIONS[i]));
    }
    return result;
}

bool brainstormV5TimelineNeedsStickerGeneration() {
    return jokerTargetsMayNeedEternalAwareSelling(
        BRAINSTORM_TARGET_JOKERS.data(),
        BRAINSTORM_TARGET_JOKER_COUNT, BRAINSTORM_STAKE);
}

bool brainstormV5HasExpiredRequirement(
    const BrainstormV5JokerMatcher& matcher, int completedAnte) {
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (!matcher.matched[i]
            && brainstormLocationLastAnte(
                BRAINSTORM_TARGET_JOKER_LOCATIONS[i])
                <= completedAnte) {
            return true;
        }
    }
    return false;
}

BrainstormV5VisibleJokers generateBrainstormV5ShopStock(
    BrainstormV5TimelineState& state, int ante) {
    const int windowSize = 2
        + (state.inst.isVoucherActive(Item::Overstock) ? 1 : 0)
        + (state.inst.isVoucherActive(Item::Overstock_Plus) ? 1 : 0);
    BrainstormV5VisibleJokers jokers;
    std::array<Item, 4> transientJokers{};
    int transientCount = 0;

    for (int i = 0; i < windowSize; i++) {
        JokerData joker;
        if (!state.inst.nextShopJokerOnly(
                ante, state.stickerGeneration, joker)) {
            continue;
        }
        jokers.push_back(joker);
        if (!state.inst.params.showman) {
            state.inst.lockTransient(joker.joker);
            transientJokers[transientCount++] = joker.joker;
        }
    }
    if (!state.inst.params.showman) {
        for (int i = 0; i < transientCount; i++) {
            state.inst.unlockTransient(transientJokers[i]);
        }
    }
    state.reapplyOwnedLocks();
    return jokers;
}

BrainstormV5VisibleJokers generateBrainstormV5BuffoonContents(
    BrainstormV5TimelineState& state, int size, int ante) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::NextBuffoonPack);
    BrainstormV5VisibleJokers jokers;
    std::array<Item, 8> transientJokers{};
    int transientCount = 0;

    for (int i = 0; i < size; i++) {
        const JokerData joker =
            state.inst.nextJoker(
                ItemSource::Buffoon_Pack, ante,
                state.stickerGeneration);
        jokers.push_back(joker);
        if (!state.inst.params.showman) {
            state.inst.lockTransient(joker.joker);
            transientJokers[transientCount++] = joker.joker;
        }
    }
    if (!state.inst.params.showman) {
        for (int i = 0; i < transientCount; i++) {
            state.inst.unlockTransient(transientJokers[i]);
        }
    }
    state.reapplyOwnedLocks();
    return jokers;
}

void appendBrainstormV5UniqueBranch(
    std::vector<BrainstormV5TimelineState>& branches,
    const BrainstormV5TimelineState& candidate) {
    const unsigned int candidateMask = candidate.matcher.matchedMask();
    for (const BrainstormV5TimelineState& branch : branches) {
        if (branch.matcher.matchedMask() == candidateMask) {
            return;
        }
    }
    branches.push_back(candidate);
}

void collectBrainstormV5AcquisitionBranches(
    const BrainstormV5TimelineState& state,
    const BrainstormV5VisibleJokers& visibleJokers,
    BrainstormJokerObservationSource source, int choiceLimit,
    unsigned int usedCards, int choicesMade,
    std::vector<BrainstormV5TimelineState>& branches) {
    appendBrainstormV5UniqueBranch(branches, state);
    if (choicesMade >= choiceLimit) {
        return;
    }

    for (std::size_t cardIndex = 0;
         cardIndex < visibleJokers.size(); cardIndex++) {
        const unsigned int cardBit = 1u << cardIndex;
        if ((usedCards & cardBit) != 0) {
            continue;
        }
        const JokerData& joker = visibleJokers[cardIndex];
        const unsigned int requirements =
            state.matcher.matchingRequirementMask(joker, source);
        for (std::size_t requirement = 0;
             requirement < BRAINSTORM_TARGET_JOKER_COUNT; requirement++) {
            if ((requirements & (1u << requirement)) == 0) {
                continue;
            }
            BrainstormV5TimelineState next = state;
            next.acquireRequirement(requirement, joker);
            collectBrainstormV5AcquisitionBranches(
                next, visibleJokers, source, choiceLimit,
                usedCards | cardBit, choicesMade + 1, branches);
        }
    }
}

std::vector<BrainstormV5TimelineState>
brainstormV5AcquisitionBranches(
    const BrainstormV5TimelineState& state,
    const BrainstormV5VisibleJokers& visibleJokers,
    BrainstormJokerObservationSource source, int choiceLimit) {
    std::vector<BrainstormV5TimelineState> result;
    result.reserve(8);
    collectBrainstormV5AcquisitionBranches(
        state, visibleJokers, source,
        std::min<int>(choiceLimit, visibleJokers.size()), 0, 0, result);
    return result;
}

enum class BrainstormV5AcquisitionPlanKind {
    None,
    ImmediateSuccess,
    DirectTwoBranch,
    General,
};

struct BrainstormV5AcquisitionPlan {
    BrainstormV5AcquisitionPlanKind kind =
        BrainstormV5AcquisitionPlanKind::None;
    std::size_t cardIndex = 0;
    std::size_t requirement = 0;
};

BrainstormV5AcquisitionPlan brainstormV5PlanVisibleAcquisition(
    const BrainstormV5TimelineState& state,
    const BrainstormV5VisibleJokers& visibleJokers,
    BrainstormJokerObservationSource source, int choiceLimit) {
    const int effectiveChoiceLimit = std::min<int>(
        choiceLimit, visibleJokers.size());
    if (effectiveChoiceLimit < 1) {
        return {};
    }

    unsigned int reachableRequirements = 0;
    bool foundFirst = false;
    std::size_t firstCardIndex = 0;
    std::size_t firstRequirement = 0;
    for (std::size_t i = 0; i < visibleJokers.size(); i++) {
        const unsigned int requirements =
            state.matcher.matchingRequirementMask(
                visibleJokers[i], source);
        reachableRequirements |= requirements;
        if (!foundFirst && requirements != 0) {
            for (std::size_t requirement = 0;
                 requirement < BRAINSTORM_TARGET_JOKER_COUNT;
                 requirement++) {
                if ((requirements & (1u << requirement)) != 0) {
                    foundFirst = true;
                    firstCardIndex = i;
                    firstRequirement = requirement;
                    break;
                }
            }
        }
    }
    if (!foundFirst) {
        return {};
    }

    const unsigned int targetMask =
        (1u << BRAINSTORM_TARGET_JOKER_COUNT) - 1u;
    const unsigned int unmatchedRequirements =
        targetMask & ~state.matcher.matchedMask();
    if ((unmatchedRequirements & (unmatchedRequirements - 1u)) == 0) {
        return BrainstormV5AcquisitionPlan{
            BrainstormV5AcquisitionPlanKind::ImmediateSuccess,
            firstCardIndex, firstRequirement};
    }

    if ((reachableRequirements & (reachableRequirements - 1u)) != 0) {
        return BrainstormV5AcquisitionPlan{
            BrainstormV5AcquisitionPlanKind::General,
            firstCardIndex, firstRequirement};
    }

    if (effectiveChoiceLimit > 1) {
        BrainstormV5JokerMatcher afterFirst = state.matcher;
        afterFirst.matched[firstRequirement] = true;
        for (std::size_t cardIndex = 0;
             cardIndex < visibleJokers.size(); cardIndex++) {
            if (cardIndex != firstCardIndex
                && afterFirst.matchingRequirementMask(
                       visibleJokers[cardIndex], source) != 0) {
                return BrainstormV5AcquisitionPlan{
                    BrainstormV5AcquisitionPlanKind::General,
                    firstCardIndex, firstRequirement};
            }
        }
    }

    return BrainstormV5AcquisitionPlan{
        BrainstormV5AcquisitionPlanKind::DirectTwoBranch,
        firstCardIndex, firstRequirement};
}

struct BrainstormV5ShopPoint {
    int ante = 1;
    bool firstShopInAnte = false;
    bool lastShopInAnte = false;
};

bool scanBrainstormV5TimelineAt(
    BrainstormV5TimelineState state,
    const std::vector<BrainstormV5ShopPoint>& shops,
    std::size_t shopIndex);

bool scanBrainstormV5DisplayedPacks(
    BrainstormV5TimelineState state, const std::array<Pack, 2>& packs,
    std::size_t packIndex, BrainstormJokerObservationSource source,
    const std::vector<BrainstormV5ShopPoint>& shops,
    std::size_t shopIndex) {
    if (state.matcher.complete()) {
        return true;
    }
    if (packIndex >= packs.size()) {
        const BrainstormV5ShopPoint& currentShop = shops[shopIndex];
        if (currentShop.lastShopInAnte
            && brainstormV5HasExpiredRequirement(
                state.matcher, currentShop.ante)) {
            return false;
        }
        return scanBrainstormV5TimelineAt(
            std::move(state), shops, shopIndex + 1);
    }

    const Pack& pack = packs[packIndex];
    if (!isBuffoonPackType(pack.type)) {
        return scanBrainstormV5DisplayedPacks(
            std::move(state), packs, packIndex + 1, source, shops,
            shopIndex);
    }

    // Buffoon contents are generated only when opened. v5 prescribes opening
    // every displayed Buffoon in left-to-right order so later buf RNG is
    // reproducible.
    const BrainstormV5VisibleJokers contents =
        generateBrainstormV5BuffoonContents(
            state, pack.size, shops[shopIndex].ante);
    const BrainstormV5AcquisitionPlan acquisitionPlan =
        brainstormV5PlanVisibleAcquisition(
            state, contents, source, pack.choices);
    if (acquisitionPlan.kind
        == BrainstormV5AcquisitionPlanKind::None) {
        state.autoSellOwnedJokersNeededByFutureOccurrences();
        return scanBrainstormV5DisplayedPacks(
            std::move(state), packs, packIndex + 1, source, shops,
            shopIndex);
    }
    if (acquisitionPlan.kind
        == BrainstormV5AcquisitionPlanKind::ImmediateSuccess) {
        return true;
    }
    if (acquisitionPlan.kind
        == BrainstormV5AcquisitionPlanKind::DirectTwoBranch) {
        BrainstormV5TimelineState acquired = state;
        acquired.acquireRequirement(
            acquisitionPlan.requirement,
            contents[acquisitionPlan.cardIndex]);

        state.autoSellOwnedJokersNeededByFutureOccurrences();
        if (scanBrainstormV5DisplayedPacks(
                std::move(state), packs, packIndex + 1, source, shops,
                shopIndex)) {
            return true;
        }
        acquired.autoSellOwnedJokersNeededByFutureOccurrences();
        const bool acquiredResult = scanBrainstormV5DisplayedPacks(
            std::move(acquired), packs, packIndex + 1, source, shops,
            shopIndex);
        return acquiredResult;
    }
    std::vector<BrainstormV5TimelineState> branches =
        brainstormV5AcquisitionBranches(
            state, contents, source, pack.choices);
    for (BrainstormV5TimelineState& branch : branches) {
        branch.autoSellOwnedJokersNeededByFutureOccurrences();
        if (scanBrainstormV5DisplayedPacks(
                std::move(branch), packs, packIndex + 1, source, shops,
                shopIndex)) {
            return true;
        }
    }
    return false;
}

bool scanBrainstormV5TimelineAt(
    BrainstormV5TimelineState state,
    const std::vector<BrainstormV5ShopPoint>& shops,
    std::size_t shopIndex) {
    if (state.matcher.complete()) {
        return true;
    }
    if (shopIndex >= shops.size()) {
        return false;
    }

    const BrainstormV5ShopPoint& shop = shops[shopIndex];
    if (shop.firstShopInAnte && shop.ante >= 2) {
        state.inst.initUnlocks(shop.ante, false);
        state.reapplyOwnedLocks();
    }

    // Each listed shop follows one completed blind. The skipped Small Blind
    // on a Charm-tag route is omitted from the shop list and therefore does
    // not age Invisible Joker.
    state.advanceCompletedBlind();

    // Initial stock and both pack types exist before the player can sell.
    const BrainstormV5VisibleJokers stock =
        generateBrainstormV5ShopStock(state, shop.ante);
    const std::array<Pack, 2> packs = {
        packInfo(state.inst.nextPack(shop.ante)),
        packInfo(state.inst.nextPack(shop.ante)),
    };
    const BrainstormJokerObservationSource source =
        brainstormObservationSourceForAnte(shop.ante);
    const BrainstormV5AcquisitionPlan acquisitionPlan =
        brainstormV5PlanVisibleAcquisition(
            state, stock, source, static_cast<int>(stock.size()));
    if (acquisitionPlan.kind
        == BrainstormV5AcquisitionPlanKind::None) {
        state.autoSellOwnedJokersNeededByFutureOccurrences();
        return scanBrainstormV5DisplayedPacks(
            std::move(state), packs, 0, source, shops, shopIndex);
    }
    if (acquisitionPlan.kind
        == BrainstormV5AcquisitionPlanKind::ImmediateSuccess) {
        return true;
    }
    if (acquisitionPlan.kind
        == BrainstormV5AcquisitionPlanKind::DirectTwoBranch) {
        BrainstormV5TimelineState acquired = state;
        acquired.acquireRequirement(
            acquisitionPlan.requirement,
            stock[acquisitionPlan.cardIndex]);

        state.autoSellOwnedJokersNeededByFutureOccurrences();
        if (scanBrainstormV5DisplayedPacks(
                std::move(state), packs, 0, source, shops, shopIndex)) {
            return true;
        }
        acquired.autoSellOwnedJokersNeededByFutureOccurrences();
        const bool acquiredResult = scanBrainstormV5DisplayedPacks(
            std::move(acquired), packs, 0, source, shops, shopIndex);
        return acquiredResult;
    }
    std::vector<BrainstormV5TimelineState> stockBranches =
        brainstormV5AcquisitionBranches(
            state, stock, source, static_cast<int>(stock.size()));

    for (BrainstormV5TimelineState& branch : stockBranches) {
        // Selling now cannot change the already-generated initial stock, but
        // it does unlock the center before unopened Buffoon contents.
        branch.autoSellOwnedJokersNeededByFutureOccurrences();
        if (scanBrainstormV5DisplayedPacks(
                std::move(branch), packs, 0, source, shops, shopIndex)) {
            return true;
        }
    }
    return false;
}

std::vector<BrainstormV5ShopPoint> buildBrainstormV5ShopTimeline(
    bool charmRoute, int maximumAnte) {
    std::vector<BrainstormV5ShopPoint> result;
    result.reserve(2 + std::max(0, maximumAnte - 1) * 3);

    const int anteOneShopCount = charmRoute ? 1 : 2;
    for (int shop = 0; shop < anteOneShopCount; shop++) {
        result.push_back(
            BrainstormV5ShopPoint{
                1, shop == 0, shop == anteOneShopCount - 1});
    }
    for (int ante = 2; ante <= maximumAnte; ante++) {
        for (int shop = 0; shop < 3; shop++) {
            result.push_back(
                BrainstormV5ShopPoint{
                    ante, shop == 0, shop == 2});
        }
    }
    return result;
}

void matchAndAcquireBrainstormV5GeneratedJoker(
    BrainstormV5TimelineState& state, const JokerData& joker,
    BrainstormJokerObservationSource source) {
    const unsigned int requirements =
        state.matcher.matchingRequirementMask(joker, source);
    if (requirements != 0) {
        for (std::size_t requirement = 0;
             requirement < BRAINSTORM_TARGET_JOKER_COUNT; requirement++) {
            if ((requirements & (1u << requirement)) != 0) {
                state.matcher.matched[requirement] = true;
                break;
            }
        }
    }
    state.acquireOwnedJoker(joker);
}

bool passesBrainstormV5JokerTargetsOnRoute(
    Instance early, bool charmRoute) {
    if (!BRAINSTORM_TARGET_JOKERS_VALID) {
        return false;
    }
    const int requiredSoulCount = requiredCharmSoulCount();

    early.initLocks(1, false, true);
    early.setDeck(BRAINSTORM_DECK);
    early.setStake(BRAINSTORM_STAKE);
    BrainstormCharmPackVisibility charmPack;
    if (charmRoute) {
        if (requiredSoulCount > 4
            || (!BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG
                && early.nextTag(1) != Item::Charm_Tag)) {
            return false;
        }
        charmPack =
            scanEarlyCharmPackVisibility(early, requiredSoulCount);
        if (charmPack.soulCount < requiredSoulCount) {
            return false;
        }
    }

    if (BRAINSTORM_TARGET_JOKER_COUNT == 0) {
        return true;
    }

    const int minimumSoulSelections =
        static_cast<int>(brainstormRequiredLegendaryTargetCount());
    const int maximumSoulSelections =
        std::min(2, charmPack.soulCount);

    BrainstormV5JokerMatcher emptyMatcher;
    const bool canUseJudgement =
        charmRoute && charmPack.hasJudgement
        && emptyMatcher.hasUnmatchedForSource(
            BrainstormJokerObservationSource::Judgement);
    const JokerStickerGeneration timelineStickerGeneration =
        brainstormV5TimelineNeedsStickerGeneration()
        ? JokerStickerGeneration::EternalOnly
        : JokerStickerGeneration::None;
    const std::vector<BrainstormV5ShopPoint> shops =
        buildBrainstormV5ShopTimeline(
            charmRoute, brainstormV5MaximumRequestedAnte());

    for (int soulSelections = minimumSoulSelections;
         soulSelections <= maximumSoulSelections; soulSelections++) {
        for (int judgementSelection = canUseJudgement ? 1 : 0;
             judgementSelection >= 0; judgementSelection--) {
            if (soulSelections + judgementSelection > 2) {
                continue;
            }
            const int orderVariants =
                soulSelections > 0 && judgementSelection != 0 ? 2 : 1;
            for (int orderVariant = 0;
                 orderVariant < orderVariants; orderVariant++) {
                const bool judgementFirst =
                    orderVariants == 2 && orderVariant == 1;
                BrainstormV5TimelineState state(
                    early, timelineStickerGeneration);

                auto acquireJudgement = [&]() {
                    const JokerData judgementJoker =
                        state.inst.nextJoker(
                            ItemSource::Judgement, 1, false);
                    matchAndAcquireBrainstormV5GeneratedJoker(
                        state, judgementJoker,
                        BrainstormJokerObservationSource::Judgement);
                    state.autoSellOwnedJokersNeededByFutureOccurrences();
                };
                auto acquireSouls = [&]() {
                    for (int i = 0; i < soulSelections; i++) {
                        const JokerData soulJoker =
                            state.inst.nextJoker(
                                ItemSource::Soul, 1, false);
                        matchAndAcquireBrainstormV5GeneratedJoker(
                            state, soulJoker,
                            BrainstormJokerObservationSource::Soul);
                        state
                            .autoSellOwnedJokersNeededByFutureOccurrences();
                    }
                };

                if (judgementFirst) {
                    acquireJudgement();
                    acquireSouls();
                } else {
                    acquireSouls();
                    if (judgementSelection != 0) {
                        acquireJudgement();
                    }
                }

                // A pure starting-pack requirement cannot be recovered later.
                bool missingSoulPackTarget = false;
                for (std::size_t i = 0;
                     i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
                    if (!state.matcher.matched[i]
                        && BRAINSTORM_TARGET_JOKER_LOCATIONS[i]
                            == BrainstormJokerLocationRequirement::SoulPack) {
                        missingSoulPackTarget = true;
                        break;
                    }
                }
                if (!missingSoulPackTarget
                    && scanBrainstormV5TimelineAt(
                        std::move(state), shops, 0)) {
                    return true;
                }
            }
        }
    }
    return false;
}

bool passesBrainstormV5JokerTargets(Instance& early) {
    if (!BRAINSTORM_TARGET_JOKERS_VALID) {
        return false;
    }

    if (needsStartingCharmPack()) {
        return passesBrainstormV5JokerTargetsOnRoute(early, true);
    }

    // A cumulative non-Legendary target does not force a Charm Tag: it may be
    // acquired naturally without skipping. When this seed actually offers a
    // Charm Tag, v6 also considers the independent skip route so Judgement is
    // genuinely part of the cumulative window.
    if (passesBrainstormV5JokerTargetsOnRoute(early, false)) {
        return true;
    }
    return BRAINSTORM_V6_DEADLINE_MODE
        && brainstormHasDeadlineJokerTarget()
        && passesBrainstormV5JokerTargetsOnRoute(early, true);
}

struct FastNodeState {
    double value = 0.0;
    bool initialized = false;
};

struct ExactCharmObservatoryEval {
    Seed &seed;
    double hashedSeed;
    FastNodeState soulTarotState;
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
        state.value = round13(
            fractPositive(state.value * 1.72431234 + 2.134453429141));
        return (state.value + hashedSeed) / 2.0;
    }

    double freshNode(const std::string &id) {
        double value = pseudohash_from(
            id, seed.pseudohash(static_cast<int>(id.length())));
        value = round13(
            fractPositive(value * 1.72431234 + 2.134453429141));
        return (value + hashedSeed) / 2.0;
    }

    template <std::size_t N, typename IsLocked>
    Item drawFreshChoice(const std::string &baseId,
                         const std::array<Item, N> &items,
                         IsLocked isLocked) {
        int resampleNumber = 1;
        while (true) {
            const double node = resampleNumber <= 1
                ? freshNode(baseId)
                : freshNode(
                    baseId + "_resample" + anteToString(resampleNumber));
            Item item = items[lua_randint_from_seed(
                node, 0,
                static_cast<int>(items.size()) - 1)];
            if ((item != Item::RETRY && !isLocked(item)) || resampleNumber >= 1000) {
                return item;
            }
            resampleNumber++;
        }
    }

    bool passesCharmTag() {
        Item tag = drawFreshChoice(
            tagKey(), TAGS,
            [](Item item) { return isAnteOneLockedTag(item); });
        return tag == Item::Charm_Tag;
    }

    bool passesSoulPerkeo() {
        // Soul eligibility has its own RNG node.  Until a Soul appears it is
        // polled exactly once per pack card, independently of which ordinary
        // Tarot the other node produces.  This filter only needs to know that
        // at least one of the five polls succeeds, so avoid generating and
        // duplicate-locking the ordinary Tarots for the overwhelmingly common
        // misses.
        for (int i = 0; i < 5; ++i) {
            if (lua_random_from_seed(
                    nextNode(soulTarotState, soulTarotKey())) > 0.997) {
                Item legendary = drawFreshChoice(
                    legendaryJokerKey(), LEGENDARY_JOKERS,
                    [](Item) { return false; });
                return legendary == Item::Perkeo;
            }
        }
        return false;
    }

    bool passesSoulCount(int requiredSoulCount) {
        int foundSouls = 0;
        for (int i = 0; i < 5; ++i) {
            if (lua_random_from_seed(
                    nextNode(soulTarotState, soulTarotKey())) > 0.997
                && ++foundSouls >= requiredSoulCount) {
                return true;
            }
        }
        return false;
    }

    bool passesCharmSoulPerkeo() {
        return passesCharmTag() && passesSoulPerkeo();
    }

    Item nextVoucher(const std::string &key) {
        return drawFreshChoice(
            key, VOUCHERS,
            [this](Item item) {
                if (telescopeLocked && item == Item::Telescope) {
                    return true;
                }
                if (item == Item::Observatory && telescopeLocked) {
                    return false;
                }
                return isFreshRunLockedVoucher(item);
            });
    }

    bool passesTelescope() {
        Item firstVoucher = nextVoucher(voucher1Key());
        return firstVoucher == Item::Telescope;
    }

    bool passesObservatory() {
        Item firstVoucher = nextVoucher(voucher1Key());
        if (firstVoucher != Item::Telescope) {
            return false;
        }
        telescopeLocked = true;
        Item secondVoucher = nextVoucher(voucher2Key());
        return secondVoucher == Item::Observatory;
    }
};

struct FastNegativeEditionEval {
    Seed& seed;
    double hashedSeed;
    FastNodeState shopCardTypeState;
    FastNodeState shopEditionState;
    FastNodeState packTypeState;
    FastNodeState buffoonEditionState;

    explicit FastNegativeEditionEval(Seed& seedRef)
        : seed(seedRef), hashedSeed(seedRef.pseudohash(0)) {}

    static const std::string& shopCardTypeKey() {
        static const std::string key =
            RandomType::Card_Type + anteToString(1);
        return key;
    }

    static const std::string& shopEditionKey() {
        static const std::string key =
            RandomType::Joker_Edition + ItemSource::Shop + anteToString(1);
        return key;
    }

    static const std::string& packTypeKey() {
        static const std::string key =
            RandomType::Shop_Pack + anteToString(1);
        return key;
    }

    static const std::string& buffoonEditionKey() {
        static const std::string key =
            RandomType::Joker_Edition
            + ItemSource::Buffoon_Pack + anteToString(1);
        return key;
    }

    double nextNode(FastNodeState& state, const std::string& id) {
        if (!state.initialized) {
            state.value = pseudohash_from(
                id, seed.pseudohash(static_cast<int>(id.length())));
            state.initialized = true;
        }
        state.value = round13(
            fractPositive(state.value * 1.72431234 + 2.134453429141));
        return (state.value + hashedSeed) / 2.0;
    }

    bool nextEditionIsNegative(FastNodeState& state,
                               const std::string& key) {
        return lua_random_from_seed(nextNode(state, key)) > 0.997;
    }

    bool nextShopCardIsJoker() {
        // Zodiac starts with both Merchant vouchers active, increasing the
        // Tarot and Planet rates from 4 to 9.6 each. Ghost instead adds a
        // spectral rate of 2. The edition gate must use the same denominator
        // as Instance::getShopInstance() or it could reject a valid seed.
        const double totalRate = BRAINSTORM_DECK == Item::Zodiac_Deck
            ? 39.2
            : (BRAINSTORM_DECK == Item::Ghost_Deck ? 30.0 : 28.0);
        const double poll = lua_random_from_seed(
            nextNode(shopCardTypeState, shopCardTypeKey())) * totalRate;
        return poll < 20.0;
    }

    Item nextRandomPack() {
        const double poll = lua_random_from_seed(
            nextNode(packTypeState, packTypeKey())) * PACKS[0].weight;
        int index = 1;
        double cumulativeWeight = 0.0;
        while (cumulativeWeight < poll) {
            cumulativeWeight += PACKS[index].weight;
            index++;
        }
        return PACKS[index - 1].item;
    }

    bool passes(int shopCards, int displayedPacks) {
        for (int i = 0; i < shopCards; i++) {
            if (nextShopCardIsJoker()
                && nextEditionIsNegative(
                    shopEditionState, shopEditionKey())) {
                return true;
            }
        }

        // The first Ante-1 pack is deterministically a normal Buffoon Pack.
        Item packType = Item::Buffoon_Pack;
        for (int i = 0; i < displayedPacks; i++) {
            if (i > 0) {
                packType = nextRandomPack();
            }
            if (!isBuffoonPackType(packType)) {
                continue;
            }
            const int packSize = packInfo(packType).size;
            for (int card = 0; card < packSize; card++) {
                if (nextEditionIsNegative(
                        buffoonEditionState, buffoonEditionKey())) {
                    return true;
                }
            }
        }
        return false;
    }
};

bool fastOpeningRequiresPerkeoIdentity() {
    if (requiredCharmSoulCount() != 1
        || brainstormRequiredLegendaryTargetCount() != 1) {
        return false;
    }

    if (customFilterRequiresPerkeo()) {
        return true;
    }
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (BRAINSTORM_TARGET_JOKERS[i] == Item::Perkeo) {
            // Legendary Jokers cannot occur in an ordinary shop or Buffoon
            // pack, so every valid Perkeo timing ultimately uses this same
            // starting Soul draw.
            return true;
        }
    }
    return false;
}

bool canUseFastOpeningCharmSoulPrefilter() {
    return requiredCharmSoulCount() > 0;
}

bool openingCharmSoulBatchStrategyEnabled() {
    const char* envValue = std::getenv("BRAINSTORM_OPENING_BATCH");
    return envValue == nullptr
        || envValue[0] == '\0'
        || (envValue[0] != '0'
            && std::strcmp(envValue, "false") != 0
            && std::strcmp(envValue, "False") != 0);
}

int soleRequiredLegendaryIndex() {
    if (brainstormRequiredLegendaryTargetCount() != 1) {
        return -1;
    }

    Item requiredLegendary = customFilterRequiresPerkeo()
        ? Item::Perkeo
        : Item::RETRY;
    for (std::size_t index = 0;
         index < BRAINSTORM_TARGET_JOKER_COUNT; ++index) {
        if (isLegendaryJoker(BRAINSTORM_TARGET_JOKERS[index])) {
            requiredLegendary = BRAINSTORM_TARGET_JOKERS[index];
            break;
        }
    }
    for (std::size_t index = 0; index < LEGENDARY_JOKERS.size(); ++index) {
        if (LEGENDARY_JOKERS[index] == requiredLegendary) {
            return static_cast<int>(index);
        }
    }
    return -1;
}

OpeningCharmSoulCriteria configuredOpeningCharmSoulCriteria() {
    OpeningCharmSoulCriteria criteria;
    criteria.minimumSoulCount = requiredCharmSoulCount();
    if (criteria.minimumSoulCount == 1
        && brainstormRequiredLegendaryTargetCount() == 1) {
        criteria.legendaryIndex = soleRequiredLegendaryIndex();
    }
    return criteria;
}

bool canUseOpeningCharmSoulBatch() {
    // Conditional estimator probes deliberately remove the Charm probability.
    // Keep those probes on their established scalar semantics rather than
    // applying an unconditional Charm gate.
    const int minimumSoulCount = requiredCharmSoulCount();
    return openingCharmSoulBatchStrategyEnabled()
        && openingCharmSoulVectorBackendAvailable()
        && !BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG
        && minimumSoulCount >= 1
        && minimumSoulCount <= 4;
}

bool perkeoInvisibleAnchorPriorityEnabled() {
    const char* envValue = std::getenv("BRAINSTORM_ANCHOR_PRIORITY");
    return envValue == nullptr
        || envValue[0] == '\0'
        || (envValue[0] != '0'
            && std::strcmp(envValue, "false") != 0
            && std::strcmp(envValue, "False") != 0);
}

bool canUsePerkeoInvisibleAnchorPriority() {
    if (!perkeoInvisibleAnchorPriorityEnabled()
        || BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG
        || requiredCharmSoulCount() != 1
        || !needsStartingCharmPack()
        || (BRAINSTORM_TAG != Item::RETRY
            && BRAINSTORM_TAG != Item::Charm_Tag)) {
        return false;
    }

    bool requiresPackPerkeo = false;
    bool requiresPackInvisible = false;
    for (std::size_t index = 0;
         index < BRAINSTORM_TARGET_JOKER_COUNT; ++index) {
        if (BRAINSTORM_TARGET_JOKER_LOCATIONS[index]
            != BrainstormJokerLocationRequirement::SoulPack) {
            continue;
        }
        requiresPackPerkeo |=
            BRAINSTORM_TARGET_JOKERS[index] == Item::Perkeo;
        requiresPackInvisible |=
            BRAINSTORM_TARGET_JOKERS[index] == Item::Invisible_Joker;
    }
    return requiresPackPerkeo && requiresPackInvisible;
}

bool canUsePerkeoInvisibleAnteTwoInvisibleAnchorPriority() {
    // Later shop/pack timelines can depend on deck-starting vouchers and stake
    // sticker rules. The derived v1 child was built for the user's exact
    // three-occurrence Plasma/Gold route. An additional acquired Joker can
    // change pool locks and later resampling, so broader target shapes must use
    // the deck/stake-independent parent rather than treating this child as a
    // complete superset.
    if (BRAINSTORM_DECK != Item::Plasma_Deck
        || BRAINSTORM_STAKE != Item::Gold_Stake
        || !canUsePerkeoInvisibleAnchorPriority()
        || BRAINSTORM_TARGET_JOKER_COUNT != 3) {
        return false;
    }
    return BRAINSTORM_TARGET_JOKERS[0] == Item::Perkeo
        && BRAINSTORM_TARGET_JOKER_LOCATIONS[0]
            == BrainstormJokerLocationRequirement::SoulPack
        && BRAINSTORM_TARGET_JOKERS[1] == Item::Invisible_Joker
        && BRAINSTORM_TARGET_JOKER_LOCATIONS[1]
            == BrainstormJokerLocationRequirement::SoulPack
        && BRAINSTORM_TARGET_JOKERS[2] == Item::Invisible_Joker
        && BRAINSTORM_TARGET_JOKER_LOCATIONS[2]
            == BrainstormJokerLocationRequirement::AnteTwo;
}

bool canUseCharmPerkeoMegaSpectralAnchorPriority() {
    if (!perkeoInvisibleAnchorPriorityEnabled()
        || BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG
        || !BRAINSTORM_TARGET_JOKERS_VALID
        || BRAINSTORM_DECK != Item::Plasma_Deck
        || BRAINSTORM_STAKE != Item::Gold_Stake
        || BRAINSTORM_PACK != Item::Mega_Spectral_Pack
        || requiredCharmSoulCount() != 1
        || !needsStartingCharmPack()
        || (BRAINSTORM_TAG != Item::RETRY
            && BRAINSTORM_TAG != Item::Charm_Tag)) {
        return false;
    }

    // The persisted parent requires the Legendary itself to be the Soul-pack
    // Perkeo. A Perkeo target with a later timing does not imply that opening
    // predicate and must stay on the exhaustive path.
    for (std::size_t index = 0;
         index < BRAINSTORM_TARGET_JOKER_COUNT; ++index) {
        if (BRAINSTORM_TARGET_JOKERS[index] == Item::Perkeo
            && BRAINSTORM_TARGET_JOKER_LOCATIONS[index]
                == BrainstormJokerLocationRequirement::SoulPack) {
            return true;
        }
    }
    return false;
}

bool canUseCharmPerkeoMegaNaneinfPlasmaGoldAnchorPriority() {
    if (!canUseCharmPerkeoMegaSpectralAnchorPriority()
        || BRAINSTORM_TARGET_JOKER_COUNT != 5) {
        return false;
    }

    // The child stores the five-Joker core with Any editions and cumulative
    // deadlines. Negative editions, earlier/fixed timings, vouchers,
    // Observatory, rank counts, and advanced filters can only narrow that
    // population; indexed candidates are authoritatively rechecked against
    // all of those active constraints. Later deadlines would broaden the
    // population and therefore cannot use a complete child miss as proof.
    constexpr std::array<std::pair<Item, int>, 5> requiredTargets{{
        {Item::Perkeo, 0},
        {Item::Blueprint, 4},
        {Item::Brainstorm, 4},
        {Item::Baron, 8},
        {Item::Mime, 8},
    }};
    std::array<bool, requiredTargets.size()> matched{};
    for (std::size_t index = 0;
         index < BRAINSTORM_TARGET_JOKER_COUNT; ++index) {
        bool found = false;
        for (std::size_t required = 0;
             required < requiredTargets.size(); ++required) {
            const int deadline = requiredTargets[required].second;
            const BrainstormJokerLocationRequirement location =
                BRAINSTORM_TARGET_JOKER_LOCATIONS[index];
            const bool locationImpliesChild = deadline == 0
                ? location == BrainstormJokerLocationRequirement::SoulPack
                : brainstormLocationLastAnte(location) <= deadline;
            if (!matched[required]
                && BRAINSTORM_TARGET_JOKERS[index]
                    == requiredTargets[required].first
                && locationImpliesChild) {
                matched[required] = true;
                found = true;
                break;
            }
        }
        if (!found) {
            return false;
        }
    }
    return std::all_of(matched.begin(), matched.end(), [](bool value) {
        return value;
    });
}

SeedBatchPrefilter openingCharmSoulBatchPrefilter() {
    const OpeningCharmSoulCriteria criteria =
        configuredOpeningCharmSoulCriteria();
    return SeedBatchPrefilter{
        createOpeningCharmSoulBatchContext,
        destroyOpeningCharmSoulBatchContext,
        collectOpeningCharmSoulCandidatesWithContext,
        encodeOpeningCharmSoulCriteria(criteria)};
}

int configuredOpeningTagIndex() {
    const Item targetTag = needsStartingCharmPack()
        ? Item::Charm_Tag
        : BRAINSTORM_TAG;
    if (targetTag == Item::RETRY) {
        return -1;
    }
    for (std::size_t index = 0; index < TAGS.size(); ++index) {
        if (TAGS[index] == targetTag) {
            return static_cast<int>(index);
        }
    }
    return -1;
}

bool canUseOpeningTagBatch() {
    // A Soul requirement always uses the richer Charm/Soul batch above. The
    // tag-only mode is reserved for disjoint searches (including a forced
    // starting-Charm route with no Soul count) and must not undo conditional
    // estimator probes that deliberately divide out the Charm probability.
    return openingCharmSoulBatchStrategyEnabled()
        && openingCharmSoulVectorBackendAvailable()
        && !BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG
        && requiredCharmSoulCount() == 0
        && configuredOpeningTagIndex() >= 0;
}

SeedBatchPrefilter openingTagBatchPrefilter() {
    const OpeningTagCriteria criteria{configuredOpeningTagIndex()};
    return SeedBatchPrefilter{
        createOpeningTagBatchContext,
        destroyOpeningTagBatchContext,
        collectOpeningTagCandidatesWithContext,
        encodeOpeningTagCriteria(criteria)};
}

bool passesFastOpeningCharmSoulPrefilter(Seed& seed) {
    ExactCharmObservatoryEval eval(seed);
    if (!BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG && !eval.passesCharmTag()) {
        return false;
    }
    if (fastOpeningRequiresPerkeoIdentity()) {
        return eval.passesSoulPerkeo();
    }
    return eval.passesSoulCount(requiredCharmSoulCount());
}

bool canUseFastNegativeBlueprintEditionPrefilter() {
    return BRAINSTORM_FILTER == customFilters::NEGATIVE_BLUEPRINT
        || BRAINSTORM_FILTER
            == customFilters::NEGATIVE_PERKEO_BLUEPRINT;
}

bool passesFastNegativeBlueprintEditionPrefilter(Seed& seed) {
    FastNegativeEditionEval eval(seed);
    const bool combinedPerkeoFilter =
        BRAINSTORM_FILTER == customFilters::NEGATIVE_PERKEO_BLUEPRINT;
    return eval.passes(
        combinedPerkeoFilter ? 2 : 4,
        combinedPerkeoFilter ? 3 : 4);
}

bool negativeBlueprintBatchStrategyEnabled() {
    const char* envValue = std::getenv(
        "BRAINSTORM_NEGATIVE_BLUEPRINT_BATCH");
    return envValue == nullptr
        || envValue[0] == '\0'
        || (envValue[0] != '0'
            && std::strcmp(envValue, "false") != 0
            && std::strcmp(envValue, "False") != 0);
}

NegativeBlueprintCriteria configuredNegativeBlueprintCriteria() {
    NegativeBlueprintCriteria criteria;
    const bool combinedPerkeoFilter =
        BRAINSTORM_FILTER == customFilters::NEGATIVE_PERKEO_BLUEPRINT;
    criteria.shopCards = combinedPerkeoFilter ? 2 : 4;
    criteria.displayedPacks = combinedPerkeoFilter ? 3 : 4;
    criteria.shopRate = BRAINSTORM_DECK == Item::Ghost_Deck
        ? NegativeBlueprintShopRate::Ghost
        : BRAINSTORM_DECK == Item::Zodiac_Deck
        ? NegativeBlueprintShopRate::Zodiac
        : NegativeBlueprintShopRate::Ordinary;
    // The extra rarity streams reduce survivors about twentyfold but cost
    // more than they save for the bare filter. Timeline target evaluation is
    // expensive enough to benefit decisively from the stronger exact gate.
    criteria.requireRare = BRAINSTORM_TARGET_JOKER_COUNT > 0;
    return criteria;
}

bool canUseNegativeBlueprintBatch() {
    return negativeBlueprintBatchStrategyEnabled()
        && negativeBlueprintVectorBackendAvailable()
        && canUseFastNegativeBlueprintEditionPrefilter();
}

SeedBatchPrefilter negativeBlueprintBatchPrefilter() {
    const NegativeBlueprintCriteria criteria =
        configuredNegativeBlueprintCriteria();
    return SeedBatchPrefilter{
        createNegativeBlueprintBatchContext,
        destroyNegativeBlueprintBatchContext,
        collectNegativeBlueprintCandidatesWithContext,
        encodeNegativeBlueprintCriteria(criteria)};
}

bool arbitraryNegativeBatchStrategyEnabled() {
    const char* envValue = std::getenv(
        "BRAINSTORM_ARBITRARY_NEGATIVE_BATCH");
    return envValue == nullptr
        || envValue[0] == '\0'
        || (envValue[0] != '0'
            && std::strcmp(envValue, "false") != 0
            && std::strcmp(envValue, "False") != 0);
}

ArbitraryNegativeRarity arbitraryNegativeRarity(Item joker) {
    if (std::find(LEGENDARY_JOKERS.begin(), LEGENDARY_JOKERS.end(), joker)
            != LEGENDARY_JOKERS.end()) {
        return ArbitraryNegativeRarity::Legendary;
    }
    if (std::find(RARE_JOKERS.begin(), RARE_JOKERS.end(), joker)
            != RARE_JOKERS.end()) {
        return ArbitraryNegativeRarity::Rare;
    }
    if (std::find(UNCOMMON_JOKERS.begin(), UNCOMMON_JOKERS.end(), joker)
            != UNCOMMON_JOKERS.end()) {
        return ArbitraryNegativeRarity::Uncommon;
    }
    return ArbitraryNegativeRarity::Common;
}

ArbitraryNegativeWindow arbitraryNegativeWindow(
    BrainstormJokerLocationRequirement location) {
    switch (location) {
    case BrainstormJokerLocationRequirement::AnteOne:
        return ArbitraryNegativeWindow::AnteOne;
    case BrainstormJokerLocationRequirement::SoulPack:
        return ArbitraryNegativeWindow::SoulPack;
    case BrainstormJokerLocationRequirement::AnteTwo:
        return ArbitraryNegativeWindow::AnteTwo;
    case BrainstormJokerLocationRequirement::SoulOrAnteTwo:
        return ArbitraryNegativeWindow::SoulOrAnteTwo;
    case BrainstormJokerLocationRequirement::AnteThree:
        return ArbitraryNegativeWindow::AnteThree;
    case BrainstormJokerLocationRequirement::AnteFour:
        return ArbitraryNegativeWindow::AnteFour;
    case BrainstormJokerLocationRequirement::ByAnteTwo:
        return ArbitraryNegativeWindow::ByAnteTwo;
    case BrainstormJokerLocationRequirement::ByAnteThree:
        return ArbitraryNegativeWindow::ByAnteThree;
    case BrainstormJokerLocationRequirement::ByAnteFour:
        return ArbitraryNegativeWindow::ByAnteFour;
    case BrainstormJokerLocationRequirement::ByAnteFive:
        return ArbitraryNegativeWindow::ByAnteFive;
    case BrainstormJokerLocationRequirement::ByAnteSix:
        return ArbitraryNegativeWindow::ByAnteSix;
    case BrainstormJokerLocationRequirement::ByAnteSeven:
        return ArbitraryNegativeWindow::ByAnteSeven;
    case BrainstormJokerLocationRequirement::ByAnteEight:
        return ArbitraryNegativeWindow::ByAnteEight;
    }
    return ArbitraryNegativeWindow::AnteOne;
}

ArbitraryNegativeCriteria configuredArbitraryNegativeCriteria() {
    ArbitraryNegativeCriteria criteria;
    for (std::size_t index = 0;
         index < BRAINSTORM_TARGET_JOKER_COUNT; ++index) {
        if (BRAINSTORM_TARGET_JOKER_EDITIONS[index]
                != BrainstormJokerEditionRequirement::Negative) {
            continue;
        }
        auto& requirement = criteria.requirements[
            static_cast<std::size_t>(criteria.requirementCount++)];
        requirement.rarity = arbitraryNegativeRarity(
            BRAINSTORM_TARGET_JOKERS[index]);
        requirement.window = arbitraryNegativeWindow(
            BRAINSTORM_TARGET_JOKER_LOCATIONS[index]);
    }
    criteria.maximumAnte = brainstormV5MaximumRequestedAnte();
    criteria.anteOneShops = needsStartingCharmPack() ? 1 : 2;
    criteria.stockSize = BRAINSTORM_DECK == Item::Zodiac_Deck ? 3 : 2;
    criteria.shopRate = BRAINSTORM_DECK == Item::Ghost_Deck
        ? ArbitraryNegativeShopRate::Ghost
        : BRAINSTORM_DECK == Item::Zodiac_Deck
        ? ArbitraryNegativeShopRate::Zodiac
        : ArbitraryNegativeShopRate::Ordinary;
    criteria.allowStartingPack = needsStartingCharmPack()
        || (BRAINSTORM_V6_DEADLINE_MODE
            && brainstormHasDeadlineJokerTarget());
    return criteria;
}

bool canUseFastArbitraryNegativePrefilter() {
    if (!arbitraryNegativeBatchStrategyEnabled()
        || !BRAINSTORM_TARGET_JOKERS_VALID
        || !BRAINSTORM_V5_OCCURRENCE_MODE
        || !brainstormNeedsV5ChronologicalJokerScan()) {
        return false;
    }
    return configuredArbitraryNegativeCriteria().requirementCount > 0;
}

bool canUseArbitraryNegativeBatch() {
    // The scalar collector still rejects most seeds before Instance timeline
    // simulation. SIMD backends can be enabled later without changing this
    // strategy selection or the batch ABI.
    return canUseFastArbitraryNegativePrefilter();
}

bool passesFastArbitraryNegativePrefilter(Seed& seed) {
    return passesArbitraryNegativeCriteria(
        seed, configuredArbitraryNegativeCriteria());
}

SeedBatchPrefilter arbitraryNegativeBatchPrefilter() {
    return SeedBatchPrefilter{
        createArbitraryNegativeBatchContext,
        destroyArbitraryNegativeBatchContext,
        collectArbitraryNegativeCandidatesWithContext,
        encodeArbitraryNegativeCriteria(
            configuredArbitraryNegativeCriteria())};
}

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
        && BRAINSTORM_TARGET_JOKERS_VALID
        && BRAINSTORM_TARGET_JOKER_COUNT == 0
        && !BRAINSTORM_FORCE_CHARM_ROUTE
        && !BRAINSTORM_EARLYCOPY
        && !BRAINSTORM_RETCON
        && !BRAINSTORM_ANTE8_BEAN
        && !BRAINSTORM_ANTE6_BURGLAR
        && BRAINSTORM_FILTER == customFilters::NO_FILTER;
}

long rankOnlyFilter(Seed &seed) {
    return passesRankCountFilters(seed) ? 1 : 0;
}

long filterConfigured(Instance &inst);
long filterConfiguredAfterOpeningGate(Instance &inst);
long filterConfiguredAfterBlueprintGate(Instance &inst);
long filterConfiguredAfterNegativeGate(Instance &inst);

bool exactQueryStrategyEnabled() {
    const char* envValue = std::getenv("BRAINSTORM_EXACT_QUERY_STRATEGY");
    return envValue == nullptr
        || envValue[0] == '\0'
        || (envValue[0] != '0'
            && std::strcmp(envValue, "false") != 0
            && std::strcmp(envValue, "False") != 0);
}

bool verifyFastFilterEnabled() {
    const char* envValue = std::getenv("BRAINSTORM_VERIFY_FAST_FILTER");
    return envValue != nullptr && envValue[0] != '\0' && envValue[0] != '0';
}

bool verifyFastFilterPositive(Seed &seed) {
    if (!verifyFastFilterEnabled()) {
        return true;
    }

    Seed configuredSeed = seed;
    Instance inst(configuredSeed);
    if (filterConfigured(inst) == 0) {
        std::cerr << "Fast exact filter mismatch on seed "
                  << seed.tostring() << std::endl;
        return false;
    }

    return true;
}

bool isExactCharmPerkeoTelescopeSearch() {
    if (!exactQueryStrategyEnabled()) {
        return false;
    }

    return BRAINSTORM_FILTER == customFilters::NO_FILTER
        && BRAINSTORM_DECK == Item::Red_Deck
        && BRAINSTORM_PACK == Item::RETRY
        && BRAINSTORM_TAG == Item::Charm_Tag
        && BRAINSTORM_VOUCHER == Item::Telescope
        && BRAINSTORM_SOULS == 1
        && !BRAINSTORM_OBSERVATORY
        && hasSolePerkeoTarget()
        && !BRAINSTORM_EARLYCOPY
        && !BRAINSTORM_RETCON
        && !BRAINSTORM_ANTE8_BEAN
        && !BRAINSTORM_ANTE6_BURGLAR;
}

bool isExactCharmPerkeoObservatorySearch() {
    if (!exactQueryStrategyEnabled()) {
        return false;
    }

    // Generic filterConfigured ignores BRAINSTORM_VOUCHER when Observatory is
    // requested, so this exact detector intentionally preserves that behavior.
    return BRAINSTORM_FILTER == customFilters::NO_FILTER
        && BRAINSTORM_DECK == Item::Red_Deck
        && BRAINSTORM_PACK == Item::RETRY
        && BRAINSTORM_TAG == Item::Charm_Tag
        && BRAINSTORM_SOULS == 1
        && BRAINSTORM_OBSERVATORY
        && BRAINSTORM_OBSERVATORY_DEADLINE == 2
        && hasSolePerkeoTarget()
        && !BRAINSTORM_EARLYCOPY
        && !BRAINSTORM_RETCON
        && !BRAINSTORM_ANTE8_BEAN
        && !BRAINSTORM_ANTE6_BURGLAR;
}

long exactCharmPerkeoTelescopeFilter(Seed &seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    ExactCharmObservatoryEval eval(seed);

    // Charm + Soul + Perkeo is far more selective than the voucher draw, and
    // these keyed RNG streams are independent. Reject almost every seed
    // before paying for voucher resampling; the authoritative verifier still
    // checks the rare positives when requested.
    if (!eval.passesCharmSoulPerkeo()) {
        return 0;
    }
    if (!eval.passesTelescope()) {
        return 0;
    }
    if (rankFiltersNeedSeedEvaluation() && !passesRankCountFilters(seed)) {
        return 0;
    }
    return verifyFastFilterPositive(seed) ? 1 : 0;
}

long exactCharmPerkeoObservatoryFilter(Seed &seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    ExactCharmObservatoryEval eval(seed);

    if (!eval.passesCharmSoulPerkeo()) {
        return 0;
    }
    if (!eval.passesObservatory()) {
        return 0;
    }
    if (rankFiltersNeedSeedEvaluation() && !passesRankCountFilters(seed)) {
        return 0;
    }
    return verifyFastFilterPositive(seed) ? 1 : 0;
}

bool hasCheapConfiguredConstraint() {
    return BRAINSTORM_PACK != Item::RETRY
        || (BRAINSTORM_VOUCHER != Item::RETRY
            && !BRAINSTORM_OBSERVATORY)
        || (BRAINSTORM_TAG != Item::RETRY
            && !(needsStartingCharmPack()
                 && BRAINSTORM_TAG == Item::Charm_Tag))
        || BRAINSTORM_OBSERVATORY;
}

bool passesObservatoryDeadline(Instance& inst) {
    // v6 treats a deck-start Telescope as satisfying the first half of the
    // ordered pair. Legacy APIs retain their historical requirement that the
    // Ante 1 offer itself be Telescope.
    bool acquiredTelescope = BRAINSTORM_V6_DEADLINE_MODE
        && inst.isVoucherActive(Item::Telescope);
    for (int ante = 1; ante <= BRAINSTORM_OBSERVATORY_DEADLINE; ante++) {
        const Item offeredVoucher = inst.nextVoucher(ante);
        if (!acquiredTelescope) {
            if (offeredVoucher == Item::Telescope) {
                acquiredTelescope = true;
                inst.activateVoucher(Item::Telescope);
            }
            continue;
        }
        if (offeredVoucher == Item::Observatory) {
            return true;
        }
    }
    return false;
}

bool passesCheapConfiguredConstraints(Instance& inst) {
    // Delayed voucher scans can consume several RNG draws. When this query
    // already requires the starting Charm route, reject the overwhelmingly
    // more common non-Charm seeds with one cheap tag draw first. Deadline 2
    // keeps the legacy voucher-first path and its specialized fast filter.
    if (BRAINSTORM_OBSERVATORY_DEADLINE > 2
        && needsStartingCharmPack()
        && !BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG
        && inst.nextTag(1) != Item::Charm_Tag) {
        return false;
    }

    if (BRAINSTORM_PACK != Item::RETRY) {
        inst.cache.generatedFirstPack = true; // We do not care about Pack 1.
        if (inst.nextPack(1) != BRAINSTORM_PACK) {
            return false;
        }
    }

    if (BRAINSTORM_VOUCHER != Item::RETRY && !BRAINSTORM_OBSERVATORY
        && inst.nextVoucher(1) != BRAINSTORM_VOUCHER) {
        return false;
    }

    if (BRAINSTORM_TAG != Item::RETRY
        && !(BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG
             && BRAINSTORM_TAG == Item::Charm_Tag)
        // Starting-Charm routes already validate this tag in their early
        // pack scan (or in the deadline prefilter above). The staged
        // estimator temporarily removes Soul targets while retaining that
        // route, so key this guard to the route itself rather than the
        // transient Soul count; otherwise its base probe demands two
        // consecutive Charm Tags and overstates search time by roughly the
        // size of the tag pool.
        && !(needsStartingCharmPack()
             && BRAINSTORM_TAG == Item::Charm_Tag)
        && inst.nextTag(1) != BRAINSTORM_TAG) {
        return false;
    }

    if (BRAINSTORM_OBSERVATORY
        && !passesObservatoryDeadline(inst)) {
        return false;
    }

    return true;
}

bool passesAdvancedConfiguredConstraints(Instance& inst) {
    if (BRAINSTORM_EARLYCOPY) {
        bool money = false;
        bool bstorm = false;
        bool bprint = false;
        Pack pack = packInfo(inst.nextPack(1));
        for (int p = 0; p <= 3; p++) {
            if (pack.type == Item::Buffoon_Pack
                || pack.type == Item::Jumbo_Buffoon_Pack) {
                auto packContents = inst.nextBuffoonPack(pack.size, 1);
                for (int x = 0; x < pack.size; x++) {
                    if (packContents[x].joker == Item::Blueprint && !bprint) {
                        bprint = true;
                        break;
                    }
                    if ((packContents[x].joker == Item::Mail_In_Rebate
                            || packContents[x].joker == Item::Reserved_Parking
                            || packContents[x].joker == Item::Business_Card
                            || packContents[x].joker == Item::To_Do_List
                            || packContents[x].joker == Item::Midas_Mask
                            || packContents[x].joker == Item::Trading_Card)
                        && !money) {
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
                    if (packContents[x].joker == Item::Mail_In_Rebate
                        || packContents[x].joker == Item::Reserved_Parking
                        || packContents[x].joker == Item::Business_Card
                        || packContents[x].joker == Item::To_Do_List
                        || packContents[x].joker == Item::Midas_Mask
                        || packContents[x].joker == Item::Trading_Card) {
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
            if (i > 1
                && (item.item == Item::Mail_In_Rebate
                    || item.item == Item::Reserved_Parking
                    || item.item == Item::Business_Card
                    || item.item == Item::To_Do_List
                    || item.item == Item::Midas_Mask
                    || item.item == Item::Trading_Card)
                && !money) {
                money = true;
            }
            if (item.item == Item::Brainstorm && !bstorm && i > 1) {
                bstorm = true;
            }
            if (!bprint || !money || !bstorm) {
                return false;
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
            return false;
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
            return false;
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
            return false;
        }
    }

    return true;
}

bool hasAdvancedConfiguredConstraint() {
    return BRAINSTORM_EARLYCOPY
        || BRAINSTORM_RETCON
        || BRAINSTORM_ANTE8_BEAN
        || BRAINSTORM_ANTE6_BURGLAR;
}

bool passesConfiguredOpeningGate(Instance& inst) {
    if (canUseFastOpeningCharmSoulPrefilter()
        && !passesFastOpeningCharmSoulPrefilter(inst.seed)) {
        inst.preserveCleanRunStateOnNext = true;
        return false;
    }
    return true;
}

long filterConfigured(Instance &inst) {
    if (!passesConfiguredOpeningGate(inst)) {
        return 0;
    }
    return filterConfiguredAfterOpeningGate(inst);
}

long filterConfiguredAfterOpeningGate(Instance &inst) {
    if (canUseFastNegativeBlueprintEditionPrefilter()
        && !passesFastNegativeBlueprintEditionPrefilter(inst.seed)) {
        inst.preserveCleanRunStateOnNext = true;
        return 0;
    }

    return filterConfiguredAfterBlueprintGate(inst);
}

long filterConfiguredAfterBlueprintGate(Instance &inst) {
    if (canUseFastArbitraryNegativePrefilter()
        && !passesFastArbitraryNegativePrefilter(inst.seed)) {
        inst.preserveCleanRunStateOnNext = true;
        return 0;
    }

    return filterConfiguredAfterNegativeGate(inst);
}

long filterConfiguredAfterNegativeGate(Instance &inst) {

    const bool needsEarlyJokerScan =
        BRAINSTORM_TARGET_JOKER_COUNT > 0
        || requiredCharmSoulCount() > 0
        || BRAINSTORM_FORCE_CHARM_ROUTE;

    // The user's common search shape starts with a single Soul -> Perkeo in
    // the Charm-tag pack. Evaluate that highly selective, fixed-key route
    // directly from the Seed before constructing general-purpose Instance
    // node maps or walking any later-Ante timeline. The full simulator still
    // verifies the rare survivors, so this is a necessary-condition gate and
    // cannot create false positives.
    // Pack, tag, and voucher checks are much cheaper than rolling four shop
    // cards plus four packs. When they are combined with Joker/Soul targets,
    // use them as an exact prefilter and spend the full simulation only on
    // candidates that survive. The normal pass below is still repeated so its
    // keyed RNG state remains identical for later combined options.
    if (needsEarlyJokerScan && hasCheapConfiguredConstraint()) {
        inst.initLocks(1, false, true);
        inst.setDeck(BRAINSTORM_DECK);
        inst.setStake(BRAINSTORM_STAKE);
        if (!passesCheapConfiguredConstraints(inst)) {
            return 0;
        }
        inst.clearRunState();
    }

    if (!(brainstormNeedsV5ChronologicalJokerScan()
            ? passesBrainstormV5JokerTargets(inst)
            : passesEarlyJokerTargets(inst))) {
        return 0;
    }

    // The early scan rejects nearly every candidate. Reusing the worker's
    // existing Instance avoids constructing and reserving a second simulator
    // for each seed. Only the rare survivors need their keyed RNG state reset
    // before the remaining independent filters are evaluated.
    if (needsEarlyJokerScan) {
        inst.clearRunState();
    }

    // Every candidate represents a new Ante 1 run. Keep profile-unlocked
    // content available while excluding state-gated tags, Jokers, and voucher
    // upgrades until the run actually unlocks them.
    inst.initLocks(1, false, true);
    inst.setDeck(BRAINSTORM_DECK);
    inst.setStake(BRAINSTORM_STAKE);

    // Legacy custom-filter presets used to return as soon as their special
    // Joker matched, silently bypassing every other selected criterion. Run
    // the common constraints against the same seed first, then reset keyed RNG
    // state so the custom scan still observes its original Ante 1 windows.
    if (BRAINSTORM_FILTER != customFilters::NO_FILTER
        && (hasCheapConfiguredConstraint()
            || hasAdvancedConfiguredConstraint())) {
        if (!passesCheapConfiguredConstraints(inst)
            || !passesAdvancedConfiguredConstraints(inst)) {
            return 0;
        }
        inst.clearRunState();
        inst.initLocks(1, false, true);
        inst.setDeck(BRAINSTORM_DECK);
        inst.setStake(BRAINSTORM_STAKE);
    }

    switch (BRAINSTORM_FILTER) {
        case customFilters::NO_FILTER: {
            if (!passesCheapConfiguredConstraints(inst)) {
                return 0;
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
            const std::vector<ShopItem> shopItems =
                inst.nextShopItems(4, 1, false);
            for (const ShopItem& item : shopItems) {
                if (item.type == Item::T_Joker) {
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
            const int requiredSoulCount = requiredCharmSoulCount();
            const ArcanaSoulPackResult soulPack =
                inst.scanArcanaPackForSoulJokers(
                    5, 1, requiredSoulCount > 1);
            if (soulPack.soulCount < requiredSoulCount
                || !hasCollectibleSoulJoker(
                    soulPack, Item::Perkeo, Item::Negative)) {
                return 0; // If Perkeo is required but not found, return 0
            }

			return 1; // Return a score of 1 if a negative Perkeo is found

        }
        case customFilters::NEGATIVE_PERKEO_BLUEPRINT: {
            const int requiredSoulCount = requiredCharmSoulCount();
            const ArcanaSoulPackResult soulPack =
                inst.scanArcanaPackForSoulJokers(
                    5, 1, requiredSoulCount > 1);
            if (soulPack.soulCount < requiredSoulCount
                || !hasCollectibleSoulJoker(
                    soulPack, Item::Perkeo, Item::Negative)) {
                return 0; // If Perkeo is required but not found, return 0
            }
            bool bprint = false;
            const std::vector<ShopItem> shopItems =
                inst.nextShopItems(2, 1, false);
            for (const ShopItem& item : shopItems) {
                if (item.type == Item::T_Joker) {
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
            const int requiredSoulCount = requiredCharmSoulCount();
            const ArcanaSoulPackResult soulPack =
                inst.scanArcanaPackForSoulJokers(
                    5, 1, requiredSoulCount > 1);
            if (soulPack.soulCount < requiredSoulCount
                || !hasCollectibleSoulJoker(
                    soulPack, Item::Perkeo, Item::RETRY)) {
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
    // For combined Erratic-deck queries, Charm/Soul is normally orders of
    // magnitude more selective than counting the whole 52-card deck.  Both
    // checks are seed-only, so run the cheap opening gate first and enter the
    // stateful simulator only after both pass.
    if (!passesConfiguredOpeningGate(inst)) {
        return 0;
    }
    if (!passesRankCountFilters(inst.seed)) {
        inst.preserveCleanRunStateOnNext = true;
        return 0;
    }
    return filterConfiguredAfterOpeningGate(inst);
}

long filterWithoutRankPrefilter(Instance &inst) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    return filterConfigured(inst);
}

long authoritativeConfiguredAfterOpeningSeedFilter(Seed& seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    if (rankFiltersNeedSeedEvaluation()
        && !passesRankCountFilters(seed)) {
        return 0;
    }
    Instance instance(seed);
    return filterConfiguredAfterOpeningGate(instance);
}

long authoritativeConfiguredAfterNegativeSeedFilter(Seed& seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    if (rankFiltersNeedSeedEvaluation()
        && !passesRankCountFilters(seed)) {
        return 0;
    }
    Instance instance(seed);
    // A scalar opening requirement can remain when its vector batch was
    // explicitly disabled or unavailable. Preserve that necessary gate while
    // skipping only the Negative-edition gate already proven by SIMD.
    if (!passesConfiguredOpeningGate(instance)) {
        return 0;
    }
    return filterConfiguredAfterBlueprintGate(instance);
}

long authoritativeConfiguredAfterArbitraryNegativeSeedFilter(Seed& seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    if (rankFiltersNeedSeedEvaluation()
        && !passesRankCountFilters(seed)) {
        return 0;
    }
    Instance instance(seed);
    if (!passesConfiguredOpeningGate(instance)) {
        return 0;
    }
    if (canUseFastNegativeBlueprintEditionPrefilter()
        && !passesFastNegativeBlueprintEditionPrefilter(instance.seed)) {
        return 0;
    }
    // The arbitrary-Negative necessary condition was already proven by the
    // batch collector. Enter the authoritative simulator at the next stage.
    return filterConfiguredAfterNegativeGate(instance);
}

long authoritativeCharmPerkeoTelescopeAfterOpeningSeedFilter(Seed& seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    ExactCharmObservatoryEval eval(seed);
    if (!eval.passesTelescope()) {
        return 0;
    }
    if (rankFiltersNeedSeedEvaluation()
        && !passesRankCountFilters(seed)) {
        return 0;
    }
    Instance instance(seed);
    return filterConfiguredAfterOpeningGate(instance) != 0 ? 1 : 0;
}

long authoritativeCharmPerkeoObservatoryAfterOpeningSeedFilter(Seed& seed) {
    BrainstormScopedPerfTimer perfTimer(BrainstormPerfMetric::Filter);
    ExactCharmObservatoryEval eval(seed);
    if (!eval.passesObservatory()) {
        return 0;
    }
    if (rankFiltersNeedSeedEvaluation()
        && !passesRankCountFilters(seed)) {
        return 0;
    }
    Instance instance(seed);
    return filterConfiguredAfterOpeningGate(instance) != 0 ? 1 : 0;
}

bool configureBrainstormSearch(
    const std::string& voucher, const std::string& pack,
    const std::string& tag, int souls, bool observatory,
    int observatoryDeadline, bool perkeo, bool copymoney, bool retcon,
    bool bean, bool burglar,
    const std::string& customFilter, const std::string& targetRank,
    const std::string& targetSuit, int specificRankMin, int anyRankMin,
    const std::string& targetJokers, const std::string& deck,
    const std::string& targetJokerLocations,
    bool retainJokerOccurrences, bool allowDeadlineLocations,
    int stakeLevel) {
    const Item parsedDeck = stringToItem(deck);
    if (!isSupportedBrainstormDeck(parsedDeck)
        || parsedDeck == Item::Challenge_Deck
        || stakeLevel < 1 || stakeLevel > 8) {
        return false;
    }

    BRAINSTORM_DECK = parsedDeck;
    BRAINSTORM_STAKE = static_cast<Item>(
        static_cast<int>(Item::White_Stake) + stakeLevel - 1);
    BRAINSTORM_PACK = stringToItem(pack);
    BRAINSTORM_TAG = stringToItem(tag);
    BRAINSTORM_VOUCHER = stringToItem(voucher);
    BRAINSTORM_FILTER = stringToFilter(customFilter);
    BRAINSTORM_SOULS = std::clamp(souls, 0, 4);
    BRAINSTORM_OBSERVATORY_DEADLINE = observatoryDeadline > 0
        ? std::clamp(observatoryDeadline, 2, 8)
        : (observatory ? 2 : 0);
    BRAINSTORM_OBSERVATORY = BRAINSTORM_OBSERVATORY_DEADLINE > 0;
    BRAINSTORM_PERKEO = perkeo;
    BRAINSTORM_V5_OCCURRENCE_MODE = retainJokerOccurrences;
    BRAINSTORM_V6_DEADLINE_MODE = allowDeadlineLocations;
    BRAINSTORM_FORCE_CHARM_ROUTE = false;
    BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG = false;
    BRAINSTORM_TARGET_JOKERS_VALID =
        parseBrainstormJokerTargets(
            targetJokers, perkeo, targetJokerLocations,
            retainJokerOccurrences, allowDeadlineLocations);
    BRAINSTORM_EARLYCOPY = copymoney;
    BRAINSTORM_RETCON = retcon;
    BRAINSTORM_ANTE6_BURGLAR = burglar;
    BRAINSTORM_ANTE8_BEAN = bean;
    setBrainstormTargetRank(targetRank);
    setBrainstormTargetSuit(targetSuit);
    BRAINSTORM_SPECIFIC_RANK_MIN =
        specificRankMin > 0 ? specificRankMin : 0;
    BRAINSTORM_ANY_RANK_MIN = anyRankMin > 0 ? anyRankMin : 0;
    prepareBrainstormRankFilterEvaluation();

    const int requiredSoulCount = requiredCharmSoulCount();
    return BRAINSTORM_TARGET_JOKERS_VALID
        && brainstormRequiredLegendaryTargetCount() <= 2
        && (!allowDeadlineLocations
            || !BRAINSTORM_OBSERVATORY
            || BRAINSTORM_VOUCHER == Item::RETRY
            || BRAINSTORM_VOUCHER == Item::Telescope)
        && (!allowDeadlineLocations
            || !BRAINSTORM_OBSERVATORY
            || !BRAINSTORM_RETCON)
        && (!retainJokerOccurrences
            || (brainstormV5DuplicateLocationsValid()
                && brainstormRequiredStartingPackChoiceCount() <= 2
                && brainstormSoulPackNonLegendaryTargetCount() <= 1
                && brainstormV5OrderedStartingChoicesFeasible()))
        && requiredSoulCount <= 4
        && (!needsStartingCharmPack()
            || BRAINSTORM_TAG == Item::RETRY
            || BRAINSTORM_TAG == Item::Charm_Tag);
}

std::string brainstorm_versioned_cpp(
    std::string seed, std::string voucher, std::string pack, std::string tag,
    int souls, bool observatory, int observatoryDeadline, bool perkeo,
    bool copymoney, bool retcon, bool bean, bool burglar,
    std::string customFilter, std::string targetRank, std::string targetSuit,
    int specificRankMin, int anyRankMin,
    std::string targetJokers, std::string deck,
    std::string targetJokerLocations, bool retainJokerOccurrences,
    bool allowDeadlineLocations, int stakeLevel) {
    const Item parsedDeck = stringToItem(deck);
    if (!isSupportedBrainstormDeck(parsedDeck)
        || parsedDeck == Item::Challenge_Deck
        || stakeLevel < 1 || stakeLevel > 8) {
        return "";
    }
    BRAINSTORM_DECK = parsedDeck;
    BRAINSTORM_STAKE = static_cast<Item>(
        static_cast<int>(Item::White_Stake) + stakeLevel - 1);
    BRAINSTORM_PACK = stringToItem(pack);
    BRAINSTORM_TAG = stringToItem(tag);
    BRAINSTORM_VOUCHER = stringToItem(voucher);
	BRAINSTORM_FILTER = stringToFilter(customFilter);
    BRAINSTORM_SOULS = std::clamp(souls, 0, 4);
    BRAINSTORM_OBSERVATORY_DEADLINE = observatoryDeadline > 0
        ? std::clamp(observatoryDeadline, 2, 8)
        : (observatory ? 2 : 0);
    BRAINSTORM_OBSERVATORY = BRAINSTORM_OBSERVATORY_DEADLINE > 0;
    BRAINSTORM_PERKEO = perkeo;
    BRAINSTORM_V5_OCCURRENCE_MODE = retainJokerOccurrences;
    BRAINSTORM_V6_DEADLINE_MODE = allowDeadlineLocations;
    BRAINSTORM_FORCE_CHARM_ROUTE = false;
    BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG = false;
	BRAINSTORM_TARGET_JOKERS_VALID =
        parseBrainstormJokerTargets(
            targetJokers, perkeo, targetJokerLocations,
            retainJokerOccurrences, allowDeadlineLocations);
	BRAINSTORM_EARLYCOPY = copymoney;
	BRAINSTORM_RETCON = retcon;
	BRAINSTORM_ANTE6_BURGLAR = burglar;
    BRAINSTORM_ANTE8_BEAN = bean;
    setBrainstormTargetRank(targetRank);
    setBrainstormTargetSuit(targetSuit);
    BRAINSTORM_SPECIFIC_RANK_MIN = specificRankMin > 0 ? specificRankMin : 0;
    BRAINSTORM_ANY_RANK_MIN = anyRankMin > 0 ? anyRankMin : 0;
    prepareBrainstormRankFilterEvaluation();

    // Only two cards can be selected from the Charm-tag Mega Arcana Pack.
    const int requiredSoulCount = requiredCharmSoulCount();
    if (!BRAINSTORM_TARGET_JOKERS_VALID
        || brainstormRequiredLegendaryTargetCount() > 2
        || (allowDeadlineLocations
            && BRAINSTORM_OBSERVATORY
            && BRAINSTORM_VOUCHER != Item::RETRY
            && BRAINSTORM_VOUCHER != Item::Telescope)
        || (allowDeadlineLocations
            && BRAINSTORM_OBSERVATORY
            && BRAINSTORM_RETCON)
        || (retainJokerOccurrences
            && (!brainstormV5DuplicateLocationsValid()
                || brainstormRequiredStartingPackChoiceCount() > 2
                || brainstormSoulPackNonLegendaryTargetCount() > 1
                || !brainstormV5OrderedStartingChoicesFeasible()))
        || requiredSoulCount > 4
        || (needsStartingCharmPack()
            && BRAINSTORM_TAG != Item::RETRY
            && BRAINSTORM_TAG != Item::Charm_Tag)) {
        return "";
    }

    // Fixed starting decks have no seed-dependent rank composition. Reject an
    // impossible threshold once, or return the starting seed immediately when
    // rank counts are the query's only criterion.
    if (rankFiltersDeterministicallyFail()) {
        return "";
    }
    if (rankFiltersDeterministicallyPass() && isRankOnlySearch()) {
        Seed startingSeed(seed);
        return startingSeed.tostring();
    }

    const int numThreads = getBrainstormSearchThreads();
    const long long searchLimit = getBrainstormSearchLimit();
    const bool useOpeningBatch = canUseOpeningCharmSoulBatch();
    const bool useNegativeBlueprintBatch =
        !useOpeningBatch && canUseNegativeBlueprintBatch();
    const bool useOpeningTagBatch =
        !useOpeningBatch && !useNegativeBlueprintBatch
        && canUseOpeningTagBatch();
    const bool useArbitraryNegativeBatch =
        !useOpeningBatch && !useNegativeBlueprintBatch
        && !useOpeningTagBatch && canUseArbitraryNegativeBatch();
    if (isExactCharmPerkeoTelescopeSearch()) {
        SeedSearch search(
            useOpeningBatch
                ? authoritativeCharmPerkeoTelescopeAfterOpeningSeedFilter
                : exactCharmPerkeoTelescopeFilter,
            seed, numThreads, searchLimit);
        if (useOpeningBatch) {
            search.batchPrefilter = openingCharmSoulBatchPrefilter();
        }
        search.exitOnFind = true;
        search.printDelay = getBrainstormPrintDelay();
        return search.search();
    }
    if (isExactCharmPerkeoObservatorySearch()) {
        SeedSearch search(
            useOpeningBatch
                ? authoritativeCharmPerkeoObservatoryAfterOpeningSeedFilter
                : exactCharmPerkeoObservatoryFilter,
            seed, numThreads, searchLimit);
        if (useOpeningBatch) {
            search.batchPrefilter = openingCharmSoulBatchPrefilter();
        }
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

    // A persisted exact anchor does not depend on the machine's SIMD backend.
    // It is useful even when the ordinary opening batch must run scalar.
    if (canUseCharmPerkeoMegaSpectralAnchorPriority()) {
        const auto tryAnchorCandidates = [&](const auto& candidates) {
            if (candidates.empty()) {
                return std::pair<bool, std::string>{false, {}};
            }
            SeedSearch indexedSearch(
                authoritativeConfiguredAfterOpeningSeedFilter,
                seed, numThreads, searchLimit);
            indexedSearch.exitOnFind = true;
            indexedSearch.printDelay = getBrainstormPrintDelay();
            const std::string result =
                indexedSearch.searchCandidateIds(candidates);
            return std::pair<bool, std::string>{
                indexedSearch.found.load(std::memory_order_relaxed),
                result};
        };

        if (canUseCharmPerkeoMegaNaneinfPlasmaGoldAnchorPriority()) {
            const auto [childFound, childResult] = tryAnchorCandidates(
                charmPerkeoMegaNaneinfPlasmaGoldCandidateIds());
            if (childFound) {
                return childResult;
            }
            if (charmPerkeoMegaNaneinfPlasmaGoldIndexComplete()) {
                std::cout
                    << "The complete five-Joker Plasma/Gold index proves "
                       "that no seed in this search range matches."
                    << std::endl;
                return "";
            }
        }

        const auto& parentCandidates =
            charmPerkeoMegaSpectralAnchorCandidateIds();
        if (!parentCandidates.empty()) {
            const auto [parentFound, parentResult] =
                tryAnchorCandidates(parentCandidates);
            if (parentFound) {
                return parentResult;
            }
            if (charmPerkeoMegaSpectralAnchorIndexComplete()) {
                std::cout
                    << "The complete Charm/Perkeo/Mega index proves that "
                       "no seed in this search range matches."
                    << std::endl;
                return "";
            }
            std::cout
                << "No Perkeo/Mega indexed candidate matched; continuing "
                   "with the exact exhaustive search."
                << std::endl;
        }
    }

    if (canUsePerkeoInvisibleAnchorPriority()) {
        const auto tryAnchorCandidates = [&](const auto& candidates) {
            if (candidates.empty()) {
                return std::pair<bool, std::string>{false, {}};
            }
            SeedSearch indexedSearch(
                authoritativeConfiguredAfterOpeningSeedFilter,
                seed, numThreads, searchLimit);
            indexedSearch.exitOnFind = true;
            indexedSearch.printDelay = getBrainstormPrintDelay();
            const std::string result =
                indexedSearch.searchCandidateIds(candidates);
            return std::pair<bool, std::string>{
                indexedSearch.found.load(std::memory_order_relaxed),
                result};
        };

        if (canUsePerkeoInvisibleAnteTwoInvisibleAnchorPriority()) {
            const auto [derivedFound, derivedResult] = tryAnchorCandidates(
                perkeoInvisibleAnteTwoInvisibleAnchorCandidateIds());
            if (derivedFound) {
                return derivedResult;
            }
            if (perkeoInvisibleAnteTwoInvisibleAnchorIndexComplete()) {
                std::cout
                    << "The complete derived anchor index proves that no "
                       "seed in this search range matches."
                    << std::endl;
                return "";
            }
        }

        const auto& anchorCandidates =
            perkeoInvisibleAnchorCandidateIds();
        if (!anchorCandidates.empty()) {
            const auto [indexedFound, indexedResult] =
                tryAnchorCandidates(anchorCandidates);
            if (indexedFound) {
                return indexedResult;
            }
            if (perkeoInvisibleAnchorIndexComplete()) {
                std::cout
                    << "The complete anchor index proves that no seed in "
                       "this search range matches."
                    << std::endl;
                return "";
            }
            std::cout
                << "No indexed candidate matched; continuing with the "
                   "exact exhaustive search."
                << std::endl;
        }
    }

    if (useOpeningBatch) {
        SeedSearch search(
            authoritativeConfiguredAfterOpeningSeedFilter,
            seed, numThreads, searchLimit);
        search.batchPrefilter = openingCharmSoulBatchPrefilter();
        search.exitOnFind = true;
        search.printDelay = getBrainstormPrintDelay();
        return search.search();
    }
    if (useNegativeBlueprintBatch) {
        SeedSearch search(
            authoritativeConfiguredAfterNegativeSeedFilter,
            seed, numThreads, searchLimit);
        search.batchPrefilter = negativeBlueprintBatchPrefilter();
        search.exitOnFind = true;
        search.printDelay = getBrainstormPrintDelay();
        return search.search();
    }
    if (useOpeningTagBatch) {
        SeedSearch search(
            authoritativeConfiguredAfterOpeningSeedFilter,
            seed, numThreads, searchLimit);
        search.batchPrefilter = openingTagBatchPrefilter();
        search.exitOnFind = true;
        search.printDelay = getBrainstormPrintDelay();
        return search.search();
    }
    if (useArbitraryNegativeBatch) {
        SeedSearch search(
            authoritativeConfiguredAfterArbitraryNegativeSeedFilter,
            seed, numThreads, searchLimit);
        search.batchPrefilter = arbitraryNegativeBatchPrefilter();
        search.exitOnFind = true;
        search.printDelay = getBrainstormPrintDelay();
        return search.search();
    }

    SearchFilter selectedFilter = rankFiltersNeedSeedEvaluation()
        ? filterWithRankPrefilter
        : filterWithoutRankPrefilter;
    Search search(selectedFilter, seed, numThreads, searchLimit);
    search.exitOnFind = true;
    search.printDelay = getBrainstormPrintDelay();
    return search.search();
}

std::string brainstorm_v4_cpp(
    std::string seed, std::string voucher, std::string pack, std::string tag,
    int souls, bool observatory, bool perkeo, bool copymoney, bool retcon,
    bool bean, bool burglar, std::string customFilter, std::string targetRank,
    std::string targetSuit, int specificRankMin, int anyRankMin,
    std::string targetJokers, std::string deck,
    std::string targetJokerLocations) {
    return brainstorm_versioned_cpp(
        seed, voucher, pack, tag, souls, observatory, 0, perkeo, copymoney,
        retcon, bean, burglar, customFilter, targetRank, targetSuit,
        specificRankMin, anyRankMin, targetJokers, deck,
        targetJokerLocations, false, false, 1);
}

std::string brainstorm_v5_cpp(
    std::string seed, std::string voucher, std::string pack, std::string tag,
    int souls, bool observatory, bool perkeo, bool copymoney, bool retcon,
    bool bean, bool burglar, std::string customFilter, std::string targetRank,
    std::string targetSuit, int specificRankMin, int anyRankMin,
    std::string targetJokers, std::string deck,
    std::string targetJokerLocations) {
    return brainstorm_versioned_cpp(
        seed, voucher, pack, tag, souls, observatory, 0, perkeo, copymoney,
        retcon, bean, burglar, customFilter, targetRank, targetSuit,
        specificRankMin, anyRankMin, targetJokers, deck,
        targetJokerLocations, true, false, 1);
}

std::string brainstorm_v6_cpp(
    std::string seed, std::string voucher, std::string pack, std::string tag,
    int souls, bool observatory, int observatoryDeadline, bool perkeo,
    bool copymoney, bool retcon, bool bean, bool burglar,
    std::string customFilter, std::string targetRank, std::string targetSuit,
    int specificRankMin, int anyRankMin, std::string targetJokers,
    std::string deck, std::string targetJokerLocations) {
    return brainstorm_versioned_cpp(
        seed, voucher, pack, tag, souls, observatory,
        observatoryDeadline, perkeo, copymoney, retcon, bean, burglar,
        customFilter, targetRank, targetSuit, specificRankMin, anyRankMin,
        targetJokers, deck, targetJokerLocations, true, true, 1);
}

std::string brainstorm_v7_cpp(
    std::string seed, std::string voucher, std::string pack, std::string tag,
    int souls, bool observatory, int observatoryDeadline, bool perkeo,
    bool copymoney, bool retcon, bool bean, bool burglar,
    std::string customFilter, std::string targetRank, std::string targetSuit,
    int specificRankMin, int anyRankMin, std::string targetJokers,
    std::string deck, std::string targetJokerLocations, int stakeLevel) {
    return brainstorm_versioned_cpp(
        seed, voucher, pack, tag, souls, observatory,
        observatoryDeadline, perkeo, copymoney, retcon, bean, burglar,
        customFilter, targetRank, targetSuit, specificRankMin, anyRankMin,
        targetJokers, deck, targetJokerLocations, true, true, stakeLevel);
}

namespace {

constexpr long long BRAINSTORM_ESTIMATE_BLOCK_SIZE = 4096;
constexpr long long BRAINSTORM_ESTIMATE_MAX_SAMPLES = 10000000;
constexpr int BRAINSTORM_ESTIMATE_MIN_EXACT_HITS = 8;

struct BrainstormEstimateStrategy {
    SearchFilter instanceFilter = nullptr;
    SeedFilter seedFilter = nullptr;
    SeedBatchPrefilter batchPrefilter{};
};

BrainstormEstimateStrategy selectBrainstormEstimateStrategy() {
    const bool useOpeningBatch = canUseOpeningCharmSoulBatch();
    const bool useNegativeBlueprintBatch =
        !useOpeningBatch && canUseNegativeBlueprintBatch();
    const bool useOpeningTagBatch =
        !useOpeningBatch && !useNegativeBlueprintBatch
        && canUseOpeningTagBatch();
    const bool useArbitraryNegativeBatch =
        !useOpeningBatch && !useNegativeBlueprintBatch
        && !useOpeningTagBatch && canUseArbitraryNegativeBatch();
    if (isExactCharmPerkeoTelescopeSearch()) {
        return BrainstormEstimateStrategy{
            nullptr,
            useOpeningBatch
                ? authoritativeCharmPerkeoTelescopeAfterOpeningSeedFilter
                : exactCharmPerkeoTelescopeFilter,
            useOpeningBatch
                ? openingCharmSoulBatchPrefilter()
                : SeedBatchPrefilter{}};
    }
    if (isExactCharmPerkeoObservatorySearch()) {
        return BrainstormEstimateStrategy{
            nullptr,
            useOpeningBatch
                ? authoritativeCharmPerkeoObservatoryAfterOpeningSeedFilter
                : exactCharmPerkeoObservatoryFilter,
            useOpeningBatch
                ? openingCharmSoulBatchPrefilter()
                : SeedBatchPrefilter{}};
    }
    if (isRankOnlySearch()) {
        return BrainstormEstimateStrategy{
            nullptr, rankOnlyFilter, SeedBatchPrefilter{}};
    }
    if (useOpeningBatch) {
        return BrainstormEstimateStrategy{
            nullptr, authoritativeConfiguredAfterOpeningSeedFilter,
            openingCharmSoulBatchPrefilter()};
    }
    if (useNegativeBlueprintBatch) {
        return BrainstormEstimateStrategy{
            nullptr, authoritativeConfiguredAfterNegativeSeedFilter,
            negativeBlueprintBatchPrefilter()};
    }
    if (useOpeningTagBatch) {
        return BrainstormEstimateStrategy{
            nullptr, authoritativeConfiguredAfterOpeningSeedFilter,
            openingTagBatchPrefilter()};
    }
    if (useArbitraryNegativeBatch) {
        return BrainstormEstimateStrategy{
            nullptr,
            authoritativeConfiguredAfterArbitraryNegativeSeedFilter,
            arbitraryNegativeBatchPrefilter()};
    }
    return BrainstormEstimateStrategy{
        rankFiltersNeedSeedEvaluation()
            ? filterWithRankPrefilter
            : filterWithoutRankPrefilter,
        nullptr,
        SeedBatchPrefilter{}};
}

bool brainstormHasDuplicateLegendaryTarget() {
    for (std::size_t i = 0; i < BRAINSTORM_TARGET_JOKER_COUNT; i++) {
        if (!isLegendaryJoker(BRAINSTORM_TARGET_JOKERS[i])) {
            continue;
        }
        for (std::size_t j = i + 1;
             j < BRAINSTORM_TARGET_JOKER_COUNT; j++) {
            if (BRAINSTORM_TARGET_JOKERS[i]
                == BRAINSTORM_TARGET_JOKERS[j]) {
                return true;
            }
        }
    }
    return false;
}

struct BrainstormEstimateSample {
    long long tested = 0;
    long long hits = 0;
    long long elapsedNs = 0;
};

struct BrainstormIndexedEstimateSelection {
    const std::vector<std::uint64_t>* ids = nullptr;
    const char* label = nullptr;
};

BrainstormIndexedEstimateSelection selectCompleteAnchorEstimateIndex() {
    if (canUseCharmPerkeoMegaSpectralAnchorPriority()) {
        if (canUseCharmPerkeoMegaNaneinfPlasmaGoldAnchorPriority()
            && charmPerkeoMegaNaneinfPlasmaGoldIndexComplete()) {
            return BrainstormIndexedEstimateSelection{
                &charmPerkeoMegaNaneinfPlasmaGoldCandidateIds(),
                "Charm/Perkeo/Mega five-Joker Plasma/Gold"};
        }
        if (charmPerkeoMegaSpectralAnchorIndexComplete()) {
            return BrainstormIndexedEstimateSelection{
                &charmPerkeoMegaSpectralAnchorCandidateIds(),
                "Charm/Perkeo/Mega Spectral"};
        }
    }
    if (!canUsePerkeoInvisibleAnchorPriority()) {
        return {};
    }
    if (canUsePerkeoInvisibleAnteTwoInvisibleAnchorPriority()
        && perkeoInvisibleAnteTwoInvisibleAnchorIndexComplete()) {
        return BrainstormIndexedEstimateSelection{
            &perkeoInvisibleAnteTwoInvisibleAnchorCandidateIds(),
            "Perkeo/Invisible/Ante-2 Invisible"};
    }
    if (perkeoInvisibleAnchorIndexComplete()) {
        return BrainstormIndexedEstimateSelection{
            &perkeoInvisibleAnchorCandidateIds(),
            "Perkeo/Invisible"};
    }
    return {};
}

BrainstormEstimateSample sampleCompleteAnchorIndex(
    const std::vector<std::uint64_t>& ids,
    std::chrono::steady_clock::time_point deadline) {
    BrainstormEstimateSample result;
    if (ids.empty()) {
        return result;
    }

    constexpr std::size_t candidateBlockSize = 64;
    const std::size_t blockCount =
        (ids.size() + candidateBlockSize - 1) / candidateBlockSize;
    const int workerCount = static_cast<int>(std::min<std::size_t>(
        static_cast<std::size_t>(std::max(1, getBrainstormSearchThreads())),
        blockCount));
    std::atomic<std::size_t> nextCandidate{0};
    std::atomic<long long> tested{0};
    std::atomic<long long> hits{0};
    const auto started = std::chrono::steady_clock::now();
    std::vector<std::thread> workers;
    workers.reserve(workerCount);
    for (int worker = 0; worker < workerCount; ++worker) {
        workers.emplace_back([&]() {
            long long localTested = 0;
            long long localHits = 0;
            while (true) {
                if (tested.load(std::memory_order_relaxed) > 0
                    && std::chrono::steady_clock::now() >= deadline) {
                    break;
                }
                const std::size_t begin = nextCandidate.fetch_add(
                    candidateBlockSize, std::memory_order_relaxed);
                if (begin >= ids.size()) {
                    break;
                }
                const std::size_t end = std::min(
                    begin + candidateBlockSize, ids.size());
                for (std::size_t index = begin; index < end; ++index) {
                    Seed seed(static_cast<long long>(ids[index]));
                    localHits +=
                        authoritativeConfiguredAfterOpeningSeedFilter(seed)
                            != 0
                        ? 1
                        : 0;
                    ++localTested;
                }
                tested.fetch_add(localTested, std::memory_order_relaxed);
                hits.fetch_add(localHits, std::memory_order_relaxed);
                localTested = 0;
                localHits = 0;
            }
            tested.fetch_add(localTested, std::memory_order_relaxed);
            hits.fetch_add(localHits, std::memory_order_relaxed);
        });
    }
    for (std::thread& worker : workers) {
        worker.join();
    }
    const auto finished = std::chrono::steady_clock::now();
    result.tested = tested.load(std::memory_order_relaxed);
    result.hits = hits.load(std::memory_order_relaxed);
    result.elapsedNs =
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            finished - started).count();
    return result;
}

BrainstormEstimateSample sampleBrainstormConfiguration(
    std::chrono::steady_clock::time_point deadline,
    long long maxSamples, long long blockSalt) {
    BrainstormEstimateSample result;
    if (maxSamples <= 0) {
        return result;
    }

    const BrainstormEstimateStrategy strategy =
        selectBrainstormEstimateStrategy();
    const long long sampleLimit =
        std::min(maxSamples, BRAINSTORM_ESTIMATE_MAX_SAMPLES);
    const long long blockCount =
        (sampleLimit + BRAINSTORM_ESTIMATE_BLOCK_SIZE - 1)
        / BRAINSTORM_ESTIMATE_BLOCK_SIZE;
    if (blockCount <= 0) {
        return result;
    }

    // Each sample block is sequential, as in the real search, but consecutive
    // logical blocks are spread hundreds of millions of seed IDs apart. This
    // avoids presenting one unusually lucky local run as a global estimate.
    const long long totalDomainBlocks =
        SEED_DOMAIN_SIZE / BRAINSTORM_ESTIMATE_BLOCK_SIZE;
    long long blockStride = 104729;
    while (std::gcd(blockStride, totalDomainBlocks) != 1) {
        blockStride += 2;
    }
    const long long saltOffset =
        (blockSalt * 15485863ll) % totalDomainBlocks;

    std::atomic<long long> nextBlock{0};
    std::atomic<long long> tested{0};
    std::atomic<long long> hits{0};
    const int workerCount = static_cast<int>(std::max<long long>(
        1, std::min<long long>(
               getBrainstormSearchThreads(), blockCount)));
    const auto started = std::chrono::steady_clock::now();
    std::vector<std::thread> workers;
    workers.reserve(workerCount);

    for (int worker = 0; worker < workerCount; worker++) {
        workers.emplace_back([&]() {
            void* batchContext = strategy.batchPrefilter
                ? strategy.batchPrefilter.createContext(
                      strategy.batchPrefilter.configuration)
                : nullptr;
            std::vector<std::uint32_t> batchSurvivors;
            while (true) {
                if (tested.load(std::memory_order_relaxed) > 0
                    && std::chrono::steady_clock::now() >= deadline) {
                    break;
                }
                const long long logicalBlock =
                    nextBlock.fetch_add(1, std::memory_order_relaxed);
                if (logicalBlock >= blockCount) {
                    break;
                }

                const long long blockSampleOffset =
                    logicalBlock * BRAINSTORM_ESTIMATE_BLOCK_SIZE;
                const long long itemsInBlock = std::min(
                    BRAINSTORM_ESTIMATE_BLOCK_SIZE,
                    sampleLimit - blockSampleOffset);
                const long long physicalBlock =
                    (saltOffset + logicalBlock * blockStride)
                    % totalDomainBlocks;
                const long long firstSeedId =
                    physicalBlock * BRAINSTORM_ESTIMATE_BLOCK_SIZE;
                long long localTested = 0;
                long long localHits = 0;

                if (strategy.batchPrefilter) {
                    strategy.batchPrefilter.collect(
                        batchContext, firstSeedId,
                        static_cast<std::size_t>(itemsInBlock),
                        batchSurvivors);
                    localTested = itemsInBlock;
                    for (std::uint32_t survivorOffset : batchSurvivors) {
                        Seed seed(normalizeSeedId(
                            firstSeedId
                            + static_cast<long long>(survivorOffset)));
                        const long score = strategy.seedFilter(seed);
                        localHits += score != 0 ? 1 : 0;
                    }
                } else if (strategy.seedFilter != nullptr) {
                    Seed seed(firstSeedId);
                    for (long long i = 0; i < itemsInBlock; i++) {
                        if ((i & 63) == 0 && i != 0
                            && std::chrono::steady_clock::now() >= deadline) {
                            break;
                        }
                        const long score = strategy.seedFilter(seed);
                        localHits += score != 0 ? 1 : 0;
                        localTested++;
                        seed.next();
                    }
                } else {
                    Seed seed(firstSeedId);
                    Instance instance(seed);
                    for (long long i = 0; i < itemsInBlock; i++) {
                        if ((i & 63) == 0 && i != 0
                            && std::chrono::steady_clock::now() >= deadline) {
                            break;
                        }
                        const long score = strategy.instanceFilter(instance);
                        localHits += score != 0 ? 1 : 0;
                        localTested++;
                        instance.next();
                    }
                }
                tested.fetch_add(localTested, std::memory_order_relaxed);
                hits.fetch_add(localHits, std::memory_order_relaxed);
            }
            if (batchContext != nullptr) {
                strategy.batchPrefilter.destroyContext(batchContext);
            }
        });
    }
    for (std::thread& worker : workers) {
        worker.join();
    }

    const auto finished = std::chrono::steady_clock::now();
    result.tested = tested.load(std::memory_order_relaxed);
    result.hits = hits.load(std::memory_order_relaxed);
    result.elapsedNs =
        std::chrono::duration_cast<std::chrono::nanoseconds>(
            finished - started).count();
    return result;
}

struct BrainstormEstimateTargetSnapshot {
    std::array<Item, BRAINSTORM_MAX_JOKER_TARGETS> jokers{};
    std::array<BrainstormJokerEditionRequirement,
               BRAINSTORM_MAX_JOKER_TARGETS> editions{};
    std::array<BrainstormJokerLocationRequirement,
               BRAINSTORM_MAX_JOKER_TARGETS> locations{};
    std::array<std::size_t, BRAINSTORM_MAX_JOKER_TARGETS> sourceSlots{};
    std::size_t count = 0;
    bool valid = true;
    bool occurrenceMode = true;
    bool orderedMode = false;
    int souls = 0;
    Item tag = Item::RETRY;
    bool forceCharmRoute = false;
    bool assumeCharmTag = false;
};

BrainstormEstimateTargetSnapshot captureBrainstormEstimateTargets() {
    BrainstormEstimateTargetSnapshot snapshot;
    snapshot.jokers = BRAINSTORM_TARGET_JOKERS;
    snapshot.editions = BRAINSTORM_TARGET_JOKER_EDITIONS;
    snapshot.locations = BRAINSTORM_TARGET_JOKER_LOCATIONS;
    snapshot.sourceSlots = BRAINSTORM_TARGET_JOKER_SLOTS;
    snapshot.count = BRAINSTORM_TARGET_JOKER_COUNT;
    snapshot.valid = BRAINSTORM_TARGET_JOKERS_VALID;
    snapshot.occurrenceMode = BRAINSTORM_V5_OCCURRENCE_MODE;
    snapshot.orderedMode = BRAINSTORM_V5_ORDERED_MODE;
    snapshot.souls = BRAINSTORM_SOULS;
    snapshot.tag = BRAINSTORM_TAG;
    snapshot.forceCharmRoute = BRAINSTORM_FORCE_CHARM_ROUTE;
    snapshot.assumeCharmTag = BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG;
    return snapshot;
}

void restoreBrainstormEstimateTargets(
    const BrainstormEstimateTargetSnapshot& snapshot) {
    BRAINSTORM_TARGET_JOKERS = snapshot.jokers;
    BRAINSTORM_TARGET_JOKER_EDITIONS = snapshot.editions;
    BRAINSTORM_TARGET_JOKER_LOCATIONS = snapshot.locations;
    BRAINSTORM_TARGET_JOKER_SLOTS = snapshot.sourceSlots;
    BRAINSTORM_TARGET_JOKER_COUNT = snapshot.count;
    BRAINSTORM_TARGET_JOKERS_VALID = snapshot.valid;
    BRAINSTORM_V5_OCCURRENCE_MODE = snapshot.occurrenceMode;
    BRAINSTORM_V5_ORDERED_MODE = snapshot.orderedMode;
    BRAINSTORM_SOULS = snapshot.souls;
    BRAINSTORM_TAG = snapshot.tag;
    BRAINSTORM_FORCE_CHARM_ROUTE = snapshot.forceCharmRoute;
    BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG = snapshot.assumeCharmTag;
}

void applyBrainstormEstimateTargetSubset(
    const BrainstormEstimateTargetSnapshot& full,
    const std::vector<std::size_t>& indices,
    bool relaxNegativeEditions) {
    BRAINSTORM_TARGET_JOKERS.fill(Item::RETRY);
    BRAINSTORM_TARGET_JOKER_EDITIONS.fill(
        BrainstormJokerEditionRequirement::Any);
    BRAINSTORM_TARGET_JOKER_LOCATIONS.fill(
        BrainstormJokerLocationRequirement::AnteOne);
    BRAINSTORM_TARGET_JOKER_SLOTS.fill(0);
    BRAINSTORM_TARGET_JOKER_COUNT = 0;
    BRAINSTORM_TARGET_JOKERS_VALID = true;
    BRAINSTORM_V5_OCCURRENCE_MODE = true;
    BRAINSTORM_V5_ORDERED_MODE = false;

    for (std::size_t sourceIndex : indices) {
        const std::size_t destination = BRAINSTORM_TARGET_JOKER_COUNT++;
        BRAINSTORM_TARGET_JOKERS[destination] = full.jokers[sourceIndex];
        BRAINSTORM_TARGET_JOKER_EDITIONS[destination] =
            relaxNegativeEditions
            ? BrainstormJokerEditionRequirement::Any
            : full.editions[sourceIndex];
        BRAINSTORM_TARGET_JOKER_LOCATIONS[destination] =
            full.locations[sourceIndex];
        BRAINSTORM_TARGET_JOKER_SLOTS[destination] =
            full.sourceSlots[sourceIndex];
        for (std::size_t earlier = 0; earlier < destination; earlier++) {
            if (BRAINSTORM_TARGET_JOKERS[earlier]
                == BRAINSTORM_TARGET_JOKERS[destination]) {
                BRAINSTORM_V5_ORDERED_MODE = true;
            }
        }
    }
}

double brainstormSoulTailProbability(int minimumSouls) {
    if (minimumSouls <= 0) {
        return 1.0;
    }
    if (minimumSouls > 5) {
        return 0.0;
    }
    constexpr double soulProbability = 0.003;
    constexpr double ordinaryProbability = 1.0 - soulProbability;
    double result = 0.0;
    for (int souls = minimumSouls; souls <= 5; souls++) {
        double combinations = 1.0;
        for (int i = 1; i <= souls; i++) {
            combinations *=
                static_cast<double>(5 - souls + i)
                / static_cast<double>(i);
        }
        result += combinations
            * std::pow(soulProbability, souls)
            * std::pow(ordinaryProbability, 5 - souls);
    }
    return result;
}

double smoothedBrainstormProbability(
    const BrainstormEstimateSample& sample) {
    if (sample.tested <= 0) {
        return 0.0;
    }
    // Jeffreys smoothing keeps a relaxed zero-hit probe finite while the
    // output's confidence/message still labels it as very uncertain.
    return (static_cast<double>(sample.hits) + 0.5)
        / (static_cast<double>(sample.tested) + 1.0);
}

struct BrainstormWilsonInterval {
    double lower = 0.0;
    double upper = 1.0;
};

BrainstormWilsonInterval brainstormWilson95(
    long long hits, long long tested) {
    if (tested <= 0) {
        return BrainstormWilsonInterval{};
    }
    constexpr double z = 1.959963984540054;
    constexpr double zSquared = z * z;
    const double n = static_cast<double>(tested);
    const double p = static_cast<double>(hits) / n;
    const double denominator = 1.0 + zSquared / n;
    const double center = (p + zSquared / (2.0 * n)) / denominator;
    const double halfWidth =
        z * std::sqrt(
            p * (1.0 - p) / n + zSquared / (4.0 * n * n))
        / denominator;
    return BrainstormWilsonInterval{
        std::max(0.0, center - halfWidth),
        std::min(1.0, center + halfWidth)};
}

double brainstormGeometricQuantileSeconds(
    double probability, double quantile, double seedsPerSecond) {
    if (!(probability > 0.0) || !(seedsPerSecond > 0.0)) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    double trials = 1.0;
    if (probability < 1.0) {
        trials = std::log1p(-quantile) / std::log1p(-probability);
        trials = std::max(1.0, trials);
    }
    return trials / seedsPerSecond;
}

double brainstormExactMedianLowerBound(
    const BrainstormEstimateSample& sample, double seedsPerSecond) {
    if (sample.tested <= 0 || !(seedsPerSecond > 0.0)) {
        return std::numeric_limits<double>::quiet_NaN();
    }
    if (sample.hits > 0) {
        const BrainstormWilsonInterval interval =
            brainstormWilson95(sample.hits, sample.tested);
        return brainstormGeometricQuantileSeconds(
            interval.upper, 0.5, seedsPerSecond);
    }

    // With zero successes, 1 - 0.05^(1/n) is the one-sided 95% upper
    // confidence bound for the hit probability.
    const double probabilityUpper =
        -std::expm1(std::log(0.05)
                    / static_cast<double>(sample.tested));
    return brainstormGeometricQuantileSeconds(
        probabilityUpper, 0.5, seedsPerSecond);
}

void appendBrainstormEstimateField(
    std::ostringstream& output, const char* key,
    const std::string& value) {
    if (output.tellp() > 0) {
        output << '\t';
    }
    output << key << '=' << value;
}

void appendBrainstormEstimateField(
    std::ostringstream& output, const char* key, long long value) {
    appendBrainstormEstimateField(output, key, std::to_string(value));
}

void appendBrainstormEstimateField(
    std::ostringstream& output, const char* key, double value) {
    if (!std::isfinite(value)) {
        appendBrainstormEstimateField(output, key, "unknown");
        return;
    }
    std::ostringstream formatted;
    formatted << std::setprecision(10) << value;
    appendBrainstormEstimateField(output, key, formatted.str());
}

std::string brainstormEstimateStatus(
    const char* status, const char* method, const char* message) {
    std::ostringstream output;
    appendBrainstormEstimateField(output, "status", status);
    appendBrainstormEstimateField(output, "method", method);
    appendBrainstormEstimateField(output, "message", message);
    return output.str();
}

} // namespace

std::string brainstorm_estimate_versioned_cpp(
    std::string voucher, std::string pack, std::string tag, int souls,
    bool observatory, int observatoryDeadline, bool perkeo,
    bool copymoney, bool retcon, bool bean, bool burglar,
    std::string customFilter, std::string targetRank, std::string targetSuit,
    int specificRankMin, int anyRankMin, std::string targetJokers,
    std::string deck, std::string targetJokerLocations, int budgetMs,
    bool allowDeadlineLocations, int stakeLevel) {
    if (!configureBrainstormSearch(
            voucher, pack, tag, souls, observatory, observatoryDeadline,
            perkeo, copymoney, retcon, bean, burglar, customFilter,
            targetRank, targetSuit, specificRankMin, anyRankMin,
            targetJokers, deck, targetJokerLocations, true,
            allowDeadlineLocations, stakeLevel)) {
        return brainstormEstimateStatus(
            "invalid", "none",
            "The selected configuration is not valid.");
    }
    if (rankFiltersDeterministicallyFail()) {
        return brainstormEstimateStatus(
            "impossible", "deterministic",
            "The selected card counts cannot occur on this deck.");
    }
    if (brainstormHasDuplicateLegendaryTarget()) {
        return brainstormEstimateStatus(
            "impossible", "deterministic",
            "The same Legendary Joker cannot be collected twice from the starting Charm Pack.");
    }
    if (rankFiltersDeterministicallyPass() && isRankOnlySearch()) {
        std::ostringstream output;
        appendBrainstormEstimateField(output, "status", "always");
        appendBrainstormEstimateField(output, "method", "deterministic");
        appendBrainstormEstimateField(output, "median_seconds", 0.0);
        appendBrainstormEstimateField(output, "p90_seconds", 0.0);
        appendBrainstormEstimateField(
            output, "confidence", "deterministic");
        appendBrainstormEstimateField(
            output, "message",
            "Every seed satisfies these fixed-deck card counts.");
        return output.str();
    }

    const int boundedBudgetMs = std::clamp(budgetMs, 25, 1000);
    const auto estimateStarted = std::chrono::steady_clock::now();
    const auto overallDeadline =
        estimateStarted + std::chrono::milliseconds(boundedBudgetMs);

    const BrainstormIndexedEstimateSelection indexedSelection =
        selectCompleteAnchorEstimateIndex();
    if (indexedSelection.ids != nullptr) {
        const BrainstormEstimateSample indexed = sampleCompleteAnchorIndex(
            *indexedSelection.ids, overallDeadline);
        const long long indexedTotal = static_cast<long long>(
            indexedSelection.ids->size());
        const bool completePopulation = indexed.tested == indexedTotal;
        const double candidatesPerSecond = indexed.elapsedNs > 0
            ? static_cast<double>(indexed.tested) * 1000000000.0
                / static_cast<double>(indexed.elapsedNs)
            : 0.0;

        if (completePopulation && indexed.hits == 0) {
            std::ostringstream output;
            appendBrainstormEstimateField(output, "status", "impossible");
            appendBrainstormEstimateField(output, "method", "exact_index");
            appendBrainstormEstimateField(
                output, "indexed_total", indexedTotal);
            appendBrainstormEstimateField(
                output, "indexed_tested", indexed.tested);
            appendBrainstormEstimateField(output, "indexed_hits", 0ll);
            appendBrainstormEstimateField(
                output, "message",
                "The complete rare-event index contains no matching seed for this setup.");
            return output.str();
        }

        if (indexed.tested > 0 && indexed.hits > 0
            && candidatesPerSecond > 0.0) {
            const double probability =
                static_cast<double>(indexed.hits)
                / static_cast<double>(indexed.tested);
            double median = brainstormGeometricQuantileSeconds(
                probability, 0.5, candidatesPerSecond);
            double p90 = brainstormGeometricQuantileSeconds(
                probability, 0.9, candidatesPerSecond);
            // Thread creation, index loading, and the first concurrently
            // claimed candidate blocks impose a small real latency floor that
            // sustained candidate throughput alone does not capture.
            median = std::max(0.001, median);
            p90 = std::max(median, std::max(0.001, p90));

            std::ostringstream output;
            appendBrainstormEstimateField(output, "status", "ok");
            appendBrainstormEstimateField(
                output, "method",
                completePopulation ? "exact_index" : "index_sample");
            appendBrainstormEstimateField(
                output, "index_name", indexedSelection.label);
            appendBrainstormEstimateField(
                output, "indexed_total", indexedTotal);
            appendBrainstormEstimateField(
                output, "indexed_tested", indexed.tested);
            appendBrainstormEstimateField(
                output, "indexed_hits", indexed.hits);
            appendBrainstormEstimateField(
                output, "candidates_per_second", candidatesPerSecond);
            appendBrainstormEstimateField(
                output, "median_seconds", median);
            appendBrainstormEstimateField(output, "p90_seconds", p90);
            appendBrainstormEstimateField(
                output, "expected_full_space_matches",
                probability * static_cast<double>(indexedTotal));
            appendBrainstormEstimateField(
                output, "confidence",
                completePopulation ? "complete_index" : "sample_based");
            appendBrainstormEstimateField(
                output, "message",
                completePopulation
                    ? "Measured across every candidate in the complete rare-event index."
                    : "Measured from a time-bounded sample of the complete rare-event index.");
            return output.str();
        }

        if (indexed.tested > 0) {
            std::ostringstream output;
            appendBrainstormEstimateField(output, "status", "no_hits");
            appendBrainstormEstimateField(output, "method", "index_sample");
            appendBrainstormEstimateField(
                output, "index_name", indexedSelection.label);
            appendBrainstormEstimateField(
                output, "indexed_total", indexedTotal);
            appendBrainstormEstimateField(
                output, "indexed_tested", indexed.tested);
            appendBrainstormEstimateField(output, "indexed_hits", 0ll);
            appendBrainstormEstimateField(
                output, "candidates_per_second", candidatesPerSecond);
            appendBrainstormEstimateField(
                output, "message",
                "No matches appeared in the time-bounded indexed sample; run the search to test the remaining exact candidates.");
            return output.str();
        }
    }

    const int initialExactMs = std::max(6, boundedBudgetMs / 4);
    const auto initialExactDeadline = std::min(
        overallDeadline,
        estimateStarted + std::chrono::milliseconds(initialExactMs));
    BrainstormEstimateSample exact = sampleBrainstormConfiguration(
        initialExactDeadline, BRAINSTORM_ESTIMATE_MAX_SAMPLES, 0);

    if (exact.hits > 0
        && std::chrono::steady_clock::now() < overallDeadline) {
        const auto extensionDeadline = std::min(
            overallDeadline,
            estimateStarted
                + std::chrono::milliseconds(
                    boundedBudgetMs * 65 / 100));
        const BrainstormEstimateSample additional =
            sampleBrainstormConfiguration(
                extensionDeadline, BRAINSTORM_ESTIMATE_MAX_SAMPLES, 1);
        exact.tested += additional.tested;
        exact.hits += additional.hits;
        exact.elapsedNs += additional.elapsedNs;
    }
    if (exact.hits >= BRAINSTORM_ESTIMATE_MIN_EXACT_HITS
        && std::chrono::steady_clock::now() < overallDeadline) {
        const BrainstormEstimateSample additional =
            sampleBrainstormConfiguration(
                overallDeadline, BRAINSTORM_ESTIMATE_MAX_SAMPLES, 2);
        exact.tested += additional.tested;
        exact.hits += additional.hits;
        exact.elapsedNs += additional.elapsedNs;
    }

    const double seedsPerSecond =
        exact.elapsedNs > 0
        ? static_cast<double>(exact.tested) * 1000000000.0
            / static_cast<double>(exact.elapsedNs)
        : 0.0;
    const double exactLower = brainstormExactMedianLowerBound(
        exact, seedsPerSecond);

    if (exact.tested > 0
        && exact.hits >= BRAINSTORM_ESTIMATE_MIN_EXACT_HITS) {
        const double probability =
            static_cast<double>(exact.hits)
            / static_cast<double>(exact.tested);
        const BrainstormWilsonInterval interval =
            brainstormWilson95(exact.hits, exact.tested);
        const double median = brainstormGeometricQuantileSeconds(
            probability, 0.5, seedsPerSecond);
        const double p90 = brainstormGeometricQuantileSeconds(
            probability, 0.9, seedsPerSecond);
        const double medianLow = brainstormGeometricQuantileSeconds(
            interval.upper, 0.5, seedsPerSecond);
        const double medianHigh = brainstormGeometricQuantileSeconds(
            interval.lower, 0.5, seedsPerSecond);
        const double expectedMatches =
            probability * static_cast<double>(SEED_DOMAIN_SIZE);

        std::ostringstream output;
        appendBrainstormEstimateField(output, "status", "ok");
        appendBrainstormEstimateField(
            output, "method", "exact_sample");
        appendBrainstormEstimateField(
            output, "exact_tested", exact.tested);
        appendBrainstormEstimateField(
            output, "exact_hits", exact.hits);
        appendBrainstormEstimateField(
            output, "seeds_per_second", seedsPerSecond);
        appendBrainstormEstimateField(
            output, "median_seconds", median);
        appendBrainstormEstimateField(output, "p90_seconds", p90);
        appendBrainstormEstimateField(
            output, "median_low_seconds", medianLow);
        appendBrainstormEstimateField(
            output, "median_high_seconds", medianHigh);
        appendBrainstormEstimateField(
            output, "exact_median_lower_seconds", exactLower);
        appendBrainstormEstimateField(
            output, "expected_full_space_matches", expectedMatches);
        appendBrainstormEstimateField(output, "confidence", "95%");
        appendBrainstormEstimateField(
            output, "message",
            "Measured directly with the selected configuration.");
        return output.str();
    }

    const BrainstormEstimateTargetSnapshot fullTargets =
        captureBrainstormEstimateTargets();
    const int fullSoulRequirement = requiredCharmSoulCount();
    const bool fullCharmRoute = needsStartingCharmPack();
    const bool customGuaranteesNegativePerkeo =
        BRAINSTORM_FILTER == customFilters::NEGATIVE_PERKEO
        || BRAINSTORM_FILTER
            == customFilters::NEGATIVE_PERKEO_BLUEPRINT;
    const bool customGuaranteesNegativeBlueprint =
        BRAINSTORM_FILTER == customFilters::NEGATIVE_BLUEPRINT
        || BRAINSTORM_FILTER
            == customFilters::NEGATIVE_PERKEO_BLUEPRINT;
    int requiredNegativeEditions = 0;
    for (std::size_t i = 0; i < fullTargets.count; i++) {
        if (fullTargets.editions[i]
            == BrainstormJokerEditionRequirement::Negative) {
            const bool alreadyGuaranteed =
                (fullTargets.jokers[i] == Item::Perkeo
                    && customGuaranteesNegativePerkeo)
                || (fullTargets.jokers[i] == Item::Blueprint
                    && customGuaranteesNegativeBlueprint
                    && fullTargets.locations[i]
                        == BrainstormJokerLocationRequirement::AnteOne);
            if (!alreadyGuaranteed) {
                requiredNegativeEditions++;
            }
        }
    }

    // Build relaxed probes. Every repeated center stays in one group so the
    // probe still exercises ownership, Invisible aging, and selling. Unique
    // centers are separated so a very rare conjunction remains measurable.
    std::vector<std::vector<std::size_t>> targetGroups;
    std::array<bool, BRAINSTORM_MAX_JOKER_TARGETS> grouped{};
    double legendaryIdentityFactor = 1.0;
    int legendaryTargetCount = 0;
    int duplicateGroups = 0;
    const int collectibleSoulChoices =
        std::min(2, std::max(1, fullSoulRequirement));
    for (std::size_t i = 0; i < fullTargets.count; i++) {
        if (grouped[i]) {
            continue;
        }
        std::vector<std::size_t> sameCenter;
        for (std::size_t j = i; j < fullTargets.count; j++) {
            if (!grouped[j]
                && fullTargets.jokers[j] == fullTargets.jokers[i]) {
                sameCenter.push_back(j);
                grouped[j] = true;
            }
        }
        if (sameCenter.size() > 1) {
            duplicateGroups++;
        }
        if (isLegendaryJoker(fullTargets.jokers[i])) {
            // Soul-based custom filters already guarantee Perkeo. Do not
            // charge its identity a second time when the same requirement is
            // also represented in an explicit target slot.
            if (!(fullTargets.jokers[i] == Item::Perkeo
                  && customFilterRequiresPerkeo())) {
                legendaryTargetCount +=
                    static_cast<int>(sameCenter.size());
            }
        } else {
            targetGroups.push_back(std::move(sameCenter));
        }
    }
    // Soul Jokers are sampled without replacement from five centers. At most
    // two cards can be selected, even when Min Souls is three or four.
    if (legendaryTargetCount == 1) {
        legendaryIdentityFactor =
            static_cast<double>(collectibleSoulChoices) / 5.0;
    } else if (legendaryTargetCount == 2) {
        legendaryIdentityFactor = fullTargets.orderedMode
            ? 1.0 / (5.0 * 4.0)
            : 2.0 / (5.0 * 4.0);
    }

    // The base probe retains every non-target constraint and the exact Charm
    // route, but removes explicit Soul-count rarity. Soul count is restored
    // once with the exact five-roll binomial tail below.
    applyBrainstormEstimateTargetSubset(fullTargets, {}, true);
    BRAINSTORM_SOULS = 0;
    BRAINSTORM_FORCE_CHARM_ROUTE = fullCharmRoute;
    const int baseImplicitSoulRequirement = requiredCharmSoulCount();

    const int totalProbeCount =
        2 + static_cast<int>(targetGroups.size());
    int probesRemaining = totalProbeCount;
    auto nextProbeDeadline = [&]() {
        const auto now = std::chrono::steady_clock::now();
        if (now >= overallDeadline) {
            return now;
        }
        const auto remaining = overallDeadline - now;
        return now + remaining / std::max(1, probesRemaining);
    };

    BrainstormEstimateSample baseSample =
        sampleBrainstormConfiguration(
            nextProbeDeadline(), BRAINSTORM_ESTIMATE_MAX_SAMPLES, 17);
    probesRemaining--;
    // Group probes condition on the Charm route instead of repeatedly
    // waiting for its natural tag. A second target-free probe measures the
    // remaining base constraints under that same condition, so their ratio
    // does not double-count (or omit) the common base.
    BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG = fullCharmRoute;
    const BrainstormEstimateSample conditionalBaseSample =
        sampleBrainstormConfiguration(
            nextProbeDeadline(), BRAINSTORM_ESTIMATE_MAX_SAMPLES, 17);
    probesRemaining--;
    long long heuristicSamples =
        baseSample.tested + conditionalBaseSample.tested;
    long long groupedTargetSamples = 0;
    long long groupedTargetHits = 0;
    long long zeroHitGroupedSamples = 0;
    int zeroHitProbes =
        (baseSample.hits == 0 ? 1 : 0)
        + (conditionalBaseSample.hits == 0 ? 1 : 0);
    const double baseProbability =
        smoothedBrainstormProbability(baseSample);
    const double conditionalBaseProbability =
        smoothedBrainstormProbability(conditionalBaseSample);
    double modeledProbability = baseProbability;

    const double fullSoulTail =
        brainstormSoulTailProbability(fullSoulRequirement);
    const double baseSoulTail =
        brainstormSoulTailProbability(baseImplicitSoulRequirement);
    if (baseSoulTail > 0.0) {
        modeledProbability *=
            std::min(1.0, fullSoulTail / baseSoulTail);
    } else {
        modeledProbability = 0.0;
    }
    modeledProbability *= legendaryIdentityFactor;
    modeledProbability *=
        std::pow(0.003, requiredNegativeEditions);

    for (const std::vector<std::size_t>& group : targetGroups) {
        applyBrainstormEstimateTargetSubset(fullTargets, group, true);
        BRAINSTORM_SOULS = 0;
        BRAINSTORM_FORCE_CHARM_ROUTE = fullCharmRoute;
        BRAINSTORM_ESTIMATE_ASSUME_CHARM_TAG = fullCharmRoute;
        const BrainstormEstimateSample groupSample =
            sampleBrainstormConfiguration(
                nextProbeDeadline(), BRAINSTORM_ESTIMATE_MAX_SAMPLES, 17);
        probesRemaining--;
        heuristicSamples += groupSample.tested;
        groupedTargetSamples += groupSample.tested;
        groupedTargetHits += groupSample.hits;
        if (groupSample.hits == 0) {
            zeroHitGroupedSamples += groupSample.tested;
        }
        zeroHitProbes += groupSample.hits == 0 ? 1 : 0;

        const double groupProbability =
            smoothedBrainstormProbability(groupSample);
        if (conditionalBaseProbability > 0.0) {
            // All probes retain the same tag/Soul/voucher/etc. base. Divide
            // by the target-free conditional base for each group so common
            // rarity is counted once:
            // P(base) * product(P(group | Charm) / P(base | Charm)).
            modeledProbability *= std::min(
                1.0, groupProbability / conditionalBaseProbability);
        } else {
            modeledProbability = 0.0;
        }
    }
    restoreBrainstormEstimateTargets(fullTargets);

    if (!(modeledProbability > 0.0)
        || !(seedsPerSecond > 0.0)
        || heuristicSamples <= 0) {
        std::ostringstream output;
        appendBrainstormEstimateField(output, "status", "no_hits");
        appendBrainstormEstimateField(output, "method", "exact_sample");
        appendBrainstormEstimateField(
            output, "exact_tested", exact.tested);
        appendBrainstormEstimateField(
            output, "exact_hits", exact.hits);
        appendBrainstormEstimateField(
            output, "seeds_per_second", seedsPerSecond);
        appendBrainstormEstimateField(
            output, "exact_median_lower_seconds", exactLower);
        appendBrainstormEstimateField(output, "confidence", "unknown");
        appendBrainstormEstimateField(
            output, "message",
            "No exact hits and the staged model had too little evidence.");
        return output.str();
    }

    modeledProbability = std::min(1.0, modeledProbability);
    const double median = brainstormGeometricQuantileSeconds(
        modeledProbability, 0.5, seedsPerSecond);
    const double p90 = brainstormGeometricQuantileSeconds(
        modeledProbability, 0.9, seedsPerSecond);

    // This is deliberately wider than a sampling confidence interval because
    // different acquisition windows are multiplied under an independence
    // approximation. Zero-hit relaxed probes and repeated centers widen it.
    double rangeExponent =
        1.0 + 0.5 * static_cast<double>(targetGroups.size())
        + 1.25 * static_cast<double>(zeroHitProbes)
        + 0.5 * static_cast<double>(duplicateGroups)
        + (fullSoulRequirement >= 3 ? 1.0 : 0.0);
    rangeExponent = std::min(8.0, rangeExponent);
    const double uncertaintyFactor = std::pow(10.0, rangeExponent);
    const double medianLow = median / uncertaintyFactor;
    const double medianHigh = median * uncertaintyFactor;
    const double expectedMatches =
        modeledProbability
        * static_cast<double>(SEED_DOMAIN_SIZE);
    const bool veryLowConfidence =
        zeroHitProbes > 0 || expectedMatches < 1.0;

    std::ostringstream output;
    appendBrainstormEstimateField(output, "status", "ok");
    appendBrainstormEstimateField(
        output, "method", "staged_heuristic");
    appendBrainstormEstimateField(
        output, "exact_tested", exact.tested);
    appendBrainstormEstimateField(
        output, "exact_hits", exact.hits);
    appendBrainstormEstimateField(
        output, "heuristic_samples", heuristicSamples);
    appendBrainstormEstimateField(
        output, "base_tested", baseSample.tested);
    appendBrainstormEstimateField(
        output, "base_hits", baseSample.hits);
    appendBrainstormEstimateField(
        output, "conditional_base_tested", conditionalBaseSample.tested);
    appendBrainstormEstimateField(
        output, "conditional_base_hits", conditionalBaseSample.hits);
    appendBrainstormEstimateField(
        output, "grouped_target_tested", groupedTargetSamples);
    appendBrainstormEstimateField(
        output, "grouped_target_hits", groupedTargetHits);
    appendBrainstormEstimateField(
        output, "zero_hit_grouped_tested", zeroHitGroupedSamples);
    appendBrainstormEstimateField(
        output, "seeds_per_second", seedsPerSecond);
    appendBrainstormEstimateField(
        output, "median_seconds", median);
    appendBrainstormEstimateField(output, "p90_seconds", p90);
    appendBrainstormEstimateField(
        output, "median_low_seconds", medianLow);
    appendBrainstormEstimateField(
        output, "median_high_seconds", medianHigh);
    appendBrainstormEstimateField(
        output, "exact_median_lower_seconds", exactLower);
    appendBrainstormEstimateField(
        output, "expected_full_space_matches", expectedMatches);
    appendBrainstormEstimateField(
        output, "confidence",
        veryLowConfidence ? "very_low" : "low");
    appendBrainstormEstimateField(
        output, "message",
        expectedMatches < 1.0
        ? "Rough staged model; it predicts fewer than one match in the full seed space, so a matching seed may not exist."
        : "Rough staged model from relaxed Joker groups; the displayed range includes structural uncertainty.");
    return output.str();
}

std::string brainstorm_estimate_v1_cpp(
    std::string voucher, std::string pack, std::string tag, int souls,
    bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean,
    bool burglar, std::string customFilter, std::string targetRank,
    std::string targetSuit, int specificRankMin, int anyRankMin,
    std::string targetJokers, std::string deck,
    std::string targetJokerLocations, int budgetMs) {
    return brainstorm_estimate_versioned_cpp(
        voucher, pack, tag, souls, observatory, 0, perkeo, copymoney,
        retcon, bean, burglar, customFilter, targetRank, targetSuit,
        specificRankMin, anyRankMin, targetJokers, deck,
        targetJokerLocations, budgetMs, false, 1);
}

std::string brainstorm_estimate_v2_cpp(
    std::string voucher, std::string pack, std::string tag, int souls,
    bool observatory, int observatoryDeadline, bool perkeo,
    bool copymoney, bool retcon, bool bean, bool burglar,
    std::string customFilter, std::string targetRank, std::string targetSuit,
    int specificRankMin, int anyRankMin, std::string targetJokers,
    std::string deck, std::string targetJokerLocations, int budgetMs) {
    return brainstorm_estimate_versioned_cpp(
        voucher, pack, tag, souls, observatory, observatoryDeadline,
        perkeo, copymoney, retcon, bean, burglar, customFilter, targetRank,
        targetSuit, specificRankMin, anyRankMin, targetJokers, deck,
        targetJokerLocations, budgetMs, true, 1);
}

std::string brainstorm_estimate_v3_cpp(
    std::string voucher, std::string pack, std::string tag, int souls,
    bool observatory, int observatoryDeadline, bool perkeo,
    bool copymoney, bool retcon, bool bean, bool burglar,
    std::string customFilter, std::string targetRank, std::string targetSuit,
    int specificRankMin, int anyRankMin, std::string targetJokers,
    std::string deck, std::string targetJokerLocations, int budgetMs,
    int stakeLevel) {
    return brainstorm_estimate_versioned_cpp(
        voucher, pack, tag, souls, observatory, observatoryDeadline,
        perkeo, copymoney, retcon, bean, burglar, customFilter, targetRank,
        targetSuit, specificRankMin, anyRankMin, targetJokers, deck,
        targetJokerLocations, budgetMs, true, stakeLevel);
}

std::string brainstorm_v3_cpp(
    std::string seed, std::string voucher, std::string pack, std::string tag,
    int souls, bool observatory, bool perkeo, bool copymoney, bool retcon,
    bool bean, bool burglar, std::string customFilter, std::string targetRank,
    std::string targetSuit, int specificRankMin, int anyRankMin,
    std::string targetJokers, std::string deck) {
    return brainstorm_v4_cpp(
        seed, voucher, pack, tag, souls, observatory, perkeo, copymoney,
        retcon, bean, burglar, customFilter, targetRank, targetSuit,
        specificRankMin, anyRankMin, targetJokers, deck, "");
}

std::string brainstorm_v2_cpp(
    std::string seed, std::string voucher, std::string pack, std::string tag,
    int souls, bool observatory, bool perkeo, bool copymoney, bool retcon,
    bool bean, bool burglar, std::string customFilter, std::string targetRank,
    std::string targetSuit, int specificRankMin, int anyRankMin,
    std::string targetJokers) {
    return brainstorm_v3_cpp(
        seed, voucher, pack, tag, souls, observatory, perkeo, copymoney,
        retcon, bean, burglar, customFilter, targetRank, targetSuit,
        specificRankMin, anyRankMin, targetJokers, "Red Deck");
}

std::string brainstorm_cpp(
    std::string seed, std::string voucher, std::string pack, std::string tag,
    double souls, bool observatory, bool perkeo, bool copymoney, bool retcon,
    bool bean, bool burglar, std::string customFilter, std::string targetRank,
    std::string targetSuit, int specificRankMin, int anyRankMin) {
    int soulCount = 0;
    if (std::isfinite(souls)) {
        soulCount = std::clamp(static_cast<int>(souls), 0, 4);
    }
    return brainstorm_v2_cpp(
        seed, voucher, pack, tag, soulCount, observatory, perkeo, copymoney,
        retcon, bean, burglar, customFilter, targetRank, targetSuit,
        specificRankMin, anyRankMin, "");
}

const char* copyBrainstormResult(const std::string& result) {
    char* copiedResult = static_cast<char*>(std::malloc(result.length() + 1));
    if (copiedResult == nullptr) {
        return nullptr;
    }
    std::memcpy(copiedResult, result.c_str(), result.length() + 1);
    return copiedResult;
}

std::string stringOrEmpty(const char* value) {
    return value == nullptr ? std::string() : std::string(value);
}

extern "C" {
    const char* brainstorm(const char* seed, const char* voucher, const char* pack, const char* tag, double souls, bool observatory, bool perkeo, bool copymoney, bool retcon, bool bean, bool burglar, const char* customFilter, const char* targetRank, const char* targetSuit, int specificRankMin, int anyRankMin) {
        const std::string result = brainstorm_cpp(
            stringOrEmpty(seed), stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, perkeo, copymoney, retcon,
            bean, burglar, stringOrEmpty(customFilter),
            stringOrEmpty(targetRank), stringOrEmpty(targetSuit),
            specificRankMin, anyRankMin);
        return copyBrainstormResult(result);
    }

    const char* brainstorm_v2(
        const char* seed, const char* voucher, const char* pack,
        const char* tag, int souls, bool observatory, bool perkeo,
        bool copymoney, bool retcon, bool bean, bool burglar,
        const char* customFilter, const char* targetRank,
        const char* targetSuit, int specificRankMin, int anyRankMin,
        const char* targetJokers) {
        const std::string result = brainstorm_v2_cpp(
            stringOrEmpty(seed), stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, perkeo, copymoney, retcon,
            bean, burglar, stringOrEmpty(customFilter),
            stringOrEmpty(targetRank), stringOrEmpty(targetSuit),
            specificRankMin, anyRankMin, stringOrEmpty(targetJokers));
        return copyBrainstormResult(result);
    }

    const char* brainstorm_v3(
        const char* seed, const char* voucher, const char* pack,
        const char* tag, int souls, bool observatory, bool perkeo,
        bool copymoney, bool retcon, bool bean, bool burglar,
        const char* customFilter, const char* targetRank,
        const char* targetSuit, int specificRankMin, int anyRankMin,
        const char* targetJokers, const char* deck) {
        const std::string result = brainstorm_v3_cpp(
            stringOrEmpty(seed), stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, perkeo, copymoney, retcon,
            bean, burglar, stringOrEmpty(customFilter),
            stringOrEmpty(targetRank), stringOrEmpty(targetSuit),
            specificRankMin, anyRankMin, stringOrEmpty(targetJokers),
            stringOrEmpty(deck));
        return copyBrainstormResult(result);
    }

    const char* brainstorm_v4(
        const char* seed, const char* voucher, const char* pack,
        const char* tag, int souls, bool observatory, bool perkeo,
        bool copymoney, bool retcon, bool bean, bool burglar,
        const char* customFilter, const char* targetRank,
        const char* targetSuit, int specificRankMin, int anyRankMin,
        const char* targetJokers, const char* deck,
        const char* targetJokerLocations) {
        const std::string result = brainstorm_v4_cpp(
            stringOrEmpty(seed), stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, perkeo, copymoney, retcon,
            bean, burglar, stringOrEmpty(customFilter),
            stringOrEmpty(targetRank), stringOrEmpty(targetSuit),
            specificRankMin, anyRankMin, stringOrEmpty(targetJokers),
            stringOrEmpty(deck), stringOrEmpty(targetJokerLocations));
        return copyBrainstormResult(result);
    }

    const char* brainstorm_v5(
        const char* seed, const char* voucher, const char* pack,
        const char* tag, int souls, bool observatory, bool perkeo,
        bool copymoney, bool retcon, bool bean, bool burglar,
        const char* customFilter, const char* targetRank,
        const char* targetSuit, int specificRankMin, int anyRankMin,
        const char* targetJokers, const char* deck,
        const char* targetJokerLocations) {
        const std::string result = brainstorm_v5_cpp(
            stringOrEmpty(seed), stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, perkeo, copymoney, retcon,
            bean, burglar, stringOrEmpty(customFilter),
            stringOrEmpty(targetRank), stringOrEmpty(targetSuit),
            specificRankMin, anyRankMin, stringOrEmpty(targetJokers),
            stringOrEmpty(deck), stringOrEmpty(targetJokerLocations));
        return copyBrainstormResult(result);
    }

    const char* brainstorm_v6(
        const char* seed, const char* voucher, const char* pack,
        const char* tag, int souls, bool observatory,
        int observatoryDeadline, bool perkeo, bool copymoney, bool retcon,
        bool bean, bool burglar, const char* customFilter,
        const char* targetRank, const char* targetSuit,
        int specificRankMin, int anyRankMin, const char* targetJokers,
        const char* deck, const char* targetJokerLocations) {
        const std::string result = brainstorm_v6_cpp(
            stringOrEmpty(seed), stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, observatoryDeadline,
            perkeo, copymoney, retcon, bean, burglar,
            stringOrEmpty(customFilter), stringOrEmpty(targetRank),
            stringOrEmpty(targetSuit), specificRankMin, anyRankMin,
            stringOrEmpty(targetJokers), stringOrEmpty(deck),
            stringOrEmpty(targetJokerLocations));
        return copyBrainstormResult(result);
    }

    const char* brainstorm_v7(
        const char* seed, const char* voucher, const char* pack,
        const char* tag, int souls, bool observatory,
        int observatoryDeadline, bool perkeo, bool copymoney, bool retcon,
        bool bean, bool burglar, const char* customFilter,
        const char* targetRank, const char* targetSuit,
        int specificRankMin, int anyRankMin, const char* targetJokers,
        const char* deck, const char* targetJokerLocations,
        int stakeLevel) {
        const std::string result = brainstorm_v7_cpp(
            stringOrEmpty(seed), stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, observatoryDeadline,
            perkeo, copymoney, retcon, bean, burglar,
            stringOrEmpty(customFilter), stringOrEmpty(targetRank),
            stringOrEmpty(targetSuit), specificRankMin, anyRankMin,
            stringOrEmpty(targetJokers), stringOrEmpty(deck),
            stringOrEmpty(targetJokerLocations), stakeLevel);
        return copyBrainstormResult(result);
    }

    const char* brainstorm_estimate_v1(
        const char* voucher, const char* pack, const char* tag, int souls,
        bool observatory, bool perkeo, bool copymoney, bool retcon,
        bool bean, bool burglar, const char* customFilter,
        const char* targetRank, const char* targetSuit,
        int specificRankMin, int anyRankMin, const char* targetJokers,
        const char* deck, const char* targetJokerLocations,
        int budgetMs) {
        const std::string result = brainstorm_estimate_v1_cpp(
            stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, perkeo, copymoney,
            retcon, bean, burglar, stringOrEmpty(customFilter),
            stringOrEmpty(targetRank), stringOrEmpty(targetSuit),
            specificRankMin, anyRankMin, stringOrEmpty(targetJokers),
            stringOrEmpty(deck), stringOrEmpty(targetJokerLocations),
            budgetMs);
        return copyBrainstormResult(result);
    }

    const char* brainstorm_estimate_v2(
        const char* voucher, const char* pack, const char* tag, int souls,
        bool observatory, int observatoryDeadline, bool perkeo,
        bool copymoney, bool retcon, bool bean, bool burglar,
        const char* customFilter, const char* targetRank,
        const char* targetSuit, int specificRankMin, int anyRankMin,
        const char* targetJokers, const char* deck,
        const char* targetJokerLocations, int budgetMs) {
        const std::string result = brainstorm_estimate_v2_cpp(
            stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, observatoryDeadline,
            perkeo, copymoney, retcon, bean, burglar,
            stringOrEmpty(customFilter), stringOrEmpty(targetRank),
            stringOrEmpty(targetSuit), specificRankMin, anyRankMin,
            stringOrEmpty(targetJokers), stringOrEmpty(deck),
            stringOrEmpty(targetJokerLocations), budgetMs);
        return copyBrainstormResult(result);
    }

    const char* brainstorm_estimate_v3(
        const char* voucher, const char* pack, const char* tag, int souls,
        bool observatory, int observatoryDeadline, bool perkeo,
        bool copymoney, bool retcon, bool bean, bool burglar,
        const char* customFilter, const char* targetRank,
        const char* targetSuit, int specificRankMin, int anyRankMin,
        const char* targetJokers, const char* deck,
        const char* targetJokerLocations, int budgetMs, int stakeLevel) {
        const std::string result = brainstorm_estimate_v3_cpp(
            stringOrEmpty(voucher), stringOrEmpty(pack),
            stringOrEmpty(tag), souls, observatory, observatoryDeadline,
            perkeo, copymoney, retcon, bean, burglar,
            stringOrEmpty(customFilter), stringOrEmpty(targetRank),
            stringOrEmpty(targetSuit), specificRankMin, anyRankMin,
            stringOrEmpty(targetJokers), stringOrEmpty(deck),
            stringOrEmpty(targetJokerLocations), budgetMs, stakeLevel);
        return copyBrainstormResult(result);
    }

    void brainstorm_set_search_thread_mode(int mode) {
        // 0 keeps the responsiveness-oriented automatic heuristic; 1 uses
        // the benchmarked maximum-throughput worker count. Environment-based
        // profiling overrides remain authoritative in getBrainstormSearchThreads().
        BRAINSTORM_SEARCH_THREAD_MODE.store(
            mode == 1 ? 1 : 0, std::memory_order_relaxed);
    }

    void free_result(const char* result) {
        free((void*)result);
    }
}
