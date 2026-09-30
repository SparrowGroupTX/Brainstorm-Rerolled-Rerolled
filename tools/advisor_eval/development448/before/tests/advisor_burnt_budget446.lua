-- Manufactured saturation: no journal or captured state is executed.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
for _,k in ipairs({'phase_copy','gold_stickers'})do m[k]=dofile('Brainstorm/Advisor/'..k..'.lua')end
local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state()
 local s=F.state(false);s.blind={key='bl_big',name='Big Blind',chips=23000};s.hand={};s.deck={};s.hand_size=8
 for i,r in ipairs({14,2,2,2,5,7,9,10})do s.hand[i]=F.card('budget446:'..i,r,i<3 and 'Spades' or 'Hearts')end
 for i=1,12 do s.deck[i]=F.card('draw446:'..i,6,'Clubs')end
 s.jokers={F.j('j_yorick'),F.j('j_brainstorm'),F.joker('j_burnt','Burnt Joker',{extra=4}),F.j('j_perkeo')}
 s.jokers[1].ability.x_mult=40;s.jokers[3].ability.effect=nil
 s.hands={['Three of a Kind']={level=3,chips=70,mult=6,l_chips=20,l_mult=2,played=5,visible=true}}
 s.consumeables={};F.population(s);return s
end
local function budget_decision(s,limit,fast,retry)
 local calls,probe,seen=0,false,{}
 local scoring=setmetatable({}, {__index=m.scoring})
 for _,k in ipairs({'score','lower_bound'})do local method=k
  scoring[method]=function(...)
   calls=calls+1;if probe then return {}end
   return m.scoring[method](...)
  end
 end
 local function spend(count)
  probe=true;for i=1,count do scoring.score(s,{1})end;probe=false
 end
 local search=setmetatable({run=function(_,_,options)
  seen.search=options.max_evaluations;local work=math.max(0,options.max_evaluations-19);spend(work)
  return {kind='play',play={indices={5},score=1,legal=true},evaluations=work,
    alternatives={{indices={2,3,4},score=1}}}
 end},{__index=m.search})
 local order=m.phase_copy.target_order(s,'j_yorick')
 local clear=m.scoring.score(m.phase_copy.reorder(s,order),{1});clear.indices={1}
 local ordering={suggest=function(_,_,_,_,options)
  seen.ordering=options.max_evaluations;spend(options.max_evaluations)
  return {action={kind='reorder_jokers',area='jokers',order=order},play=clear},options.max_evaluations
 end}
 local late={suggest=function(_,_,_,_,options)seen.late=options.max_evaluations;return nil,0 end}
 local modules={decision=m.decision,scoring=scoring,search=search,ordering=ordering,multi_discard=late,
  phase_copy=m.phase_copy,growth=m.growth,strategy=m.strategy,gold_stickers=m.gold_stickers}
 local opts={prepared_scoring=false,search={max_evaluations=limit,fast_clear=fast},retry=retry}
 local r=m.decision.run(s,modules,nil,opts)
 check(calls==r.evaluations,'every actual score/lower-bound call is counted')
 check(r.evaluations<=limit,'shared requested allowance remains binding')
 check(seen.search==limit-18 and seen.ordering==19 and seen.late==0,
  'search and all specialists preserve the same eighteen calls')
 check(opts.search.max_evaluations==limit,'caller options unchanged')
 return r
