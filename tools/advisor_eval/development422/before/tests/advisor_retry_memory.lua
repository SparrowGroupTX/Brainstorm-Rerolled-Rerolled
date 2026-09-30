local R=dofile('Brainstorm/Advisor/retry_memory.lua')
local S=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,label) assert(v,label);checks=checks+1 end
local function equal(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(v) return S.copy(v) end
local function card(id,rank,suit)
  return {id=id,key='c_base',rank=rank,nominal=rank==14 and 11 or math.min(rank,10),
    suit=suit or 'Spades',ability={},face_down=false,debuff=false}
end
local function state()
  local s={phase='hand',ante=2,round=4,challenge='public-challenge',deck_key='b_challenge',
    hand={},deck={},playing_cards={},jokers={},consumeables={},shop_jokers={},shop_vouchers={},
    shop_booster={},pack_cards={},hands={},modifiers={},blind={key='bl_small',chips=800},
    dollars=5,chips=0,hands_left=3,discards_left=2,hand_limit=5,joker_limit=5,
    consumable_limit=2,hand_size=5,current_round={hands_left=3,discards_left=2},probabilities={normal=1}}
  for i=1,5 do local c=card('playing:'..i,i+2);s.hand[i]=c;s.playing_cards[i]=c end
  for i=6,8 do local c=card('playing:'..i,i+2);c.face_down=true;s.deck[#s.deck+1]=c;s.playing_cards[i]=c end
  return s
end
local run='public-run:one'
local function marked(s) return assert(R.mark(assert(R.new(run)),run,s)) end
local function play(i) return {kind='play',area='hand',indices={i or 1}} end

do
  local s=state();local before=S.fingerprint(s)
  local fresh=assert(R.new(run));local ledger=assert(R.mark(fresh,run,s))
  equal(fresh.marks,0,'mark does not mutate the supplied ledger')
  equal(ledger.marks,1,'first checkpoint has a monotone sequence')
  equal(R.context(ledger,run,s).active,false,'unfailed checkpoint has no retry advice')
  local record=assert(R.record(ledger,run,s,play(1)))
  equal(ledger.checkpoint.pending,nil,'record is pure')
  check(R.context(record,run,s).pending,'recorded user execution is pending')
  equal(R.failed(ledger,run,s),nil,'unrecorded line cannot spend a reload')
  local failed=assert(R.failed(record,run,s));local context=R.context(failed,run,s)
  check(context.active and context.matched,'explicit report activates only this public checkpoint')
  equal(context.reloads_used,1,'report spends one manual reload')
  equal(context.reloads_remaining,4,'five is a per-run budget')
  equal(context.evidence,'user_reported_public_checkpoint','evidence does not assert hidden RNG equality')
  equal(failed.checkpoint.failures[1].scope,'reported_line_start','failure describes a line start, not a proven bad move')
  check(context.failed_actions[assert(R.action_key(s,play(1)))],'the reported first action has its canonical key')
  equal(R.record(failed,run,s,play(1)),nil,'stale line start is not a new recorded attempt')
  equal(R.failed(failed,run,s),nil,'a report cannot be counted twice')
  local repeated=assert(R.mark(failed,run,s))
  equal(repeated.reloads_used,1,'remarking a checkpoint cannot reset reloads')
  equal(#repeated.checkpoint.failures,1,'remarking a checkpoint preserves line history')
  equal(S.fingerprint(s),before,'checkpoint operations never mutate observations')
  local exported=assert(R.export(failed));exported.checkpoint.failures[1].scope='changed'
  equal(failed.checkpoint.failures[1].scope,'reported_line_start','export is detached')
  local imported=assert(R.import(assert(R.export(failed)),run));imported.reports[1].action_key='changed'
  check(failed.reports[1].action_key~='changed','import is detached')
  context.failed_actions={};equal(#failed.checkpoint.failures,1,'read-only context is detached')
end

do
  local s=state();local ledger=marked(s)
  for i=1,5 do
    ledger=assert(R.record(ledger,run,s,play(i)))
    ledger=assert(R.failed(ledger,run,s))
    equal(ledger.reloads_used,i,'manual reload count '..i..' increases exactly once')
  end
  local context=R.context(ledger,run,s)
  check(context.active,'the fifth authorized reload still receives different-line advice')
  equal(context.reloads_remaining,0,'no sixth reload remains')
  local final=assert(R.record(ledger,run,s,{kind='discard',indices={1}}))
  equal(R.failed(final,run,s),nil,'a sixth user report is rejected')
  equal(final.reloads_used,5,'exhausted report leaves counters intact')
  local nextstate=clone(s);nextstate.round=5;nextstate.ante=3
  local nextcheckpoint=assert(R.mark(final,run,nextstate))
  equal(nextcheckpoint.reloads_used,5,'a different checkpoint never resets the run budget')
  equal(#nextcheckpoint.reports,5,'all spent reload records survive the new checkpoint')
  equal(nextcheckpoint.marks,2,'a new checkpoint advances sequence')
  equal(R.context(nextcheckpoint,run,s).active,false,'old public state cannot inherit new checkpoint failures')
  equal(R.import(nextcheckpoint,'public-run:two'),nil,'different run cannot import spent or fresh counters')
end

do
  local s=state();local ledger=assert(R.record(marked(s),run,s,play()))
  local variants={
    function(t)t.dollars=t.dollars+1 end,function(t)t.ante=t.ante+1 end,
    function(t)t.round=t.round+1 end,function(t)t.blind.chips=900 end,
    function(t)t.hand[1],t.hand[2]=t.hand[2],t.hand[1] end,
    function(t)t.hands.Pair={chips=15,mult=2} end,
    function(t)t.deck[1].rank=14;t.deck[1].nominal=11 end,
    function(t)t.modifiers.no_extra_hand_money=true end,
    function(t)t.hand[1].ability.perma_bonus=5 end,
  }
  for i,change in ipairs(variants) do
    local t=clone(s);change(t)
    equal(R.failed(ledger,run,t),nil,'changed public mechanics '..i..' cannot report a restored line')
    local context=R.context(ledger,run,t)
    check(not context.active and next(context.failed_actions)==nil,'mismatched context '..i..' exposes no failure preference')
  end
  equal(R.record(ledger,'another-run',s,play()),nil,'a mismatched run cannot record an action')
  equal(R.failed(ledger,'another-run',s),nil,'a mismatched run cannot report failure')
end

do
  local s=state();local key=assert(R.public_key(s))
  local reordered=clone(s);reordered.deck[1],reordered.deck[3]=reordered.deck[3],reordered.deck[1]
  equal(R.public_key(reordered),key,'future draw order never enters the public key')
  reordered.playing_cards[1],reordered.playing_cards[8]=reordered.playing_cards[8],reordered.playing_cards[1]
  equal(R.public_key(reordered),key,'population storage order does not enter the public key')
  local composition=clone(s)
  composition.deck[1].rank=14;composition.deck[1].nominal=11
  composition.playing_cards[6].rank=14;composition.playing_cards[6].nominal=11
  check(R.public_key(composition) and R.public_key(composition)~=key,'coherent known remaining composition change changes the public key')
  local relabelled=clone(s)
  for _,area in ipairs({'hand','deck','playing_cards'}) do
    for _,c in ipairs(relabelled[area]) do c.id='unrelated-address-'..c.id;c.ability.blueprint_compat_ui='hovered';c.ability.blueprint_compat_check=true end
  end
  equal(R.public_key(relabelled),key,'object labels and tooltip caches are irrelevant')
  relabelled.seed='secret-unused';relabelled.rng={counter=999};relabelled.shop_forecast={future_cards={'hidden'}}
  equal(R.public_key(relabelled),key,'private top-level metadata is outside the projection')
  local hidden=clone(s);hidden.hand[1].face_down=true
  equal(R.public_key(hidden),nil,'concealed held identity prevents a public checkpoint')
  hidden.hand[1].rank=14;hidden.hand[1].suit='Hearts'
  equal(R.public_key(hidden),nil,'concealed held identity changes cannot produce a fingerprint oracle')
  local outside=card('outside',14,'Hearts');outside.face_down=true
  hidden=clone(s);hidden.playing_cards[#hidden.playing_cards+1]=outside
  equal(R.public_key(hidden),nil,'genuinely concealed nondrawable cards abstain before composition')
  outside.rank=2;outside.suit='Clubs'
  equal(R.public_key(hidden),nil,'concealed outside identity changes cannot produce a key')
  outside.face_down=false;check(R.public_key(hidden),'ordinary publicly discarded backs normalized by snapshot can enter known composition')
  local changed=clone(hidden);changed.playing_cards[#changed.playing_cards].rank=3
  check(R.public_key(changed)~=R.public_key(hidden),'known outside composition changes invalidate a checkpoint')
end

do
  local s=state()
  equal(R.action_key(s,play()),R.action_key(s,{kind='play',indices={1}}),'default hand area is canonical')
  local original,validations=R.public_key,0
  R.public_key=function(value)validations=validations+1;return original(value)end
  local encoder=assert(R.action_key_context(s))
  for i=1,5 do equal(encoder(play(i)),R.action_key(s,play(i)),'prepared canonical action key '..i..' has exact parity') end
  equal(validations,6,'one prepared public validation plus five independent reference calls')
  R.public_key=original
  check(R.action_key(s,{kind='play',indices={1,2}})~=R.action_key(s,{kind='play',indices={2,1}}),'played order is preserved')
  check(R.action_key(s,{kind='discard',indices={1,2}})~=R.action_key(s,{kind='discard',indices={2,1}}),'discard order preserves Burnt/Yorick and identity effects')
  local invalid={
    {kind='play',indices={}}, {kind='play',indices={1,1}}, {kind='play',indices={0}},
    {kind='play',indices={6}}, {kind='play',indices={1.5}}, {kind='play',indices={'1'}},
    {kind='play',indices={1},area='deck'}, {kind='play',indices={1},targets={}},
    {kind='play',indices={1},future_score=100}, {kind='unknown'},
    {kind='reorder_hand',order={1,2}}, {kind='reorder_jokers',order={}},
    {kind='reroll'}, {kind='buy',area='shop_jokers',index=1},
  }
  for i,a in ipairs(invalid) do equal(R.action_key(s,a),nil,'unsupported action '..i..' is not canonicalized') end
  check(R.action_key(s,{kind='reorder_hand',order={5,4,3,2,1}}),'complete hand permutation is supported')
  s.consumeables={{id='table: address',key='c_death',ability={name='Death'}}}
  check(R.action_key(s,{kind='use',index=1,targets={1,2}})~=R.action_key(s,{kind='use',index=1,targets={2,1}}),'Death target direction is preserved')
  equal(R.action_key(s,{kind='use',index=1}),R.action_key(s,{kind='use',area='consumeables',index=1,targets={}}),'empty use targets normalize consistently')
  s.phase='shop';s.shop_jokers={{key='j_joker',ability={name='Joker'}}}
  for _,a in ipairs({{kind='buy',area='shop_jokers',index=1},{kind='reroll'},{kind='leave_shop'}}) do check(R.action_key(s,a),'known shop action is represented') end
  s.shop_booster={{key='p_arcana_normal_1',ability={set='Booster'}}}
  check(R.action_key(s,{kind='open',area='shop_booster',index=1}),'real booster-opening action is represented')
  equal(R.action_key(s,{kind='buy',area='shop_booster',index=1}),nil,'a booster cannot be mislabeled as an ordinary purchase')
  equal(R.action_key(s,{kind='open',area='shop_jokers',index=1}),nil,'open cannot name the regular shop area')
  check(R.action_key(s,{kind='buy_and_use',area='shop_jokers',index=1,targets={1}}),'known immediate shop-use action is represented')
  s.jokers={{key='j_egg',ability={name='Egg'}}}
  local sale={kind='sell',area='jokers',index=1}
  local sale_followup=clone(sale);sale_followup.followup={kind='open',area='shop_booster',index=1}
  equal(R.action_key(s,sale),R.action_key(s,sale_followup),'descriptive future purchase is not part of the executed line start')
  sale_followup.followup.callback=function()end
  equal(R.action_key(s,sale_followup),nil,'unknown followup metadata is rejected')
  equal(R.action_key(s,{kind='reorder_hand',order={5,4,3,2,1}}),nil,'hand reorder respects the actual execution phases')
  s.phase='blind';check(R.action_key(s,{kind='select_blind',blind='Small'}),'known blind choice is represented')
  s.phase='pack';s.pack_cards={{key='c_fool',ability={name='The Fool'}}}
  check(R.action_key(s,{kind='choose',index=1}),'known pack choice is represented')
  check(R.action_key(s,{kind='skip_pack'}),'known pack skip is represented')
  s.phase='round';check(R.action_key(s,{kind='cash_out'}),'known cashout is represented')
end

do
  local s=state();local ledger=assert(R.failed(assert(R.record(marked(s),run,s,play())),run,s))
  local variants={
    function(t)t.schema=2 end,function(t)t.run_id='wrong' end,function(t)t.limit=6 end,
    function(t)t.reloads_used=0 end,function(t)t.reloads_used=6 end,function(t)t.reloads_used=0/0 end,
    function(t)t.marks=0 end,function(t)t.marks=257 end,function(t)t.extra=true end,
    function(t)t.reports={} end,function(t)t.reports[1].checkpoint_sequence=2 end,
    function(t)t.checkpoint.key='retry-state-v1:malformed' end,
    function(t)t.checkpoint.key=t.checkpoint.key..'trailing' end,
    function(t)t.checkpoint.attempts[2]=t.checkpoint.attempts[1] end,
    function(t)t.checkpoint.pending='unrecorded' end,
    function(t)t.checkpoint.pending=t.checkpoint.attempts[1] end,
    function(t)t.checkpoint.failures[1].scope='proven_loss' end,
    function(t)t.checkpoint.failures[1].reload=2 end,
    function(t)t.checkpoint.failures[2]=clone(t.checkpoint.failures[1]) end,
    function(t)t.checkpoint.failures={};t.checkpoint.attempts={} end,
    function(t)t.checkpoint.attempts[2]=assert(R.action_key(s,play(2))) end,
    function(t)t.checkpoint.attempts[1]='retry-action-v1:{s4:kindn1;}' end,
    function(t)t.cycle=t end,function(t)setmetatable(t,{__index=function()error('must not execute')end}) end,
    function(t)t.checkpoint.key=string.rep('x',131073) end,
    function(t)t.checkpoint.failures[1].callback=function()error('must not execute')end end,
  }
  for i,change in ipairs(variants) do
    local t=clone(ledger);change(t)
    equal(R.import(t,run),nil,'malformed journal '..i..' fails closed')
    check(not R.context(t,run,s).active,'malformed journal '..i..' cannot affect advice')
  end
  equal(R.new(''),nil,'empty run identity is unsupported')
  equal(R.new('line\nbreak'),nil,'control characters cannot form run identity')
  equal(R.new(string.rep('x',257)),nil,'run identity is bounded')
  equal(R.new({}),nil,'run identity is plain text, not an object')
  local unknown={
    function(t)t.ante=nil end,function(t)t.round=nil end,function(t)t.deck=nil end,
    function(t)t.playing_cards=nil end,function(t)t.hand[1].key=nil end,
    function(t)t.hand[1].ability.wheel_flipped=true end,function(t)t.uncertain=true end,
    function(t)t.current_round.rng_state={counter=2} end,
    function(t)t.hand[1].ability.callback=function()end end,
    function(t)t.playing_cards[8].id=t.playing_cards[7].id end,
    function(t)t.hand[1].id='missing-population' end,
    function(t)t.deck[1].unknown=true end,
    function(t)t.deck[513]={} end,
    function(t)t.hand[1].ability.name=string.rep('x',2049) end,
  }
  for i,change in ipairs(unknown) do local t=clone(s);change(t);equal(R.public_key(t),nil,'incomplete/unknown public state '..i..' abstains') end
  local capped=assert(R.new(run));capped.marks=256
  capped.checkpoint={key=assert(R.public_key(s)),sequence=256,attempts={},failures={}}
  local t=clone(s);t.round=t.round+1
  equal(R.mark(capped,run,t),nil,'checkpoint metadata cannot exceed its fixed mark cap')
end

do
  local s=state();local ledger=marked(s)
  local oldio,oldos,oldg,oldrandom=io,os,G,math.random
  io=setmetatable({},{__index=function()error('Filesystem access is forbidden')end})
  os=setmetatable({},{__index=function()error('OS access is forbidden')end})
  G=setmetatable({},{__index=function()error('Game access is forbidden')end})
  math.random=function()error('RNG access is forbidden')end
  local ok,result=pcall(function()
    local recorded=assert(R.record(ledger,run,s,play()))
    local failed=assert(R.failed(recorded,run,s))
    return R.context(assert(R.import(assert(R.export(failed)),run)),run,s)
  end)
  io,os,G,math.random=oldio,oldos,oldg,oldrandom
  check(ok and result.active,'pure retry operations need no filesystem, OS, game or RNG')
end
print('advisor_retry_memory: '..checks..' checks passed')
