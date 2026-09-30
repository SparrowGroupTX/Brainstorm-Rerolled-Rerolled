local prefix='tools/advisor_eval/development299/drafts/shop_order/'
local Shop=dofile(prefix..'shop_scoring.lua')
local Finish=dofile(prefix..'blind_finishing.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local function attach(shop,finish)
  for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
    finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
  end
  finish.strategy=Strategy;shop.blind_finishing=finish;shop.strategy=Strategy
end
attach(Shop,Finish)
local checks=0
local function check(v,msg) checks=checks+1;assert(v,msg) end
local function eq(a,b,msg) check(a==b,msg..': '..tostring(a)..' ~= '..tostring(b)) end
local function joker(key,name,a)
  a=a or {};a.name=name;a.set='Joker'
  return {id=key,key=key,name=name,ability=a,blueprint_compat=true,sell_cost=10}
end
local function state()
  -- New synthetic composition and levels; models the observed integration
  -- defect without loading, replaying, or copying an original-source snapshot.
  local s={phase='shop',deck_key='b_red',ante=4,dollars=61,bankrupt_at=0,joker_limit=5,
    consumable_limit=2,consumeables={},hands={},modifiers={},probabilities={normal=1},
    hand_size=8,hand_limit=5,round_resets={hands=4,discards=4},current_round={},playing_cards={},
    next_blind={key='bl_small',chips=10000},next_blind_chips=10000,
    shop_jokers={},shop_booster={},shop_vouchers={},reroll_cost=5}
  for i=1,40 do s.playing_cards[i]={id='synthetic:'..i,rank=2+(i-1)%13,
    suit=({'Hearts','Clubs','Spades','Diamonds'})[(i-1)%4+1],ability={}} end
  s.jokers={joker('j_yorick','Yorick',{x_mult=4,yorick_discards=13,extra={discards=23,xmult=1}}),
    joker('j_perkeo','Perkeo',{}),joker('j_droll','Droll Joker',{t_mult=10,type='Flush',eternal=true}),
    joker('j_brainstorm','Brainstorm',{eternal=true}),joker('j_scary_face','Scary Face',{extra=30,eternal=true})}
  return s
end
local function rotated(s)
  local t=Snapshot.copy(s);t.jokers[1],t.jokers[2]=t.jokers[2],t.jokers[1];return t
end
local function mean_worlds(r)
  local out={}
  for _,p in ipairs(r.finishing.policies) do for _,w in ipairs(p.worlds) do
    out[#out+1]={score=w.score,progress=w.progress,hands=w.hands_used,discards=w.discards_used}
  end end
  return Snapshot.fingerprint(out)
end
math.random=function() error('Shop-order fixture touched RNG') end
math.randomseed=function() error('Shop-order fixture seeded RNG') end

do
  local oldShop=dofile(prefix..'baseline_shop_scoring.lua')
  local oldFinish=dofile(prefix..'baseline_blind_finishing.lua');attach(oldShop,oldFinish)
  local s=state();local t=rotated(s)
  local prior=oldShop.new(s,Scorer):readiness(s);local rotated_prior=oldShop.new(t,Scorer):readiness(t)
  check(prior.finishing.complete and rotated_prior.finishing.complete,'synthetic physical-row baseline completes')
  eq(prior.opening_mean,rotated_prior.opening_mean,'old exhaustive opening scores already agree')
  check(prior.cumulative_mean~=rotated_prior.cumulative_mean,'synthetic baseline reproduces copied-Yorick finishing collapse')

  local hash=Snapshot.fingerprint({s,t});local context=Shop.new(s,Scorer);local after=context:readiness(s)
  local after_rotated=Shop.new(t,Scorer):readiness(t)
  check(after.finishing.complete and after_rotated.finishing.complete,'both fixed-layout continuations complete')
  eq(after.cumulative_mean,after_rotated.cumulative_mean,'reordering Perkeo in shop no longer erases achievable Yorick scaling')
  eq(mean_worlds(after),mean_worlds(after_rotated),'every fixed policy keeps the same score/progress/resources in every world')
  eq(after.ordering.identity,after_rotated.ordering.identity,'the same fixed physical scoring arrangement is selected')
  check(after.ordering.samples==4 and after.ordering.selection=='one_fixed_layout_by_complete_common_opening_mean',
    'one arrangement is selected across all four common worlds')
  check(context.evaluations<=50000 and not context.truncated,'ordinary shared shop cap stays unchanged')
  eq(Snapshot.fingerprint({s,t}),hash,'original rows, deck, cash, and inventory are unchanged')

  for _,r in ipairs({after,after_rotated}) do
    for _,p in ipairs(r.finishing.policies) do
      eq(#p.worlds,4,'both policies retain all four worlds')
      eq(p.mean_setup_actions,r.ordering.action_count,'policy charges its actual setup action')
      for _,w in ipairs(p.worlds) do
        eq(#w.actions,w.hands_used+w.discards_used+w.setup_actions,'all action counts include the actual reorder')
        eq(w.action_count,#w.actions,'world action total is explicit')
        if w.setup_actions>0 then
          eq(w.actions[1].kind,'reorder_jokers','first projected action restores scoring order')
          eq(Snapshot.fingerprint(w.actions[1].order),Snapshot.fingerprint(r.ordering.order),'one same order across all worlds and policies')
        end
      end
    end
  end
  print('synthetic order collapse '..prior.cumulative_mean..' -> '..rotated_prior.cumulative_mean..'; repaired '..after.cumulative_mean..' = '..after_rotated.cumulative_mean)
end

do
  local s=state();local before=Shop.new(s,Scorer):readiness(s)
  local aligned=Snapshot.copy(s);aligned.jokers={}
  for i,index in ipairs(before.ordering.order) do aligned.jokers[i]=s.jokers[index] end
  local same=Shop.new(aligned,Scorer):readiness(aligned)
  eq(same.ordering.action_count,0,'already selected physical arrangement adds no fictitious action')
  eq(same.finishing.selected.mean_setup_actions,0,'aligned world does not pay reorder cost')
  local sold=Snapshot.copy(aligned)
  sold.jokers[#sold.jokers+1]=joker('j_joker','Joker',{mult=4});sold.joker_limit=6
  local evidence=Shop.new(aligned,Scorer):compare(aligned,sold)
  check(evidence and evidence.complete_finishing and evidence.ordering_cost,'paired comparison carries actual setup costs')
  eq(evidence.ordering_cost.adjustment,-2*evidence.ordering_cost.extra_actions,'setup action charged at existing action utility')
end

do
  local s=state();s.jokers[1].pinned=true;s.jokers[2].ability.pinned=true
  local r=Shop.new(s,Scorer):readiness(s)
  check(r.finishing.complete,'pinned but supported layouts remain usable')
  eq(r.ordering.order[1],1,'physical pinned Yorick remains in its original slot')
  eq(r.ordering.order[2],2,'ability-pinned Perkeo remains in its original slot')
  local cut=Shop.new(state(),Scorer,nil,{max_evaluations=90})
  check(not cut:compare(state(),state()) and cut.truncated and cut.evaluations<=90,'incomplete layout family cannot support a paired override')
end

do
  local s=state();local worlds={}
  s.phase='hand';s.hand={s.playing_cards[1]};s.deck={};s.hands_left=1;s.discards_left=0;s.hand_size=1;s.chips=0
  s.blind={disabled=true,chips=1};s.current_round={hands_left=1,discards_left=0}
  local score=Scorer.score(s,{1});score.indices={1}
  for i=1,4 do worlds[i]={state=Snapshot.copy(s),opening_play=Snapshot.copy(score),
    setup_action={kind='reorder_jokers',area='jokers',order={2,1,3,4,5}}} end
  worlds[1].state.jokers[1].pinned=true
  local result=Finish.forecast(worlds,Scorer,function() error('invalid setup must spend no score call') end)
  check(not result.complete and result.reason:find('pinned',1,true),'illegal physical setup rejects the whole comparison')
  worlds[1].state.jokers[1].pinned=nil;worlds[1].setup_action.order={2,2,3,4,5}
  result=Finish.forecast(worlds,Scorer,function() error('duplicate setup must spend no score call') end)
  check(not result.complete,'duplicate Joker membership cannot enter a complete forecast')
  worlds[1].setup_action.order={1,2,3,4,5}
  result=Finish.forecast(worlds,Scorer,function() error('no-op setup must spend no score call') end)
  check(not result.complete,'no-op setup cannot invent an action cost')
  worlds[1].setup_action.order={2,1,3,4,5};worlds[1].state.jokers[1].face_down=true
  result=Finish.forecast(worlds,Scorer,function() error('hidden setup must spend no score call') end)
  check(not result.complete,'hidden Joker cannot be moved in a projected setup')
end
print('advisor_shop_order: '..checks..' checks passed')
