-- Real manufactured decisions; no public journal is replayed.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
for _,k in ipairs({'phase_copy','ordering','gold_stickers'})do m[k]=dofile('Brainstorm/Advisor/'..k..'.lua')end
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state()
 local s=F.state(false);s.blind={key='bl_big',name='Big Blind',chips=23000};s.hand={};s.deck={};s.hand_size=8
 for i,r in ipairs({14,2,2,2,5,7,9,10})do s.hand[i]=F.card('burnt434:'..i,r,i<3 and 'Spades' or 'Hearts')end
 for i=1,12 do s.deck[i]=F.card('draw434:'..i,6,'Clubs')end
 s.jokers={F.j('j_yorick'),F.j('j_brainstorm'),F.joker('j_burnt','Burnt Joker',{extra=4}),F.j('j_perkeo')}
 s.jokers[1].ability.x_mult=40;s.jokers[3].ability.effect=nil
 s.hands={['Three of a Kind']={level=3,chips=70,mult=6,l_chips=20,l_mult=2,played=5,visible=true}}
 s.consumeables={{key='c_high_priestess',ability={name='The High Priestess',set='Tarot',consumeable={planets=2}}}}
 F.population(s);return s
end
local opts={prepared_scoring=false,search={samples=0}}
local s=state();local before=m.snapshot.fingerprint(s)
local first=m.decision.run(s,m,nil,opts)
check(first.action.kind=='reorder_jokers' and first.phase_copy,'first Decision physically prepares copied Burnt')
local prepared=m.phase_copy.reorder(s,first.action.order)
local base_modules={};for k,v in pairs(m)do if k~='phase_copy'then base_modules[k]=v end end
local incumbent=m.decision.run(prepared,base_modules,nil,opts)
-- Supply an unselected, earlier proposal through the actual consumable stage;
-- ordering must independently clear before it can mark that proposal superseded.
local proposed={action={kind='use_consumable',area='consumeables',index=1},play={score=30000,indices={1},legal=true,uncertain=false},lines={}}
local with_item={};for k,v in pairs(m)do with_item[k]=v end
with_item.consumables=setmetatable({suggest=function()return proposed,0 end},{__index=m.consumables})
local unphased={};for k,v in pairs(with_item)do if k~='phase_copy'then unphased[k]=v end end
local stale=m.decision.run(prepared,unphased,nil,opts)
check(stale.consumable==proposed and stale.action==stale.ordering.action and stale.ordering.supersedes_consumable,
 'real ordering arbitration retains the obsolete item proposal beside its independent clear')
local fresh=m.decision.run(prepared,with_item,nil,opts)
check(fresh.action.kind=='discard' and fresh.phase_copy and fresh.phase_copy.complete,'fresh Decision discards despite superseded item')
check(not fresh.consumable and not fresh.ordering,'only chosen action is displayed')
local after,e=assert(m.scoring.after_discard(prepared,fresh.action.indices))
check(e.burnt_levels==2 and after.discards_left==s.discards_left-1,'physical discard doubles Burnt and spends one discard')
check(#fresh.action.indices==5,'phase setup retains full-five volume')
check(m.snapshot.fingerprint(s)==before,'original public state preserved')
-- Direct guard controls isolate genuinely selected rescue and incomplete proof.
local b=F.copy(incumbent);b.consumable=proposed;b.action=proposed.action
check(not m.phase_copy.suggest(prepared,m,b,{max_evaluations=30}),'necessary selected item is never displaced')
b=F.copy(incumbent);b.consumable=proposed;b.ordering.supersedes_consumable=true;b.action=b.ordering.action
check(not m.phase_copy.suggest(prepared,m,b,{max_evaluations=1}),'incomplete budget cannot override stale proposal')
local failing=F.copy(prepared);failing.blind.chips=1e12
check(not m.phase_copy.suggest(failing,m,b,{max_evaluations=30}),'no independent held clear means no override')
local lucky=F.copy(prepared);lucky.hand[3]=F.card('lucky434',2,'Hearts','m_lucky')
lucky.hand[3].name='Lucky Card';lucky.hand[3].ability.name='Lucky Card';lucky.hand[3].ability.effect='Lucky Card'
lucky.hand[3].ability.mult=20;lucky.hand[3].ability.p_dollars=20
lucky.hands['Three of a Kind'].chips=30;lucky.hands['Three of a Kind'].mult=3;F.population(lucky)
local average=m.decision.run(lucky,unphased,nil,opts)
check(average.consumable and average.ordering and average.action==average.ordering.action and average.ordering.play.uncertain,
 'Lucky-average scoring reorder carries stale proposal, despite independent reliable singleton')
local rescued=m.decision.run(lucky,with_item,nil,opts)
check(rescued.action.kind=='discard' and rescued.phase_copy.complete and not rescued.phase_copy.retained_finish.uncertain,
 'fresh reliable independent finish permits actual discard beside Lucky-average reorder')
local only_random=F.copy(lucky);only_random.blind.chips=500000
local a=m.decision.run(only_random,unphased,nil,opts)
check(a.ordering and a.ordering.play.uncertain and a.ordering.play.score>=only_random.blind.chips,
 'negative control still has a clearing random-mean reorder')
check(not m.phase_copy.suggest(only_random,m,a,{max_evaluations=30}),'a random-mean clear cannot replace independent reliable proof')
print('Burnt stale434: '..n..' manufactured assertions passed')
