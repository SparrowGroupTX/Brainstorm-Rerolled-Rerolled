#include "immolate.hpp"
#include "functions.hpp"
#include "opening_batch.hpp"
#include "search.hpp"

#include <array>
#include <cstring>
#include <sstream>
#include <string_view>

namespace {
// This is an opening-route contract for the unmodified vanilla challenges,
// not a simulation of their decks, shops or later rounds. Lua also checks the
// actual challenge definition before requesting this endpoint.
struct ChallengeOpeningProfile {
    const char* id;
    int slots; // Includes Negative starting Jokers' extra slots.
    int owned;
    int requiredSales;
    bool bansStandardTag = false;
    int protectedStarting = 0;
    int acquisitionThrough = 8;
};
constexpr std::array<ChallengeOpeningProfile, 19> profiles{{
    {"c_omelette_1",5,5,2}, {"c_city_1",5,2,0,false,2},
    {"c_rich_1",5,0,0}, {"c_knife_1",5,1,0,false,1},
    {"c_xray_1",5,0,0}, {"c_mad_world_1",6,2,0,false,2},
    {"c_luxury_1",5,0,0}, {"c_non_perishable_1",5,0,0},
    {"c_medusa_1",5,1,0,false,1}, {"c_double_nothing_1",5,0,0},
    {"c_typecast_1",5,0,0,false,0,4}, {"c_inflation_1",5,1,0},
    {"c_bram_poker_1",5,1,0,false,1}, {"c_fragile_1",7,2,0,true,2},
    {"c_monolith_1",6,2,0,false,2}, {"c_blast_off_1",4,2,0,false,2},
    {"c_five_card_1",7,2,0}, {"c_golden_needle_1",5,1,0},
    {"c_cruelty_1",3,0,0}
}};
const ChallengeOpeningProfile* profileFor(std::string_view id) {
    for (const auto& profile : profiles) if (id==profile.id) return &profile;
    // Jokerless bans The Soul and has zero slots; unknown/modded IDs fail closed.
    return nullptr;
}
const char* jokerKey(Item item) {
    switch (item) {
        case Item::Canio: return "j_caino";
        case Item::Triboulet: return "j_triboulet";
        case Item::Yorick: return "j_yorick";
        case Item::Chicot: return "j_chicot";
        case Item::Perkeo: return "j_perkeo";
        default: return "";
    }
}
// The source's complete ordered Rare pool has no enhancement/death gates.
// A live profile mask preserves UNAVAILABLE positions rather than compacting
// that pool. Common/Uncommon identities have separate keyed RNG streams.
constexpr std::array<const char*,20> rareKeys{{
    "j_dna","j_vagabond","j_baron","j_obelisk","j_baseball",
    "j_ancient","j_campfire","j_blueprint","j_wee","j_hit_the_road",
    "j_duo","j_trio","j_family","j_order","j_tribe","j_stuntman",
    "j_invisible","j_brainstorm","j_drivers_license","j_burnt"
}};
const char* editionKey(Item edition) {
    switch (edition) {
        case Item::Foil: return "foil";
        case Item::Holographic: return "holo";
        case Item::Polychrome: return "polychrome";
        case Item::Negative: return "negative";
        default: return "base";
    }
}
std::string_view trim(std::string_view text) {
    const auto first=text.find_first_not_of(" \t\r\n");
    if (first==std::string_view::npos) return {};
    const auto last=text.find_last_not_of(" \t\r\n");
    return text.substr(first,last-first+1);
}
bool parseTargets(std::string_view text,std::vector<Item>& targets) {
    text=trim(text);
    if (text.empty()) return true;
    for (;;) {
        const auto comma=text.find(',');
        const auto token=trim(text.substr(0,comma));
        Item target=Item::RETRY;
        for (Item item : LEGENDARY_JOKERS) {
            if (token==jokerKey(item) || token==itemToString(item)) target=item;
        }
        if (target==Item::RETRY || targets.size()>=2 ||
            std::find(targets.begin(),targets.end(),target)!=targets.end()) return false;
        targets.push_back(target);
        if (comma==std::string_view::npos) return true;
        text=text.substr(comma+1);
    }
}
bool validSeed(std::string_view seed) {
    if (seed.size()>8) return false;
    for (char c : seed) if (seedChars.find(c)==std::string::npos) return false;
    return true;
}
struct OpeningResult {
    int souls=0;
    std::array<Item,2> jokers{Item::RETRY,Item::RETRY};
    int laterAnte=0, laterShop=0, laterSlot=0;
    Item laterEdition=Item::No_Edition;
    int negativeLegendaries=0;
};

bool nextRareOffer(Instance& instance,int ante,JokerData& joker) {
    const auto& a=anteToString(ante);
    auto shop=instance.getShopInstance();
    if (shopItemType(shop,instance.random(RandomType::Card_Type+a)*shop.getTotalRate())!=Item::T_Joker)
        return false;
    const double rarity=instance.random(RandomType::Joker_Rarity+a+ItemSource::Shop);
    // Every Joker, including unobserved Commons/Uncommons, advances this shared
    // shop edition node. Other generation sources use different node keys.
    const double edition=instance.random(RandomType::Joker_Edition+ItemSource::Shop+a);
    if (rarity<=0.95) return false;
    const auto node=RandomType::Joker_Rare+ItemSource::Shop+a;
    const bool available=std::any_of(RARE_JOKERS.begin(),RARE_JOKERS.end(),
        [&](Item item){return !instance.isLocked(item);});
    if (!available) {
        // Original get_current_pool uses singleton j_joker when no Rare is
        // eligible (e.g. the sole unlocked Rare is already in shop slot1).
        // Consume that main node once, without bogus resample-node advances.
        instance.random(node);
        return false;
    }
    joker.joker=instance.randchoice(node,RARE_JOKERS);
    joker.edition=edition>0.997?Item::Negative:edition>0.994?Item::Polychrome:
        edition>0.98?Item::Holographic:edition>0.96?Item::Foil:Item::No_Edition;
    return true;
}
struct OpeningQuery {
    const ChallengeOpeningProfile* profile;
    std::vector<Item> targets;
    int laterTarget=-1, deadline=0;
    std::string rareMask;
};

bool evaluateLater(Instance& instance,const OpeningQuery& query,OpeningResult& result) {
    for (std::size_t i=0;i<RARE_JOKERS.size();++i) {
        if (query.rareMask[i]=='0') instance.lock(RARE_JOKERS[i]);
        else instance.unlock(RARE_JOKERS[i]);
    }
    if (std::string_view(query.profile->id)=="c_blast_off_1")
        instance.activateVoucher(Item::Planet_Tycoon);
    // The first skipped Small has no shop. Big's shop is Ante1; the Boss
    // increases the ante before its shop, so Ante2 onward has three shops.
    // Packs/vouchers use independent streams and are not opened/purchased.
    // Common/Uncommon shop buys/sales (except Showman) do not change Rare
    // pools, shop rates or slot count and are permitted by this route.
    for (int ante=1;ante<=std::min(query.deadline,query.profile->acquisitionThrough);++ante) {
        for (int shop=1;shop<=(ante==1?1:3);++shop) {
            std::array<Item,2> visible{Item::RETRY,Item::RETRY};
            for (int slot=1;slot<=2;++slot) {
                JokerData joker;
                if (!nextRareOffer(instance,ante,joker)) continue;
                visible[slot-1]=joker.joker;
                instance.lockTransient(joker.joker);
                const int capacity=query.profile->slots+result.negativeLegendaries+(joker.edition==Item::Negative?1:0);
                if (joker.joker==RARE_JOKERS[query.laterTarget] &&
                    query.profile->protectedStarting+2<capacity) {
                    result.laterAnte=ante; result.laterShop=shop;
                    result.laterSlot=slot; result.laterEdition=joker.edition;
                    return true;
                }
            }
            for (Item item:visible) if (item!=Item::RETRY) instance.unlockTransient(item);
        }
    }
    return false;
}

bool evaluateOpening(Seed& seed,const OpeningQuery& query,OpeningResult& result) {
    Instance instance(seed);
    instance.setDeck(Item::Challenge_Deck); // Never masquerade as a normal deck.
    instance.setStake(Item::White_Stake);
    instance.initLocks(1,false,true);
    if (query.profile->bansStandardTag) instance.lock(Item::Standard_Tag);
    if (instance.nextTag(1)!=Item::Charm_Tag) return false;

    // common_events.lua:2088-2093: each eligible Arcana slot polls soul_Tarot1.
    // The existing first-Charm multi-Soul exception removes only its duplicate
    // guard. Ordinary Tarot bans/owned cards affect Tarot_ar1, never this node.
    // None of the nineteen profiles starts with Omen Globe, Showman, a Soul,
    // or a Legendary; none bans a Legendary. Fragile's Oops probability boost
    // does not enter this fixed >0.997 Soul check.
    for (int i=0;i<5;++i) {
        if (instance.random(RandomType::Soul+RandomType::Tarot+anteToString(1))>0.997) ++result.souls;
    }
    if (result.souls<2 || query.profile->slots-query.profile->owned+query.profile->requiredSales<2) return false;
    // Exactly two pack choices. Lock the first owned Legendary before drawing
    // the second, matching vanilla get_current_pool's used_jokers exclusion.
    for (int i=0;i<2;++i) {
        const auto legendary=instance.nextJoker(ItemSource::Soul,1,false);
        result.jokers[i]=legendary.joker;
        if (legendary.edition==Item::Negative) ++result.negativeLegendaries;
        instance.lock(result.jokers[i]);
    }
    if (result.jokers[0]==result.jokers[1]) return false;
    for (Item target : query.targets) {
        if (target!=result.jokers[0] && target!=result.jokers[1]) return false;
    }
    return query.laterTarget<0 || evaluateLater(instance,query,result);
}

// Only this new API uses this context. The mutex spans the joined search;
// normal search/filter globals and normal APIs are never read or changed.
std::mutex openingMutex;
const OpeningQuery* activeQuery=nullptr;
long openingFilter(Seed& seed) {
    OpeningResult result;
    return activeQuery && evaluateOpening(seed,*activeQuery,result) ? 1 : 0;
}
std::string searchOpening(const std::string& seed,const std::string& challenge,
                          const std::string& targetText,const std::string& laterKey="",
                          int deadline=0,const std::string& rareMask="",bool later=false) {
    const auto* profile=profileFor(challenge);
    if (!profile) return R"({"status":"invalid","reason":"Unsupported challenge or Jokerless."})";
    if (!validSeed(seed)) return R"({"status":"invalid","reason":"Seed must have at most eight characters from 1-9 and A-Z."})";
    OpeningQuery query{profile,{},-1,0,{}};
    if (!parseTargets(targetText,query.targets)) return R"({"status":"invalid","reason":"Choose zero to two distinct vanilla Legendary Jokers."})";
    if (later) {
        if (challenge=="c_bram_poker_1") return R"({"status":"invalid","reason":"Bram Poker has no shop Joker offers; use the opening-only route."})";
        if (deadline<2 || deadline>8) return R"({"status":"invalid","reason":"Later deadline must be Ante 2 through 8."})";
        if (rareMask.size()!=rareKeys.size() || rareMask.find_first_not_of("01")!=std::string::npos)
            return R"({"status":"invalid","reason":"A verified live twenty-position Rare pool mask is required."})";
        for (std::size_t i=0;i<rareKeys.size();++i) if (laterKey==rareKeys[i]) query.laterTarget=static_cast<int>(i);
        if (query.laterTarget<0 || rareMask[query.laterTarget]!='1')
            return R"({"status":"invalid","reason":"Choose an available vanilla Rare later target."})";
        if ((challenge=="c_monolith_1" && rareMask[3]!='0') ||
            (challenge=="c_non_perishable_1" && rareMask[16]!='0'))
            return R"({"status":"invalid","reason":"Live Rare pool conflicts with the original challenge restrictions."})";
        query.deadline=deadline; query.rareMask=rareMask;
    }
    std::lock_guard<std::mutex> guard(openingMutex);
    activeQuery=&query;
    struct Reset { ~Reset() { activeQuery=nullptr; } } reset;
    const long long limit=std::clamp(getBrainstormSearchLimit(),1LL,1000000LL);
    SeedSearch search(openingFilter,seed,getBrainstormSearchThreads(),limit);
    OpeningCharmSoulCriteria criteria; criteria.minimumSoulCount=2;
    // Every supported profile has the vanilla first-Ante tag pool: the only
    // extra banned tag is Fragile's Standard, already excluded until Ante 2.
    // Both scalar and SIMD gates therefore remain exact for this allowlist.
    search.batchPrefilter={createOpeningCharmSoulBatchContext,
        destroyOpeningCharmSoulBatchContext,collectOpeningCharmSoulCandidatesWithContext,
        encodeOpeningCharmSoulCriteria(criteria)};
    search.exitOnFind=true; search.printDelay=0;
    const std::string found=search.search();
    std::ostringstream out;
    out << "{\"status\":\"" << (found.empty()?"not_found":"found")
        << "\",\"challenge_id\":\"" << profile->id
        << "\",\"first_tag\":\"tag_charm\",\"multi_soul_exception\":true"
        << ",\"required_sales\":" << profile->requiredSales
        << ",\"starting_joker_count\":" << profile->owned
        << ",\"starting_joker_limit\":" << profile->slots
        << ",\"search_limit\":" << limit;
    if (later) {
        out << ",\"api_version\":2,\"later_target\":\"" << laterKey
            << "\",\"later_deadline\":" << deadline << ",\"later_pool_mask\":\"" << rareMask
            << "\",\"later_source\":\"shop_initial\",\"later_schedule\":\"first_charm_then_play_all_fixed_rare_pool\""
            << ",\"later_offer_status\":\"conditional\",\"later_retention\":\"not_verified\"";
    }
    if (!found.empty()) {
        Seed matched(found); OpeningResult result;
        if (!evaluateOpening(matched,query,result)) return R"({"status":"error","reason":"Opening revalidation failed."})";
        out << ",\"seed\":\"" << found << "\",\"soul_count\":" << result.souls
            << ",\"legendary_jokers\":[\"" << jokerKey(result.jokers[0])
            << "\",\"" << jokerKey(result.jokers[1]) << "\"]";
        if (later) out << ",\"later_found_ante\":" << result.laterAnte
            << ",\"later_shop\":" << result.laterShop << ",\"later_slot\":" << result.laterSlot
            << ",\"later_edition\":\"" << editionKey(result.laterEdition) << "\""
            << ",\"later_eternal\":" << (challenge=="c_non_perishable_1"?"true":"false");
    } else {
        Seed starting(seed),next(normalizeSeedId(starting.getID()+limit));
        out << ",\"next_seed\":\"" << next.tostring() << '"';
    }
    out << '}';
    return out.str();
}
}

