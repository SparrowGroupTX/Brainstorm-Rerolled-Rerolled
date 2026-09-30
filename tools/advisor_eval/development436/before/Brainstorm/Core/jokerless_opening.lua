-- Deterministic detached opening search. No live RNG, game mutations, saves or
-- native-library calls. LuaJIT FFI only supplies private 64-bit arithmetic.
local M={schema=1,mode='jokerless_coupon_blue_v1'}
local ffi=require('ffi');local bit=require('bit')
pcall(ffi.cdef,'typedef union { double d; uint32_t words[2]; } brainstorm_jokerless_bits_v1;')
local U=ffi.typeof('brainstorm_jokerless_bits_v1')
local masks={bit.lshift(-1,1),bit.lshift(-1,6),bit.lshift(-1,9),bit.lshift(-1,17)}
local shifts={{31,45,18},{19,30,28},{24,48,7},{21,39,8}}
local function left(lo,hi,n)
  if n>=32 then return 0,bit.lshift(lo,n-32) end
  return bit.lshift(lo,n),bit.bor(bit.lshift(hi,n),bit.rshift(lo,32-n))
end
local function right(lo,hi,n)
  if n>=32 then return bit.rshift(hi,n-32),0 end
  return bit.bor(bit.rshift(lo,n),bit.lshift(hi,32-n)),bit.rshift(hi,n)
end
local function random(seed)
  local d=seed;local lows,highs={},{};local minima={2,64,512,131072};local u=U()
  for i=1,4 do d=d*math.pi+2.7182818284590452354;u.d=d;local lo,hi=u.words[0],u.words[1]
    if hi==0 and lo<minima[i] then lo=lo+minima[i] end;lows[i],highs[i]=lo,hi end
  local rlo,rhi
  for _=1,11 do
    rlo,rhi=0,0
    for i=1,4 do local lo,hi=lows[i],highs[i];local s=shifts[i]
      local alo,ahi=left(lo,hi,s[1]);alo,ahi=right(bit.bxor(alo,lo),bit.bxor(ahi,hi),s[2])
      local blo,bhi=left(bit.band(lo,masks[i]),hi,s[3])
      lo,hi=bit.bxor(alo,blo),bit.bxor(ahi,bhi)
      lows[i],highs[i]=lo,hi;rlo,rhi=bit.bxor(rlo,lo),bit.bxor(rhi,hi)
    end
  end
  u.words[0]=rlo;u.words[1]=bit.bor(bit.band(rhi,0xfffff),0x3ff00000)
  return u.d-1
end
function M.pseudohash(seed)
  local value=1
  for i=#seed,1,-1 do value=((1.1239285023/value)*seed:byte(i)*math.pi+math.pi*i)%1 end
  return value
end
M.random=random
function M.stream(seed)
  local nodes={};local hashed=M.pseudohash(seed)
  return function(key)
    local node=nodes[key] or M.pseudohash(key..seed)
    node=math.abs(tonumber(string.format('%.13f',(2.134453429141+node*1.72431234)%1)))
    nodes[key]=node;return random((node+hashed)/2)
  end
