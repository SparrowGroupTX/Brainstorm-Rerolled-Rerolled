#include "immolate.hpp"
#include "functions.hpp"
#include <cstdlib>
#include <iostream>
#include <string>

namespace {
int checks=0;
void check(bool condition,const char* message) {
    if (!condition) { std::cerr << "FAIL: " << message << '\n'; std::exit(1); }
    ++checks;
}
void env(const char* key,const char* value) {
#ifdef _WIN32
    _putenv_s(key,value);
#else
    setenv(key,value,1);
#endif
}
bool contains(const std::string& text,const std::string& part) {
    return text.find(part)!=std::string::npos;
}
std::string call(const char* seed,const char* challenge,const char* targets="") {
    const char* raw=brainstorm_challenge_opening_v1(seed,challenge,targets);
    check(raw!=nullptr,"C endpoint returns an owned result");
    std::string result(raw); free_result(raw); return result;
}
std::string normal(const char* deck="Red Deck") {
    return brainstorm_v3_cpp("KLF2111","Telescope","","Charm Tag",1,
        false,false,false,false,false,false,"No Filter","King","Any Suit",0,0,"Perkeo",deck);
}
std::string later(const char* challenge="c_omelette_1",const char* target="j_duo",
                  int deadline=8,const char* mask="11111111111111111111") {
    const char* raw=brainstorm_challenge_opening_v2("I1L21111",challenge,"j_yorick,j_perkeo",target,deadline,mask);
    check(raw!=nullptr,"later C endpoint returns owned allocation");
    std::string result(raw); free_result(raw); return result;
}
}
int main() {
    env("BRAINSTORM_THREADS","1"); env("BRAINSTORM_SEARCH_LIMIT","1");
    env("BRAINSTORM_PRINT_DELAY","0"); env("BRAINSTORM_OPENING_BATCH_BACKEND","scalar");
    check(normal()=="KLF2111","legacy normal-deck opening remains available before challenge calls");

    // Existing native multi-Soul fixture, now evaluated with an explicit
    // challenge identity. The independent full Arcana scanner is the oracle.
    Seed seed("I1L21111"); Instance source(seed);
    source.setDeck(Item::Challenge_Deck); source.initLocks(1,false,true);
    check(source.nextTag(1)==Item::Charm_Tag,"fixture starts with Small Blind Charm");
    const auto pack=source.scanArcanaPackForSoulJokers(5,1,true);
    check(pack.soulCount==2 && pack.soulJokers.size()==2,"full pack oracle has two natural Soul rolls");
    check(pack.soulJokers[0].joker==Item::Yorick && pack.soulJokers[1].joker==Item::Perkeo,
        "full pack oracle reports Yorick then Perkeo");
    Seed vanillaSeed("I1L21111"); Instance vanilla(vanillaSeed);
    const auto vanillaPack=vanilla.scanArcanaPackForSoulJokers(5,1,false);
    check(vanillaPack.soulCount==1,"vanilla duplicate suppression would allow only one Soul");

    const char* ids[]={"c_omelette_1","c_city_1","c_rich_1","c_knife_1","c_xray_1",
        "c_mad_world_1","c_luxury_1","c_non_perishable_1","c_medusa_1","c_double_nothing_1",
        "c_typecast_1","c_inflation_1","c_bram_poker_1","c_fragile_1","c_monolith_1",
        "c_blast_off_1","c_five_card_1","c_golden_needle_1","c_cruelty_1"};
    for (const char* id : ids) {
        const auto result=call("I1L21111",id);
        check(contains(result,"\"status\":\"found\"") && contains(result,"\"seed\":\"I1L21111\""),
            "every compatible vanilla challenge accepts the exact opening fixture");
        check(contains(result,std::string("\"challenge_id\":\"")+id+"\""),"result preserves exact challenge identity");
        check(contains(result,"\"legendary_jokers\":[\"j_yorick\",\"j_perkeo\"]"),"ordered Legendary metadata matches full scanner");
    }
    const auto omelette=call("I1L21111","c_omelette_1");
    check(contains(omelette,"\"required_sales\":2") && contains(omelette,"\"starting_joker_count\":5"),
        "Omelette exposes two necessary legal Egg sales instead of promising free capacity");
    check(contains(call("I1L21111","c_blast_off_1"),"\"starting_joker_limit\":4"),"Blast Off retains its four-slot limit");
    check(contains(call("I1L21111","c_fragile_1"),"\"starting_joker_limit\":7"),"Fragile includes both Negative starting slots");
    check(contains(call("I1L21111","c_omelette_1","Perkeo,Yorick"),"\"status\":\"found\""),"target pair is unordered across the two actual Soul uses");
    check(call("I1L21111","c_omelette_1"," j_perkeo, j_yorick ")==call("I1L21111","c_omelette_1","Yorick,Perkeo"),
        "native names and vanilla keys produce identical deterministic metadata");
    check(contains(call("I1L21111","c_omelette_1","Yorick"),"\"status\":\"found\""),"one desired Legendary may occupy either choice");
    check(contains(call("I1L21111","c_omelette_1","Chicot"),"\"status\":\"not_found\""),"incorrect desired Legendary rejects the known seed");
    for (const char* bad : {"Yorick,Yorick","j_yorick,Yorick","Chicot,Perkeo,Yorick","Joker","","modded"}) {
        if (*bad) check(contains(call("I1L21111","c_omelette_1",bad),"\"status\":\"invalid\""),"invalid target requirements fail closed");
    }
    for (const char* bad : {"Yorick,",",Yorick","Yorick,,Perkeo"})
        check(contains(call("I1L21111","c_omelette_1",bad),"\"status\":\"invalid\""),"empty CSV target entries fail closed");
    for (const char* bad : {"c_jokerless_1","c_modded_1","Challenge Deck","","c_omelette_1\""})
        check(contains(call("I1L21111",bad),"\"status\":\"invalid\""),"incompatible and unknown challenges cannot use a default deck");
    for (const char* bad : {"123456789","0","lower","\xff"})
        check(contains(call(bad,"c_omelette_1"),"\"status\":\"invalid\""),"malformed seeds cannot overflow native Seed storage");
    const auto miss=call("KLF2111","c_omelette_1");
    Seed start("KLF2111"),next(normalizeSeedId(start.getID()+1));
    check(contains(miss,"\"status\":\"not_found\"") && !contains(miss,"\"seed\":"),"one-Soul opening returns no matched seed");
    check(contains(miss,"\"next_seed\":\""+next.tostring()+"\""),"exhausted bounded batch returns its exact resume position");
    check(contains(miss,"\"search_limit\":1"),"test batch respects the lower search limit");
    env("BRAINSTORM_OPENING_BATCH_BACKEND","auto");
    check(call("I1L21111","c_omelette_1")==omelette,"automatic SIMD dispatcher agrees with scalar challenge search");

    // Starting inventory/restrictions change ordinary Tarots, not the separate
    // Soul and Legendary nodes. Explicitly exercise Bram Poker and Fragile.
    for (bool fragile : {false,true}) {
        Seed testSeed("I1L21111"); Instance limited(testSeed);
        limited.setDeck(Item::Challenge_Deck); limited.initLocks(1,false,true);
        limited.lock(Item::The_Empress); limited.lock(Item::The_Emperor);
        if (fragile) { limited.lock(Item::Standard_Tag); limited.lock(Item::The_Magician); limited.params.sixesFactor=4; }
        check(limited.nextTag(1)==Item::Charm_Tag,"applicable challenge tag bans preserve this first Charm");
        const auto limitedPack=limited.scanArcanaPackForSoulJokers(5,1,true);
        check(limitedPack.soulCount==2 && limitedPack.soulJokers[0].joker==Item::Yorick && limitedPack.soulJokers[1].joker==Item::Perkeo,
            "starting ordinary consumables and Tarot bans do not alter the guaranteed Soul outcomes");
    }
    env("BRAINSTORM_SEARCH_LIMIT","999999999");
    check(contains(call("I1L21111","c_omelette_1"),"\"search_limit\":1000000"),"new endpoint hard-caps a caller's huge search limit");
    env("BRAINSTORM_SEARCH_LIMIT","1");
    check(normal()=="KLF2111","challenge endpoint leaves normal query state and results unchanged");
    check(normal("Challenge Deck").empty(),"general native API still rejects unsupported challenge simulation");
    const auto duo=later();
    check(contains(duo,"\"status\":\"found\"") && contains(duo,"\"later_found_ante\":5") &&
          contains(duo,"\"later_shop\":2") && contains(duo,"\"later_slot\":1"),
          "conditional known Rare offer has precise post-Small Ante5 location");
    check(contains(duo,"\"later_retention\":\"not_verified\"") &&
          contains(duo,"\"later_offer_status\":\"conditional\""),"offer never claims acquisition or retention");
    check(contains(later("c_omelette_1","j_duo",4),"\"status\":\"not_found\""),"deadline excludes later offered target");
    check(contains(later("c_omelette_1","j_blueprint"),"\"status\":\"not_found\""),"opening alone cannot satisfy later target");
    check(contains(later("c_omelette_1","j_blueprint",8,"00000001000000000000"),"\"status\":\"found\""),
          "unavailable Rare positions trigger source-style resampling rather than compacting the pool");
    for (const char* mask:{"","111","1111111111111111111x","111111111111111111111","00000000000000000000"})
        check(contains(later("c_omelette_1","j_duo",8,mask),"\"status\":\"invalid\""),"malformed or unavailable live profile fails closed");
    for (const char* key:{"j_perkeo","j_joker","Blueprint","j_blueprint,j_brainstorm","modded"})
        check(contains(later("c_omelette_1",key),"\"status\":\"invalid\""),"later target must be one declared Rare center key");
    for (int ante:{-1,0,1,9,999}) check(contains(later("c_omelette_1","j_duo",ante),"\"status\":\"invalid\""),"unsupported deadline rejected");
    check(contains(later("c_bram_poker_1"),"\"status\":\"invalid\""),"Bram's no-shop-Joker restriction is explicit");
    check(contains(later("c_jokerless_1"),"\"status\":\"invalid\""),"Jokerless remains excluded");
    check(contains(later("c_monolith_1"),"\"status\":\"invalid\""),"owned Obelisk must be unavailable");
    check(contains(later("c_non_perishable_1"),"\"status\":\"invalid\""),"banned Invisible must be unavailable");
    check(contains(later("c_non_perishable_1","j_duo",8,"11111111111111110111"),"\"later_eternal\":true"),"all-Eternal challenge offer sticker remains explicit");
    check(contains(later("c_typecast_1"),"\"status\":\"not_found\""),"Typecast rejects post-Ante4 capacity collapse even when requested deadline is eight");
    check(contains(later("c_blast_off_1"),"\"status\":\"not_found\""),"full Eternal BlastOff row cannot add positive target while retaining pair");
    check(call("I1L21111","c_omelette_1")==omelette,"later endpoint preserves byte-for-byte v1 result/state");
    std::cout << "challenge_opening_regression: " << checks << " checks passed\n";
}
