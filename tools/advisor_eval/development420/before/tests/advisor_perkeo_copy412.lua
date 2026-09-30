-- Invented public rows/decks and paired receipts, never captured-state replay.
local P='Brainstorm/Advisor/';local S=dofile(P..'strategy.lua');local Snap=dofile(P..'snapshot.lua')
local Shop=dofile(P..'shop_scoring.lua');local Seq=dofile(P..'shop_sequences.lua')
local checks,failures=0,0
local function check(v,m)checks=checks+1;if not v then failures=failures+1;print('FAIL: '..m)end end
local function j(key,id,a)
 a=a or {};a.set='Joker';a.name=({j_perkeo='Perkeo',j_yorick='Yorick',j_blueprint='Blueprint',j_brainstorm='Brainstorm'})[key] or key
 return {key=key,id=id,name=a.name,ability=a,blueprint_compat=true,cost=6,sell_cost=8}
end
local function state(key)
 return {phase='shop',teacher_profile='perkeo_yorick_win_v1',ante=4,win_ante=8,
 dollars=28,bankrupt_at=0,joker_limit=2,consumable_limit=2,
 jokers={j('j_yorick','source',{x_mult=4,eternal=true,yorick_discards=8,extra={discards=23,xmult=1}}),j('j_perkeo','victim',{})},
 shop_jokers={j(key or 'j_blueprint','incoming',{})},shop_vouchers={},shop_booster={},
 consumeables={{id='negative_death',key='c_death',edition='negative',ability={set='Tarot',name='Death'}}},
 hand={},deck={},playing_cards={},hands={},hand_size=5,hand_limit=5,round_resets={hands=4,discards=3},current_round={},
 modifiers={},probabilities={normal=1},blind={key='bl_small',name='Small Blind'},
 next_blind={key='bl_big',label='Big',ante=4,chips=1800},interest_cap=25,reroll_cost=5}
end
local function endpoint(s)
 local after=assert(Seq.transition(s,{kind='sell',area='jokers',index=2},{strategy=S,shop_scoring=Shop}))
 return assert(Seq.transition(after,{kind='buy',area='shop_jokers',index=1},{strategy=S,shop_scoring=Shop}))
end
local function worlds()
 local rows={};for i=1,4 do rows[i]={clear=true,progress=1}end
 return {samples=4,complete=true,supported=true,known_mechanics=true,selected={clearing_samples=4,worlds=rows}}
end
local function evidence(key)
 return {samples=4,ratio=4,adjustment=100,before_mean=2100,after_mean=8400,before_target=1800,after_target=1800,
 complete_finishing=true,before_finishing=worlds(),after_finishing=worlds(),
 before_readiness={supported=true,status='sampled_safe',target=1800,opening_mean=2100},
 after_readiness={supported=true,status='sampled_safe',target=1800,opening_mean=8400},
 common_worlds={kind='shop_four_common_worlds_v1',samples=4,world_ids={1,2,3,4},family_key='invented412'},
 after_ordering={samples=4,order=key=='j_brainstorm' and {1,2} or {2,1}},reason='Invented complete common-world comparison.'}
end
local function context(key)
 local c={evaluations=0,truncated=false,max_evaluations=50000}
 function c:compare()self.evaluations=self.evaluations+4;return evidence(key)end
 function c:readiness()return evidence(key).before_readiness end
 return c
