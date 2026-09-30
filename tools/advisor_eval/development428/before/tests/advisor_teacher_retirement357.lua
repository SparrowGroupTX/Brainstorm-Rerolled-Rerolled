-- Manufactured teacher-state contracts; no recorded policy replay or game I/O.
local R=dofile('Brainstorm/Advisor/joker_retirement.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
S.joker_retirement=R
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function state()
 local s=F.state()
 s.teacher_profile='perkeo_yorick_win_v1';s.ante=6;s.win_ante=8;s.dollars=92;s.bankrupt_at=0;s.rental_rate=3
 s.joker_limit=5;s.modifiers={};s.hand={};s.deck={};s.hands={}
 s.shop_jokers={};s.shop_vouchers={};s.shop_booster={};s.reroll_cost=5
 s.next_blind={key='bl_small',boss=false,chips=60000,ante=6};s.blind_choices={Boss='bl_wheel'}
 s.consumeables={F.observe(F.raw('c_hermit',40,true))};s.consumable_limit=3
 s.jokers={F.joker('j_blueprint','Blueprint','copy'),F.joker('j_yorick','Yorick','scaling'),
  F.joker('j_greedy_joker','Greedy Joker','cargo'),F.joker('j_trio','The Trio','expired'),
  F.joker('j_perkeo','Perkeo','generator')}
 local dead=s.jokers[4];dead.sell_cost=1;dead.debuff=true
 dead.ability.perishable=true;dead.ability.perish_tally=0;dead.ability.rental=true
 s.collection_progress={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
  eligibility={eligible=true,status='eligible'},by_key={j_trio={status='complete'},j_greedy_joker={status='missing'}}}
 return s
end
do
 local s=state();local key=F.Snapshot.fingerprint(s);local a,d=R.suggest(s,S)
 check(a and a.action.kind=='sell' and a.action.index==4,'explicit win-first teacher retires the expired completed rental')
 check(d.complete and d.evaluations==0 and d.additional_score_calls==0,'the existing exact disposal spends no score allowance')
 check(d.rental_saved==3 and d.sale_proceeds==1 and d.copy_targets_unchanged and d.inventory_unchanged,
  'retirement preserves the live copy row and full Negative inventory')
 check(F.Snapshot.fingerprint(s)==key and s.completionist_goal==nil,'teacher ledger remains informational and input is unchanged')
 local result=D.run(s,{strategy=S,joker_retirement=R,shop_scoring={new=function()error('Exact disposal precedes shop scoring')end}})
 check(result.action.kind=='sell' and result.action.index==4 and result.evaluations==0,'decision exposes disposal before unrelated comparisons')
 check(S.advise(s,{shop_scoring={readiness=function()error('Exact disposal does not need readiness')end}}).action.kind=='sell',
  'ordinary strategy entry also sees teacher retirement')
 for _,edit in ipairs({
  function(t)t.teacher_profile=nil end,
  function(t)t.teacher_profile='other_teacher' end,
  function(t)t.collection_progress=nil end,
  function(t)t.collection_progress.schema=2 end,
  function(t)t.collection_progress.goal='wins' end,
  function(t)t.collection_progress.metadata_status='unknown' end,
  function(t)t.collection_progress.catalog_status='unknown' end,
  function(t)t.collection_progress.held_status='unknown' end,
  function(t)t.collection_progress.eligibility.eligible=false end,
  function(t)t.collection_progress.by_key.j_trio.status='unknown' end,
  function(t)t.collection_progress.by_key.j_trio.status='missing' end,
  function(t)t.completionist_goal={} end,
  function(t)t.completionist_goal=false end,
  function(t)t.phase='hand' end,
  function(t)t.jokers[4].ability.perish_tally=1 end,
  function(t)t.jokers[4].debuff=false end,
  function(t)t.jokers[4].ability.rental=false end,
  function(t)t.jokers[4].ability.eternal=true end,
  function(t)t.jokers[4].pinned=true end,
  function(t)t.jokers[4].edition={negative=true} end,
  function(t)t.jokers[3].key='j_swashbuckler' end,
  function(t)t.jokers[3].key='j_campfire' end,
  function(t)t.jokers[3].key='unknown_callback' end,
  function(t)t.jokers[1].face_down=true end,
  function(t)t.ordering_safe=false end,
  function(t)t.next_blind.key='bl_final_leaf' end,
  function(t)t.blind_choices.Boss='bl_final_heart' end,
  function(t)t.blind_choices.Boss='bl_final_acorn' end,
  function(t)t.consumeables[1].key='c_temperance';t.consumeables[1].ability.extra=50;t.consumeables[1].ability.consumeable.extra=50 end,
  function(t)t.consumeables[1].key='c_fool';t.last_tarot_planet='c_temperance' end,
  function(t)t.consumeables[1].key='c_ankh';t.consumeables[1].ability.set='Spectral' end,
  function(t)t.jokers[1],t.jokers[3]=t.jokers[3],t.jokers[1] end,
 })do local t=state();edit(t);check(not R.suggest(t,S),'explicit mode, verified ledger, full effects and resource guards remain')end
 local ordinary=state();ordinary.teacher_profile=nil;ordinary.completionist_goal=ordinary.collection_progress;ordinary.collection_progress=nil
 check(R.suggest(ordinary,S),'ordinary collection retirement remains available')
end
print('advisor_teacher_retirement357: '..checks..' manufactured checks passed')
