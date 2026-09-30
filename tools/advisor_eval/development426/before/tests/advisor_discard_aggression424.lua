-- Manufactured score surfaces isolate admission; physical discard transitions
-- and the complete production search/arbitration are real detached modules.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
local Search=SEARCH424_PATH and dofile(SEARCH424_PATH) or m.search
local count=0;local function check(v,msg)count=count+1;assert(v,msg)end
local function state()
 local s=F.state(false);s.ante=5;s.blind={key='bl_big',name='Big Blind',chips=75};s.hand={};s.deck={};s.hand_size=8
 for i=1,8 do s.hand[i]=F.card('held424:'..i,i+1,'Spades')end
 for i=1,16 do s.deck[i]=F.card('draw424:'..i,13,'Hearts')end
 s.jokers={F.j('j_yorick')};s.jokers[1].ability.x_mult=6;s.jokers[1].ability.yorick_discards=23
 s.consumeables={};s.hands={};s.hands_left=3;s.discards_left=3;s.discards_used=0;F.population(s);return s
end
local function run(s,opts)
 opts=opts or {};local calls=0
 local scorer={after_discard=m.scoring.after_discard}
 function scorer.score(t,indices)
  calls=calls+1
  local score=t.discards_used>s.discards_used and (opts.redraw_score or 80) or 80
  return {score=score,legal=true,uncertain=false,hand='High Card',indices=indices,scoring_indices=indices,warnings={}}
 end
 if opts.continuation_loss then scorer.after_play=function(t,indices)
  scorer.score(t,indices) -- the transition's charged scoring call
  local next=F.copy(t);next.hands_left=0;next.chips=t.discards_used>s.discards_used and 0 or t.blind.chips
  return next
 end end
 if opts.population_loss then scorer.after_discard=function(t,indices)
  local next,effects=m.scoring.after_discard(t,indices);if effects then effects.population_delta=-1 end;return next,effects
 end end
 local strategy={build_profile=function()return {horizon=opts.no_horizon and 0 or 6,final=opts.no_horizon or false}end}
 local scoped={search=Search,scoring=scorer,strategy=strategy}
 local options={samples=opts.samples or 24,candidates=5,draw_targets=false,resource_samples=opts.continuation_loss and 4 or 0,max_evaluations=opts.cap or 140000}
 if opts.fast_clear then options.fast_clear=true end
 local before=m.snapshot.fingerprint(s)
 local r=m.decision.run(s,scoped,nil,{search=options,prepared_scoring=false})
 check(r.evaluations==calls,'every score is charged: '..tostring(opts.label)..' '..tostring(r.evaluations)..'/'..calls)
 check(r.evaluations<=(opts.cap or 140000),'ordinary cap remains binding')
 check(m.snapshot.fingerprint(s)==before,'input population and cards unchanged')
 return r
end
do
 local s=state();local r=run(s)
 if EXPECT_BASELINE424 then
  check(r.action.kind=='play','baseline declines full batch despite all compared clears')
  check(r.risky_yorick_clear and r.risky_yorick_clear.samples==24 and r.risky_yorick_clear.sampled_clears==24,'baseline completed the comparison')
  print('Baseline424 conservative rejection confirmed');return
 end
 check(r.action.kind=='discard' and #r.action.indices==5,'all-clear105% full batch bypasses the heuristic taper')
 check(r.risky_yorick_clear.full_batch_preference and r.risky_yorick_clear.sampled_clears==24,'new preference explicitly witnessed')
 check(r.discard.prepared.jokers[1].ability.x_mult==6 and r.discard.prepared.jokers[1].ability.yorick_discards==18,'five physical cards advance one Yorick counter once')
 local J=dofile('Brainstorm/Advisor/player_journal.lua');local public=J.compact_yorick_review(r)
 check(public.risk.full_batch_preference and public.risk.selected,'public scalar receipt records final selected preference')
 local encoded=J.encode(public);check(not encoded:find('prepared',1,true),'no hypothetical state in public receipt')
end
local cases={
 {'104 percent',function(s)s.blind.chips=77 end,{}},
 {'failed redraw',function()end,{redraw_score=74}},
 {'incomplete samples',function()end,{samples=23}},
 {'small caller cap',function()end,{cap=500}},
 {'explicit fast clear',function()end,{fast_clear=true}},
 {'no growth horizon',function()end,{no_horizon=true}},
 {'destructive transition',function()end,{population_loss=true}},
 {'completed continuation loss',function()end,{continuation_loss=true}},
 {'cash cost',function(s)s.modifiers.discard_cost=1 end,{}},
 {'Green Joker conflict',function(s)s.jokers[2]=F.joker('j_green_joker','Green Joker',{mult=5})end,{}},
 {'Ramen conflict',function(s)s.jokers[2]=F.joker('j_ramen','Ramen',{x_mult=2,extra=0.01})end,{}},
 {'held Gold',function(s)for _,c in ipairs(s.hand)do c.enhancement='m_gold' end end,{}},
 {'held Steel',function(s)for _,c in ipairs(s.hand)do c.ability.h_x_mult=1.5 end end,{}},
 {'seal',function(s)for _,c in ipairs(s.hand)do c.seal='Red' end end,{}},
 {'enhancement',function(s)for _,c in ipairs(s.hand)do c.enhancement='m_mult' end end,{}},
 {'mature eligibility unchanged',function(s)s.jokers[1].ability.x_mult=9 end,{}},
 {'generic profile',function(s)s.teacher_profile=nil end,{}}}
for _,c in ipairs(cases)do local s=state();c[2](s);c[3].label=c[1];local r=run(s,c[3])
 check(r.action.kind=='play','new aggression cannot bypass '..c[1])
 check(not r.risky_yorick_clear or not r.risky_yorick_clear.selected,'final selection stays honest '..c[1])
end
print('Discard aggression424: '..count..' manufactured assertions passed')
