-- Manufactured hand states only. No captured-game policy or scorer replay.
local C=dofile('Brainstorm/Advisor/consumables.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function check(ok,message) assert(ok,message);checks=checks+1 end
local function fool(id,negative)
  return {id=id,key='c_fool',name='The Fool',debuff=false,sell_cost=negative and 3 or 1,
    edition=negative and {negative=true,type='negative'} or nil,
    ability={name='The Fool',set='Tarot',order=1,consumeable={},effect='Disable Blind Effect',
      bonus=0,d_size=0,extra_value=0,h_dollars=0,h_mult=0,h_size=0,h_x_mult=0,mult=0,
      p_dollars=0,perma_bonus=0,t_chips=0,t_mult=0,x_mult=1,type=''}}
end
local function state(count,negative_count,limit)
  local stock={}
  for i=1,count do stock[#stock+1]=fool('fool:'..i,i<=negative_count) end
  stock[#stock+1]={id='sun:1',key='c_sun',sell_cost=1,ability={name='The Sun',set='Tarot'}}
  local hand={}
  for i,spec in ipairs({{14,'Spades'},{12,'Spades'},{9,'Spades'},{6,'Spades'},
      {2,'Spades'},{7,'Hearts'},{5,'Clubs'},{3,'Diamonds'}}) do
    hand[i]={id='playing:'..i,key='c_base',rank=spec[1],suit=spec[2],
      nominal=spec[1]==14 and 11 or math.min(10,spec[1]),ability={set='Default'}}
  end
  return {phase='hand',teacher_profile='perkeo_yorick_win_v1',ante=8,win_ante=8,
    blind={key='bl_big',chips=300000},chips=0,hands_left=4,discards_left=0,
    consumable_limit=limit,consumeable_buffer=0,consumeables=stock,last_tarot_planet='c_jupiter',
    fool_source={schema='fool_last_center_v1',key='c_jupiter',name='Jupiter',set='Planet',
      effect='Hand Upgrade',order=5,cost=3,config={hand_type='Flush'}},
    hands={Flush={level=3,chips=65,mult=8,l_chips=15,l_mult=2,s_chips=35,s_mult=4,played=14},
      ['High Card']={level=3,chips=25,mult=3,played=12}},
    jokers={{key='j_yorick',ability={name='Yorick',set='Joker',x_mult=5}},
      {key='j_perkeo',ability={name='Perkeo',set='Joker'}}},
    used_vouchers={},consumeable_usage={},consumeable_usage_total={tarot=0,planet=0,
      spectral=0,tarot_planet=0,all=0},hand=hand,playing_cards=Snapshot.copy(hand),
    modifiers={},probabilities={normal=1},dollars=20}
end
local function result(score)
  return {action={kind='play',area='hand',indices={1,2,3,4,5}},
    play={hand='Flush',score=score,legal=true,uncertain=false,indices={1,2,3,4,5}},evaluations=12}
end

do
  local s=state(15,14,16);local before=Snapshot.fingerprint(s)
  local first,endpoint,proof=C.project_fool_jupiter(s,15)
  check(first and endpoint and proof,'full ordinary Fool admits one complete public cycle')
  check(#first.consumeables==16 and first.consumable_limit==16 and first.last_tarot_planet=='c_fool',
    'ordinary full stock remains legal after the copied Jupiter settles')
  check(first.consumeables[#first.consumeables].key=='c_jupiter' and not first.consumeables[#first.consumeables].edition,
    'generated Jupiter is a fresh editionless card')
  check(#endpoint.consumeables==15 and endpoint.consumable_limit==16 and endpoint.last_tarot_planet=='c_jupiter',
    'Jupiter use frees one slot and restores last-used key')
  check(endpoint.hands.Flush.level==4 and endpoint.hands.Flush.chips==80 and endpoint.hands.Flush.mult==10,
    'the complete endpoint adds exactly one Flush level')
  check(first.hands.Flush.level==3 and first.consumeable_usage_total.tarot==1 and
      endpoint.consumeable_usage_total.planet==1,'Fool alone never receives premature Planet credit')
  check(endpoint.consumeable_usage.c_jupiter.count==1 and endpoint.consumeable_usage.c_fool.count==1,
    'both physical uses update their per-key history in the projected cycle')
  check(Snapshot.fingerprint(s)==before,'projection does not mutate the original public state')
  check(not C.project_fool_jupiter(first,1),'second Fool is unavailable until a Jupiter is used')
  local indices={1,2,3,4,5}
  local baseline=Scoring.score(s,indices)
  local improved=Scoring.score(endpoint,indices)
  check(baseline.legal and not baseline.uncertain and baseline.hand=='Flush' and
      improved.legal and not improved.uncertain and improved.hand=='Flush' and
      improved.score>baseline.score,'same legal manufactured Flush has a higher exact score after the complete cycle')
  local proposal=C.fool_jupiter_stock(s,S,result(baseline.score))
  check(proposal and proposal.action.index==15 and proposal.fool_jupiter_stock.step=='fool' and
      proposal.fool_jupiter_stock.merit>0,'large stock chooses the legal ordinary Fool')
  local full_row=Snapshot.copy(s)
  full_row.jokers={
    {key='j_ride_the_bus',ability={name='Ride the Bus',set='Joker',mult=4,extra=1}},
    {key='j_yorick',ability={name='Yorick',set='Joker',x_mult=5}},
    {key='j_mail',ability={name='Mail-In Rebate',set='Joker'}},
    {key='j_perkeo',ability={name='Perkeo',set='Joker'}},
    {key='j_delayed_grat',ability={name='Delayed Gratification',set='Joker'}}}
  local row_score=Scoring.score(full_row,indices)
  check(row_score.legal and not row_score.uncertain and
      C.fool_jupiter_stock(full_row,S,result(row_score.score)),
    'the observed class of five safe Jokers admits the same manufactured useful cycle')
  local fresh=Snapshot.copy(first);fresh.consumeables[#fresh.consumeables].id='observed:jupiter'
  local consumed=C.apply(fresh,#fresh.consumeables,{})
  local future_loss,_,last_source=S.preservation_cost(fresh,consumed,#fresh.consumeables)
  check(last_source and future_loss>0,'the visible last Jupiter has a real Perkeo-pool opportunity cost')
  local follow=C.fool_jupiter_stock(fresh,S,result(baseline.score))
  check(follow and follow.action.index==#fresh.consumeables and follow.fool_jupiter_stock.step=='jupiter',
    'fresh observation selects the visible Jupiter by its current index')
  check(follow.fool_jupiter_stock.development_gain>future_loss+2,
    'the last Jupiter is used only when its hand gain beats pool loss and action cost')
end

do
  local full=state(15,15,16)
  check(not C.project_fool_jupiter(full,1),'full Negative Fool is rejected at overcapacity intermediate endpoint')
  local spare=state(14,14,16)
  local first,endpoint=C.project_fool_jupiter(spare,1)
  check(first and #first.consumeables==15 and first.consumable_limit==15 and
      #endpoint.consumeables==14 and endpoint.consumable_limit==15,
    'Negative Fool with one spare slot conserves both settled endpoints')
  local ordinary=state(14,13,16)
  first,endpoint=C.project_fool_jupiter(ordinary,14)
  check(first and #first.consumeables==15 and first.consumable_limit==16 and
      #endpoint.consumeables==14,'ordinary Fool with spare capacity is legal')
  local string_negative=state(14,14,16);string_negative.consumeables[1].edition='negative'
  check(C.project_fool_jupiter(string_negative,1),'string Negative edition is supported')
end

do
  local mutations={
    function(s)s.fool_source=nil end,
    function(s)s.fool_source.config.bonus=3 end,
    function(s)s.fool_source.config.hand_type='High Card' end,
    function(s)s.fool_source.key='c_mars' end,
    function(s)s.fool_source.unlocked=false end,
    function(s)s.consumeable_buffer=1 end,
    function(s)s.consumeables[2].id=s.consumeables[1].id end,
    function(s)s.consumeables[15].edition={negative=true,foil=true} end,
    function(s)s.consumeables[15].ability.consumeable.chips=1 end,
    function(s)s.consumeables[15].debuff=true end,
    function(s)s.jokers[1].key='j_fortune_teller' end,
    function(s)s.used_vouchers.v_observatory=true end,
    function(s)s.last_tarot_planet='c_fool' end,
    function(s)s.consumeable_usage_total.tarot=nil end,
  }
  for i,mutate in ipairs(mutations) do
    local s=state(15,14,16);mutate(s)
    check(not C.project_fool_jupiter(s,15),'unsupported metadata/capacity/callback mutation '..i..' abstains')
  end
  local s=state(15,14,16)
  check(not C.fool_jupiter_stock(s,S,result(300000)),'supported current clear holds stock')
  local wrong=result(80000);wrong.play.hand='High Card'
  check(not C.fool_jupiter_stock(s,S,wrong),'non-main current play does not trigger stock cycling')
  wrong=result(80000);wrong.action.kind='discard'
  check(not C.fool_jupiter_stock(s,S,wrong),'a selected discard keeps priority')
  wrong=result(80000);wrong.action.kind='use'
  check(not C.fool_jupiter_stock(s,S,wrong),'another selected consumable keeps priority')
  local first=C.project_fool_jupiter(s,15)
  first.consumeables[#first.consumeables].identity_redacted=true
  check(not C.fool_jupiter_stock(first,S,result(80000)),
    'concealed generated-Planet identity cannot be used by the exact continuation')
  first=C.project_fool_jupiter(s,15)
  first.consumeables[#first.consumeables].ability.h_size=1
  check(not C.fool_jupiter_stock(first,S,result(80000)),
    'resource-modified Jupiter cannot enter the exact continuation')
  s.hands.Flush.level=30;s.hands.Flush.chips=470;s.hands.Flush.mult=62
  check(not C.fool_jupiter_stock(s,S,result(80000)),'holding wins when marginal growth cannot repay action and stock costs')
end

do
  local s=state(15,14,16)
  local scoped={comparison_reserve=function()return 0 end,suggest=function()return nil,0,{} end,
    fool_jupiter_stock=C.fool_jupiter_stock}
  local modules={strategy=S,consumables=scoped,
    search={run=function()return result(80000) end}}
  local answer=D.run(s,modules,nil,{})
  check(answer.action.kind=='use' and answer.action.index==15 and answer.evaluations==12,
    'decision integrates stock cycle without adding score evaluations')
  modules.search.run=function()local r=result(80000);r.kind='discard';r.discard={indices={6},probability=0.4};
    r.action={kind='discard',area='hand',indices={6}};return r end
  answer=D.run(s,modules,nil,{})
  check(answer.action.kind=='discard','decision retains selected discard')
  modules.search.run=function()
    local r=result(80000);r.two_hand_finish={action={kind='play',area='hand',indices={1,2,3,4,5}}}
    return r
  end
  answer=D.run(s,modules,nil,{})
  check(answer.action.kind=='play' and not answer.fool_jupiter_stock,
    'a specialist play keeps priority over strategic Fool stock')
end

print('advisor_fool_stock376: '..checks..' checks passed')
