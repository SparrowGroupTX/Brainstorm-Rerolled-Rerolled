-- Bounded strategic utility for the discard/Death teacher. This is neither a
-- score bound nor a forecast of future offers/draws. The scorer and admission
-- checks still decide immediate feasibility. No rarity-based preference.
local M={}
local min,max,sqrt,log=math.min,math.max,math.sqrt,math.log
local function num(x,d)return type(x)=='number' and x==x and math.abs(x)<math.huge and x or (d or 0)end
local function ability(c)return c.ability or {} end
local function active(c)local a=ability(c);return not c.debuff and not a.perma_debuff and not(c.unknown or c.identity_redacted) and not(a.perishable and num(a.perish_tally,5)<=0)end
local function has(s,k)for _,c in ipairs(s.jokers or {})do if c.key==k and active(c) then return c end end end
local function owned(s,c)for _,v in ipairs(s.jokers or {})do if v==c or c.id and v.id==c.id then return true end end end
local sizes={['High Card']=1,Pair=2,['Two Pair']=4,['Three of a Kind']=3,Straight=5,Flush=5,
 ['Full House']=5,['Four of a Kind']=4,['Straight Flush']=5,['Five of a Kind']=5,['Flush House']=5,['Flush Five']=5}
local order={'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House','Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'}
local contains={Pair={Pair=true,['Two Pair']=true,['Three of a Kind']=true,['Full House']=true,['Four of a Kind']=true,['Five of a Kind']=true,['Flush House']=true,['Flush Five']=true},
 ['Three of a Kind']={['Three of a Kind']=true,['Full House']=true,['Four of a Kind']=true,['Five of a Kind']=true,['Flush House']=true,['Flush Five']=true},
 ['Two Pair']={['Two Pair']=true,['Full House']=true,['Flush House']=true},
 ['Four of a Kind']={['Four of a Kind']=true,['Five of a Kind']=true,['Flush Five']=true},
 Straight={Straight=true,['Straight Flush']=true},Flush={Flush=true,['Straight Flush']=true,['Flush House']=true,['Flush Five']=true}}
function M.profile(s)
 local p={weights={},scoring_cards=0,small=0,repeated=0,total=0,source='public_hand_history_and_levels'}
 for _,h in ipairs(order)do local v=(s.hands or {})[h] or {};local w=(sqrt(max(0,num(v.played)))+2*max(0,num(v.level,1)-1))^2
  p.weights[h]=w;p.total=p.total+w
 end
 if p.total==0 then p.weights.Pair=1;p.total=1;p.source='uncommitted_pair_prior' end
 for _,h in ipairs(order)do local w=p.weights[h]/p.total;p.weights[h]=w;p.scoring_cards=p.scoring_cards+w*sizes[h]
  if sizes[h]<=3 then p.small=p.small+w end
  if contains.Pair[h] then p.repeated=p.repeated+w end
 end
 local bonus=s.round_bonus or (s.shop_forecast or {}).round_bonus or {}
 p.hands=max(0,num((s.round_resets or {}).hands,4)+num(bonus.next_hands))
 p.discards=max(0,num((s.round_resets or {}).discards,3)+num(bonus.discards))
 if has(s,'j_burglar') then p.discards=0 end
 if not has(s,'j_chicot') then
  if (s.next_blind or {}).key=='bl_needle' then p.hands=max(1,1+num(bonus.next_hands)) end
  if (s.next_blind or {}).key=='bl_water' then p.discards=0 end
  if (s.next_blind or {}).key=='bl_psychic' then p.small=0 end
 end
 local burglar=has(s,'j_burglar');if burglar then p.hands=p.hands+max(0,num(ability(burglar).extra,3)) end
 -- Scoring-card count and cards physically played are different quantities.
 -- Psychic can score a Pair but still consumes five cards from the hand.
 p.minimum_played=p.scoring_cards
 if (s.next_blind or {}).key=='bl_psychic' and not has(s,'j_chicot') then p.minimum_played=max(5,p.minimum_played) end
 p.held=max(0,num(s.hand_size,8)-p.minimum_played)
 return p
