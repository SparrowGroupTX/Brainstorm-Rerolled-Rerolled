-- Independent manufactured openings; no journal replay or full-game attempts.
local P='Brainstorm/Advisor/';local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH420_PATH then m.growth=dofile(GROWTH420_PATH)end
m.phase_copy=dofile(PHASE420_PATH or P..'phase_copy.lua');m.gold_stickers=dofile(P..'gold_stickers.lua')
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state()
 local s=F.state();s.ante=2;s.hand={};s.deck={};s.hands_left=3;s.hand_size=8
 s.jokers={F.j('j_yorick'),F.joker('j_burnt','Burnt Joker',{extra=4})};s.jokers[1].ability.x_mult=30
 s.hands={Pair={level=1,played=20,chips=10,mult=2,l_chips=15,l_mult=1},['High Card']={level=1,played=0,chips=5,mult=1,l_chips=10,l_mult=1}}
 s.blind={key='bl_big',name='Big Blind',chips=475}
 for i,r in ipairs({14,2,4,6,8,10,11,12})do s.hand[i]=F.card('burnt-hand:'..i,r,({'Clubs','Spades','Hearts','Diamonds'})[i%4+1])end
 for i=1,24 do s.deck[i]=F.card('burnt-deck:'..i,i<=20 and 2 or 9,({'Clubs','Hearts','Spades','Diamonds'})[i%4+1])end
 F.population(s);return s
end
local function suggest(s,cap)
 return m.growth.suggest(s,m,F.clear(m,s,{1}),{exhaust_discards=true,max_evaluations=cap or 12})
