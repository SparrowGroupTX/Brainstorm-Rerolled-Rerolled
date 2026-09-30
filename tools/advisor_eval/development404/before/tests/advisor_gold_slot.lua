-- Manufactured direct-acquisition evidence; no captured/source/game execution.
local P='Brainstorm/Advisor/'
local Slot=dofile(P..'gold_slot.lua')
local Goal=dofile(P..'gold_goal.lua');local Perkeo=dofile(P..'gold_perkeo.lua')
local Hold=dofile(P..'gold_tarot_hold.lua');local Shop=dofile(P..'shop_scoring.lua')
local Score=dofile(P..'scoring.lua');local Snapshot=dofile(P..'snapshot.lua')
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
Slot.gold_goal=Goal;Slot.gold_perkeo=Perkeo;Slot.gold_tarot_hold=Hold
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local copy=Snapshot.copy
local function state()
 local s={phase='shop',dollars=80,bankrupt_at=0,joker_limit=5,consumable_limit=2,consumeable_buffer=0,
  consumeables={},jokers={F.joker('j_joker','Joker','owned')},playing_cards={},hands={},
  hand_size=4,hand_limit=5,round_resets={hands=1,discards=0},current_round={},modifiers={},probabilities={normal=1},
  next_blind={key='bl_small',name='Small Blind',boss=false,chips=500,ante=3},blind={disabled=true},
  ordering_safe=true,jokers_shuffling=false,used_vouchers={},interest_amount=1,interest_cap=25,
  completionist_goal={schema=1,goal='gold_stickers',metadata_status='complete',catalog_status='complete',held_status='complete',
   eligibility={status='eligible',eligible=true},by_key={j_caino={status='complete'},j_joker={status='complete'},j_perkeo={status='complete'}}}}
 s.jokers[1].ability.mult=0
 local c=F.joker('j_caino','Caino','incoming');c.ability.caino_xmult=10;c.ability.extra=1;c.ability.eternal=true
 s.shop_jokers={c}
 for _,name in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
  'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'})do s.hands[name]={chips=100,mult=1,played=1,level=1}end
 for i=1,16 do s.playing_cards[i]={id='public:'..i,rank=2+i%8,nominal=2+i%8,
  suit=({'Spades','Hearts','Clubs','Diamonds'})[1+i%4],ability={}}end
 return s,c
