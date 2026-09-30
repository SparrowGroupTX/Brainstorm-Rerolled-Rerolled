local S=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function c(id,r,e) return {id=id,rank=r,suit='Spades',enhancement=e or 'c_base',ability={}} end
local function j(n,a,debuff) a=a or {};a.name=n;return {ability=a,debuff=debuff} end
local a,b,d=c(1,13,'m_glass'),c(2,13,'m_steel'),c(3,2)
local s={hand={a,b,d},playing_cards={a,b,d},deck={},hands_left=4,hands_played=1,discards_left=3,discards_used=0,dollars=10,
 hand_size=8,blind={key='bl_hook'},jokers={j('Yorick',{x_mult=1,yorick_discards=2,extra={discards=23,xmult=1}})}}
local t,e,r=assert(S.after_play(s,{1},{hook_indices={2,3},glass_outcomes={[1]=false}}))
eq(#t.hand,0);eq(#t.playing_cards,3);eq(t.discards_left,3);eq(t.discards_used,0)
eq(t.jokers[1].ability.x_mult,2);eq(r.score,60);eq(r.scoring_indices[1],1);eq(r.uncertain,false)
eq(t.blind.hook_resolved,nil);eq(s.jokers[1].ability.x_mult,1)
eq(S.after_play(s,{1}),nil);eq(S.after_play(s,{1},{hook_indices={1,2}}),nil)
eq(S.after_play(s,{1},{hook_indices={2,2}}),nil)
t,e=assert(S.after_play(s,{2},{hook_indices={1,3}}));eq(e.population_delta,0);eq(#t.playing_cards,3)
s.blind={};t,e=assert(S.after_play(s,{1},{glass_outcomes={[1]=true}}));eq(e.population_delta,-1);eq(#t.playing_cards,2)
t,e=assert(S.after_play(s,{1},{glass_outcomes={[1]=false}}));eq(e.population_delta,0);eq(#t.playing_cards,3)
s.hand={b,a,d};s.blind={key='bl_hook'};s.jokers={}
t,e,r=assert(S.after_play(s,{2},{hook_indices={1,3},glass_outcomes={[2]=true}}));eq(r.scoring_indices[1],2);eq(r.glass_exposure[1].index,2);eq(e.destroyed_indices[1],2)
s.blind={key='bl_final_heart'};s.jokers={j('Turtle Bean',{extra={h_size=5}},true),j('Oops! All 6s'),j('Stuntman',{extra={h_size=2,chip_mod=250}})}
s.hand_size=6;s.probabilities={normal=2};s.hands_played=1
t=assert(S.after_play(s,{3},{defer_crimson=true}));eq(t.hand_size,6,'draw before Heart capacitychange');eq(t.blind.crimson_pending,true)
local candidates=S.crimson_candidates(t);eq(#candidates,2);eq(candidates[1],2)
local u,m=assert(S.after_draw(t,{crimson_index=2}));eq(u.hand_size,11);eq(u.probabilities.normal,1);eq(u.jokers[1].debuff,false);eq(u.jokers[2].debuff,true)
eq(t.hand_size,6);eq(S.after_draw(t,{crimson_index=1}),nil);eq(u.blind.crimson_pending,nil)
t.jokers={j('DNA',{perishable=true,perish_tally=0},true)};u=assert(S.after_draw(t,{crimson_index=1}));eq(u.jokers[1].debuff,true)
t.jokers={j('Chicot',{},true),j('Joker')};eq(S.after_draw(t,{crimson_index=2}),nil)
t.jokers={j('Unknown custom',{},true),j('Joker')};eq(S.after_draw(t,{crimson_index=2}),nil)
s.blind={};s.jokers={};s.consumeables={};s.consumable_limit=1;s.hand={d,b};s.playing_cards={d,b};d.seal='Purple'
eq(S.after_discard(s,{1}),nil)
local tarot={key='c_death',ability={set='Tarot',name='Death'}}
t,e=assert(S.after_discard(s,{1},{generated_consumables={[1]=tarot}}));eq(#t.consumeables,1);eq(t.consumeables[1].key,'c_death');eq(#e.generated_consumables,1)
eq(#s.consumeables,0);s.consumeables={tarot};t=assert(S.after_discard(s,{1}));eq(#t.consumeables,1,'full inventory no generation')
print('sampled transitions: '..checks..' checks passed')
