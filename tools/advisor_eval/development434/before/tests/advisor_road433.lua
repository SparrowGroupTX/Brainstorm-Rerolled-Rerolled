local T=dofile('tests/fixtures/shop433.lua');local F,m,j=T.F,T.m,T.joker
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state()
 local s=T.state();s.phase='pack';s.pack_type='BUFFOON_PACK';s.pack_choices=1;s.hand_limit=1;s.hand_size=5
 s.jokers={};s.hands={['High Card']={chips=5,mult=1,level=1,played=5,l_chips=10,l_mult=1}}
 s.playing_cards={};for i=1,24 do s.playing_cards[i]=F.card('road:'..i,i<=12 and 11 or 13,'Clubs')end
 s.next_blind={key='bl_big',name='Big Blind',chips=100,ante=4};s.round_resets={hands=3,discards=3}
 s.pack_cards={j('j_hit_the_road'),j('j_red_card')};return s
end
local function compare(s,cap)
 local after=F.copy(s);after.jokers[#after.jokers+1]=F.copy(s.pack_cards[1])
 local ctx=m.shop_scoring.new(s,m.scoring,nil,{max_evaluations=cap or 50000})
 return ctx:compare(s,after),ctx,after
end
local function road_policy(f)
 for _,p in ipairs(f.policies)do if p.name=='one_observed_road_discard' then return p end end
end
do
 local s=state();local before=m.snapshot.fingerprint(s);local e,ctx=compare(s)
 check(e and e.complete_finishing,'changed Road reaches complete real-discard comparison: '..tostring(ctx.unavailable_reason))
 local policy=assert(road_policy(e.after_finishing));local before_policy=assert(road_policy(e.before_finishing))
 check(#policy.worlds==4 and #before_policy.worlds==4,'identical declared family on both endpoints')
 local discards=0;for _,world in ipairs(policy.worlds)do
  for _,a in ipairs(world.actions)do if a.kind=='discard' then
   discards=discards+1;check(#a.indices==1,'legal hand_limit respected')
   for _,id in ipairs(a.card_ids)do check(tonumber(id:match(':(%d+)'))<=12,'only observed Jacks selected')end
  end end
 end
 check(discards==4,'all four real worlds execute one Jack discard')
 check(m.snapshot.fingerprint(s)==before and ctx.evaluations<=50000,'input purity and shared shop cap')
 local exact,c=compare(s,ctx.evaluations);check(exact and exact.complete_finishing and c.evaluations==ctx.evaluations,'exact complete-family cap')
 local partial,c=compare(s,ctx.evaluations-1);check(not partial and c.truncated and c.evaluations<=ctx.evaluations-1,'incomplete family rejected as whole')
 s.pack_cards[1].ability.x_mult=12
 local stale=compare(s);check(stale.after_mean==e.after_mean and stale.after_finishing.selected.mean_score==e.after_finishing.selected.mean_score,'last-round Road XMult reset before new blind')
 s=state();s.jokers={j('j_blueprint')}
 local copied,ctx=compare(s);check(copied and copied.complete_finishing,'copied Road comparison completes real paths')
 local actions=road_policy(copied.after_finishing).worlds[1].actions
 check(actions[1].kind=='discard' or actions[2] and actions[2].kind=='discard','copy policy commits actual discard before scoring')
end
-- Physical counters advance once; Blueprint repeats the scoring factor only.
do
 local s=T.F.state(false);s.jokers={j('j_blueprint'),j('j_hit_the_road')};s.jokers[2].ability.x_mult=1
 s.hand[1]=F.card('jack1',11,'Clubs');s.hand[2]=F.card('jack2',11,'Hearts');s.hand[3]=F.card('debuff-jack',11,'Spades');s.hand[3].debuff=true
 F.population(s);local after=assert(m.scoring.after_discard(s,{1,2,3}))
 check(after.jokers[2].ability.x_mult==2,'two nondebuff Jacks grow physical Road once each, not per copy')
 check(s.jokers[2].ability.x_mult==1,'real transition is detached')
end
for _,case in ipairs({'no_jacks','water','no_discards','paid','modified','purple_gold_blue'})do
 local s=state()
 if case=='no_jacks' then for _,c in ipairs(s.playing_cards)do c.rank=13;c.base.id=13 end
 elseif case=='water' then s.next_blind={key='bl_water',name='The Water',chips=100,boss=true}
 elseif case=='no_discards' then s.round_resets.discards=0
 elseif case=='paid' then s.dollars=0;s.modifiers.discard_cost=2
 elseif case=='modified' then s.pack_cards[1].ability.extra=7
 elseif case=='purple_gold_blue' then for _,c in ipairs(s.playing_cards)do c.seal='Blue' end end
 local e,ctx=compare(s)
 if case=='modified' then check(not e,'modified Road rejected')else
  check(e and e.complete_finishing,'complete restriction control '..case..' / '..tostring(ctx.unavailable_reason))
  check(road_policy(e.after_finishing).max_discards_used==0,'Jack policy respects '..case)
 end
end
-- One-round Road keeps present opportunity, but cannot claim years of rebuild.
do
 local s=state();local values={}
 for _,life in ipairs({1,2,5})do local card=j('j_hit_the_road');card.ability.perishable=true;card.ability.perish_tally=life
  values[life]=m.strategy.owned_joker_value(s,card)end
 check(values[1]<values[2] and values[2]<values[5],'perishable rebuilding horizon affects value')
 s.ante=8;s.next_blind={ante=8,boss=true,key='bl_final_vessel',chips=100}
 local a=j('j_hit_the_road');a.ability.perishable=true;a.ability.perish_tally=1
 local b=F.copy(a);b.ability.perish_tally=5
 check(m.strategy.owned_joker_value(s,a)==m.strategy.owned_joker_value(s,b),'final boss has no invented future lifetime premium')
end
-- The real pack path compares both known offers rather than giving Road an
-- unpaired generic score when its discard path can be modeled.
do
 local s=state();local r=m.decision.run(s,m,nil,{prepared_scoring=false})
 check(r.action and r.action.kind=='choose','real pack makes a legal choice')
 check(not r.strategy.pack_diagnostics.tactical_fallback,'Road does not force whole-pack tactical fallback')
 check(r.evaluations<=50000,'real pack allowance')
end
do
 local s=T.state();s.next_blind={key='bl_hook',name='The Hook',chips=6400,boss=true}
 local r=m.shop_scoring.new(s,m.scoring):readiness(s)
 check(r and not r.supported and r.reason:find('mechanics',1,true),'known Hook target reports unsupported mechanics')
 check(not r.reason:find('target is unavailable',1,true),'does not mislabel public6400 target as missing')
end
print('Road433: '..n..' manufactured assertions passed')
