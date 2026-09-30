local Phase=dofile('Brainstorm/Advisor/phase_copy.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local modules={scoring=Scoring,growth=Growth,search=Search,strategy=Strategy,gold_stickers=Gold}
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function joker(key,name,a) a=a or {};a.name=name;return {key=key,name=name,ability=a,blueprint_compat=true} end
local function card(id,rank,suit) return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit or 'Spades',enhancement='c_base',ability={}} end
local function state()
  local s={phase='hand',ante=2,blind={chips=600},chips=0,hands_left=4,hands_played=0,discards_left=4,discards_used=0,
    current_round={},dollars=20,hand_size=8,hand_limit=5,modifiers={},
    jokers={joker('j_yorick','Yorick',{x_mult=8,yorick_discards=23,extra={discards=23,xmult=1}}),
      joker('j_brainstorm','Brainstorm'),joker('j_burnt','Burnt Joker'),joker('j_perkeo','Perkeo')},
    hand={card('a',14),card('b',2,'Hearts'),card('c',2,'Clubs'),card('d',2,'Diamonds'),card('e',5,'Hearts'),card('f',7),card('g',9),card('h',10)},
    deck={},hands={},consumeables={},probabilities={normal=1},consumeable_buffer=0,consumable_limit=2}
  for i=1,20 do s.deck[i]=card('k'..i,i<=12 and 2 or 6,i%2==0 and 'Hearts' or 'Spades') end
  s.playing_cards={};for _,c in ipairs(s.hand) do s.playing_cards[#s.playing_cards+1]=c end
  for _,c in ipairs(s.deck) do s.playing_cards[#s.playing_cards+1]=c end
  s.hands['Three of a Kind']={level=3,chips=70,mult=6,l_chips=20,l_mult=2,played=5,visible=true}
  return s
end
local function base(s)
  local play=Scoring.score(s,{1});play.indices={1}
  return {kind='play',action={kind='play',area='hand',indices={1}},play=play}
end
local function call(s,b,opts)
  return Phase.suggest(s,modules,b or base(s),opts or {max_evaluations=30})
end
math.random=function() error('phase copy touched RNG') end
pseudorandom=function() error('phase copy touched game RNG') end

do
  local s=state();local original=Snapshot.fingerprint(s)
  eq(Scoring.score(s,{1}).score,1024,'original copied Yorick square clears with one Ace')
  local r,n,d=call(s)
  check(r and r.action.kind=='reorder_jokers','first real action prepares Burnt')
  check(r.needs_refresh and d.complete,'prepared action requires a fresh state')
  eq(d.events_before,1,'baseline has one real Burnt callback')
  eq(d.events_after,2,'Brainstorm copies Burnt for a second callback')
  eq(d.burnt_hand,'Three of a Kind','public sustainable rank hand earns the first discard')
  eq(#d.discard_indices,5,'padded Burnt hand also spends a full Yorick discard')
  check(n<=18,'bounded complete comparison and retained growth fit eighteen scores')
  eq(Snapshot.fingerprint(s),original,'the source snapshot remains unchanged')
  eq(Snapshot.fingerprint(r),Snapshot.fingerprint(call(s)),'suggestions are deterministic')
  local prepared=Phase.reorder(s,r.action.order)
  eq(Phase.copy_effects(prepared,'j_burnt'),2,'physical arrangement has both Burnt effects')
  check(Scoring.score(prepared,{1}).score<600,'copying Burnt alone temporarily loses the cheap score')
  local fresh=base(prepared)
  fresh.ordering={play={score=1024,indices={1}},action={kind='reorder_jokers',order=d.finish_order}}
  fresh.action=fresh.ordering.action
  local discard,work,dd=call(prepared,fresh)
  check(discard and discard.action.kind=='discard','fresh advice discards instead of bouncing back to Yorick')
  local after,e=Scoring.after_discard(prepared,discard.action.indices)
  eq(e.burnt_levels,2,'the actual selected discard receives two levels')
  eq(e.burnt_hand,'Three of a Kind','the exact classified hand matches the recommendation')
  local yorick
  for _,j in ipairs(after.jokers) do if j.key=='j_yorick' then yorick=j end end
  eq(yorick.ability.yorick_discards,18,'physical Yorick growth counts five cards once, not twice')
  eq(yorick.ability.x_mult,8,'a copied discard does not invent Yorick XMult')
  local ready=Phase.reorder(after,dd.finish_order)
  check(Scoring.score(ready,discard.play.indices).score>=600,'the retained cards clear under the separately executable scoring order')
  eq(call(after),nil,'Burnt does not repeat after the actual first discard')
end

do
  local s=state();s.phase='shop';s.consumeables={{key='c_temperance',ability={name='Temperance',set='Tarot'}}}
  for _,j in ipairs(s.jokers) do j.sell_cost=10 end
  local b={action={kind='leave_shop'}};local before=Snapshot.fingerprint(s)
  local r,n,d=call(s,b)
  check(r and r.action.kind=='reorder_jokers','shop exit prepares Perkeo')
  eq(n,0,'shop preparation needs no score calls')
  eq(d.events_before,1,'one ordinary Perkeo before setup')
  eq(d.events_after,2,'copying Joker doubles shop-exit copy events')
  eq(Phase.copy_effects(Phase.reorder(s,r.action.order),'j_perkeo'),2,'real row resolves to Perkeo')
  eq(Snapshot.fingerprint(s),before,'shop proposal preserves cash and all inventory')
  eq(call(Phase.reorder(s,r.action.order),b),nil,'already arranged exit does not reorder again')
  eq(call(s,{action={kind='buy',area='shop_jokers',index=1}}),nil,'do not displace buying or funding decisions')
  s.consumeables[1].edition={negative=true}
  check(call(s,b),'a Negative consumable remains a valid Perkeo target')
  s.ante=8;s.next_blind={chips=100000,boss=true};s.blind.boss=true
  check(call(s,b),'the immediate final-shop copy is not erased by a zero later-shop horizon')
  s.consumeables={};eq(call(s,b),nil,'empty Perkeo pools never create imagined copies')
end

do
  local s=state();s.jokers[2]=joker('j_blueprint','Blueprint')
  local r,_,d=call(s)
  check(r and (r.action.kind=='reorder_jokers' or r.action.kind=='discard'),'Blueprint also supports Burnt preparation')
  eq(d.events_after,2,'Blueprint produces two total Burnt callbacks')
  s.jokers[#s.jokers+1]=joker('j_brainstorm','Brainstorm')
  local order,count=Phase.target_order(s,'j_burnt')
  eq(count,3,'Blueprint and Brainstorm can form a complete chain into Burnt')
  eq(Phase.copy_effects(Phase.reorder(s,order),'j_burnt'),3,'both copies resolve without a cycle')
  local cycle={jokers={joker('j_blueprint','Blueprint'),joker('j_brainstorm','Brainstorm')}}
  eq(Phase.copy_effects(cycle,'j_burnt'),0,'cycles produce no invented callback')
end

do
  local s=state();local b=base(s)
  local _,n,d=call(s,b,{max_evaluations=1})
  eq(n,0,'insufficient comparison budget does no partial work')
  check(not d.complete,'insufficient budget cannot publish')
  s=state();s.jokers[2].debuff=true;eq(call(s),nil,'a debuffed copy Joker is inactive')
  s=state();s.jokers[2].ability.perishable=true;s.jokers[2].ability.perish_tally=0;eq(call(s),nil,'expired Perishable copy Joker is inactive')
  s=state();s.jokers[1].pinned=true;s.jokers[2].pinned=true;s.jokers[3].pinned=true;s.jokers[4].pinned=true
  eq(call(s),nil,'pinned row cannot invent a different Burnt arrangement')
  s=state();s.jokers[3].facing='back';eq(call(s),nil,'face-down card blocks setup')
  s=state();s.ordering_safe=false;eq(call(s),nil,'movement guard blocks setup')
  s=state();s.blind={chips=600,key='bl_final_acorn'};eq(call(s),nil,'Amber Acorn stays unsupported')
  s=state();s.jokers[#s.jokers+1]=joker('j_custom','Unknown mod callback');eq(call(s),nil,'unknown callbacks cannot get a phase proof')
  s=state();for _,c in ipairs(s.hand) do c.seal='Purple' end;eq(call(s),nil,'unknown Tarot generation is never filled in')
  s=state();s.ante=8;s.blind.boss=true;eq(call(s),nil,'the final win takes precedence over further Burnt investment')
end

do
  local s=state();s.jokers[1]=joker('j_mail','Mail-In Rebate',{extra=5});s.current_round.mail_card={id=2}
  s.jokers[4]=joker('j_yorick','Yorick',{x_mult=8,yorick_discards=23,extra={discards=23,xmult=1}})
  local r=call(s)
  eq(r,nil,'losing copied discard income prevents claiming a free Burnt improvement')
  s=state();s.phase='shop';s.consumeables={{key='c_temperance',ability={name='Temperance',set='Tarot'}}}
  s.jokers[#s.jokers+1]=joker('j_ceremonial','Ceremonial Dagger',{mult=10})
  local order=Phase.target_order(s,'j_perkeo')
  local arranged=Phase.reorder(s,order)
  eq(arranged.jokers[#arranged.jokers].key,'j_ceremonial','safe reorder leaves Dagger without a new victim')
  s.jokers[1],s.jokers[5]=s.jokers[5],s.jokers[1]
  order=Phase.target_order(s,'j_perkeo');arranged=Phase.reorder(s,order)
  local before,after
  for i,j in ipairs(s.jokers) do if j.key=='j_ceremonial' then before=s.jokers[i+1] end end
  for i,j in ipairs(arranged.jokers) do if j.key=='j_ceremonial' then after=arranged.jokers[i+1] end end
  eq(after,before,'the same physical Dagger victim remains adjacent')
end
do
  local s=state()
  s.jokers[1].ability.x_mult=40;s.blind.chips=23000
  local full={};for k,v in pairs(modules) do full[k]=v end
  full.ordering=dofile('Brainstorm/Advisor/ordering.lua')
  local initial=Decision.run(s,full,nil,{search={samples=0}})
  local prepared=Phase.apply(s,full,initial)
  local integrated={};for k,v in pairs(full) do integrated[k]=v end;integrated.phase_copy=Phase
  local actual=Decision.run(s,integrated,nil,{search={samples=0}})
  eq(Snapshot.fingerprint(actual.action),Snapshot.fingerprint(prepared.action),'production decision applies phase setup exactly once')
  eq(actual.evaluations,prepared.evaluations,'production phase score accounting matches the detached comparison')
  eq(prepared.action.kind,'reorder_jokers','shared decision gets a real Burnt setup action')
  check(prepared.ordering and prepared.ordering.action==prepared.action,'existing display renders the same new order action')
  check(prepared.evaluations<=70,'fast clear and phase work jointly remain within seventy scores')
  eq(initial.action.kind,'discard','the original safe-growth incumbent is preserved independently')
  local fresh_state=Phase.reorder(s,prepared.action.order)
  local fresh=Decision.run(fresh_state,full,nil,{search={samples=0}})
  eq(fresh.action.kind,'reorder_jokers','ordinary scorer alone wants to undo Burnt setup')
  local combined=Phase.apply(fresh_state,full,fresh)
  actual=Decision.run(fresh_state,integrated,nil,{search={samples=0}})
  eq(Snapshot.fingerprint(actual.action),Snapshot.fingerprint(combined.action),'production fresh decision spends the Burnt discard')
  eq(combined.action.kind,'discard','joint phase planning correctly spends the first discard')
  check(combined.growth and not combined.ordering,'display presents only the selected discard')
  local after=Scoring.after_discard(fresh_state,combined.action.indices)
  local next_decision=Phase.apply(after,full,Decision.run(after,full,nil,{search={samples=0}}))
  eq(next_decision.action.kind,'reorder_jokers','after the discard the normal scored order resumes')
  local cutoff=base(s);cutoff.fast_clear={};cutoff.evaluations=69
  local exhausted=Phase.apply(s,full,cutoff)
  eq(exhausted.action.kind,'play','insufficient leftover fast-clear budget retains the incumbent')
  eq(exhausted.evaluations,69,'failed budget admission spends no scores')
  cutoff.fast_clear=nil;cutoff.evaluations=139999
  exhausted=Phase.apply(s,full,cutoff)
  eq(exhausted.action.kind,'play','insufficient normal budget also retains the incumbent')
  eq(exhausted.evaluations,139999,'ordinary existing score cap is not enlarged')
end
do
  local original=state();original.jokers[1].ability.x_mult=40;original.blind.chips=23000
  local order,used={},{}
  local function permutations(position)
    if position>#original.jokers then
      local s=Phase.reorder(original,order);local r,n,d=call(s)
      check(r and d.complete,'every visible four-Joker arrangement has a complete supported setup')
      check(n<=18,'all four-Joker arrangements respect the bounded score cost')
      if r.action.kind=='reorder_jokers' then s=Phase.reorder(s,r.action.order);r=call(s) end
      check(r and r.action.kind=='discard','at most one preparation reorder leads to a real discard')
      local after,effects=Scoring.after_discard(s,r.action.indices)
      eq(effects.burnt_levels,2,'all arrangements realize two Burnt callbacks')
      local ready=Phase.reorder(after,r.phase_copy.finish_order)
      check(Scoring.score(ready,r.play.indices).score>=23000,'every restored retained finish really clears')
      return
    end
    for i=1,#original.jokers do if not used[i] then used[i]=true;order[position]=i;permutations(position+1);used[i]=nil end end
  end
  permutations(1)
end
print('advisor_phase_copy: '..checks..' checks passed')