end
local function append(s,c)
 local a=copy(s);a.jokers[#a.jokers+1]=copy(c);a.dollars=s.dollars-(s.phase=='shop'and c.cost or 0);return a
end
local calls=0
local function evidence(s,a)
 local scorer={score=function(...)calls=calls+1;return Score.score(...)end}
 local ctx=Shop.new(s,scorer,nil,{max_evaluations=50000,current_order_opening_only=true})
 local e=assert(ctx:compare(s,a));eq(ctx.evaluations,calls,'one fresh actual context charges every fixture score')
 return e
end
math.random=function()error('No RNG in the manufactured slot guard fixture')end;pseudorandom=math.random;pseudoseed=math.random
do
 local s,c=state();local before=Snapshot.fingerprint(s);local a=append(s,c);local e=evidence(s,a)
 local spent=calls
 local protected,d=Slot.protected(s,c);check(protected and d.applies and not d.allowed,'verified ordinary already-Gold Eternal is protected')
 local ok,r=Slot.admit(s,c,a,e)
 check(ok and r.applies and r.allowed,'actual exact score evidence can admit meaningful direct support')
 eq(r.samples,4,'four common worlds');check(r.after_min>=625 and r.before_min<500,'the actual receipt repairs an opening shortfall with 25% margin')
 eq(r.additional_score_calls,0,'the validator adds no score work');eq(calls,spent,'receipt validation consumes no hidden scores')
 check(not r.terminal_evidence,'local opening support is not a terminal claim')
 local allowed,ep=Slot.endpoint(s,a,e,{{kind='buy',area='shop_jokers',index=1}})
 check(allowed and ep.allowed and ep.applies,'the exact one-action endpoint passes')
 for _,name in ipairs({'j_caino','j_perkeo','j_yorick','j_blueprint','j_brainstorm','j_burnt'})do
  local target=copy(c);target.key=name;s.completionist_goal.by_key[name]={status='complete'}
  check(Slot.protected(s,target),'core target preference grants no exemption: '..name)
 end
 s=state();c=s.shop_jokers[1]
 eq(Snapshot.fingerprint(s),before,'classification and admission do not mutate the original input')
 for _,change in ipairs({
  function(t,j)t.completionist_goal=nil end,
  function(t,j)t.completionist_goal.eligibility.eligible=false end,
  function(t,j)t.completionist_goal.by_key[j.key].status='missing'end,
  function(t,j)t.completionist_goal.by_key[j.key].status='unknown'end,
  function(t,j)t.completionist_goal.metadata_status='unavailable'end,
  function(t,j)j.ability.eternal=false end,
  function(t,j)j.edition={negative=true,type='negative'}end,
  function(t,j)j.edition='negative'end,
 })do
  local t,j=state();change(t,j);local changed=append(t,j)
  check(not Slot.protected(t,j),'unprotected categories remain outside this rule')
  local pass,reason=Slot.admit(t,j,changed,nil);check(pass and not reason.applies,'unprotected acquisition needs no new evidence')
 end
 local t,j=state();t.completionist_goal.by_key[j.key].status='unknown'
 local _,unknown=Slot.protected(t,j);check(unknown.metadata_unknown,'unknown Gold status stays explicit')
 t,j=state();j.ability.eternal=nil;t.modifiers.all_eternal=true
 check(Slot.protected(t,j),'all_eternal modifier also creates permanent ownership')
 for _,edit in ipairs({
  function(t)t.uncertain=true end,function(t)t.incomplete=true end,function(t)t.samples=3 end,
  function(t)t.temporal={weight=.2}end,function(t)t.before_startup={}end,function(t)t.after_startup={}end,
  function(t)t.common_worlds.world_ids[4]=3 end,function(t)t.common_worlds.family_key=''end,
  function(t)t.after_target=499 end,function(t)t.blind='bl_final_heart'end,function(t)t.boss_fallback='neutral'end,
  function(t)t.after_readiness.opening_scores[4]=624 end,function(t)t.after_readiness.opening_scores[4]=nil end,
  function(t)t.after_readiness.ordering.action_count=1 end,function(t)t.after_readiness.ordering.order={2,1}end,
  function(t)t.before_finishing={complete=true,supported=true,known_mechanics=true,samples=4,selected={clearing_samples=4}}end,
  function(t)t.before_finishing={complete=true,supported=false,samples=4,selected={clearing_samples=0}}end,
  function(t)t.before_finishing=17 end,
 })do
  local altered=copy(e);edit(altered);local pass,reason=Slot.admit(s,c,a,altered)
  check(not pass and reason.applies and not reason.allowed,'partial, uncertain, changed-order or nonessential evidence cannot buy permanence')
 end
 local enough=copy(e);for i=1,4 do enough.before_readiness.opening_scores[i]=500 end
 check(not Slot.admit(s,c,a,enough),'already clearing each opening blocks overkill')
 check(not Slot.admit(s,c,a,nil),'no evidence defaults to protecting the ordinary slot')
 s._shop_scoring={truncated=true};check(not Slot.admit(s,c,a,e),'partial shared comparison cannot grant an exception');s._shop_scoring=nil
 for _,edit in ipairs({
  function(t)t.dollars=t.dollars+1 end,function(t)t.consumeables[1]={id='new'}end,
  function(t)t.playing_cards[1].rank=14 end,function(t)t.hands.Pair.level=9 end,
  function(t)t.jokers[1].ability.mult=999 end,function(t)table.remove(t.jokers,1)end,
  function(t)t.round_resets.hands=4 end,function(t)t.hand_size=8 end,
  function(t)t.consumable_limit=9 end,function(t)t.consumeable_buffer=1 end,
 })do local changed=copy(a);edit(changed);check(not Slot.admit(s,c,changed,e),'unrelated resource changes cannot borrow the survival exception')end
 for _,actions in ipairs({{},{{kind='use',area='consumeables',index=1},{kind='buy',area='shop_jokers',index=1}},
  {{kind='sell',area='jokers',index=1},{kind='buy',area='shop_jokers',index=1}},
  {{kind='buy',area='shop_jokers',index=2}},{{kind='choose',area='pack_cards',index=1}}})do
  local pass,reason=Slot.endpoint(s,a,e,actions);check(not pass and reason.applies,'unrelated or unbound sequence cannot smuggle a protected Eternal')
 end
 local p,pc=state();p.phase='pack';local pa=append(p,pc)
 check(Slot.admit(p,pc,pa,e),'exact free direct pack choice can use the same supported opening evidence')
 eq(pa.dollars,p.dollars,'the free pack choice pays no shop cost')
 eq(calls,spent,'all pure guard branch tests add zero scoring work')
end
do
 local s,c=state();s.jokers[#s.jokers+1]=F.joker('j_perkeo','Perkeo','perkeo')
 local a=append(s,c);calls=0;local e=evidence(s,a)
 check(Slot.admit(s,c,a,e),'exact empty Perkeo pool cannot generate an unknown card')
 local inventory=F.state().consumeables;s.consumeables=copy(inventory);s.consumable_limit=16;a=append(s,c)
 check(Slot.admit(s,c,a,e),'both qualified fixed-hold Tarot endpoints preserve first-hand score')
 s.phase='pack';a=append(s,c)
 check(not Slot.admit(s,c,a,e),'nonempty pack Perkeo pool cannot impersonate a shop certificate')
 s.phase='shop';s.consumeables[1].tarot_hold_source=nil;a=append(s,c)
 check(not Slot.admit(s,c,a,e),'one unsupported held card invalidates the whole pool proof')
 s,c=state();s.jokers[#s.jokers+1]=F.joker('j_cartomancer','Cartomancer','carto');a=append(s,c)
 check(not Slot.admit(s,c,a,e),'free-slot Cartomancer startup remains explicitly unsupported')
end
print('advisor_gold_slot: '..checks..' manufactured checks passed')
