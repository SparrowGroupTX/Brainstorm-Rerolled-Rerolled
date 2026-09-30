-- Diagnostic reproductions of current limitations, NOT repaired acceptance tests.
-- All input states invented here; no captured state, game engine, or hidden data.
local B=dofile('Brainstorm/Advisor/acorn_belief.lua')
local O=dofile('Brainstorm/Advisor/acorn_ordering.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Pack=dofile('Brainstorm/Advisor/pack_scoring.lua')
local Sequence=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local checks=0
local function check(v,m)assert(v,m);checks=checks+1 end
local function joker(key,name,a)
  a=a or {};a.name=name;a.set='Joker'
  return {id='invented:'..key,key=key,name=name,cost=4,base_cost=4,sell_cost=2,ability=a,blueprint_compat=true}
end
local function hand()
  return {phase='hand',hand={{id='invented:card',rank=4,suit='Clubs',nominal=4,enhancement='c_base',ability={}}},
    hands={},deck={},playing_cards={},consumeables={},hands_left=4,discards_left=3,hand_limit=5,chips=0,dollars=20,
    blind={key='bl_final_acorn',name='Amber Acorn',chips=1000000},modifiers={},probabilities={normal=1}}
end
local epoch='invented407'
local function belief(js)return assert(B.start(js,epoch,{public_before_shuffle=true}))end
local plain=joker('j_joker','Joker',{mult=4})
do
  local s=hand();local b=belief({joker('j_green_joker','Green Joker',{mult=10,extra={hand_add=1,discard_sub=1}}),plain})
  local before=Snapshot.fingerprint(b)
  local a,n,d=O.suggest(s,b,Score,B,{max_evaluations=2,max_order_evaluations=0})
  check(a and n==2 and d.complete,'Green admits complete initial two-world comparison')
  local observed=B.observe(b,{epoch=epoch,slot=1,type='rendered_status',phase='play',qualified_render=true,channel='mult',amount=11,text='+11 Mult'})
  check(observed and #observed.worlds>=1,'pre-completion Green popup does not eliminate all worlds')
  local after=B.advance_public(observed,{epoch=epoch,kind='play',observed_complete=true})
  check(after and not after.state_valid,'known current gap: Green invalidates after completed play')
  local refused,nn,dd=O.suggest(s,after,Score,B,{max_evaluations=2,max_order_evaluations=0})
  check(not refused and nn==0 and not dd.complete,'invalidated Green stops before next score')
  check(Snapshot.fingerprint(b)==before,'Green observation/advance preserves original belief')
  check(not B.advance_public(b,{epoch='stale',kind='play',observed_complete=true}),'stale completion rejected')
end
do
  local s=hand();local misprint=joker('j_misprint','Misprint',{effect='Random Mult',extra={min=0,max=23}})
  local b=belief({misprint,plain})
  local a,n,d=O.suggest(s,b,Score,B,{max_evaluations=2,max_order_evaluations=0})
  check(not a and n==1 and not d.complete,'known current gap: no-Lucky Misprint initial comparison stops')
  local floor=Snapshot.copy(s);floor.jokers={misprint,plain}
  local result=Score.lower_bound(floor,{1})
  check(result and result.reliable_bound and not result.uncertain and #(result.warnings or {})==0,'canonical Misprint floor independently supported')
  s.hand[1].enhancement='m_lucky'
  local lucky,calls,diag=O.suggest(s,b,Score,B,{max_evaluations=2,max_order_evaluations=0})
  check(lucky and calls==2 and diag.complete,'Lucky activates existing floor and admits the same Misprint family')
  check(not B.advance_public(b,{epoch=epoch,kind='play',observed_complete=true}).state_valid,'Misprint also lacks next-action continuity')
  local bb=belief({joker('j_blackboard','Blackboard',{extra=3}),plain})
  check(not B.advance_public(bb,{epoch=epoch,kind='discard',observed_complete=true,discarded_count=5}).state_valid,'Blackboard also lacks post-discard continuity')
  local control=belief({plain})
  check(B.advance_public(control,{epoch=epoch,kind='play',observed_complete=true}).state_valid,'fixed ordinary Joker continuity is admitted')
end
local function shop()
  return {phase='shop',ante=2,dollars=14,bankrupt_at=0,joker_limit=5,consumable_limit=2,jokers={},consumeables={},
    shop_jokers={},shop_vouchers={},shop_booster={},hand_size=8,hand_limit=5,hand={},playing_cards={},deck={},
    hands={Straight={level=2,chips=60,mult=7,played=5}},round_resets={hands=1,discards=3},current_round={},
    modifiers={},probabilities={normal=1},interest_cap=25,next_blind={key='bl_big',name='Big Blind',chips=4000},
    next_blind_chips=4000,last_tarot_planet='c_saturn',shop_forecast={discount_percent=0,inflation=0}}
end
Strategy.consumables=Consumables;Strategy.pack_scoring=Pack
local modules={strategy=Strategy,pack_scoring=Pack,shop_scoring=Shop,consumables=Consumables,scoring=Score}
do
  local s=shop();s.consumeables={{id='invented:fool',key='c_fool',name='The Fool',cost=3,sell_cost=1,
    ability={name='The Fool',set='Tarot',order=1,consumeable={}}}}
  check(Pack.owned_fool_candidate(s,1,modules),'ordinary Fool with main Planet and free slot is admitted without Jokers')
  s.jokers={joker('j_perkeo','Perkeo')}
  local value=Strategy.shop_sequence_api.card_value(s,s.consumeables[1])
  check(value>0,'Perkeo Fool still receives positive acquisition value')
  local candidate,reason=Pack.owned_fool_candidate(s,1,modules)
  check(not candidate and reason=='Owned Fool is outside the main-Planet shop scope.','known current gap: adding Perkeo removes owned Fool use admission')
  check(not Sequence.transition(s,{kind='use',area='consumeables',index=1,targets={}},modules),'production sequence transition cannot use Perkeo Fool')
end
do
  local s=shop();s.jokers={joker('j_yorick','Yorick',{x_mult=1,extra={discards=23,xmult=1},yorick_discards=7})}
  local original=Snapshot.fingerprint(s)
  local sold=Sequence.transition(s,{kind='sell',area='jokers',index=1},modules)
  check(sold and #sold.jokers==0 and sold.dollars==16,'sequence transition permits sale of a developing Yorick')
  check(Snapshot.fingerprint(s)==original,'sale projection preserves original invented input')
  local calls=0;local localStrategy={};for k,v in pairs(Strategy)do localStrategy[k]=v end
  localStrategy.shop_sequence_api={};for k,v in pairs(Strategy.shop_sequence_api)do localStrategy.shop_sequence_api[k]=v end
  localStrategy.shop_sequence_api.joker_admission=function()calls=calls+1;return false,{reason='invented explicit admission veto'} end
  s.shop_jokers={plain}
  local ms={strategy=localStrategy,shop_scoring=Shop}
  local bought=Sequence.transition(s,{kind='buy',area='shop_jokers',index=1},ms)
  check(bought and calls==0,'known plumbing gap: ordinary Joker transition never consults shared admission')
  s.shop_jokers={joker('j_madness','Madness',{x_mult=1,extra=.5})}
  check(not Sequence.transition(s,{kind='buy',area='shop_jokers',index=1},ms) and calls==1,'Madness explicitly consults the same injected admission veto')
  local ctx={readiness=function()return {supported=true,status='sampled_deficit',target=4000,opening_mean=100}end}
  local result,d=Sequence.suggest(s,modules,{action={kind='buy',area='shop_vouchers',index=1}},ctx)
  check(not result and d.reason=='The existing action has an outcome outside the supported sequence comparison.','fresh voucher incumbent exits sequence arbitration before a continuation comparison')
end
print('manufactured_diagnostics407: '..checks..' checks passed (limitations reproduced; no repairs claimed)')
