-- Manufactured public rows, not a captured-run replay.
local R=dofile('Brainstorm/Advisor/joker_retirement.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local Snapshot=F.Snapshot
S.joker_retirement=R
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function state()
 local s=F.state();s.dollars=130;s.bankrupt_at=0;s.rental_rate=3;s.joker_limit=5;s.modifiers={}
 s.hand={};s.deck={};s.hands={};s.shop_jokers={};s.shop_vouchers={};s.shop_booster={};s.reroll_cost=5
 s.next_blind={key='bl_wheel',chips=1000};s.consumeables={F.observe(F.raw('c_hermit',40,true))};s.consumable_limit=3
 s.jokers={F.joker('j_blueprint','Blueprint','copy'),F.joker('j_perkeo','Perkeo','generator'),
  F.joker('j_greedy_joker','Greedy Joker','cargo'),F.joker('j_trio','The Trio','expired'),F.joker('j_yorick','Yorick','scaling')}
 s.jokers[4].ability.perishable=true;s.jokers[4].ability.perish_tally=0;s.jokers[4].ability.rental=true;s.jokers[4].debuff=true
 s.completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
  eligibility={eligible=true,status='eligible'},by_key={j_trio={status='complete'},j_greedy_joker={status='missing'}}}
 return s
end
do
 local s=state();local before=Snapshot.fingerprint(s);local a,d=R.suggest(s,S)
 check(a and a.action.kind=='sell' and a.action.index==4,'sell a completed dead rental without requiring an incoming offer')
 check(d.complete and d.evaluations==0 and d.additional_score_calls==0,'full structural comparison adds no score work')
 check(d.rental_saved==3 and d.sale_proceeds==2 and d.copy_targets_unchanged and d.inventory_unchanged,'exact cash/copy/inventory receipt')
 check(Snapshot.fingerprint(s)==before,'input untouched')
 local ctx={readiness=function()error('Retirement must not need an unsupported concealed-blind forecast')end}
  a=S.advise(s,{shop_scoring=ctx});check(a.action.kind=='sell' and a.action.index==4,'real shop advice exposes the standalone sale before scoring')
 local Decision=dofile('Brainstorm/Advisor/decision.lua')
 local result=Decision.run(s,{strategy=S,joker_retirement=R,shop_scoring={new=function()error('No unrelated shop family before this exact disposal')end}})
 check(result.action.kind=='sell' and result.evaluations==0 and result.retirement_diagnostics.complete,'public decision performs the exact sale without spending the shop budget')
 -- Gold metadata exempts no useful owned target: disabled missing cards still
 -- count towards an eligible future sticker award.
 for _,edit in ipairs({
  function(t)t.completionist_goal.by_key.j_trio.status='missing'end,
  function(t)t.completionist_goal.by_key.j_trio.status='unknown'end,
  function(t)t.completionist_goal.eligibility.eligible=false end,
  function(t)t.jokers[4].ability.perish_tally=1 end,
  function(t)t.jokers[4].ability.perishable=false end,
  function(t)t.jokers[4].debuff=false end,
  function(t)t.jokers[4].ability.eternal=true end,
  function(t)t.jokers[4].edition={negative=true}end,
  function(t)t.jokers[4].pinned=true end,
  function(t)t.jokers[1].face_down=true end,
  function(t)t.jokers[3].key='j_abstract'end,
  function(t)t.jokers[3].key='j_swashbuckler'end,
  function(t)t.jokers[3].key='j_campfire'end,
  function(t)t.jokers[3].key='unknown_effect'end,
  function(t)t.next_blind.key='bl_final_leaf'end,
  function(t)t.next_blind.key='bl_final_heart'end,
  function(t)t.next_blind.key='bl_final_acorn'end,
  function(t)t.next_blind.key='bl_small';t.blind_choices={Boss='bl_final_leaf'}end,
  function(t)t.next_blind.key='bl_big';t.round_resets={blind_choices={Boss='bl_final_heart'}}end,
  function(t)t.jokers[2].edition={negative=true,unknown_callback=true}end,
  function(t)t.consumeables[1].key='c_ankh';t.consumeables[1].ability.set='Spectral'end,
  function(t)t.consumeables[1].key='c_temperance'end,
  function(t)t.consumeables[1].key='c_fool';t.last_tarot_planet='c_temperance'end,
  function(t)t.consumeables[1].key='c_fool';t.last_tarot_planet=nil end,
  function(t)t.modifiers.all_eternal=true end,
  function(t)t.ordering_safe=false end,
  function(t)t.modifiers.minus_hand_size_per_X_dollar=5;t.dollars=129;t.hand_size=8 end,
 })do local t=state();edit(t);local no=R.suggest(t,S);check(not no,'unsupported/valuable/temporary/cargo resources are preserved')end
 local t=state();t.jokers[1],t.jokers[3]=t.jokers[3],t.jokers[1]
 check(not R.suggest(t,S),'selling the inactive target cannot silently redirect Blueprint to a different effect')
 t=state();t.consumeables[1].key='c_temperance';t.consumeables[1].ability.extra=50;t.consumeables[1].ability.consumeable.extra=50;t.jokers[2].sell_cost=50
 check(R.suggest(t,S),'saturated Temperance retains its entire capped value')
 t.consumeables[1].ability.extra=60;t.consumeables[1].ability.consumeable.extra=60
 check(not R.suggest(t,S),'a noncanonical cap is not silently treated as saturated at50')
 t=state();t.consumeables[1].key='c_fool';t.last_tarot_planet='c_pluto'
 check(R.suggest(t,S),'known unaffected Fool copy preserves inventory')
 local after=S.shop_sequence_api.after_joker_sale(s,4)
 check(#after.jokers==4 and after.joker_limit==5 and after.dollars==132,'actual public transition frees a normal slot and receives exact proceeds')
end
print('advisor_joker_retirement: '..checks..' checks passed')
