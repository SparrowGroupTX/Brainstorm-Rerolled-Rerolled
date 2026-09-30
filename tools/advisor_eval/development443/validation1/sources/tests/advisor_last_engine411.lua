-- Independently invented rows and paired evidence; no captured game inputs.
local P='Brainstorm/Advisor/';local S=dofile(P..'strategy.lua')
local Snap=dofile(P..'snapshot.lua');local Seq=dofile(P..'shop_sequences.lua')
local Shop=dofile(P..'shop_scoring.lua')
local Journal=dofile(P..'player_journal.lua');local checks,failures=0,0
local function check(v,m) checks=checks+1;if not v then failures=failures+1;print('FAIL: '..m) end end
local function j(key,id,a)
 a=a or {};a.set='Joker';a.name=a.name or ({j_yorick='Yorick',j_perkeo='Perkeo',j_blueprint='Blueprint',j_joker='Joker',j_cavendish='Cavendish'})[key] or key
 return {key=key,id=id,ability=a,name=a.name,cost=3,sell_cost=7,blueprint_compat=true}
end
local function state(key)
 return {phase='shop',teacher_profile='perkeo_yorick_win_v1',ante=5,win_ante=8,
 dollars=32,bankrupt_at=0,joker_limit=2,consumable_limit=2,consumeables={},hand={},deck={},playing_cards={},
 jokers={j(key or 'j_yorick','engine',{x_mult=3,yorick_discards=9,extra={discards=23,xmult=1}}),
 j('j_joker','fixed',{eternal=true,mult=4})},
 shop_jokers={j('j_cavendish','offer',{x_mult=3})},shop_vouchers={},shop_booster={},
 hands={},hand_size=8,hand_limit=5,round_resets={hands=4,discards=3},current_round={},
 modifiers={},probabilities={normal=1},blind={key='bl_small',name='Small Blind'},
 next_blind={key='bl_big',label='Big',ante=5,chips=7000},interest_cap=25,reroll_cost=5}