end
do
 local s=state();local a,work,d=suggest(s)
 check(a and a.action.kind=='play' and a.growth.kind=='burnt_setup','one supported spare play improves the first full Burnt discard')
 check(work<=12 and a.growth.burnt_preparation.discards_preserved==3 and a.growth.burnt_preparation.full_discard_size==5,'setup preserves discard count and full batch capacity within existing work')
 check(m.scoring.score(s,a.action.indices).score<s.blind.chips,'the actual setup cannot clear and waste discards')
 local after=assert(m.scoring.after_play(s,a.action.indices))
 check(after.discards_used==0 and after.discards_left==3 and after.hands_left==2,'exact setup spends one hand and zero discards')
 for i=1,#after.deck do
  local observed=F.copy(after);observed.hand[#observed.hand+1]=table.remove(observed.deck,i)
  local fresh=m.decision.run(observed,m,nil,{search={fast_clear=true}})
  check(fresh.action.kind=='discard' and #fresh.action.indices==5,'every public one-card draw retains a full safe next discard')
  local discarded,effects=assert(m.scoring.after_discard(observed,fresh.action.indices))
  check(discarded.discards_used==1 and effects.burnt_levels==1,'actual first discard is tracked and triggers Burnt once')
 end
 local result=m.decision.run(s,m,nil,{search={fast_clear=true}})
 check(result.action.kind=='play' and result.growth.growth.kind=='burnt_setup' and result.evaluations<=70,'production arbitration retains the safe setup under the fast allowance')
 local receipt=dofile(P..'player_journal.lua').compact_copy_death_review(result)
 check(receipt.burnt and receipt.burnt.desired_hand=='Pair' and not receipt.burnt.guaranteed_target,'public receipt distinguishes desired category from an actual upgrade')
 for _,edit in ipairs({function(x)x.hands_left=1 end,function(x)x.hands_played=1 end,
  function(x)x.discards_used=1 end,function(x)x.blind.key='bl_eye';x.blind.name='The Eye' end,
  function(x)x.deck[1].unknown=true end,function(x)x.deck[1].seal='Blue' end,
  function(x)while #x.deck>5 do table.remove(x.deck)end;F.population(x)end})do
  local x=state();edit(x);local b=suggest(x)
  check(not b or b.action.kind~='play','unsupported state cannot spend a fishing hand')
 end
 local b=suggest(state(),2);check(not b or b.action.kind~='play','partial proof budget cannot dispatch setup')
end
-- First-discard copying must preserve five-card volume even when time-cost
-- heuristics previously preferred a tiny unscaled category or no arrangement.
for _,copy_keys in ipairs({{'j_brainstorm'},{'j_blueprint'},{'j_blueprint','j_brainstorm'}})do
 local s=state();s.hands_played=1;s.jokers[1].ability.x_mult=8;s.blind.chips=500
 s.jokers={s.jokers[1],F.j(copy_keys[1]),s.jokers[2]}
 if copy_keys[2] then s.jokers[#s.jokers+1]=F.j(copy_keys[2])end
 s.hand[3].rank=2;s.hand[3].base.id=2;s.hand[3].nominal=2;s.hand[3].base.nominal=2;F.population(s)
 local base={action={kind='discard',area='hand',indices={2,3,4,5,6}},play=F.clear(m,s,{1})}
 local a,work,d=m.phase_copy.suggest(s,m,base,{max_evaluations=30})
 check(a and (a.action.kind=='reorder_jokers' or a.action.kind=='discard') and d.events_after==1+#copy_keys,
  'every legal copy routes to Burnt before first discard')
 check(#d.discard_indices==5 and work<=30,'Burnt copying preserves full discard batch and existing phase allowance')
 local arranged=a.action.kind=='reorder_jokers' and m.phase_copy.reorder(s,a.action.order) or s
 local fresh=m.phase_copy.suggest(arranged,m,base,{max_evaluations=30})
 check(fresh and fresh.action.kind=='discard','fresh Burnt arrangement actually discards instead of reordering back')
 local after,effects=m.scoring.after_discard(arranged,fresh.action.indices)
 check(effects.burnt_levels==1+#copy_keys,'settled manufactured discard applies physical Burnt plus all copy callbacks')
 local ready=m.phase_copy.reorder(after,fresh.phase_copy.finish_order)
 check(m.scoring.score(ready,fresh.play.indices).score>=ready.blind.chips-ready.chips,'separate scoring restoration keeps the held winning continuation')
 local restoration,_,rd=m.phase_copy.suggest(after,m,base,{max_evaluations=30})
 check(not restoration or rd.scope=='restore_yorick_after_first_discard','used first discard can only restore scoring copies, never repeat Burnt setup')
end
do
 local s=state();s.hands_played=1;s.ante=8;s.blind={key='bl_wall',name='The Wall',boss=true,chips=500}
 s.jokers[1].ability.x_mult=8;s.jokers={s.jokers[1],F.j('j_brainstorm'),s.jokers[2]}
 local base={action={kind='discard',area='hand',indices={2,3,4,5,6}},play=F.clear(m,s,{1})}
 local choice,_,d=m.phase_copy.suggest(s,m,base,{max_evaluations=30})
 check(choice and d.events_after==2 and #d.discard_indices==5,'teacher copies Burnt even when future-growth utility is too small to pay an arrangement-time heuristic')
 local ready=m.phase_copy.reorder(s,choice.action.order)
 m.ordering=dofile(P..'ordering.lua');m.hand_copy_preflight=dofile(P..'hand_copy_preflight.lua')
 local live=m.decision.run(ready,m,nil,{search={samples=0}})
 check(live.action.kind=='discard' and #live.action.indices==5,'production first-discard copy arrangement does not bounce back to a scoring reorder')
 local after,e=m.scoring.after_discard(ready,live.action.indices)
 check(e.burnt_levels==2,'production-selected first discard realizes the copy callback')
end
do
 local s=state();s.hand={s.hand[1],s.hand[2],s.hand[3],s.hand[4],s.hand[5],s.hand[6]};s.hand_size=6
 s.jokers[1].ability.x_mult=16;s.jokers={s.jokers[1],F.j('j_brainstorm'),s.jokers[2]};s.blind.chips=1500;F.population(s)
 for i=2,#s.hand do check(m.scoring.score(s,{i}).score>=1500,'every plain singleton would prematurely win with Yorick copied')end
 local first=m.decision.run(s,m,nil,{search={samples=0}})
 check(first.action.kind=='reorder_jokers' and first.phase_copy.scope=='nonwinning_burnt_setup','production temporarily removes Yorick copy to make fishing nonwinning')
  local prepared=m.phase_copy.reorder(s,first.action.order)
  local jr=dofile(P..'player_journal.lua').compact_phase_copy_review(first)
  check(jr and jr.selected and jr.scope=='nonwinning_burnt_setup','public journal exposes the reduced-score setup phase')
 local fish=m.decision.run(prepared,m,nil,{search={samples=0}})
 check(fish.action.kind=='play' and fish.growth.growth.kind=='burnt_setup','fresh reduced row plays the actual nonwinning setup')
 check(m.scoring.score(prepared,fish.action.indices).score<1500,'setup score is measured in the real reduced row')
 local after=m.scoring.after_play(prepared,fish.action.indices)
 after.hand[#after.hand+1]=table.remove(after.deck,1)
 local discard=m.decision.run(after,m,nil,{search={samples=0}})
 check(discard.action.kind=='discard' and #discard.action.indices==5,'after fishing the copied Burnt row spends a full first discard')
 local used,e=m.scoring.after_discard(after,discard.action.indices)
  check(e.burnt_levels==2 and used.discards_left==2,'first discard receives both Burnt effects and leaves the other discards intact')
  jr=dofile(P..'player_journal.lua').compact_phase_copy_review(discard)
  check(jr and jr.selected and jr.events_after==2 and jr.burnt_hand==e.burnt_hand,'first-discard receipt names the actual category and expected copy count for settlement checking')
 for i=1,5 do used.hand[#used.hand+1]=table.remove(used.deck,1)end
 local restored=m.decision.run(used,m,nil,{search={samples=0}})
 check(restored.action.kind=='reorder_jokers' and restored.phase_copy.scope=='restore_yorick_after_first_discard','scoring copies restore after Burnt even when another current play could already clear')
 local ready=m.phase_copy.reorder(used,restored.action.order)
  check(m.phase_copy.copy_effects(ready,'j_yorick')==2,'actual restoration reconnects the copy to Yorick')
  jr=dofile(P..'player_journal.lua').compact_phase_copy_review(restored)
  check(jr and jr.selected and jr.scope=='restore_yorick_after_first_discard' and jr.score_after>jr.score_before,'restored scoring improvement is publicly auditable')
end
print('Burnt setup420: '..n..' checks passed')
