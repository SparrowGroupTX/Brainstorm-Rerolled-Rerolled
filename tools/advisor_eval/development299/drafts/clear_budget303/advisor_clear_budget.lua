local prefix='tools/advisor_eval/development299/drafts/clear_budget303/'
local Search=dofile(prefix..'search.lua')
local Decision=dofile(prefix..'decision.lua')
local Phase=dofile(prefix..'phase_copy.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(i,r,suit) return {id=i,rank=r,nominal=r==14 and 11 or math.min(10,r),
  suit=suit or 'Spades',ability={},enhancement='c_base'} end
local function state()
  local s={phase='hand',ante=2,hand={},deck={},playing_cards={},jokers={},consumeables={},
    hands={},hand_limit=5,hand_size=8,hands_left=4,discards_left=4,discards_used=0,dollars=20,chips=0,
    blind={key='bl_small',chips=300},current_round={},modifiers={},probabilities={normal=1}}
  for i=1,8 do s.hand[i]=card(i,i<=4 and 13 or i-3);s.playing_cards[i]=s.hand[i] end
  return s
end
local forbidden=function() error('exhaustive specialist ran after supported clear') end
math.random=function() error('clear budget touched RNG') end
pseudorandom=math.random

do
  local s=state();local before=Snapshot.fingerprint(s)
  local r=Search.run(s,Scoring)
  check(r.fast_clear and not r.clear_shortcut,'shortlist clear retains its distinct fast contract')
  eq(r.fast_clear.search_path,'shortlist','records initial shortlist discovery')
  eq(r.fast_clear.aggregate_limit,70,'initial shortlist has seventy total scores')
  check(r.evaluations<=48,'search and conservation remain at most48')
  local calls=0
  local fake={score=function(_,indices)
    calls=calls+1
    return {legal=true,score=table.concat(indices,',')=='4,5,6,7,8' and 400 or 0,hand='Flush'}
  end}
  r=Decision.run(s,{search=Search,scoring=fake,ordering={suggest=forbidden},hand_ordering={suggest=forbidden}})
  check(r.clear_shortcut and not r.fast_clear,'late enumeration has no false fast-clear label')
  eq(r.clear_shortcut.search_path,'enumeration','records later enumeration discovery')
  eq(r.clear_shortcut.aggregate_limit,140000,'late enumeration shares the ordinary ceiling')
  eq(r.evaluations,calls,'all raw score calls remain accounted')
  check(calls>70 and calls<=140000,'late clear can honestly exceed70 within ordinary allowance')
  check(r.clear_shortcut.conservation_evaluations<=16,'late conservation remains bounded')
  check(r.clear_shortcut.specialists_skipped and not r.play_complete,'clear shortcut never claims complete play coverage')
  eq(r.action.kind,'play','reliable late clear is still the executable incumbent')
  eq(Snapshot.fingerprint(s),before,'classification does not mutate public state')
end

do
  local function budget_case(tag,initial)
    local observed={}
    local s=state();s.consumeables={{key='c_strength'}}
    local base={kind='play',play={score=400,legal=true,indices={1}},evaluations=initial}
    base[tag]={}
    local r=Decision.run(s,{scoring={},search={run=function() return base end},
      consumables={develop=function(_,_,_,options)
        observed.development=options.max_development_evaluations
        return nil,observed.development,{}
      end,suggest=forbidden},
      growth={suggest=function(_,_,_,options)
        observed.growth=options.max_evaluations;return nil,observed.growth,{}
      end},ordering={suggest=forbidden},hand_ordering={suggest=forbidden}})
    return r,observed
  end
  local r,seen=budget_case('fast_clear',69)
  eq(seen.development,1,'fast-clear development shares the last available score')
  eq(seen.growth,0,'fast-clear growth cannot renew spent work')
  eq(r.evaluations,70,'seventy remains a whole-decision hard bound')
  r,seen=budget_case('clear_shortcut',139995)
  eq(seen.development,5,'late development clips to ordinary remaining budget')
  eq(seen.growth,0,'late growth cannot exceed the aggregate cap')
  eq(r.evaluations,140000,'late shortcut has no additional score allowance')
  r,seen=budget_case('clear_shortcut',173)
  eq(seen.development,6,'late development keeps the existing six-score local ceiling')
  eq(seen.growth,12,'late growth keeps the existing twelve-score local ceiling')
  eq(r.evaluations,191,'late post-clear actual work is accounted')
end

do
  local function joker(key,name,ability)
    ability=ability or {};ability.name=name
    return {key=key,name=name,ability=ability,blueprint_compat=true}
  end
  local s=state();s.blind.chips=600
  s.jokers={joker('j_yorick','Yorick',{x_mult=8,yorick_discards=23,extra={discards=23,xmult=1}}),
    joker('j_brainstorm','Brainstorm'),joker('j_burnt','Burnt Joker'),joker('j_perkeo','Perkeo')}
  s.hand={card('a',14),card('b',2,'Hearts'),card('c',2,'Clubs'),card('d',2,'Diamonds'),
    card('e',5,'Hearts'),card('f',7),card('g',9),card('h',10)}
  for i=1,20 do s.deck[i]=card('k'..i,i<=12 and 2 or 6,i%2==0 and 'Hearts' or 'Spades') end
  s.playing_cards={};for _,c in ipairs(s.hand) do s.playing_cards[#s.playing_cards+1]=c end
  for _,c in ipairs(s.deck) do s.playing_cards[#s.playing_cards+1]=c end
  s.hands['Three of a Kind']={level=3,chips=70,mult=6,l_chips=20,l_mult=2,played=5,visible=true}
  local before=Snapshot.fingerprint(s)
  local play=Scoring.score(s,{1});play.indices={1}
  local base={kind='play',play=play,action={kind='play',area='hand',indices={1}},evaluations=173,fast_clear={}}
  local modules={scoring=Scoring,growth=Growth,search=Search,strategy=Strategy,gold_stickers=Gold}
  local old=Phase.apply(s,modules,base)
  eq(old.action.kind,'play','old ambiguous fast label fails closed after70')
  eq(old.evaluations,173,'old ambiguous label cannot conceal earlier score work')
  base.fast_clear=nil;base.clear_shortcut={search_path='enumeration'}
  local repaired=Phase.apply(s,modules,base)
  eq(repaired.action.kind,'reorder_jokers','late clear permits a complete legal Burnt preparation')
  check(repaired.phase_copy and repaired.phase_copy.complete,'phase proof is complete')
  eq(repaired.phase_copy_diagnostics.aggregate_limit,140000,'Burnt comparison inherits ordinary allowance')
  eq(repaired.phase_copy_diagnostics.remaining_before,139827,'phase sees actual unspent work only')
  check(repaired.evaluations>173 and repaired.evaluations<=203,'phase work remains at most thirty calls')
  local arranged=Phase.reorder(s,repaired.action.order)
  eq(Phase.copy_effects(arranged,'j_burnt'),2,'actual new order copies Burnt')
  eq(Snapshot.fingerprint(s),before,'the phase proposal never applies an imaginary order to input')
  base.evaluations=139999
  repaired=Phase.apply(s,modules,base)
  eq(repaired.action.kind,'play','insufficient ordinary remainder retains incumbent')
  eq(repaired.evaluations,139999,'incomplete phase comparison spends no partial proof')
end
print('advisor_clear_budget: '..checks..' checks passed')