end
for _,key in ipairs({'j_blueprint','j_brainstorm'}) do
 local s=state(key);local after=endpoint(s);local e=evidence(key);local fp=Snap.fingerprint(s)
 check(S.joker_admission(s,s.shop_jokers[1],after,e),key..' may replace sole Perkeo for retained Yorick')
 check(S.shop_sequence_admission(s,after,e),key..' full sequence endpoint admits Perkeo exchange')
 check(S.supported_copy_priority(s,s.jokers[2],s.shop_jokers[1],after,e),key..' strong copy priority survives Perkeo sale')
 local plan=S.copy_acquisition(s,context(key))
 check(plan and plan.action.kind=='sell' and plan.action.index==2,key..' focused acquisition enumerates and selects Perkeo')
 if plan then
  local sold=assert(Seq.transition(s,plan.action,{strategy=S,shop_scoring=Shop}))
  local fresh=S.copy_acquisition(sold,context(key))
  check(fresh and fresh.action.kind=='buy' and fresh.action.index==1,key..' fresh advice completes the visible copy purchase')
 end
 local exhausted={truncated=true,evaluations=1,max_evaluations=1,compare=function()return nil end}
 check(not S.copy_acquisition(s,exhausted),key..' exhausted proof cannot publish a sale')
 local ordinary=S.advise(s,{shop_scoring=context(key)})
 check(ordinary.action.kind=='sell' and ordinary.action.index==2,key..' ordinary direct arbitration admits exchange')
 local trace_context=context(key);S.advise(s,{shop_scoring=trace_context})
 local public=dofile(P..'player_journal.lua').compact_replacement_review({shop_diagnostics={replacements=trace_context.replacement_diagnostics}})
 local identified=false
 for _,r in ipairs(public and public.candidates or {})do if r.sale_id=='victim' and r.offer_id=='incoming' and r.reason=='perkeo_yorick_copy_exchange' then identified=true end end
 check(identified,key..' named public receipt identifies actual Perkeo/copy exchange')
 local pack=Snap.copy(s);pack.phase='pack';pack.pack_type='BUFFOON_PACK';pack.pack_choices=1;pack.pack_cards=pack.shop_jokers;pack.shop_jokers={}
 local packed=S.advise(pack,{shop_scoring=context(key)})
 check(packed.action.kind=='sell' and packed.action.index==2,key..' full Buffoon row admits Perkeo sale')
 local two=Snap.copy(pack);two.pack_cards[2]=j('j_cavendish','other',{x_mult=3})
 local competing=context(key)
 function competing:compare(before,after)
  local ev=evidence(key)
  for _,card in ipairs(after.jokers)do if card.id=='other' then ev.after_mean=1e12;ev.ratio=1e8 end end
  return ev
 end
 check(S.advise(two,{shop_scoring=competing}).action.kind~='sell',key..' reject initial sale when fresh endpoint ranking would choose another offer')
 local vacancy=Snap.copy(pack);table.remove(vacancy.jokers,2);vacancy.dollars=vacancy.dollars+8
 local choice=S.advise(vacancy,{shop_scoring=context(key)})
 check(choice.action.kind=='choose' and choice.action.index==1,key..' fresh vacant row chooses the intended revealed copy')
 local seq=context(key)
 function seq:readiness()return {supported=true,status='sampled_deficit',target=1800,opening_mean=1000}end
 local _,diagnostic=Seq.suggest(s,{strategy=S,shop_scoring=Shop},nil,seq);local admitted=false
 for _,p in ipairs(diagnostic.plans or {})do if p.gold_slot_admitted and #p.actions==2 and p.actions[1].kind=='sell' then admitted=true end end
 check(diagnostic.complete and admitted,key..' actual sequence graph includes admitted exchange')
 check(Snap.fingerprint(s)==fp and after.consumeables[1].id=='negative_death',key..' held Negative inventory survives sale')
 local function reject(label,change)
  local x=state(key);local a=endpoint(x);local ev=evidence(key);change(x,a,ev)
  check(not S.joker_admission(x,x.shop_jokers[1],a,ev),key..' rejects '..label)
 end
 reject('missing Yorick',function(x,a) x.jokers[1].key='j_joker';a.jokers[1].key='j_joker' end)
 reject('unscaled Yorick',function(x,a)x.jokers[1].ability.x_mult=1;a.jokers[1].ability.x_mult=1 end)
 reject('different physical Yorick',function(x,a)a.jokers[1].id='different' end)
 reject('debuffed source',function(x,a)a.jokers[1].debuff=true end)
 reject('Perishable source',function(x,a)a.jokers[1].ability.perishable=true end)
 reject('incompatible source',function(x,a)a.jokers[1].blueprint_compat=false end)
 reject('unknown source',function(x,a)a.jokers[1].unknown=true end)
 reject('temporary copy',function(x,a)a.jokers[2].ability.perishable=true;a.jokers[2].ability.perish_tally=5 end)
 reject('debuffed copy',function(x,a)a.jokers[2].debuff=true end)
 reject('permanently debuffed copy',function(x,a)a.jokers[2].ability.perma_debuff=true end)
 reject('concealed copy',function(x,a)a.jokers[2].identity_redacted=true end)
 reject('no new physical copy',function(x,a)x.jokers[1].id='incoming' end)
 reject('unaffordable upkeep',function(x,a)a.jokers[2].ability.rental=true;a.dollars=0 end)
 reject('uncertain evidence',function(x,a,ev)ev.uncertain=true end)
 reject('incomplete evidence',function(x,a,ev)ev.complete_finishing=false end)
 reject('unsupported mechanics',function(x,a,ev)ev.after_finishing.known_mechanics=false end)
 reject('one losing world',function(x,a,ev)ev.after_finishing.selected.worlds[2].clear=false end)
 reject('wrong paired IDs',function(x,a,ev)ev.common_worlds.world_ids={2,1,3,4} end)
 reject('no material scoring gain',function(x,a,ev)ev.ratio=1 end)
 reject('missing supported order',function(x,a,ev)ev.after_ordering=nil end)
 reject('loop or empty copy target',function(x,a,ev)ev.after_ordering.order=key=='j_brainstorm' and {2,1} or {1,2} end)
 reject('invalid permutation',function(x,a,ev)ev.after_ordering.order={1,1} end)
 reject('pinned illegal reorder',function(x,a,ev)a.jokers[2].pinned=true;ev.after_ordering.order={2,1} end)
 local funded=Snap.copy(s);funded.shop_jokers[1].ability.rental=true
 check(S.joker_admission(funded,funded.shop_jokers[1],endpoint(funded),e),key..' affordable rental copy permitted')
 local wrong=Snap.copy(s);wrong.jokers[1].ability.eternal=nil;local no_y=Snap.copy(after);table.remove(no_y.jokers,1)
 check(not S.shop_sequence_admission(wrong,no_y,e),key..' exception never waives sole Yorick loss')