end
local function endpoint(s,offer)
 local a=Snap.copy(s);table.remove(a.jokers,1);a.jokers[#a.jokers+1]=offer or a.shop_jokers[1];return a
end
local function worlds(clear)
 local rows={};for i=1,4 do rows[i]={clear=clear,progress=clear and 1 or .4} end
 return {complete=true,supported=true,known_mechanics=true,samples=4,
 selected={clearing_samples=clear and 4 or 0,worlds=rows}}
end
local function evidence(rescue)
 return {samples=4,ratio=4,adjustment=200,before_mean=3000,after_mean=12000,
 before_target=7000,after_target=7000,complete_finishing=true,
 before_finishing=worlds(not rescue),after_finishing=worlds(true),
 common_worlds={kind='shop_four_common_worlds_v1',samples=4,world_ids={1,2,3,4},family_key='invented411'},
 before_readiness={supported=true,status='sampled_safe'},after_readiness={supported=true,status='sampled_safe'},
 reason='Invented endpoint evidence, not a win probability.'}
end
local function context(rescue)
 local c={evaluations=0,truncated=false,max_evaluations=50000}
 function c:compare()self.evaluations=self.evaluations+4;return evidence(rescue)end
 function c:readiness()return {supported=true,status='sampled_safe',target=7000,opening_mean=3000}end
 return c
end
for _,key in ipairs({'j_yorick','j_perkeo'}) do
 for _,offer in ipairs({'j_cavendish','j_blueprint','j_brainstorm',key=='j_yorick' and 'j_perkeo' or 'j_yorick'}) do
  local s=state(key);local c=j(offer,'incoming',{x_mult=4});local a=endpoint(s,c)
  local ok,why=S.joker_admission(s,c,a,evidence(false))
  check(not ok and why and why.kind=='last_durable_engine_guard',key..' direct loss to '..offer)
  ok,why=S.shop_sequence_admission(s,a,evidence(false))
  check(not ok and why and why.kind=='last_durable_engine_guard',key..' sequence loss to '..offer)
 end
 local s=state(key);local offer=s.shop_jokers[1];local a=endpoint(s)
 check(S.joker_admission(s,offer,a,evidence(true)),key..' complete immediate rescue')
 for _,change in ipairs({function(e)e.uncertain=true end,function(e)e.incomplete=true end,
  function(e)e.complete_finishing=false end,function(e)e.common_worlds.world_ids[2]=3 end,
  function(e)e.after_finishing.selected.worlds[3].clear=false end,
  function(e)e.after_target=7001 end,function(e)e.after_finishing.known_mechanics=false end}) do
  local e=evidence(true);change(e);check(not S.joker_admission(s,offer,a,e),key..' incomplete rescue rejected')
 end
 s.next_blind={label='Boss',ante=8};check(S.joker_admission(s,offer,a,nil),key..' explicit final Boss exception')
 s.next_blind={label='Small',ante=8};check(not S.joker_admission(s,offer,a,nil),key..' final ante alone is not final Boss')
 s.teacher_profile=nil;check(S.joker_admission(s,offer,a,nil),key..' ordinary profile unchanged')
 s=state(key);s.jokers[1].ability.rental=true;check(not S.joker_admission(s,offer,endpoint(s,offer),nil),key..' rental still durable')
 s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=0
 check(S.joker_admission(s,offer,endpoint(s,offer),nil),key..' expired incumbent exception')
 s=state(key);local replacement=j(key,'upgraded',{x_mult=6})
 check(S.joker_admission(s,replacement,endpoint(s,replacement),nil),key..' same-engine upgrade admitted')
 check(S.shop_sequence_admission(s,endpoint(s,replacement),nil),key..' sale then same-engine upgrade admitted')
 s.jokers[3]=j(key,'duplicate',{x_mult=2});s.joker_limit=3
 -- Ramen now has its own discard-conflict acquisition guard. Use an ordinary
 -- perishable scorer to isolate duplicate-engine retention from that policy.
 for _,c in ipairs({offer,j('j_popcorn','temporary',{mult=20}),j('j_ice_cream','perishable',{extra={chips=85,chip_mod=5},perishable=true,perish_tally=1})}) do
  check(S.joker_admission(s,c,endpoint(s,c),nil),key..' retained duplicate permits replacement')
  check(S.shop_sequence_admission(s,endpoint(s,c),nil),key..' retained duplicate permits sequence')
 end
 for _,change in ipairs({function(c)c.debuff=true end,function(c)c.ability.perma_debuff=true end,
  function(c)c.ability.perishable=true;c.ability.perish_tally=5 end,
  function(c)c.unknown=true end,function(c)c.identity_redacted=true end,function(c)c.face_down=true end}) do
  local x=Snap.copy(s);change(x.jokers[3])
  check(not S.joker_admission(x,offer,endpoint(x,offer),nil),key..' unusable duplicate cannot waive last-engine loss')
 end
 local x=state(key);local fp=Snap.fingerprint(x);local c=context(false)
 local decision=S.advise(x,{shop_scoring=c});local row=c.replacement_diagnostics and c.replacement_diagnostics.candidates[1]
 check(decision.action.kind~='sell',key..' actual direct arbitration preserves last engine')
 check(row and not row.admitted and row.reason==(key=='j_yorick' and 'unsupported_sale' or 'last_durable_engine_guard'),key..' direct public rejection reason')
 check(Snap.fingerprint(x)==fp,key..' direct input unchanged')
 local sequence_context=context(false)
 function sequence_context:readiness()return {supported=true,status='sampled_deficit',target=7000,opening_mean=3000}end
 x.shop_jokers={j('j_brainstorm','copy_offer',{})}
 local proposal,diagnostic=Seq.suggest(x,{strategy=S,shop_scoring=Shop},nil,sequence_context)
 local rejected=false
 for _,p in ipairs(diagnostic.plans or {}) do
  if p.gold_slot_admission and p.gold_slot_admission.kind=='last_durable_engine_guard' and not p.gold_slot_admitted then rejected=true end
 end
 check(diagnostic.complete and rejected and not proposal,key..' complete sequence graph rejects last-engine copy trade')
 x.shop_jokers={j('j_cavendish','offer',{x_mult=3})}
 x.phase='pack';x.pack_cards=x.shop_jokers;x.shop_jokers={};x.pack_type='BUFFOON_PACK';x.pack_choices=1
 decision=S.advise(x,{shop_scoring=context(false)})
 check(decision.action.kind~='sell',key..' actual Buffoon arbitration preserves last engine')
 local public=Journal.compact_copy_death_review({strategy=decision,action=decision.action})
 row=public.pack and public.pack.candidates[1]
 check(row and not row.admitted and row.reason==(key=='j_yorick' and
  'The owned Joker cannot be safely sold or its sale does not free a legal slot.' or 'last_durable_engine_guard'),key..' pack rejection survives serialization')
 local rescued=S.advise(x,{shop_scoring=context(true)})
 check(key=='j_yorick' and rescued.action.kind~='sell' or key=='j_perkeo' and rescued.action.kind=='sell' and rescued.action.index==1,
  key..' actual pack rescue respects existing supported-sale eligibility')
end
-- Empty acquisition endpoint still goes through sequence protection.
local s=state();local a=Snap.copy(s);table.remove(a.jokers,1)
check(not S.shop_sequence_admission(s,a,evidence(false)),'sale-only endpoint retains last engine')
-- Focused Blueprint acquisition can spend a duplicate, not the sole underlying engine.
s=state();s.jokers[2]=j('j_yorick','retained',{x_mult=4,eternal=true,yorick_discards=7,extra={discards=23,xmult=1}})
s.shop_jokers={j('j_blueprint','blueprint',{})}
local c=context(false);local plan=S.copy_acquisition(s,c)
check(plan and plan.action.kind=='sell' and plan.action.index==1,'duplicate-only full row can acquire Blueprint')
if plan then
 local sold=assert(Seq.transition(s,plan.action,{strategy=S,shop_scoring=Shop}))
 local fresh=S.copy_acquisition(sold,context(false))
 check(fresh and fresh.action.kind=='buy' and fresh.action.index==1,'fresh observation follows duplicate sale with Blueprint')
end
local no_duplicate=state();no_duplicate.shop_jokers=s.shop_jokers
check(not S.copy_acquisition(no_duplicate,context(false)),'focused copy cannot spend sole Yorick')
check(c.evaluations<=8,'duplicate candidate reuses bounded comparison work')
local pack=Snap.copy(s);pack.phase='pack';pack.pack_type='BUFFOON_PACK';pack.pack_choices=1
pack.pack_cards=pack.shop_jokers;pack.shop_jokers={}
local from_pack=S.advise(pack,{shop_scoring=context(false)})
check(from_pack.action.kind=='sell' and from_pack.action.index==1,'revealed Blueprint can replace expendable duplicate Yorick')
local incomplete=context(false)
function incomplete:compare()local e=evidence(false);e.complete_finishing=false;return e end
check(S.advise(pack,{shop_scoring=incomplete}).action.kind~='sell','unmodeled duplicate sale needs complete supported copy evidence')
-- Production scorer/finisher, still an independently invented deck and row.
local Score=dofile(P..'scoring.lua');local Finish=dofile(P..'blind_finishing.lua')
local D=dofile(P..'decision.lua')
for _,n in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do Finish[n]=dofile(P..n..'.lua') end
Finish.strategy=S;Shop.blind_finishing=Finish;Shop.strategy=S;Shop.paired_deck=dofile(P..'paired_deck.lua')
s.hands={Pair={level=4,played=6,chips=55,mult=5}};s.hand_size=5;s.next_blind.chips=1200
for i=1,12 do s.playing_cards[i]={id='manufactured:'..i,rank=7,suit='Clubs',nominal=7,ability={},enhancement='c_base'} end
local fp=Snap.fingerprint(s)
local actual=D.run(s,{strategy=S,scoring=Score,shop_scoring=Shop,shop_sequences=Seq},nil,{prepared_scoring=false})
check(actual.action.kind=='sell' and actual.action.index==1 and actual.copy_acquisition_diagnostics and
 actual.copy_acquisition_diagnostics.reason=='supported_copy_priority','production scoring selects duplicate-only Blueprint acquisition')
check(actual.evaluations<=50000 and Snap.fingerprint(s)==fp,'production acquisition respects work cap and immutable observation')
print('last engine411: '..checks..' checks, '..failures..' failures')
assert(failures==0,'last engine411 failures')