end
local function choice(draw,key,pool)
  local result=pool[math.floor(draw(key)*#pool)+1];local i=1
  while result=='UNAVAILABLE' do i=i+1;if i>128 then return nil,'Pool resampling exceeded bound.' end
    result=pool[math.floor(draw(key..'_resample'..i)*#pool)+1] end
  return result
end
local function weighted(draw,key,pool,prepared_total)
  local total=prepared_total
  if total==nil then total=0;for _,p in ipairs(pool) do total=total+p.weight end end
  local value=draw(key)*total;local sum=0
  for _,p in ipairs(pool) do sum=sum+p.weight;if sum>=value and sum-p.weight<=value then return p end end
end
local function standard(draw,catalog,count)
  local result={}
  for i=1,count do
    local key='c_base'
    if draw('stdset1')>0.6 then key=choice(draw,'Enhancedsta1',catalog.enhancements) end
    local front=choice(draw,'frontsta1',catalog.fronts)
    local edition=draw('standard_edition1');local rate=catalog.edition_rate
    edition=edition>1-0.012*rate and 'polychrome' or edition>1-0.04*rate and 'holo' or edition>1-0.08*rate and 'foil' or 'base'
    local seal='none'
    if draw('stdseal1')>0.8 then local value=draw('stdsealtype1')
      seal=value>0.75 and 'Red' or value>0.5 and 'Blue' or value>0.25 and 'Gold' or 'Purple' end
    result[i]={front=type(front)=='table' and front.key or front,key=key,edition=edition,seal=seal}
  end
  return result
end
M.standard=standard
-- These Planets are available before any hidden hand has been played. Planet X,
-- Ceres and Eris are later development options, not fresh-opening predicates.
local planet_hands={c_mercury='Pair',c_venus='Three of a Kind',c_earth='Full House',
  c_mars='Four of a Kind',c_jupiter='Flush',c_saturn='Straight',c_uranus='Two Pair',
  c_neptune='Straight Flush',c_pluto='High Card'}
local planet_names={c_mercury='Mercury',c_venus='Venus',c_earth='Earth',c_mars='Mars',
  c_jupiter='Jupiter',c_saturn='Saturn',c_uranus='Uranus',c_neptune='Neptune',c_pluto='Pluto'}
local hand_planets={};for key,hand in pairs(planet_hands) do hand_planets[hand]=key end
local function requested_target(options)
  if options.require_planet==nil and options.target_hand==nil then return nil end
  local key=options.require_planet or hand_planets[options.target_hand]
  if not planet_hands[key] or (options.target_hand~=nil and options.target_hand~=planet_hands[key]) or
    (options.require_saturn and key~='c_saturn') then return nil,nil,'Unsupported or inconsistent opening Planet target.' end
  return key,planet_hands[key]
end
local function recipe_target(result)
  if result.target_planet==nil and result.target_hand==nil then return nil end
  if not planet_hands[result.target_planet] or result.target_hand~=planet_hands[result.target_planet] then return nil,nil,'Invalid bound opening Planet target.' end
  return result.target_planet,result.target_hand
end
local prepare_search
local function predict(seed,catalog,options,prepared,filter)
  options=options or {};local target,hand,target_reason=requested_target(options)
  if target_reason then return nil,target_reason end
  local draw=M.stream(seed)
  local small,reason=choice(draw,'Tag1',catalog.tags);if not small then return nil,reason end
  if options.require_coupon and small~='tag_coupon' then return {seed=seed,small_tag=small,matched=false} end
  local big;big,reason=choice(draw,'Tag1',catalog.tags);if not big then return nil,reason end
  local voucher;voucher,reason=choice(draw,'Voucher1',catalog.vouchers);if not voucher then return nil,reason end
  -- Search-only gates use a detached validated catalog. Once a requested
  -- condition is false, downstream generation cannot repair it. Public predict
  -- supplies no private context and still evaluates the full requested recipe.
  if prepared and filter.require_telescope and voucher~='v_telescope' then return false end
  local result={seed=seed,small_tag=small,big_tag=big,voucher=voucher,packs={},shop={},qualification=false,
    catalog_signature=prepared and prepared.signature or M.catalog_signature(catalog)}
  if target then result.target_planet=target;result.target_hand=hand end
  if options.generation_only then result.pack=standard(draw,catalog,5);return result end
  local used={}
  for i=1,2 do
    local set=draw('cdt1')<=0.5 and 'Tarot' or 'Planet'
    local original=set=='Tarot' and catalog.tarots or catalog.planets;local pool={}
    for j,key in ipairs(original) do pool[j]=used[key] and 'UNAVAILABLE' or key end
    local key;key,reason=choice(draw,set..'sho1',pool);if not key then return nil,reason end
    result.shop[i]={key=key,set=set};used[key]=true
  end
  if prepared then
    local wanted=target or (filter.require_saturn and 'c_saturn')
    if wanted then
      local present=false
      for _,offer in ipairs(result.shop) do if offer.key==wanted and offer.set=='Planet' then present=true end end
      if not present then return false end
    end
  end
  for i=1,2 do
    local pack=weighted(draw,'shop_pack1',catalog.boosters,prepared and prepared.booster_total)
    if not pack then return nil,'No supported pack.' end
    result.packs[i]={key=pack.key,kind=pack.kind,choose=pack.choose,extra=pack.extra,cost=pack.cost}
  end
  if prepared then
    local capacity=0
    for _,pack in ipairs(result.packs) do if pack.kind=='Standard' then capacity=capacity+pack.choose end end
    if capacity<math.max(filter.min_blue or 2,filter.min_quality or 0,filter.min_steel or 0) then return false end
  end
  -- Only the Standard packs are opened, left to right, with no rerolls, other
  -- packs, consumable uses or voucher purchases before their cards are created.
  for _,pack in ipairs(result.packs) do if pack.kind=='Standard' then pack.cards=standard(draw,catalog,pack.extra) end end
  return result
end
function M.predict(seed,catalog,options) return predict(seed,catalog,options) end
function M.match(result,options)
  options=options or {};if not result or result.small_tag~='tag_coupon' then return false end
  local target,_,reason=requested_target(options);if reason then return false end
  local bound,_,bound_reason=recipe_target(result)
  if bound_reason or (target and bound and target~=bound) or (options.require_saturn and bound and bound~='c_saturn') then return false end
  target=target or bound
  local blue,saturn,quality,steel,planet=0,false,0,0,false
  for _,offer in ipairs(result.shop or {}) do
    if offer.key=='c_saturn' then saturn=true end
    if offer.key==target and offer.set=='Planet' then planet=true end
  end
  for _,pack in ipairs(result.packs or {}) do if pack.cards then
    local count,good,steel_count=0,0,0
    for _,card in ipairs(pack.cards) do if card.seal=='Blue' then
      count=count+1
      if card.edition~='base' or card.key=='m_steel' then good=good+1 end
      if card.key=='m_steel' then steel_count=steel_count+1 end
    end end
    blue=blue+math.min(count,pack.choose)
    quality=quality+math.min(good,pack.choose);steel=steel+math.min(steel_count,pack.choose)
  end end
  result.blue_choices=blue;result.saturn=saturn;result.blue_quality=quality;result.blue_steel=steel
  return blue>=(options.min_blue or 2) and (not options.require_saturn or saturn) and (not target or planet) and
    (not options.require_telescope or result.voucher=='v_telescope') and quality>=(options.min_quality or 0) and steel>=(options.min_steel or 0)
end
local alphabet='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
function M.seed_at(index)
  if type(index)~='number' or index%1~=0 or index<0 or index>=35^8 then return nil end
  local out={};for i=1,8 do local n=index%35;out[i]=alphabet:sub(n+1,n+1);index=math.floor(index/35) end
  return table.concat(out)
end
function M.search(catalog,options,yield_fn)
  options=options or {};local start,limit=options.start or 0,options.limit or 10000
  if type(start)~='number' or start%1~=0 or start<0 or type(limit)~='number' or limit%1~=0 or limit<1 or limit>1000000 or start+limit>35^8 then return nil,'Invalid bounded seed range.' end
  for _,key in ipairs({'max_matches','min_blue','min_quality','min_steel'}) do local n=options[key]
    if n~=nil and (type(n)~='number' or n~=n or n%1~=0 or n<0 or n>(key=='max_matches' and 16 or 4) or (key=='max_matches' and n<1)) then return nil,'Invalid bounded match predicate.' end
  end
  local target,hand,target_reason=requested_target(options);if target_reason then return nil,target_reason end
  if target then
    local available=false;for _,key in ipairs(catalog.planets or {}) do if key==target then available=true;break end end
    if not available then return nil,'The selected Planet is unavailable in the opening catalog.' end
  end
  local result={schema=1,mode=M.mode,status='not_found',tested=0,start=start,limit=limit,matches={},qualification=false}
  local prepared=prepare_search(catalog)
  for index=start,start+limit-1 do
    local settings={require_coupon=true,require_planet=target,target_hand=hand}
    local predicted,reason
    if prepared then predicted,reason=predict(M.seed_at(index),prepared.catalog,settings,prepared,options)
    else predicted,reason=M.predict(M.seed_at(index),catalog,settings) end
    if predicted==nil then result.status='unsupported';result.reason=reason;return result end
    result.tested=result.tested+1
    if predicted~=false and M.match(predicted,options) then
      result.matches[#result.matches+1]=predicted
      if #result.matches>=(options.max_matches or 1) then result.status='found';result.next_index=index+1;return result end
    end
    if yield_fn and result.tested%64==0 then
      yield_fn()
      -- Public callbacks may change their catalog. Refresh the private snapshot
      -- so subsequent seeds cannot retain stale provenance across a yield.
      prepared=prepare_search(catalog)
    end
  end
  result.next_index=start+limit;return result
end

-- Canonical original-source pool order; these are mechanics, never seed examples.
local expected_keys={[ [=[Booster]=] ]={[=[p_arcana_normal_1]=],[=[p_arcana_normal_2]=],[=[p_arcana_normal_3]=],[=[p_arcana_normal_4]=],[=[p_arcana_jumbo_1]=],[=[p_arcana_jumbo_2]=],[=[p_arcana_mega_1]=],[=[p_arcana_mega_2]=],[=[p_celestial_normal_1]=],[=[p_celestial_normal_2]=],[=[p_celestial_normal_3]=],[=[p_celestial_normal_4]=],[=[p_celestial_jumbo_1]=],[=[p_celestial_jumbo_2]=],[=[p_celestial_mega_1]=],[=[p_celestial_mega_2]=],[=[p_standard_normal_1]=],[=[p_standard_normal_2]=],[=[p_standard_normal_3]=],[=[p_standard_normal_4]=],[=[p_standard_jumbo_1]=],[=[p_standard_jumbo_2]=],[=[p_standard_mega_1]=],[=[p_standard_mega_2]=],[=[p_buffoon_normal_1]=],[=[p_buffoon_normal_2]=],[=[p_buffoon_jumbo_1]=],[=[p_buffoon_mega_1]=],[=[p_spectral_normal_1]=],[=[p_spectral_normal_2]=],[=[p_spectral_jumbo_1]=],[=[p_spectral_mega_1]=]},[ [=[Enhanced]=] ]={[=[m_bonus]=],[=[m_mult]=],[=[m_wild]=],[=[m_glass]=],[=[m_steel]=],[=[m_stone]=],[=[m_gold]=],[=[m_lucky]=]},[ [=[Planet]=] ]={[=[c_mercury]=],[=[c_venus]=],[=[c_earth]=],[=[c_mars]=],[=[c_jupiter]=],[=[c_saturn]=],[=[c_uranus]=],[=[c_neptune]=],[=[c_pluto]=],[=[c_planet_x]=],[=[c_ceres]=],[=[c_eris]=]},[ [=[Tag]=] ]={[=[tag_uncommon]=],[=[tag_rare]=],[=[tag_negative]=],[=[tag_foil]=],[=[tag_holo]=],[=[tag_polychrome]=],[=[tag_investment]=],[=[tag_voucher]=],[=[tag_boss]=],[=[tag_standard]=],[=[tag_charm]=],[=[tag_meteor]=],[=[tag_buffoon]=],[=[tag_handy]=],[=[tag_garbage]=],[=[tag_ethereal]=],[=[tag_coupon]=],[=[tag_double]=],[=[tag_juggle]=],[=[tag_d_six]=],[=[tag_top_up]=],[=[tag_skip]=],[=[tag_orbital]=],[=[tag_economy]=]},[ [=[Tarot]=] ]={[=[c_fool]=],[=[c_magician]=],[=[c_high_priestess]=],[=[c_empress]=],[=[c_emperor]=],[=[c_heirophant]=],[=[c_lovers]=],[=[c_chariot]=],[=[c_justice]=],[=[c_hermit]=],[=[c_wheel_of_fortune]=],[=[c_strength]=],[=[c_hanged_man]=],[=[c_death]=],[=[c_temperance]=],[=[c_devil]=],[=[c_tower]=],[=[c_star]=],[=[c_moon]=],[=[c_sun]=],[=[c_judgement]=],[=[c_world]=]},[ [=[Voucher]=] ]={[=[v_overstock_norm]=],[=[v_overstock_plus]=],[=[v_clearance_sale]=],[=[v_liquidation]=],[=[v_hone]=],[=[v_glow_up]=],[=[v_reroll_surplus]=],[=[v_reroll_glut]=],[=[v_crystal_ball]=],[=[v_omen_globe]=],[=[v_telescope]=],[=[v_observatory]=],[=[v_grabber]=],[=[v_nacho_tong]=],[=[v_wasteful]=],[=[v_recyclomancy]=],[=[v_tarot_merchant]=],[=[v_tarot_tycoon]=],[=[v_planet_merchant]=],[=[v_planet_tycoon]=],[=[v_seed_money]=],[=[v_money_tree]=],[=[v_blank]=],[=[v_antimatter]=],[=[v_magic_trick]=],[=[v_illusion]=],[=[v_hieroglyph]=],[=[v_petroglyph]=],[=[v_directors_cut]=],[=[v_retcon]=],[=[v_paint_brush]=],[=[v_palette]=]}}
local expected_bans={[ [=[bl_final_acorn]=] ]=true,[ [=[bl_final_heart]=] ]=true,[ [=[bl_final_leaf]=] ]=true,[ [=[c_judgement]=] ]=true,[ [=[c_soul]=] ]=true,[ [=[c_wraith]=] ]=true,[ [=[p_buffoon_jumbo_1]=] ]=true,[ [=[p_buffoon_mega_1]=] ]=true,[ [=[p_buffoon_normal_1]=] ]=true,[ [=[p_buffoon_normal_2]=] ]=true,[ [=[tag_buffoon]=] ]=true,[ [=[tag_foil]=] ]=true,[ [=[tag_holo]=] ]=true,[ [=[tag_negative]=] ]=true,[ [=[tag_polychrome]=] ]=true,[ [=[tag_rare]=] ]=true,[ [=[tag_top_up]=] ]=true,[ [=[tag_uncommon]=] ]=true,[ [=[v_antimatter]=] ]=true}
local function empty(t) return type(t)=='table' and next(t)==nil end
local function whole(n,lo,hi) return type(n)=='number' and n==n and n%1==0 and n>=lo and n<=hi end
function M.catalog_signature(c)
  local values={'jokerless_opening_catalog_v1',tostring(c.edition_rate)}
  for _,name in ipairs({'tags','vouchers','tarots','planets','enhancements'}) do
    values[#values+1]=name;for _,key in ipairs(c[name] or {}) do values[#values+1]=key end
  end
  for _,p in ipairs(c.boosters or {}) do values[#values+1]=table.concat({p.key,p.kind,p.weight,p.choose,p.extra,p.cost},':') end
  for _,p in ipairs(c.fronts or {}) do values[#values+1]=type(p)=='table' and p.key or p end
  return table.concat(values,'|')
end
local known={};for set,keys in pairs(expected_keys) do known[set]={};for _,key in ipairs(keys) do known[set][key]=true end end
-- Never cache invariants on a mutable live catalog. Unrecognized inputs retain
-- the full predictor and its existing errors instead of gaining unsafe gates.
prepare_search=function(catalog)
  local function dense(t,count)
    if type(t)~='table' or getmetatable(t)~=nil or #t~=count then return false end
    for key in pairs(t) do if type(key)~='number' or key%1~=0 or key<1 or key>count then return false end end
    for i=1,count do if rawget(t,i)==nil then return false end end
    return true
  end
  if type(catalog)~='table' or getmetatable(catalog)~=nil or catalog.edition_rate~=1 then return nil end
  local c={edition_rate=catalog.edition_rate}
  for _,pair in ipairs({{'tags','Tag'},{'vouchers','Voucher'},{'tarots','Tarot'},{'planets','Planet'},{'enhancements','Enhanced'}}) do
    local name,set=pair[1],pair[2];local pool=catalog[name];local keys=expected_keys[set]
    if not dense(pool,#keys) then return nil end
    local out,available={},false;c[name]=out
    for i,key in ipairs(keys) do
      if pool[i]~=key and pool[i]~='UNAVAILABLE' then return nil end
      out[i]=pool[i];available=available or pool[i]~='UNAVAILABLE'
    end
    if not available then return nil end
  end
  if type(catalog.boosters)~='table' or #catalog.boosters<1 or not dense(catalog.boosters,#catalog.boosters) or
    #catalog.boosters>#expected_keys.Booster then return nil end
  local total,seen=0,{};c.boosters={}
  local kinds={arcana='Arcana',celestial='Celestial',standard='Standard',buffoon='Buffoon',spectral='Spectral'}
  for i,p in ipairs(catalog.boosters) do
    if type(p)~='table' or getmetatable(p)~=nil or not known.Booster[p.key] or seen[p.key] or
      p.kind~=kinds[p.key:match('^p_([^_]+)_')] or not whole(p.choose,1,2) or not whole(p.extra,2,5) or
      not whole(p.cost,0,100) or type(p.weight)~='number' or p.weight~=p.weight or p.weight<=0 or p.weight>100 then return nil end
    seen[p.key]=true;total=total+p.weight
    c.boosters[i]={key=p.key,kind=p.kind,choose=p.choose,extra=p.extra,cost=p.cost,weight=p.weight}
  end
  if not dense(catalog.fronts,52) then return nil end
  c.fronts={};seen={}
  for i,p in ipairs(catalog.fronts) do
    if type(p)=='table' and getmetatable(p)~=nil then return nil end
    local key=type(p)=='table' and p.key or p
    if type(key)~='string' or not key:match('^[CDHS]_[2-9TJQKA]$') or seen[key] then return nil end
    seen[key]=true;c.fronts[i]=key
  end
  return {catalog=c,signature=M.catalog_signature(c),booster_total=total}
end
function M.validate_result(r)
  if type(r)~='table' or type(r.seed)~='string' or #r.seed~=8 or r.seed:find('[^1-9A-Z]') or
    not known.Tag[r.small_tag] or not known.Tag[r.big_tag] or not known.Voucher[r.voucher] or
    type(r.shop)~='table' or #r.shop~=2 or type(r.packs)~='table' or #r.packs~=2 or r.qualification~=false then return false end
  local _,_,target_reason=recipe_target(r);if target_reason then return false end
  for _,c in ipairs(r.shop) do if type(c)~='table' or not known[c.set] or (c.set~='Tarot' and c.set~='Planet') or not known[c.set][c.key] then return false end end
  for _,p in ipairs(r.packs) do
    if type(p)~='table' or not known.Booster[p.key] or not whole(p.choose,1,2) or not whole(p.extra,2,5) or
      type(p.kind)~='string' or not whole(p.cost,0,100) then return false end
    if p.kind=='Standard' then
      if not p.key:match('^p_standard_') or type(p.cards)~='table' or #p.cards~=p.extra then return false end
      for _,c in ipairs(p.cards) do if type(c)~='table' or type(c.front)~='string' or not c.front:match('^[CDHS]_[2-9TJQKA]$') or
        (c.key~='c_base' and not known.Enhanced[c.key]) or
        not ({none=true,Red=true,Blue=true,Gold=true,Purple=true})[c.seal] or
        not ({base=true,foil=true,holo=true,polychrome=true})[c.edition] then return false end end
    elseif p.cards then return false end
  end
  return true
end
function M.catalog(g)
  local game=g and g.GAME;local pools=g and g.P_CENTER_POOLS;local centers=g and g.P_CENTERS
  if type(game)~='table' or game.challenge~='c_jokerless_1' or (game.stake or 1)~=1 or
    not game.challenge_tab or game.challenge_tab.id~=game.challenge then return nil,'Start original Jokerless first.' end
  if not g.STAGES or not g.STATES or g.STAGE~=g.STAGES.RUN or g.STATE~=g.STATES.BLIND_SELECT or
    game.blind_on_deck~='Small' or ((game.round_resets or {}).blind_states or {}).Small~='Select' or (game.skips or 0)~=0 or
    game.round~=0 or (game.round_resets or {}).ante~=1 or (game.hands_played or 0)~=0 or
    not g.jokers or #(g.jokers.cards or {})~=0 or (g.jokers.config or {}).card_limit~=0 or
    not g.consumeables or #(g.consumeables.cards or {})~=0 or not empty(game.used_vouchers) or
    not empty(game.modifiers) or #(game.tags or {})~=0 then return nil,'Search requires a fresh original Jokerless run.' end
  if game.joker_rate~=0 or game.tarot_rate~=4 or game.planet_rate~=4 or game.playing_card_rate~=0 or
    (game.spectral_rate or 0)~=0 or game.edition_rate~=1 or (game.shop or {}).joker_max~=2 then
    return nil,'The shop generation rates differ from the supported opening.' end
  if type(pools)~='table' or type(centers)~='table' or type(game.banned_keys)~='table' then return nil,'Public source catalogs are unavailable.' end
  for k,v in pairs(expected_bans) do if game.banned_keys[k]~=v then return nil,'The challenge ban profile differs.' end end
  for k,v in pairs(game.banned_keys) do if v and not expected_bans[k] then return nil,'The challenge has additional bans.' end end
  for k,v in pairs(game.used_jokers or {}) do if v and k~='c_base' then return nil,'An opening card was already generated.' end end
  for set,keys in pairs(expected_keys) do local p=pools[set]
    if type(p)~='table' or #p~=#keys then return nil,'A source pool has unsupported entries.' end
    for i,key in ipairs(keys) do local c=p[i]
      if type(c)~='table' or c.key~=key or c.set~=set or c.yes_pool_flag or c.no_pool_flag or c.enhancement_gate then
        return nil,'A source pool differs from original supported mechanics.' end
    end
  end
  if type(g.playing_cards)~='table' or #g.playing_cards~=52 then return nil,'The initial public deck differs.' end
  local seen={};for _,c in ipairs(g.playing_cards) do local key=(c.config or {}).card_key
    if type(key)~='string' or seen[key] or ((c.config or {}).center or {}).key~='c_base' or c.seal or c.edition then
      return nil,'The initial public deck is not the original plain 52 cards.' end;seen[key]=true
  end
  local catalog={schema=1,mode=M.mode,tags={},vouchers={},tarots={},planets={},enhancements={},boosters={},fronts={},edition_rate=game.edition_rate}
  for _,set in ipairs({'Tag','Voucher','Tarot','Planet','Enhanced'}) do
    local name=({Tag='tags',Voucher='vouchers',Tarot='tarots',Planet='planets',Enhanced='enhancements'})[set]
    local out=catalog[name];local available=0
    for i,c in ipairs(pools[set]) do local allowed=not game.banned_keys[c.key]
      if set=='Tag' then allowed=allowed and (not c.min_ante or c.min_ante<=1) and
        (not c.requires or (centers[c.requires] and centers[c.requires].discovered))
      elseif set~='Enhanced' then
        allowed=allowed and c.unlocked~=false and not (game.used_jokers or {})[c.key]
        if set=='Voucher' then allowed=allowed and not c.requires
        elseif set=='Planet' then allowed=allowed and not (c.config or {}).softlock end
      end
      out[i]=allowed and c.key or 'UNAVAILABLE';if allowed then available=available+1 end
    end
    if available==0 then return nil,'An opening source pool has no eligible entries.' end
  end
  for _,p in ipairs(pools.Booster) do if not game.banned_keys[p.key] then
    local config=p.config or {};local weight=p.weight or 1
    if type(weight)~='number' or weight~=weight or weight<=0 or weight>100 or
      not whole(config.choose,1,2) or not whole(config.extra,2,5) or not whole(p.cost,0,100) then
      return nil,'A booster has unsupported generation metadata.' end
    catalog.boosters[#catalog.boosters+1]={key=p.key,kind=p.kind,weight=weight,choose=config.choose,extra=config.extra,cost=p.cost}
  end end
  for key,c in pairs(g.P_CARDS or {}) do
    if not seen[key] or c.sort_id~=nil then return nil,'The card-front catalog differs from the supported deck.' end
    catalog.fronts[#catalog.fronts+1]={key=key,suit=c.suit}
  end
  if #catalog.fronts~=52 then return nil,'The original 52 card fronts are unavailable.' end
  table.sort(catalog.fronts,function(a,b)return a.key<b.key end)
  catalog.signature=M.catalog_signature(catalog)
  return catalog
end
local function review(reason)
  return {title='Review the searched Jokerless opening',lines={reason},warnings={'Opening recipe paused; the advisor has not verified this continuation.'}}
end
local function recommendation(title,line,action)
  return {title=title,lines={line},warnings={},action=action}
end
local suits={C='Clubs',D='Diamonds',H='Hearts',S='Spades'}
local ranks={T=10,J=11,Q=12,K=13,A=14}
local function visible_key(c)
  if type(c)~='table' or c.face_down or c.debuff or not whole(c.rank,2,14) then return nil end
  local suit;for letter,name in pairs(suits) do if c.suit==name then suit=letter end end
  if not suit then return nil end
  local rank=tostring(c.rank);for letter,value in pairs(ranks) do if c.rank==value then rank=letter end end
  local edition='base'
  if c.edition~=nil and type(c.edition)~='table' then return nil end
  for _,key in ipairs({'foil','holo','polychrome'}) do if (c.edition or {})[key] then
    if edition~='base' or c.edition[key]~=true then return nil end;edition=key
  end end
  local values=edition=='foil' and {chips=50} or edition=='holo' and {mult=10} or edition=='polychrome' and {x_mult=1.5} or {}
  for key,value in pairs(c.edition or {}) do if value then
    if key==edition then
      if value~=true then return nil end
    elseif key=='type' then
      if edition=='base' or value~=edition then return nil end
    elseif values[key]~=value then return nil end
  end end
  return suit..'_'..rank..':'..(c.enhancement or c.key or 'c_base')..':'..(c.seal or 'none')..':'..edition
end
local function predicted_key(c) return c.front..':'..c.key..':'..c.seal..':'..c.edition end
local function stock_subset(actual,expected,free)
  local counts={};for _,c in ipairs(expected) do counts[c.key]=(counts[c.key] or 0)+1 end
  for _,c in ipairs(actual or {}) do if c.face_down or not counts[c.key] or counts[c.key]<1 or (free and c.cost~=0) then return false end
    counts[c.key]=counts[c.key]-1 end
  return true
end
-- Conditional financing for an already-declared visible purchase. This does
-- not rank the purchase against using the free Planet or leaving the shop.
-- Only a caller-qualified original free stock and its single-card continuation
-- can enter; no original mixed inventory is liquidated and no actions are queued.
function M.cash_bridge(s,purchase,options)
  options=options or {}
  local function no(reason) return nil,reason end
  local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
  if type(s)~='table' or s.phase~='shop' or type(purchase)~='table' or purchase.kind~='buy' or
    purchase.area~='shop_vouchers' or not whole(purchase.index,1,3) then return no('No supported declared visible purchase.') end
  local wanted=(s.shop_vouchers or {})[purchase.index]
  if not wanted or type(wanted.id)~='string' or wanted.id=='' or wanted.face_down or wanted.debuff or
    (wanted.ability or {}).set~='Voucher' or type(wanted.key)~='string' or
    not finite(wanted.cost) or wanted.cost<=0 then return no('The declared voucher identity or price is unavailable.') end
  local debt=s.bankrupt_at or 0
  if not finite(s.dollars) or not finite(debt) or debt>0 then return no('Cash or the signed debt limit is unknown.') end
  if wanted.cost<=s.dollars-debt then return no('The declared purchase is already affordable.') end
  if #(s.jokers or {})~=0 or (s.used_vouchers or {}).v_observatory or (s.vouchers or {}).v_observatory then
    return no('Joker and Observatory inventory effects are outside this cash-only bridge.') end
  -- Unknown challenge modifiers may change purchase/sale or cash resources.
  -- The initial narrow bridge therefore requires the plain resource rules.
  if next(s.modifiers or {}) then return no('Modified purchase or cash-resource rules are unsupported.') end
  local meta=s.shop_forecast or {}
  if meta.inflation~=0 or not finite(meta.discount_percent) or meta.discount_percent<0 or meta.discount_percent>100 then
    return no('Exact unchanged sale pricing is unavailable.') end
  if (s.consumeable_buffer or 0)~=0 or not whole(s.consumable_limit,1,100) or #(s.consumeables or {})>1 then
    return no('The bridge requires unreserved space and no mixed held inventory.') end
  local source=options.source_shop
  if type(source)~='table' or #source<1 or #source>3 or type(options.protected_keys)~='table' then
    return no('Original free-stock qualification is unavailable.') end
  local expected,eligible={},{}
  for _,c in ipairs(source) do
    if type(c)~='table' or type(c.key)~='string' or expected[c.key] then return no('Original free stock has ambiguous identities.') end
    expected[c.key]=true
    if c.set=='Planet' and planet_hands[c.key] and not options.protected_keys[c.key] then eligible[c.key]=true end
  end
  local ids,stock_keys={[wanted.id]=true},{}
  for _,area in ipairs({'shop_jokers','consumeables'}) do
    for _,c in ipairs(s[area] or {}) do
      if type(c)~='table' or type(c.id)~='string' or c.id=='' or ids[c.id] then return no('A bridge card lacks a unique public identity.') end
      ids[c.id]=true
      if area=='shop_jokers' then
        if not expected[c.key] or stock_keys[c.key] or c.cost~=0 or c.face_down then return no('Current stock differs from the qualified free stock.') end
        stock_keys[c.key]=true
      end
    end
  end
  local function ordinary(c)
    local a=c.ability or {};local config=a.consumeable
    if not eligible[c.key] or c.cost~=0 or c.edition~=nil or c.seal~=nil or c.debuff or c.face_down or c.pinned or
      a.pinned or a.eternal or a.rental or a.perishable or a.couponed~=true or a.set~='Planet' or
      a.name~=planet_names[c.key] or type(config)~='table' or config.hand_type~=planet_hands[c.key] or
      (a.h_size or 0)~=0 or (a.d_size or 0)~=0 or (a.extra_value or 0)~=0 or
      not finite(c.base_cost) or c.base_cost<0 or not whole(c.sell_cost,1,1000000) then return false end
    for k in pairs(config) do if k~='hand_type' then return false end end
    for _,k in ipairs({'mult','h_mult','h_x_mult','h_dollars','p_dollars','t_mult','t_chips','bonus','perma_bonus'}) do
      if (a[k] or 0)~=0 then return false end
    end
    if (a.x_mult or 1)~=1 or a.extra~=nil then return false end
    local price=math.max(1,math.floor((c.base_cost+0.5)*(100-meta.discount_percent)/100))
    return c.sell_cost==math.max(1,math.floor(price/2))
  end
  local held=s.consumeables or {};local candidates={}
  if #held==1 then
    local c=held[1]
    if not stock_keys[c.key] and ordinary(c) then candidates[1]={card=c,index=1,held=true} end
  elseif #held<s.consumable_limit then
    for i,c in ipairs(s.shop_jokers or {}) do if ordinary(c) then candidates[#candidates+1]={card=c,index=i,held=false} end end
  end
  local comparisons,best={},nil
  for _,candidate in ipairs(candidates) do
    local final=s.dollars+candidate.card.sell_cost-wanted.cost
    local admitted=final>=debt
    comparisons[#comparisons+1]={source_id=candidate.card.id,source_key=candidate.card.key,
      cash_after_sale=s.dollars+candidate.card.sell_cost,cash_after_purchase=final,funds_declared_purchase=admitted}
    if admitted and (not best or candidate.card.sell_cost>best.card.sell_cost) then best=candidate end
  end
  if not best then return no('No complete one-card bridge funds the declared purchase.') end
  local c=best.card;local actions={}
  if not best.held then actions[#actions+1]={kind='buy',area='shop_jokers',index=best.index} end
  actions[#actions+1]={kind='sell',area='consumeables',index=1}
  actions[#actions+1]={kind='buy',area='shop_vouchers',index=purchase.index}
  local bridge={complete=true,scope='Conditional cash financing of an already-declared purchase; no strategic dominance or survival claim.',
    source_id=c.id,source_key=c.key,target_id=wanted.id,target_key=wanted.key,target_cost=wanted.cost,
    actions=actions,action_count=#actions,cash_before=s.dollars,cash_after_sale=s.dollars+c.sell_cost,
    cash_after_purchase=s.dollars+c.sell_cost-wanted.cost,debt_limit=debt,comparisons=comparisons}
  local result=recommendation((best.held and 'Sell ' or 'Buy the free ')..planet_names[c.key]..' to fund '..(wanted.name or wanted.key),
    'This visible cash path needs '..#actions..' actions and leaves $'..tostring(bridge.cash_after_purchase)..
      ' after the declared purchase. Refresh advice after each action; the Planet is sold, not used.',actions[1])
  result.cash_bridge=bridge
  return result
end
function M.advice(s)
  local recipe=s and s.filter_info and s.filter_info.jokerless_opening
  if type(recipe)~='table' or s.challenge~='c_jokerless_1' or s.ante~=1 or not whole(s.round,0,1) then return nil end
  if not M.validate_result(recipe) then return review('The stored opening recipe is malformed or unsupported.') end
  if s.filter_info.jokerless_catalog_signature and s.filter_info.jokerless_catalog_signature~=recipe.catalog_signature then return review('The stored opening catalog provenance differs.') end
  local shallow={};for k,v in pairs(recipe) do shallow[k]=v end
  local target,hand=recipe_target(recipe);target=target or 'c_saturn';hand=hand or 'Straight'
  local name=planet_names[target]
  if recipe.small_tag~='tag_coupon' or recipe.voucher~='v_telescope' or not M.match(shallow,{min_blue=2,require_planet=target,target_hand=hand,require_telescope=true}) then
    return review('The stored opening does not satisfy the verified Coupon/Blue/'..name..'/Telescope predicate.') end
  if s.phase=='blind' and s.round==0 then
    if s.blind_on_deck=='Small' then
      if (s.skip_tags or {}).Small~='tag_coupon' then return review('The visible Small Blind tag differs from the searched Coupon.') end
      return recommendation('Skip Small Blind for the searched Coupon','The first shop cards and packs become free; Telescope still costs money.',{kind='skip_blind',blind='Small'})
    elseif s.blind_on_deck=='Big' and (s.blind_states or {}).Small=='Skipped' then
      return recommendation('Play Big Blind to reach the Coupon shop','Clear this blind with the normal advisor; the seed filter does not prove survival.',{kind='select_blind',blind='Big'})
    end
    return review('The public blind route differs from the searched opening.')
  end
  if s.phase=='hand' then return nil end
  if s.round~=1 or (s.blind_states or {}).Small~='Skipped' then return nil end
  if s.phase=='shop' then
    if not stock_subset(s.shop_jokers,recipe.shop,true) or not stock_subset(s.shop_booster,recipe.packs,true) then
      return review('The visible first-shop cards or free pack prices differ from the searched opening.') end
    for i,c in ipairs(s.consumeables or {}) do if c.key==target then
      return recommendation('Use '..name..' to develop '..hand,'Reassess the next blind after this visible hand upgrade.',{kind='use',area='consumeables',index=i,targets={}})
    end end
    for i,c in ipairs(s.shop_jokers or {}) do if c.key==target then
      if #(s.consumeables or {})+(s.consumeable_buffer or 0)>=(s.consumable_limit or 0) then return review('Make a safe consumable-space decision before buying '..name..'.') end
      return recommendation('Buy the free '..name,'The Coupon pays for this visible Planet; use it before the next blind.',{kind='buy',area='shop_jokers',index=i})
    end end
    for i,c in ipairs(s.shop_vouchers or {}) do if c.key=='v_telescope' and not (s.used_vouchers or {}).v_telescope then
      if type(c.cost)~='number' or c.cost<0 then return review('Telescope affordability is unavailable.') end
      if c.cost<=(s.dollars or 0)-(s.bankrupt_at or 0) then
        return recommendation('Buy Telescope for repeated hand development','The voucher guarantees the most-played hand in future Celestial packs; cash is checked now.',{kind='buy',area='shop_vouchers',index=i})
      end
      local bridge=M.cash_bridge(s,{kind='buy',area='shop_vouchers',index=i},
        {source_shop=recipe.shop,protected_keys={[target]=true}})
      if bridge then return bridge end
    elseif c.key~=recipe.voucher then return review('The visible voucher differs from the searched Telescope.') end end
    for i,c in ipairs(s.shop_booster or {}) do if c.key:match('^p_standard_') then
      return recommendation('Open the free Standard pack','Open Standard packs from left to right and choose the visible Blue seals.',{kind='open',area='shop_booster',index=i})
    end end
    return nil
  elseif s.phase=='pack' then
    if s.pack_type and s.pack_type~='STANDARD_PACK' then return nil end
    if s.opened_booster_key and not s.opened_booster_key:match('^p_standard_') then return nil end
    local cards=s.pack_cards or {};local matched=false
    if #cards==0 then return nil end
    for _,p in ipairs(recipe.packs) do if p.kind=='Standard' and p.cards and #cards<=#p.cards then
      local counts={};for _,c in ipairs(p.cards) do local key=predicted_key(c);counts[key]=(counts[key] or 0)+1 end
      local ok=true;for _,c in ipairs(cards) do local key=visible_key(c)
        if not key or not counts[key] or counts[key]<1 then ok=false;break end;counts[key]=counts[key]-1
      end
      if ok then matched=true;break end
    end end
    if not matched then return review('The visible pack contents differ from the recorded Standard pack recipe.') end
    local chosen;for i,c in ipairs(cards) do if c.seal=='Blue' then
      if not chosen or (c.enhancement=='m_steel' and cards[chosen].enhancement~='m_steel') then chosen=i end
    end end
    if chosen then return recommendation('Choose the visible Blue seal','Hold Blue seals in the winning hand to create the last-played hand’s Planet when space allows.',{kind='choose',area='pack_cards',index=chosen,targets={}}) end
  end
end
return M