end
local Score=dofile(P..'scoring.lua');local Finish=dofile(P..'blind_finishing.lua');local D=dofile(P..'decision.lua')
for _,n in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'})do Finish[n]=dofile(P..n..'.lua')end
Finish.strategy=S;Shop.blind_finishing=Finish;Shop.strategy=S;Shop.paired_deck=dofile(P..'paired_deck.lua')
for _,key in ipairs({'j_blueprint','j_brainstorm'})do
 local s=state(key);s.hands={Pair={level=4,played=6,chips=55,mult=5}}
 for i=1,12 do s.playing_cards[i]={id='invented:'..i,rank=7,suit='Clubs',nominal=7,ability={},enhancement='c_base'}end
 local r=D.run(s,{strategy=S,scoring=Score,shop_scoring=Shop,shop_sequences=Seq},nil,{prepared_scoring=false})
 check(r.action.kind=='sell' and r.action.index==2 and r.copy_acquisition_diagnostics and r.copy_acquisition_diagnostics.reason=='supported_copy_priority',key..' production scorer and arbitration choose Perkeo exchange')
 check(r.evaluations<=50000,key..' unchanged production work limit')
end
print('Perkeo copy412: '..checks..' checks, '..failures..' failures')
assert(failures==0,'Perkeo copy412 failures')