extern "C" IMMOLATE_API const char* brainstorm_challenge_opening_v2(
    const char* seed,const char* challenge_id,const char* targetJokersCSV,
    const char* laterJokerKey,int deadlineAnte,const char* rarePoolMask) {
    std::string result;
    try {
        result=searchOpening(seed?seed:"",challenge_id?challenge_id:"",targetJokersCSV?targetJokersCSV:"",
            laterJokerKey?laterJokerKey:"",deadlineAnte,rarePoolMask?rarePoolMask:"",true);
    } catch (...) {
        result=R"({"status":"error","reason":"Conditional later-offer search failed."})";
    }
    char* copy=static_cast<char*>(std::malloc(result.size()+1));
    if (copy) std::memcpy(copy,result.c_str(),result.size()+1);
    return copy;
}

extern "C" IMMOLATE_API const char* brainstorm_challenge_opening_v1(
    const char* seed,const char* challenge_id,const char* targetJokersCSV) {
    std::string result;
    try {
        result=searchOpening(seed?seed:"",challenge_id?challenge_id:"",targetJokersCSV?targetJokersCSV:"");
    } catch (...) {
        result=R"({"status":"error","reason":"Opening search failed."})";
    }
    char* copy=static_cast<char*>(std::malloc(result.size()+1));
    if (copy) std::memcpy(copy,result.c_str(),result.size()+1);
    return copy; // Same allocation contract as free_result.
}
