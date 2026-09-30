local B=dofile('Brainstorm/Advisor/concealed_belief.lua')
local P=dofile('Brainstorm/Advisor/phase_copy.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local O=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local F=dofile('Brainstorm/Advisor/finish_rewards.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Registry=dofile('Brainstorm/Advisor/gold_stickers.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function c(id,rank,hidden,suit,enhancement)
  return {id=id,rank=rank,suit=suit or 'Hearts',nominal=math.min(rank,10),enhancement=enhancement or 'c_base',
    face_down=not not hidden,ability={}}
end
local function j(key,name,extra)
  local a={set='Joker',name=name,h_size=0,d_size=0}
  for k,v in pairs(extra or {})do a[k]=v end
  return {id=key,key=key,name=name,ability=a,debuff=false,blueprint_compat=true,pinned=false,cost=4,sell_cost=2}
end
local function state()
  local s={phase='hand',hand={c('a',13,true),c('v',13,false),c('b',13,true)},
    deck={c('d',2,true),c('e',7,true),c('f',13,true)},playing_cards={},hands={},
    jokers={j('j_blueprint','Blueprint'),j('j_perkeo','Perkeo'),j('j_greedy_joker','Greedy Joker',{extra={s_mult=3,suit='Diamonds'}}),
      j('j_trio','The Trio',{perishable=true,perish_tally=0,rental=true,x_mult=3,type='Three of a Kind'}),
      j('j_yorick','Yorick',{x_mult=4,yorick_discards=17,extra={discards=23,xmult=1}})},
    consumeables={},consumable_limit=2,consumeable_buffer=0,joker_limit=5,dollars=154,
    hands_left=1,discards_left=0,hand_limit=5,hand_size=8,blind={key='bl_wheel',name='The Wheel',chips=100000},chips=0,
    modifiers={},current_round={hands_left=1,discards_left=0,hands_played=0,discards_used=0},probabilities={normal=1}}
  s.jokers[4].debuff=true
  for _,card in ipairs(s.hand)do s.playing_cards[#s.playing_cards+1]=card end
  for _,card in ipairs(s.deck)do s.playing_cards[#s.playing_cards+1]=card end
  return s
end
local function modules(scorer)
  return {concealed_belief=B,phase_copy=P,scoring=scorer or S,sampled_outcomes=O,finish_rewards=F,gold_stickers=Registry,
    search={run=function()error('concealed input reached identity-aware ordinary search')end}}
end
local function run(s,options,scorer)return D.run(s,modules(scorer),nil,options or {concealed_belief={samples=4}})end
local function reorder(s,order)
  local out=Snapshot.copy(s);out.jokers={}
  for _,i in ipairs(order)do out.jokers[#out.jokers+1]=Snapshot.copy(s.jokers[i])end
  return out
end
local s=state();local unchanged=Snapshot.fingerprint(s)
local r=run(s)
eq(r.action.kind,'reorder_jokers','concealed hand restores a useful known scoring row')
check(r.reorder_only and r.needs_refresh,'only the actual arrangement is executable')
check(r.concealed_belief.complete and r.concealed_belief.ordering.complete,'whole play and order families complete')
eq(P.copy_effects(reorder(s,r.action.order),'j_yorick'),2,'scored comparison selects useful copied effect')
eq(P.copy_effects(reorder(s,r.action.order),'j_trio'),0,'expired Trio is never a live copy target')
eq(Snapshot.fingerprint(s),unchanged,'input unchanged')
eq(r.concealed_belief.ordering.score_calls,r.concealed_belief.ordering.required_score_calls,'complete charged row family')
eq(r.evaluations,28+r.concealed_belief.ordering.score_calls,'one shared allowance')
eq(r.concealed_belief.ordering.terminal_evidence,false,'no win claim')
local fresh=run(reorder(s,r.action.order))
eq(fresh.action.kind,'play','fresh advice does not bounce back to shop copying')
check(not fresh.reorder_only,'current row wins equal-score choices')
-- Sampling remains invariant to actual hidden-slot identities and deck order.
local permuted=Snapshot.copy(s)
permuted.hand[1],permuted.deck[2]=permuted.deck[2],permuted.hand[1]
permuted.hand[3],permuted.deck[1]=permuted.deck[1],permuted.hand[3]
permuted.deck[1],permuted.deck[3]=permuted.deck[3],permuted.deck[1]
eq(Snapshot.fingerprint(run(permuted)),Snapshot.fingerprint(r),'latent permutations do not change order or evidence')
-- Generic comparison chooses another public effect without a Yorick target.
local other=state();other.jokers[5]=j('j_caino','Caino',{caino_xmult=5,extra=1})
local alternative=run(other)
eq(alternative.action.kind,'reorder_jokers','copy-target family is not restricted to Yorick')
eq(P.copy_effects(reorder(other,alternative.action.order),'j_caino'),2,'Caino arrangement is actually selected')
local duplicate=state();duplicate.jokers[3]=j('j_yorick','Yorick',{x_mult=2,yorick_discards=17,extra={discards=23,xmult=1}})
duplicate.jokers[3].id='weak-yorick'
local dr=run(duplicate);eq(dr.action.kind,'reorder_jokers')
eq(P.copy_effects(reorder(duplicate,dr.action.order),'j_yorick','j_yorick'),2,'duplicate identities compare physical targets separately')
-- Held Negative inventory stays physically intact throughout the proof.
local inventory=state()
inventory.consumeables={{id='held',key='c_temperance',debuff=false,edition={negative=true},ability={set='Tarot',name='Temperance',money=40}}}
inventory.consumable_limit=3
local ir=run(inventory);eq(ir.action.kind,'reorder_jokers','held Tarot remains in the paired resource states')
eq(#inventory.consumeables,1);eq(inventory.consumable_limit,3)
local glass=state();glass.hand[1].enhancement='m_glass';glass.hand[1].ability.extra=4
eq(run(glass).action.kind,'reorder_jokers','same private Glass outcomes preserve paired population effects')
-- A fully clearing current fixed play needs no additional arrangement.
local clear=state();clear.blind.chips=1
local cr=run(clear);eq(cr.action.kind,'play');eq(cr.concealed_belief.ordering.score_calls,0,'no overkill order work')
local opted=run(s,{concealed_belief={samples=4,copy_order=false}})
eq(opted.action.kind,'play');eq(opted.evaluations,28,'opt-out is the original immediate comparison')
local budget=run(s,{concealed_belief={samples=4,max_evaluations=28+r.concealed_belief.ordering.required_score_calls-1}})
eq(budget.action.kind,'play','no partial prefix when full order family cannot fit')
eq(budget.evaluations,28,'preflight spends no partial order budget')
check(not budget.concealed_belief.ordering.complete)
local pinned=state();for _,card in ipairs(pinned.jokers)do card.pinned=true end
eq(run(pinned).action.kind,'play','pinned physical rows stay put')
local disabled=state();disabled.jokers[1].debuff=true
eq(run(disabled).action.kind,'play','disabled copying card is not reactivated')
local malformed=state();malformed.jokers[4].ability.perish_tally=nil
eq(run(malformed).action.kind,'play','unknown perish timing does not qualify ordering')
-- No hidden-Joker path can borrow this visible-row comparison.
local hidden=state();hidden.jokers[1].face_down=true
local hr=run(hidden);eq(hr.action,nil);eq(hr.evaluations,0)
local acorn=state();acorn.blind={key='bl_final_acorn',name='Amber Acorn',chips=100000}
acorn.modifiers.flipped_cards=7
eq(run(acorn).action.kind,'play','known-row shortcut still declines Amber Acorn')
-- A supported resource difference disqualifies its row; score alone is not enough.
local altered=setmetatable({},{__index=S})
altered.after_play=function(world,indices,context)
  local after,effects,play=S.after_play(world,indices,context)
  if after and P.copy_effects(world,'j_yorick')>1 then after.dollars=after.dollars-1 end
  return after,effects,play
end
local ar=run(s,nil,altered);eq(ar.action.kind,'play','money-changing row cannot qualify')
check(ar.concealed_belief.ordering.complete,'all rows still compared after resource rejection')
-- Unsupported members reject the whole order family, never a scored prefix.
local rejected=setmetatable({},{__index=S})
rejected.after_play=function(world,indices,context)
  if P.copy_effects(world,'j_yorick')>1 then return nil,'manufactured unsupported callback' end
  return S.after_play(world,indices,context)
end
local ur=run(s,nil,rejected);eq(ur.action.kind,'play');check(not ur.concealed_belief.ordering.complete)
-- Copying away from Mime must not spend held Gold/Blue generation for score.
local mime=state();mime.jokers[2]=j('j_mime','Mime',{extra=1});mime.hand[2].seal='Blue'
local mr=run(mime);eq(mr.action.kind,'play','cashout Mime copies are conserved')
check(mr.concealed_belief.ordering.complete)
local expiring=Snapshot.copy(mime);expiring.jokers[1].ability.perishable=true;expiring.jokers[1].ability.perish_tally=1
eq(run(expiring).action.kind,'reorder_jokers','an expiring copy cannot retrigger held cards at cashout')
-- Retry review-only rules are applied after the concealed order result too.
local review=run(s,{concealed_belief={samples=4},retry={unavailable=true,reason='unverified'}})
eq(review.action,nil);check(review.retry.review_only);eq(review.strategy.action,nil)
-- Actual eight-card work remains within the original 8,000-score ceiling.
local eight=state();eight.hand={};eight.deck={};eight.playing_cards={}
for i=1,8 do local card=c('large:'..i,i<5 and 13 or i,i%2==0);eight.hand[i]=card;eight.playing_cards[i]=card end
for i=9,12 do local card=c('large:'..i,i,true);eight.deck[#eight.deck+1]=card;eight.playing_cards[#eight.playing_cards+1]=card end
local er=run(eight,{concealed_belief={samples=16}})
eq(er.action.kind,'reorder_jokers','ordinary eight-card Wheel shape fits')
check(er.evaluations<=8000,'original concealed cap unchanged')
eq(er.evaluations,218*16+er.concealed_belief.ordering.required_score_calls)
local ninth=c('large:13',13,true);eight.hand[9]=ninth;eight.playing_cards[#eight.playing_cards+1]=ninth
local nr=run(eight,{concealed_belief={samples=16}})
eq(nr.action.kind,'reorder_jokers','complete nine-card family still fits')
eq(nr.evaluations,381*16+nr.concealed_belief.ordering.required_score_calls)
check(nr.evaluations<=8000)
math.randomseed(95001);local expected=math.random();math.randomseed(95001);run(s);eq(math.random(),expected,'no live or global RNG')
print('concealed copy order: '..checks..' checks passed')
