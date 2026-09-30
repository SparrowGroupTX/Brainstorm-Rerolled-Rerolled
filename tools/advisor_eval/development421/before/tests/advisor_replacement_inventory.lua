-- Manufactured endpoint comparisons. No player state, source game or RNG.
local Strategy=dofile(ADVISOR_STRATEGY_MODULE or 'Brainstorm/Advisor/strategy.lua')
local api=Strategy.shop_sequence_api
local checks=0
local function ok(v,label) checks=checks+1;assert(v,label) end
local function near(a,b,label) ok(math.abs(a-b)<0.0000001,label..': '..a..' ~= '..b) end
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
local function encode(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys,r={},{};for k in pairs(v)do keys[#keys+1]=k end;table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  for _,k in ipairs(keys)do r[#r+1]=encode(k)..'='..encode(v[k])end;return '{'..table.concat(r,';')..'}'
end
local function joker(key,name,sell,extra)
  local c={key=key,name=name,cost=sell*2,sell_cost=sell,ability={name=name,set='Joker',x_mult=1}}
  for k,v in pairs(extra or {})do c.ability[k]=v end;return c
end
local function planet(key,negative)
  return {key=key,cost=3,sell_cost=1,edition=negative and {negative=true,type='negative'} or nil,ability={set='Planet'}}
end
local function state(inventory)
  local s={phase='shop',ante=4,win_ante=8,dollars=3,bankrupt_at=0,joker_limit=3,consumable_limit=2,
    jokers={joker('j_perkeo','Perkeo',10),joker('j_yorick','Yorick',10,{x_mult=12,yorick_discards=12,extra={discards=23,xmult=1}}),
      joker('j_joker','Joker',1,{mult=4})},consumeables=inventory or {},playing_cards={},hand={},deck={},shop_jokers={},shop_booster={},shop_vouchers={},
    hands={Pair={level=4,played=12,chips=55,mult=5,l_chips=15,l_mult=1}},interest_cap=25,modifiers={},reroll_cost=5}
  for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'})do for r=2,14 do
    s.playing_cards[#s.playing_cards+1]={id=#s.playing_cards+1,rank=r,suit=suit,ability={}}
  end end
  s.shop_jokers={joker('j_blueprint','Blueprint',5,{effect='Copycat'})};return s
end
local original_random=math.random;math.random=function()error('Replacement valuation must not consume RNG')end
local unit=8+65*(15/55+1/5)
local empty=state()
near(api.replacement_value(empty),api.build_value(empty),'empty inventory has zero replacement premium')
local chosen=Strategy.advise(empty)
ok(chosen.action.kind=='sell' and chosen.action.index==1,'empty Perkeo can still fund a sufficiently strong visible replacement')
local s=state({planet('c_mercury'),planet('c_mercury',true)})
local encoded=encode(s)
local total,inventory=Strategy.inventory_value(s)
near(inventory.direct,2*unit,'ordinary and Negative sources both retain direct utility')
near(inventory.future,2*unit,'two identical sources do not double the number of Perkeo events')
near(api.replacement_value(s)-api.build_value(s),4*unit,'full inventory enters replacement utility exactly once')
chosen=Strategy.advise(s)
ok(chosen.action.kind=='leave_shop','valuable held Planet copying can outweigh the same visible replacement')
ok(encode(s)==encoded,'valuation and advice preserve every source input')
ok(encode(chosen)==encode(Strategy.advise(s)),'replacement advice is deterministic')
local pack=copy(s);pack.phase='pack';pack.pack_choices=1;pack.pack_cards=pack.shop_jokers;pack.shop_jokers={}
pack.jokers[2].ability.eternal=true;pack.jokers[3].ability.eternal=true
ok(Strategy.advise(pack).action.kind=='skip_pack','a revealed free pack copy still accounts for losing the held Perkeo engine')
pack.consumeables={}
local pack_action=Strategy.advise(pack).action
ok(pack_action.kind=='sell' and pack_action.index==1 and pack_action.followup.kind=='choose','empty Perkeo can still fund a concrete pack replacement')
local sold=assert(api.after_joker_sale(s,1))
local endpoint=assert(api.after_joker_purchase(sold,s.shop_jokers[1]))
local row_delta=api.build_value(endpoint)-api.build_value(s)
near(api.replacement_value(endpoint)-api.replacement_value(s)-row_delta,-2*unit,'selling Perkeo loses future copies but retains both owned Planets')
ok(#endpoint.consumeables==2 and endpoint.consumeables[2].edition.negative,'replacement keeps the entire Negative inventory')

local observed=copy(s);observed.used_vouchers={v_observatory=true}
local _,before=Strategy.inventory_value(observed)
near(before.held,30,'two held matching Planets retain the nonlinear Observatory multiplier')
near(before.future,2*unit+67.5,'two copy events include the nonlinear Observatory increase')
local gone=assert(api.after_joker_sale(observed,1))
local _,after=Strategy.inventory_value(gone)
near(after.held,before.held,'selling a Joker cannot erase existing Observatory inventory')
near(after.future,0,'no Perkeo remains to create later copies')
near(api.replacement_value(gone)-api.replacement_value(observed)-(api.build_value(gone)-api.build_value(observed)),
  -before.future,'the actual nonlinear future inventory loss participates in the sale comparison')

local copies=state({planet('c_mercury',true)})
copies.jokers={joker('j_blueprint','Blueprint',5,{effect='Copycat'}),joker('j_perkeo','Perkeo',10),copies.jokers[2]}
local _,info=Strategy.inventory_value(copies)
ok(info.effects==2 and info.events==4,'a valid Blueprint chain counts supported Perkeo copying')
local no_blueprint=assert(api.after_joker_sale(copies,1))
near(api.replacement_value(no_blueprint)-api.replacement_value(copies)-(api.build_value(no_blueprint)-api.build_value(copies)),
  -2*unit,'selling the copy Joker also loses its actual copying opportunities')

local invalid=copy(s);invalid.jokers[1].ability.eternal=true
ok(Strategy.advise(invalid).action.kind~='sell','inventory utility does not relax eternal sale legality')
invalid=copy(empty);invalid.dollars=-20
ok(Strategy.advise(invalid).action.kind~='sell','inventory utility does not fund an unaffordable replacement')
local inactive=copy(s);inactive.jokers[1].ability.perishable=true;inactive.jokers[1].ability.perish_tally=0;inactive.jokers[1].debuff=true
near(api.replacement_value(inactive)-api.build_value(inactive),2*unit,'expired Perkeo keeps source inventory but receives no future-copy credit')
local mixed=state({planet('c_mercury'),planet('c_jupiter',true),planet('c_mercury',true),
  {key='c_hermit',edition={negative=true},ability={set='Tarot'}}})
local mixed_copy=encode(mixed)
near(api.replacement_value(mixed)-api.build_value(mixed),Strategy.inventory_value(mixed),'mixed inventories retain the whole existing copying distribution')
ok(encode(mixed)==mixed_copy,'mixed inventory valuation neither truncates nor rewrites Negative slots')

-- New replacement bookkeeping must not change the sequence API: it already
-- adds inventory endpoints itself, including Planet consumption credits.
local sequence_merit=api.build_value(endpoint)-api.build_value(s)+Strategy.inventory_value(endpoint)-Strategy.inventory_value(s)
near(sequence_merit,api.replacement_value(endpoint)-api.replacement_value(s),'sequence endpoint merit counts inventory exactly once')
math.random=original_random
print('advisor_replacement_inventory: '..checks..' checks passed')
