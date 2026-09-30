-- Generation-only source parity probe. Original start_run has already applied
-- the challenge's real inventory, deck, vouchers and banned_keys. No blind is
-- played, policy run, user save accessed, or rendering/window called.
Brainstorm=Brainstorm or {}
Brainstorm.ChallengeOpening=require('probe_challenge_opening')
assert(loadstring(PROBE_CHARM_HOOK,'@current_multisoul_hook'))()
local function pump(frames)
    for i=1,frames do
        for _,key in ipairs({'REAL','TOTAL','UPTIME'}) do G.TIMERS[key]=G.TIMERS[key]+1/60 end
        G.real_dt=1/60
        G.E_MANAGER:update(1/60)
        for _,area in ipairs(G.I.CARDAREA) do area:update(1/60);area:align_cards() end
    end
end
local challenge=G.GAME.challenge
assert(challenge==PROBE_CHALLENGE,'Source lost the requested challenge identity')
local small=G.GAME.round_resets.blind_tags.Small
local original_owned=#G.jokers.cards
local original_limit=G.jokers.config.card_limit
-- These two UI bookkeeping fields are ordinarily completed by
-- Game:update_blind_select and create_UIBox_blind_select. The headless adapter
-- omits that display surface; all challenge/rule/resource fields are untouched.
assert(G.STATE==G.STATES.BLIND_SELECT and G.GAME.round==0 and G.GAME.round_resets.ante==1)
G.STATE_COMPLETE=true; G.GAME.blind_on_deck='Small'
local valid,reason=Brainstorm.ChallengeOpening.validate(G,{enabled=true,targets={'',''}})
assert(valid==(challenge~='c_jokerless_1'),'Opening validation disagrees with actual challenge start: '..tostring(reason))
local parsed,error_text=Brainstorm.ChallengeOpening.result(PROBE_NATIVE_JSON,challenge,'')
assert((parsed~=nil)==(challenge~='c_jokerless_1'),'Actual Lua transport rejected native result: '..tostring(error_text))
if parsed then
    assert(parsed.starting_joker_count==original_owned and parsed.starting_joker_limit==original_limit,
        'Native capacity metadata disagrees with original challenge initialization')
end
G.GAME.used_filter=PROBE_MULTI_SOUL
G.GAME.filter_info={challenge_opening=true,challenge_id=challenge,
    required_soul_count=2,soul_count=2,multi_soul_pack_consumed=false}
-- The source skip callback's post-Small state, before generating the Charm
-- pack. This probe does not construct tag UI or run its pack animation.
G.GAME.round_resets.blind_states.Small='Skipped'
G.GAME.round_resets.blind_states.Big='Select'
G.GAME.blind_on_deck='Big'; G.GAME.skips=1
-- Pack display is irrelevant here; actual Card constructors and source
-- create_card/get_current_pool/RNG run with the actual original CardArea.
G.pack_cards=CardArea(0,0,5*G.CARD_W,G.CARD_H,{card_limit=5,type='consumeable'})
G.STATE=G.STATES.TAROT_PACK
local pack={from_tag=true,config={center_key='p_arcana_mega_1'}}
local souls,keys={},{}
for i=1,5 do
    local card=Brainstorm.createCharmArcanaCard(pack,'Tarot',G.pack_cards,nil,nil,true,true,nil,'ar1')
    G.pack_cards:emplace(card)
    keys[#keys+1]=card.config.center.key
    assert(not G.GAME.banned_keys[card.config.center.key],'Source generated a banned pack card')
    if card.config.center.key=='c_soul' then souls[#souls+1]=card end
end
if PROBE_MULTI_SOUL then assert(G.pack_cards.brainstorm_challenge_opening,'Opening pack was not marked for tactical advice') end
local sold=0
local initial_usable=#souls>0 and souls[1]:can_use_consumeable(true,true) or false
if challenge=='c_omelette_1' and PROBE_MULTI_SOUL then
    assert(not initial_usable,'Full Omelette row must block Soul before selling')
    for i=1,2 do
        local egg=G.jokers.cards[1]
        assert(egg.config.center.key=='j_egg' and not egg.ability.eternal,'Only sell ordinary initial Eggs')
        egg:sell_card(); pump(180); sold=sold+1
    end
    assert(#G.jokers.cards==3,'Original Egg sales did not free both slots')
end
local jokers={}
if challenge~='c_jokerless_1' and PROBE_MULTI_SOUL then
    assert(small=='tag_charm','Source first Small Blind tag must be Charm')
    assert(#souls==2,'Source first Charm pack must contain two natural Soul rolls')
    for i=1,2 do
        local soul=souls[i]
        assert(soul:can_use_consumeable(true,true),'Original Soul capacity check failed')
        local before=#G.jokers.cards
        soul:use_consumeable(G.pack_cards); pump(180)
        assert(#G.jokers.cards==before+1,'Original Soul use did not add exactly one Joker')
        jokers[i]=G.jokers.cards[#G.jokers.cards].config.center.key
    end
    assert(jokers[1]=='j_yorick' and jokers[2]=='j_perkeo','Source ordered Legendary outcomes differ from native fixture')
elseif challenge=='c_jokerless_1' then
    assert(G.GAME.banned_keys.c_soul and #souls==0 and original_limit==0,'Jokerless restriction was not preserved')
else
    assert(#souls==1,'Without the authorized exception vanilla must suppress the second Soul')
end
print('SOURCE_CHALLENGE_OPENING '..challenge..' '..small..' souls='..#souls..' slots='..original_limit..
    ' owned='..original_owned..' sales='..sold..' cards='..table.concat(keys,',')..' jokers='..table.concat(jokers,','))
PROBE_OPENING_RESULT={challenge=challenge,small=small,souls=#souls,limit=original_limit,
    owned=original_owned,sales=sold,pack=keys,jokers=jokers,exception=PROBE_MULTI_SOUL}
PROBE_OPENING_RESULT_TEXT=STR_PACK(PROBE_OPENING_RESULT)
