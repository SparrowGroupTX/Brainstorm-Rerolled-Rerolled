-- Original-source generation only. The independently recorded synthetic profile
-- is a mechanics fixture, never a user profile or a played/qualified seed run.
local keys={'j_dna','j_vagabond','j_baron','j_obelisk','j_baseball','j_ancient','j_campfire','j_blueprint',
 'j_wee','j_hit_the_road','j_duo','j_trio','j_family','j_order','j_tribe','j_stuntman','j_invisible',
 'j_brainstorm','j_drivers_license','j_burnt'}
local function pump(n)
 for i=1,n do
  for _,key in ipairs({'REAL','TOTAL','UPTIME'}) do G.TIMERS[key]=G.TIMERS[key]+1/60 end
  G.real_dt=1/60;G.E_MANAGER:update(1/60)
  for _,a in ipairs(G.I.CARDAREA) do a:update(1/60);a:align_cards() end
 end
end
assert(G.GAME.challenge==PROBE_CHALLENGE)
assert(#G.P_JOKER_RARITY_POOLS[3]==20)
for i,key in ipairs(keys) do
 local c=G.P_JOKER_RARITY_POOLS[3][i]
 assert(c.key==key and not c.enhancement_gate and not c.no_pool_flag and not c.yes_pool_flag)
 if PROBE_LIMITED and i~=8 then c.unlocked=false end
end
Brainstorm={}
assert(loadstring(PROBE_CHARM_HOOK))()
G.GAME.used_filter=true
G.GAME.filter_info={challenge_opening=true,challenge_id=PROBE_CHALLENGE,required_soul_count=2,
 multi_soul_pack_consumed=false}
G.pack_cards=CardArea(0,0,5*G.CARD_W,G.CARD_H,{card_limit=5,type='consumeable'})
G.STATE=G.STATES.TAROT_PACK
local souls={};local pack={from_tag=true,config={center_key='p_arcana_mega_1'}}
for i=1,5 do
 local c=Brainstorm.createCharmArcanaCard(pack,'Tarot',G.pack_cards,nil,nil,true,true,nil,'ar1')
 G.pack_cards:emplace(c);if c.config.center.key=='c_soul' then souls[#souls+1]=c end
end
assert(G.GAME.round_resets.blind_tags.Small=='tag_charm' and #souls==2)
if PROBE_CHALLENGE=='c_omelette_1' then
 for i=1,2 do G.jokers.cards[1]:sell_card();pump(180) end
end
for i=1,2 do
 assert(souls[i]:can_use_consumeable(true,true));souls[i]:use_consumeable(G.pack_cards);pump(180)
end
local protected=0
for _,j in ipairs(G.jokers.cards) do
 if j.ability.eternal or j.config.center.rarity==4 then protected=protected+1 end
end
PROBE_CAPACITY_TEXT=protected..'|'..G.jokers.config.card_limit..'|'..(G.GAME.modifiers.set_joker_slots_ante or 8)
local mask={}
for i,key in ipairs(keys) do
 mask[i]=(G.P_CENTERS[key].unlocked~=false and not G.GAME.banned_keys[key] and not G.GAME.used_jokers[key]) and '1' or '0'
end
local rates={G.GAME.joker_rate,G.GAME.tarot_rate,G.GAME.planet_rate,G.GAME.playing_card_rate,G.GAME.spectral_rate or 0}
assert(rates[1]==20 and rates[2]==4 and rates[3]==(PROBE_CHALLENGE=='c_blast_off_1' and 32 or 4) and rates[4]==0 and rates[5]==0)
assert(G.GAME.shop.joker_max==2)
G.pack_cards:remove();G.pack_cards=nil
G.shop_jokers=CardArea(0,0,5*G.CARD_W,G.CARD_H,{card_limit=2,type='shop'})
-- This isolated original function is extracted verbatim; only its price/UI
-- rendering function is replaced. Original Card constructors/RNG are intact.
assert(loadstring(PROBE_CREATE_SHOP))()
create_shop_card_ui=function() end
G.STATE=G.STATES.SHOP
local rows={};local trades=0
G.GAME.dollars=1000 -- A declared resource fixture to exercise actual buy/sell callbacks.
for ante=1,8 do
 G.GAME.round_resets.ante=ante
 for shop=1,(ante==1 and 1 or 3) do
  for slot=1,2 do
   local c=assert(create_card_for_shop(G.shop_jokers));G.shop_jokers:emplace(c)
   if c.config.center.set=='Joker' and c.config.center.rarity==3 then
    local edition=c.edition and (c.edition.negative and 'negative' or c.edition.polychrome and 'polychrome' or c.edition.holo and 'holo' or c.edition.foil and 'foil') or 'base'
    rows[#rows+1]=table.concat({ante,shop,slot,c.config.center.key,edition,tostring(c.ability.eternal==true)},'|')
   end
  end
  if PROBE_TRADE then
   for _,c in ipairs(G.shop_jokers.cards) do
    if c.config.center.set=='Joker' and c.config.center.rarity<3 and c.config.center.key~='j_ring_master' and
       not c.ability.eternal and #G.jokers.cards<G.jokers.config.card_limit then
     local before=#G.jokers.cards
     G.FUNCS.buy_from_shop({config={ref_table=c}});pump(180)
     assert(#G.jokers.cards==before+1,'original purchase failed')
     c:sell_card();pump(180);assert(#G.jokers.cards==before,'original sale failed')
     trades=trades+1;break
    end
   end
  end
  while #G.shop_jokers.cards>0 do G.shop_jokers.cards[1]:remove() end
 end
end
if PROBE_TRADE then assert(trades>0,'trade fixture did not exercise a buy/sell') end
PROBE_LATER_TEXT=table.concat(mask)..'\n'..table.concat(rows,'\n')
PROBE_LATER_TRADES=tostring(trades)
print('SOURCE_LATER_GENERATION '..PROBE_CHALLENGE..' mask='..table.concat(mask)..' rare_offers='..#rows..' trades='..trades)
if PROBE_RIFF then
 local before=copy_table(G.GAME.pseudorandom)
 local rare_before=copy_table(G.GAME.used_jokers)
 local riff=Card(0,0,G.CARD_W,G.CARD_H,G.P_CARDS.empty,G.P_CENTERS.j_riff_raff,{bypass_discovery_center=true})
 riff:add_to_deck();G.jokers:emplace(riff)
 local count=#G.jokers.cards
 riff:calculate_joker({setting_blind=true});pump(300)
 assert(#G.jokers.cards>count,'actual Riff-Raff fixture generated no Joker')
 for _,node in ipairs({'cdt8','rarity8sho','Joker3sho8','edisho8'}) do
  assert(G.GAME.pseudorandom[node]==before[node],'Riff-Raff changed shop node '..node)
 end
 for _,key in ipairs(keys) do assert(G.GAME.used_jokers[key]==rare_before[key],'Riff-Raff changed Rare eligibility') end
 assert(G.GAME.pseudorandom.edirif8~=before.edirif8,'Riff-Raff did not consume its own edition stream')
 PROBE_RIFF_TEXT=tostring(#G.jokers.cards-count)
 print('SOURCE_RIFF_INDEPENDENCE '..PROBE_RIFF_TEXT..' original generated Commons; shop streams and Rare pool unchanged')
end
if PROBE_ROLLOVER then
 for ante=1,2 do
  G.GAME.round_resets.ante=ante
  G.GAME.blind_on_deck='Boss';G.GAME.round_resets.blind=G.P_BLINDS.bl_hook
  G.GAME.blind:set_blind(G.P_BLINDS.bl_hook)
  G.GAME.chips=G.GAME.blind.chips;G.STATE=G.STATES.HAND_PLAYED
  end_round();pump(600)
  assert(G.GAME.round_resets.ante==ante+1 and G.STATE==G.STATES.ROUND_EVAL,'source Boss rollover timing differs')
 end
 PROBE_ROLLOVER_TEXT='2'
end
