-- Manufactured public constructor/unused-copy dependency family, no source run.
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local H,S=F.Hold,F.Snapshot;S.gold_tarot_hold=H
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local specs={
 {'c_temperance','Temperance','Joker Money',15,{extra=50}},
 {'c_sun','The Sun','Suit Conversion',20,{suit_conv='Hearts',max_highlighted=3,mod_num=3}},
 {'c_moon','The Moon','Suit Conversion',19,{suit_conv='Clubs',max_highlighted=3,mod_num=3}},
 {'c_wheel_of_fortune','The Wheel of Fortune','Joker Edition',11,{extra=4}},
 {'c_hanged_man','The Hanged Man','Card Removal',13,{remove_card=true,max_highlighted=2,mod_num=2}},
}
-- Other vanilla key/name identities use the same generic constructor proof;
-- their use-only data here is manufactured and is never executed or credited.
for i,spec in ipairs({{'c_fool','The Fool'},{'c_high_priestess','The High Priestess'},
 {'c_empress','The Empress'},{'c_emperor','The Emperor'},{'c_heirophant','The Hierophant'},
 {'c_lovers','The Lovers'},{'c_chariot','The Chariot'},{'c_justice','Justice'},
 {'c_strength','Strength'},{'c_death','Death'},{'c_devil','The Devil'},{'c_tower','The Tower'},
 {'c_star','The Star'},{'c_judgement','Judgement'},{'c_world','The World'}}) do
  specs[#specs+1]={spec[1],spec[2],'Manufactured unused config',i,{mod_num=2,max_highlighted=2}}
end
local function raw(spec,id,negative)
  local card=F.raw('c_hermit',id,negative);local center=card.config.center
  center.key,center.name,center.effect,center.order,center.config=spec[1],spec[2],spec[3],spec[4],S.copy(spec[5])
  card.ability.name,card.ability.effect,card.ability.order=center.name,center.effect,center.order
  card.ability.extra=S.copy(center.config.extra);card.ability.consumeable=S.copy(center.config)
  if spec[1]=='c_temperance' then card.ability.money=30 end
  card.pinned=nil;return card
end
local function observe(c)
  G={P_CENTERS={[c.config.center.key]=c.config.center}}
  return S.card(c)
end
math.random=function() error('No RNG belongs in held Tarot qualification') end;pseudorandom=math.random;pseudoseed=math.random
for _,spec in ipairs(specs) do
  for _,negative in ipairs({false,true}) do
    local c=raw(spec,1,negative);local before=S.fingerprint(c);local observed=observe(c)
    check(observed.tarot_hold_source.supported,'unused ordinary/Negative constructor '..spec[1])
    check(observed.tarot_hold_source.constructor_policy=='plain_data_unused_tarot','use is deliberately unmodeled')
    check(S.fingerprint(c)==before,'capture preserves public original')
    local s=F.state();s.consumeables={observed};s.consumable_limit=negative and 3 or 2
    local r,why=H.certify(s);check(r,why or 'new source class certifies')
    check(r.generated_future_utility_credit==0 and r.generated_resale_credit==0,'no use/resale utility invented')
    check(r.cash_after==s.dollars and r.first_hand_consumable_actions==0,'no cash payout or Tarot use credited')
  end
  local changes={
    function(c)c.config.center.calculate=function()end end,
    function(c)c.config.center.config.h_size=1;c.ability.consumeable.h_size=1 end,
    function(c)c.config.center.config.d_size=1;c.ability.consumeable.d_size=1 end,
    function(c)c.ability.h_size=1 end,
    function(c)c.config.center.config.Xmult=2;c.ability.consumeable.Xmult=2 end,
    function(c)c.ability.consumeable.extra=999 end,
    function(c)c.config.center.name='Credit Card';c.ability.name='Credit Card' end,
    function(c)c.config.center.key='c_modded' end,
    function(c)c.config.center.set='Planet';c.ability.set='Planet' end,
    function(c)c.edition={foil=true,type='foil',chips=50} end,
    function(c)c.pinned='false' end,
    function(c)c.config.center.config.hidden=function()end;c.ability.consumeable.hidden=c.config.center.config.hidden end,
  }
  for i,change in ipairs(changes) do
    local c=raw(spec,1,true);change(c);local proof=observe(c).tarot_hold_source
    check(not proof or not proof.supported,'invalid held constructor '..spec[1]..':'..i)
  end
end
for _,money in ipairs({-1,51,'30',false}) do
  local c=raw(specs[1],1,true);c.ability.money=money
  check(not observe(c).tarot_hold_source.supported,'malformed Temperance display value rejects')
end
local s=F.state();s.consumeables={};s.consumable_limit=25
for i=1,25 do s.consumeables[i]=observe(raw(specs[1+(i-1)%#specs],i,true)) end
local before=S.fingerprint(s);local receipt,why=H.certify(s)
check(receipt,why or '25 held mixed unused Tarots qualify')
check(receipt.inventory_count_after==27 and receipt.capacity_after==27,'full inventory preserves free capacity after two Negative copies')
check(S.fingerprint(s)==before,'whole original pool stays unchanged')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
s.jokers={F.joker('j_fortune_teller','Fortune Teller')};s.consumeable_usage_total={tarot=9}
s.hand={{id='p1',rank=2,nominal=2,suit='Clubs',ability={}},{id='p2',rank=2,nominal=2,suit='Hearts',ability={}}}
s.playing_cards=S.copy(s.hand);s.deck={};s.hands={Pair={level=1,chips=10,mult=2,l_chips=15,l_mult=1,played=0}}
s.hand_size=2;s.hand_limit=5;s.hands_left=4;s.discards_left=3;s.current_round={};s.probabilities={normal=1};s.used_vouchers.v_observatory=true
local initial=Scoring.score(s,{1,2})
for i,spec in ipairs(specs) do
  local after=S.copy(s);after.consumeables[#after.consumeables+1]=observe(raw(spec,100+i,true));after.consumable_limit=after.consumable_limit+1
  if spec[1]=='c_temperance' then after.consumeables[#after.consumeables].ability.money=0 end
  check(Scoring.score(after,{1,2}).score==initial.score,'held generated '..spec[1]..' has no score or Tarot-usage value')
end
local changed=F.raw('c_magician',1,true);changed.config.center.config.mod_num=3;changed.ability.consumeable.mod_num=3
check(not observe(changed).tarot_hold_source.supported,'previous exact Magician definition remains strict')
print('PASS expanded unused Tarot source family '..checks..' checks')