end
function M.match(p,target)
 local rate=0
 for _,h in ipairs(order)do
  if h==target or contains[target] and contains[target][h] then rate=rate+p.weights[h]
  elseif h=='Flush' and (target=='Pair' or target=='Three of a Kind' or target=='Two Pair' or target=='Four of a Kind') then
   -- A modified-deck Flush may embed ranks; the label alone cannot decide.
   rate=rate+p.weights[h]*0.25
  end
 end
 return rate
end
local targets={j_jolly='Pair',j_sly='Pair',j_duo='Pair',j_zany='Three of a Kind',j_wily='Three of a Kind',j_trio='Three of a Kind',
 j_mad='Two Pair',j_clever='Two Pair',j_trousers='Two Pair',j_family='Four of a Kind',j_crazy='Straight',j_devious='Straight',j_runner='Straight',j_order='Straight',j_droll='Flush',j_crafty='Flush',j_tribe='Flush'}
local per_rank={j_fibonacci={2,3,5,8,14},j_even_steven={2,4,6,8,10},j_odd_todd={3,5,7,9,14},j_scholar={14},j_walkie_talkie={4,10},j_hack={2,3,4,5}}
local per_suit={j_greedy_joker='Diamonds',j_lusty_joker='Hearts',j_wrathful_joker='Spades',j_gluttenous_joker='Clubs',j_arrowhead='Spades',j_onyx_agate='Clubs',j_bloodstone='Hearts',j_rough_gem='Diamonds'}
local growing_mult={j_ride_the_bus=true,j_green_joker=true,j_red_card=true,j_ceremonial=true,j_trousers=true,j_flash=true}
local growing_chips={j_runner=true,j_square=true,j_wee=true,j_castle=true,j_ice_cream=true}
local growing_x={j_hologram=true,j_constellation=true,j_vampire=true,j_lucky_cat=true,j_glass=true,j_obelisk=true,j_madness=true,j_hit_the_road=true,j_campfire=true,j_yorick=true,j_throwback=true,j_ramen=true}
local function population(s,stats,p)
 local out={known=type(s.playing_cards)=='table' and #s.playing_cards>0,size=0,faces=0,kq=0,steel=0,gold=0,glass=0,lucky=0,wild=0,quality=0,ranks={},suits={}}
 for _,c in ipairs(s.playing_cards or {})do
  out.size=out.size+1
  if c.unknown or c.identity_redacted then out.known=false else
  local a=ability(c);local enh=c.enhancement or a.effect;local stone=enh=='m_stone' or enh=='Stone Card'
  if not stone then
   local r=num(c.rank,num((c.base or {}).id));out.ranks[r]=(out.ranks[r] or 0)+1
   if r>=11 and r<=13 or has(s,'j_pareidolia') then out.faces=out.faces+1 end
   if r==12 or r==13 then out.kq=out.kq+1 end
   if enh=='m_wild' or enh=='Wild Card' then out.wild=out.wild+1
   elseif c.suit then out.suits[c.suit]=(out.suits[c.suit] or 0)+1 end
  end
  if enh=='m_steel' or enh=='Steel Card' then out.steel=out.steel+1 end
  if enh=='m_gold' or enh=='Gold Card' then out.gold=out.gold+1 end
  if enh=='m_glass' or enh=='Glass Card' then out.glass=out.glass+1;out.quality=out.quality+3 end
  if enh=='m_lucky' or enh=='Lucky Card' then out.lucky=out.lucky+1 end
  if enh=='m_mult' or enh=='Mult Card' or enh=='m_bonus' or enh=='Bonus Card' then out.quality=out.quality+1 end
  if type(c.edition)=='table' and c.edition.polychrome then out.quality=out.quality+3 end
  end
 end
 out.size=max(1,out.size)
 local rank,count,second=nil,0,0
 for r=2,14 do local n=out.ranks[r] or 0;if n>count then second=count;rank,count=r,n elseif n>second then second=n end end
 if p.repeated>=0.5 and count>=5 and count>=second*1.4 and count/out.size>=0.2 then out.focus_rank=rank end
 return out
end
-- Actual counters, not the generic initialized zero fields shadowing extra.
-- Hand-conditional factors are discounted here as well as in the base rating:
-- otherwise complete-row replacement would silently add them back unconditionally.
function M.strength(s,c,p)
 p=p or M.profile(s);local a=ability(c);local e=type(a.extra)=='table' and a.extra or {};local k=c.key
 local mult,chips,factor=0,0,1
 if growing_mult[k] then mult=max(0,num(a.mult)) end
 if growing_chips[k] then chips=max(0,num(e.chips)) end
 if growing_x[k] then factor=max(1,num(a.x_mult,1)) end
 if k=='j_caino' then factor=max(1,num(a.caino_xmult,1)) end
 if k=='j_popcorn' then mult=max(0,num(a.mult,num(e.mult,20))) end
 if k=='j_fortune_teller' then mult=max(0,num((s.consumeable_usage_total or {}).tarot)) end
 if k=='j_supernova' then for _,h in ipairs(order)do mult=mult+p.weights[h]*num(((s.hands or {})[h] or {}).played) end end
 if k=='j_bull' then chips=max(0,num(s.dollars))*num(a.extra,2) end
 if k=='j_bootstraps' then mult=math.floor(max(0,num(s.dollars))/max(1,num(e.dollars,5)))*num(e.mult,2) end
 if k=='j_erosion' and type(s.playing_cards)=='table' then mult=max(0,num(s.starting_deck_size,52)-#s.playing_cards)*num(a.extra,4) end
 if a.type and targets[k] then
  local match=M.match(p,a.type);mult=mult+num(a.t_mult)*match;chips=chips+num(a.t_chips)*match
  factor=1+(max(1,num(a.x_mult,1))-1)*match
 end
 if k=='j_hit_the_road' then factor=1 end -- resets at round end; old XMult cannot finance the next blind
 return 14*log(1+mult/4)+12*log(1+chips/40)+30*log(factor),growing_mult[k] or growing_chips[k] or growing_x[k] or k=='j_caino' or k=='j_popcorn' or k=='j_fortune_teller' or k=='j_supernova' or k=='j_bull' or k=='j_bootstraps' or k=='j_erosion' or targets[k]~=nil
end
function M.assess(s,c,stats,base,known)
 if s.teacher_profile~='perkeo_yorick_win_v1' then return end
 local p=M.profile(s);local pop=population(s,stats,p);local a=ability(c);local e=type(a.extra)=='table' and a.extra or {};local k=c.key
 local value=base;local reason='Public hand mix and trigger opportunities; heuristic utility, not a survival guarantee.'
 local faces=pop.known and min(1,pop.faces/pop.size*p.scoring_cards) or 0.35
 local held=min(p.held,pop.steel+(has(s,'j_baron') and (pop.ranks[13] or 0) or 0))
 local future=max(0,min(3,(num(s.win_ante,8)-num((s.next_blind or {}).ante,num(s.ante,1)))*3+((s.next_blind or {}).boss and 0 or 1)))
 if a.perishable then future=min(future,max(0,num(a.perish_tally,5)-1)) end
 if targets[k] then
  local rate=M.match(p,targets[k]);value=base*(0.2+0.8*rate)
  reason='Values contained '..targets[k]..' hands across the public hand mix, including higher rank-repeat hands.'
 end
 if pop.known and (per_rank[k] or per_suit[k] or k=='j_smiley' or k=='j_scary_face' or k=='j_sock_and_buskin') then
  local fraction,focus=0,false
  if per_rank[k] then for _,r in ipairs(per_rank[k])do fraction=fraction+(pop.ranks[r] or 0)/pop.size;if r==pop.focus_rank then focus=true end end
  elseif per_suit[k] then
   local suit=per_suit[k];local matches=num(stats.suits[suit]);if has(s,'j_smeared') then matches=min(pop.size,matches+num(stats.suits[({Clubs='Spades',Spades='Clubs',Hearts='Diamonds',Diamonds='Hearts'})[suit]])) end
   fraction=matches/pop.size
  else fraction=pop.faces/pop.size;focus=pop.focus_rank and (pop.focus_rank>=11 and pop.focus_rank<=13 or has(s,'j_pareidolia')) end
  if pop.focus_rank and not per_suit[k] and fraction>0 then fraction=0.5*fraction+(focus and 0.5 or 0) end
  value=fraction>0 and base*(0.25+0.75*min(1.5,p.scoring_cards*fraction/2)) or 0
  reason='Scoring-card count and owned rank/suit concentration determine trigger opportunity; membership alone is not a promised scoring trigger.'
 end
 if growing_mult[k] or growing_chips[k] or growing_x[k] or k=='j_caino' then
  -- Existing strength is added once by the whole-row endpoint. This term
  -- values only bounded growth opportunity, never imaginary future counters.
  value=min(value,18+8*future)
  if targets[k] then value=value*(0.25+0.75*M.match(p,targets[k])) end
  if k=='j_red_card' then value=6+2*future end
  if k=='j_green_joker' then value=p.discards>0 and 6 or 18+6*future end
  if k=='j_yorick' then value=22+(p.discards>0 and 12*future or 0) end
  if k=='j_castle' then value=p.discards>0 and 20+10*future or 6 end
  if k=='j_hit_the_road' then value=p.discards>0 and 10+30*min(1,(pop.ranks[11] or 0)/max(1,pop.size)*p.discards*5) or 0 end
  if k=='j_glass' then value=6+min(18,pop.glass*3)*min(1,future) end
  if k=='j_wee' then value=pop.known and (pop.ranks[2] or 0)==0 and 0 or value end
  if k=='j_lucky_cat' then value=pop.known and pop.lucky==0 and 0 or value end
  if k=='j_ride_the_bus' and has(s,'j_pareidolia') then value=0 end
  if k=='j_caino' then value=8 end -- no free destroyed faces
  if k=='j_vampire' then value=8 end -- removes the valuable enhancements Death copies
  if k=='j_obelisk' then local dominant=0;for _,w in pairs(p.weights)do dominant=max(dominant,w)end;value=6+6*(1-dominant) end
  if k=='j_ramen' then value=p.discards>0 and 0 or 28 end
  if k=='j_throwback' then value=4 end -- no future blind skip assumed
  known=true
 end
 if k=='j_half' then value=12+52*p.small
 elseif k=='j_flower_pot' then
  value=8+50*max(0,min(1,p.scoring_cards-3));if has(s,'j_splash') or num(stats.stone)>0 then value=max(value,25) end
  if pop.known then
   local missing=0
   if has(s,'j_smeared') then
    missing=4-min(2,num(pop.suits.Hearts)+num(pop.suits.Diamonds))-min(2,num(pop.suits.Clubs)+num(pop.suits.Spades))
   else for _,suit in ipairs({'Clubs','Spades','Hearts','Diamonds'})do if num(pop.suits[suit])==0 then missing=missing+1 end end end
   if missing>pop.wild or pop.size-num(stats.stone)<4 then value=0 end
  end
 elseif k=='j_seeing_double' then
  local smear=has(s,'j_smeared');value=12+45*min(1,max(0,p.scoring_cards-1))
  if pop.known then
   local clubs=num(pop.suits.Clubs)+(smear and num(pop.suits.Spades) or 0)
   local other=num(pop.suits.Spades)+num(pop.suits.Hearts)+num(pop.suits.Diamonds)
   local possible=clubs>0 and (other>0 or pop.wild>0 or smear) or pop.wild>0 and (other>0 or pop.wild>1)
   if not possible then value=0 elseif smear and clubs>0 then value=57 end
  end
 elseif k=='j_photograph' then value=faces>0 and 18+40*faces or 0;known=true
 elseif k=='j_triboulet' then value=pop.known and (pop.kq>0 and 22+20*min(4,p.scoring_cards*pop.kq/pop.size) or 0) or 22;known=true
 elseif k=='j_hanging_chad' then value=38+8*min(3,max(0,num(a.extra,2)))+min(18,pop.quality*3);known=true
 elseif k=='j_mime' then value=pop.known and min(78,held*18+min(p.held,pop.gold)*5+(has(s,'j_shoot_the_moon') and min(p.held,pop.ranks[12] or 0)*10 or 0)) or 12;known=true
 elseif k=='j_dusk' or k=='j_acrobat' then value=base*(p.hands<=1 and 1 or 0.45)
 elseif k=='j_card_sharp' then value=p.hands<=1 and 0 or base*0.65
 elseif k=='j_selzer' then value=num(a.extra,10)>0 and base*min(1,num(a.extra,10)/3) or 0
 elseif k=='j_drunkard' or k=='j_merry_andy' then value=p.discards>0 and (k=='j_drunkard' and 42 or 54)+(has(s,'j_yorick') and 20 or 0) or 0;known=true
 elseif k=='j_delayed_grat' or k=='j_banner' then value=0
 elseif k=='j_space' then value=12+6*future;known=true
 elseif k=='j_hiker' then value=10+future*4*min(4,p.scoring_cards);known=true
 elseif k=='j_splash' then value=6+5*(5-p.scoring_cards);known=true
 elseif k=='j_8_ball' then value=pop.known and min(35,(pop.ranks[8] or 0)*4)*min(1,future) or 8;known=true
 elseif k=='j_sixth_sense' then value=p.hands>1 and (pop.ranks[6] or 0)>0 and #(s.consumeables or {})<num(s.consumable_limit,2) and 20 or 0;known=true
 elseif k=='j_superposition' or k=='j_seance' then value=24*M.match(p,k=='j_superposition' and 'Straight' or 'Straight Flush');if k=='j_superposition' and pop.known and not pop.ranks[14] then value=0 end;known=true
 elseif k=='j_marble' then value=has(s,'j_hologram') and 35 or has(s,'j_stone') and 28 or 6;known=true
 elseif k=='j_midas_mask' then value=has(s,'j_ticket') and 22*faces or 4*faces;known=true
 elseif k=='j_erosion' or k=='j_flash' then value=6;known=true
 elseif k=='j_chaos' then value=8+10*min(3,future);known=true
 elseif k=='j_hallucination' then value=8+5*future;known=true
 elseif k=='j_ring_master' then value=(has(s,'j_blueprint') or has(s,'j_brainstorm')) and 22 or 12;value=value*min(1,future);known=true
 elseif k=='j_astronomer' then value=8+8*future;known=true
 elseif k=='j_diet_cola' then value=10*min(1,future);known=true
 elseif k=='j_matador' then value=0;known=true
 elseif k=='j_oops' then value=min(30,pop.lucky*6+(has(s,'j_bloodstone') and 15 or 0))-min(35,pop.glass*5);known=true
 elseif k=='j_riff_raff' then local slots=max(0,num(s.joker_limit,5)-#(s.jokers or {})-(owned(s,c) and 0 or 1));value=slots>0 and 14+8*min(2,slots) or 0;known=true
 elseif k=='j_vagabond' then value=num(s.dollars)>num(e.dollars,4) and 0 or #(s.consumeables or {})>=num(s.consumable_limit,2) and 0 or 32
 elseif k=='j_cartomancer' then value=#(s.consumeables or {})<num(s.consumable_limit,2) and 25+8*future or 4
 elseif k=='j_baseball' then local count=0;for _,j in ipairs(s.jokers or {})do if j.rarity==2 then count=count+1 end end;value=count>0 and 18+18*min(4,count) or 0
 elseif k=='j_turtle_bean' then value=12+8*max(0,num(e.h_size,5))
 elseif k=='j_troubadour' then value=p.hands<=1 and 8 or 38
 elseif k=='j_shortcut' then value=8+54*M.match(p,'Straight')
 elseif k=='j_smeared' then value=8+54*M.match(p,'Flush')
 elseif k=='j_four_fingers' then value=8+54*min(1,M.match(p,'Straight')+M.match(p,'Flush')) end
 local strength,handled=M.strength(s,c,p)
 if handled then value=value+strength end
 return {value=value,known=known,reason=reason,profile=p}
end
return M