end
local s=state();local hash=m.snapshot.fingerprint(s)
local first=budget_decision(s,140000)
check(first.action.kind=='reorder_jokers' and first.phase_copy.complete,'saturated ordinary decision prepares Burnt')
local prepared=m.phase_copy.reorder(s,first.action.order)
check(m.phase_copy.comparison_reserve(prepared,m)==18,'already copied Burnt also reserves comparison work')
local fresh=budget_decision(prepared,140000)
check(fresh.action.kind=='discard' and #fresh.action.indices==5,'fresh saturated decision actually discards instead of reversing order')
local after,e=assert(m.scoring.after_discard(prepared,fresh.action.indices))
check(e.burnt_levels==2 and after.discards_left==s.discards_left-1,'settled physical discard spends one and gains two levels')
check(m.snapshot.fingerprint(s)==hash,'original input unchanged')
check(fresh.discard_preference_work==fresh.phase_copy_diagnostics.growth_work and fresh.discard_preference_work<=12,
 'phase growth work is charged to the shared twelve')
local compact=Journal.compact_phase_copy_review(fresh)
check(compact.selected and compact.reserved_evaluations==18 and compact.remaining_before==18,'public receipt exposes reserved comparison')
for _,fast in ipairs({false,true})do
 local r=budget_decision(prepared,90,fast)
 check(r.action.kind=='discard','smaller caller and unsuccessful fast-clear searches retain complete qualified action')
end
local actual=m.decision.run(s,m,nil,{prepared_scoring=false,search={samples=0,fast_clear=true}})
check(type(actual.fast_clear)=='table' and actual.evaluations<=70,'actual early-clear result retains its seventy-call aggregate contract')
check((actual.discard_preference_work or 0)<=12,'actual shortcut and phase share twelve growth calls')
check(actual.phase_copy and actual.phase_copy.complete and actual.action.kind=='reorder_jokers',
 'actual shortcut gives the shared growth comparison to the first-discard copied row')
local tiny=state();tiny.hand={tiny.hand[1]};tiny.hand_size=1;tiny.blind.chips=1;F.population(tiny)
local cheap=m.decision.run(tiny,m,nil,{prepared_scoring=false,search={fast_clear=true,max_evaluations=1}})
check(cheap.action and cheap.action.kind=='play' and cheap.evaluations==1 and cheap.phase_copy_reserved_evaluations==0,
 'optional proof cannot starve a one-call caller of its legal incumbent')
local no_burnt=state();no_burnt.jokers[3]=F.j('j_perkeo');no_burnt.blind.chips=1e12
local search_seen
local no_modules={scoring=m.scoring,phase_copy=m.phase_copy,gold_stickers=m.gold_stickers,
 search={run=function(_,_,o)search_seen=o.max_evaluations;return {kind='play',play={score=1,indices={1}},evaluations=100}end}}
local ordinary=m.decision.run(no_burnt,no_modules,nil,{search={fast_clear=true,max_evaluations=120},prepared_scoring=false})
check(search_seen==120 and ordinary.evaluations==100 and not ordinary.fast_clear,
 'requesting early-clear search never turns a failed shortcut into a global seventy-score cap')
local retried=budget_decision(prepared,90,false,{unavailable=true})
check(not retried.action and retried.retry.status=='unavailable','retry arbitration still removes the action')
local bad=F.copy(prepared);bad.blind.chips=1e12
local rejected=budget_decision(bad,90)
check(not rejected.phase_copy and rejected.action.kind=='reorder_jokers','no independent clear cannot publish Burnt action')
local base={action={kind='reorder_jokers',order={1,2,3,4}},ordering={play={indices={1},score=30000}},
 play={indices={1},score=30000},alternatives={{indices={2,3,4},score=1}}}
local _,_,d=m.phase_copy.suggest(prepared,m,base,{max_evaluations=30})
local required=assert(d.required_evaluations)
local fit,_,fitd=m.phase_copy.suggest(prepared,m,base,{max_evaluations=required})
check(fit and fitd.complete,'exact paired-family allowance fits')
local no,work,nd=m.phase_copy.suggest(prepared,m,base,{max_evaluations=required-1})
check(not no and work==0 and nd.scope=='first_discard_burnt','one short never starts an incomplete family')
local receipt=Journal.compact_phase_copy_review({phase_copy_diagnostics=nd,action=base.action})
check(receipt and not receipt.selected and receipt.required_evaluations==required,'failed comparison remains public without selecting it')
base.discard_preference_work=9
local _,used,shared=m.phase_copy.suggest(prepared,m,base,{max_evaluations=30})
check(shared.growth_remaining==3 and (shared.growth_work or 0)<=3 and used<=9,'earlier growth cannot renew the twelve-call budget')
base.discard_preference_work=12
local exhausted,count=m.phase_copy.suggest(prepared,m,base,{max_evaluations=30})
check(not exhausted and count==0,'fully consumed growth budget starts no phase family')
base.discard_preference_work=nil;base.consumable={action={kind='use_consumable'}};base.action=base.consumable.action
check(not m.phase_copy.suggest(prepared,m,base,{max_evaluations=30}),'necessary selected consumable is protected')
for _,case in ipairs({'used','nocopy','pinned','hidden'})do
 local x=state()
 if case=='used'then x.discards_used=1 elseif case=='nocopy'then x.jokers[2]=F.j('j_perkeo')
 elseif case=='pinned'then for _,j in ipairs(x.jokers)do j.pinned=true end
 else x.jokers[2].face_down=true end
 check(m.phase_copy.comparison_reserve(x,m)==0,'no reserve for '..case)
end
print('Burnt budget446: '..n..' manufactured assertions passed')
