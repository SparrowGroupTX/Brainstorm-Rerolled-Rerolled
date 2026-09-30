-- Invented finite hands only. Never execute a captured state or saved game.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
if GROWTH450_PATH then m.growth=dofile(GROWTH450_PATH)end
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local function state(anchors,steels,ordinary)
 local s=F.state(false);s.ante=5;s.hand={};s.deck={};s.consumeables={};s.hands={
  ['High Card']={chips=30,mult=6,level=3,played=2},['Four of a Kind']={chips=120,mult=12,level=4,played=5}}
 for i=1,anchors do s.hand[i]=F.card('anchor450:'..i,anchors==1 and 14 or 13,'Clubs',anchors==1 and 'm_mult'or 'c_base')end
 for i=1,steels do s.hand[#s.hand+1]=F.card('steel450:'..i,5+i,'Hearts','m_steel')end
 for i=1,ordinary do s.hand[#s.hand+1]=F.card('spare450:'..i,1+i,'Diamonds')end
 for i=1,6 do s.deck[i]=F.card('draw450:'..i,2+i%8,'Spades')end
 s.hand_size=#s.hand;s.jokers={F.j('j_yorick'),F.j('j_perkeo')}
 s.current_round={discards_left=3,hands_left=3,discards_used=0,hands_played=0}
 s.blind={key='bl_big',name='Big Blind',chips=1};F.population(s)
 return s
end
local function anchor(s)
 local a={};for i,c in ipairs(s.hand)do if c.id:find('anchor450:',1,true)then a[#a+1]=i end end;return a
end
local function clear(s)
 local a=anchor(s);local c=m.scoring.lower_bound(s,a);c.indices=a;return c
end
local function target(s,ratio)F.population(s);local c=clear(s);s.blind.chips=c.score*(ratio or .95);return c end
local function run(s,c,options)
 local modules={};for k,v in pairs(m)do modules[k]=v end
 local calls=0;modules.scoring=setmetatable({},{__index=m.scoring})
 for _,key in ipairs({'score','lower_bound'})do local method=key
  modules.scoring[key]=function(...)calls=calls+1;return m.scoring[method](...)end
 end
 local hash=m.snapshot.fingerprint(s)
 local opts=options or {exhaust_discards=true,skip_singleton_probes=true,max_evaluations=12}
 local r,w,d=m.growth.suggest(s,modules,c,opts)
 check(w==calls and w<=math.min(12,opts.max_evaluations or 12),'all scoring work charged')
 check(m.snapshot.fingerprint(s)==hash,'input preserved')
 return r,w,d
end
local function oracle(s)
 local spare={};for i,c in ipairs(s.hand)do if not c.id:find('anchor450:',1,true)then spare[#spare+1]=i end end
 local best=0;local count=0;local chosen={}
 local function visit(pos)
  if pos>#spare then
   if #chosen==0 or #chosen>5 then return end
   count=count+1;local after=assert(m.scoring.after_discard(s,chosen));local v=clear(after)
   if v.legal and not v.uncertain and v.score>=s.blind.chips and after.dollars>=s.dollars then best=math.max(best,#chosen)end
   return
  end
  visit(pos+1);chosen[#chosen+1]=spare[pos];visit(pos+1);chosen[#chosen]=nil
 end
 visit(1);check(count>0,'nonempty complete physical subset oracle');return best
end
local basics={{1,5,2},{4,1,4}}
local function refills(s,r,orders)
 local after=assert(m.scoring.after_discard(s,r.action.indices));local draw=#r.action.indices
 local chosen={};local worlds=0
 local function visit(first)
  if #chosen==draw then
   local future=F.copy(after);future.deck={};local selected={}
   for _,i in ipairs(chosen)do selected[i]=true;future.hand[#future.hand+1]=F.copy(after.deck[i])end
   for i,c in ipairs(after.deck)do if not selected[i]then future.deck[#future.deck+1]=F.copy(c)end end
   check(#future.deck+#future.hand==#after.deck+#after.hand,'draw conserves physical population')
   local function score(indices)
    local v=m.scoring.lower_bound(future,indices)
    check(v.legal and not v.uncertain and v.score>=r.play.score and v.glass_loss<=r.play.glass_loss,'every complete refill/order retains floor and Glass bound')
   end
   if orders then F.permutations(anchor(future),score)else score(anchor(future))end
   worlds=worlds+1;return
  end
  for i=first,#after.deck do chosen[#chosen+1]=i;visit(i+1);chosen[#chosen]=nil end
 end
 visit(1)
 local expected=1;for i=1,draw do expected=expected*(#after.deck-i+1)/i end
 check(worlds==expected and worlds>0,'complete full-population refill family')
end
if EXPECT_BASELINE450 then
 for _,shape in ipairs(basics)do
  local s=state(unpack(shape));local c=target(s);local expected=oracle(s);local r=run(s,c)
  check(expected==shape[3],'manufactured oracle establishes safe larger batch')
  check(not r or #r.action.indices<expected,'old shortlist misses larger safe batch')
 end
 print('Baseline450: '..n..' checks; both resource-preserving batches missed');return
end
for _,shape in ipairs(basics)do
 local s=state(unpack(shape));local c=target(s);local expected=oracle(s);local r=run(s,c)
 check(r and #r.action.indices==expected and expected==shape[3],'largest safe physical batch found')
 for _,i in ipairs(r.action.indices)do check(s.hand[i].enhancement~='m_steel','required Steel retained')end
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 local independent=math.floor(shape[1]==1 and (30+11)*(6+4)*4*1.5^shape[2] or (120+40)*12*4*1.5^shape[2])
 check(r.play.score==independent and clear(after).score==independent,'independent retained arithmetic before draws '..shape[1]..':'..r.play.score..'/'..clear(after).score..'/'..independent)
end
-- All locations of two ordinary spares among seven; index and rank grouping
-- must not hide the only safe pair behind any of the five Steel cards.
for a=1,6 do for b=a+1,7 do
 local s=state(1,5,2);local steels={};for i=2,6 do steels[#steels+1]=s.hand[i]end
 local plain={s.hand[7],s.hand[8]};local si,pi=1,1
 for i=1,7 do if i==a or i==b then s.hand[i+1]=plain[pi];pi=pi+1 else s.hand[i+1]=steels[si];si=si+1 end end
 local r=run(s,target(s));check(r and #r.action.indices==oracle(s) and #r.action.indices==2,'all21 ordinary-card placements')
 local after=assert(m.scoring.after_discard(s,r.action.indices));check(clear(after).score>=s.blind.chips,'actual retained finish')
 refills(s,r)
end end
for position=5,9 do
 local s=state(4,1,4);s.hand[5],s.hand[position]=s.hand[position],s.hand[5]
 local r=run(s,target(s));check(r and #r.action.indices==4 and oracle(s)==4,'all five required-Steel positions')
 local after=assert(m.scoring.after_discard(s,r.action.indices))
 F.permutations(anchor(after),function(order)
  local v=m.scoring.lower_bound(after,order);check(v.score==r.play.score,'all24 retained four-King orders')
 end)
 refills(s,r,true)
end
do
 local s=state(1,2,3);s.hand[3].seal='Red';local r=run(s,target(s,.55))
 check(r and #r.action.indices==4 and oracle(s)==4,'four-card batch can discard one expendable Steel')
 for _,i in ipairs(r.action.indices)do check(i~=3,'Red Steel with two activations retained')end
 check(r.growth.discarded_public_steel_units==1,'priority receipt counts actual public Steel activations')
 check(r.play.score==math.floor(41*10*4*1.5^2),'independent Red Steel arithmetic');refills(s,r)
 s=state(1,2,3);r=run(s,target(s,.1));check(r and #r.action.indices==5,'unneeded Steel never unconditionally protected')
 check(r.play.score==41*10*4,'independent no-Steel arithmetic');refills(s,r)
 s=state(1,2,3);s.hand[2].debuff=true;s.hand[3].debuff=true;r=run(s,target(s))
 check(r and #r.action.indices==5 and r.growth.discarded_public_steel_units==0,'debuffed Steel is disposable')
 check(r.play.score==41*10*4,'independent debuffed-Steel arithmetic');refills(s,r)
end
for _,kind in ipairs({'chad','blueprint','brainstorm','burnt','first_burnt'})do
 local s=state(1,4,3)
 if kind=='chad'then s.jokers[3]=F.j('j_hanging_chad')
 elseif kind=='blueprint'then s.jokers={F.j('j_blueprint'),F.j('j_yorick'),F.j('j_perkeo')}
 elseif kind=='brainstorm'then s.jokers[3]=F.j('j_brainstorm')
 else s.jokers[3]=F.joker('j_burnt','Burnt Joker',{extra=4});if kind=='burnt'then s.discards_used=1;s.current_round.discards_used=1 end end
 local c=target(s);local r,w=run(s,c)
 check(r and #r.action.indices==oracle(s),'complete subset maximum with '..kind)
 local after=assert(m.scoring.after_discard(s,r.action.indices));check(clear(after).score>=s.blind.chips,'actual retained '..kind..' finish')
 local exact=run(s,c,{exhaust_discards=true,skip_singleton_probes=true,max_evaluations=w})
 check(exact and #exact.action.indices==#r.action.indices,'exact charged allowance suffices '..kind)
 refills(s,r)
end
do
 local s=state(1,1,4);s.hand[3].seal='Blue';s.hand[4]=F.card('gold450',3,'Diamonds','m_gold')
 local r=run(s,target(s));check(r and #r.action.indices==2,'ordinary spares available beside held rewards')
 for _,i in ipairs(r.action.indices)do check(i~=2 and i~=3 and i~=4,'required Steel/Blue/Gold retained')end
 local c=clear(s)
 check(not run(s,c,{exhaust_discards=true,max_evaluations=0}),'zero allowance cannot prove')
 s.modifiers.discard_cost=100;check(not run(s,c),'paid discard rejected by actual cash guard')
end
-- New ranking is disabled outside exhaust mode; compare the exact old-module
-- action, score and charge on manufactured inputs, not historical observations.
if GROWTH450_COMPARE_PATH then
 local old=dofile(GROWTH450_COMPARE_PATH)
 for _,shape in ipairs(basics)do
  local s=state(unpack(shape));local c=target(s);local opts={max_evaluations=12,skip_singleton_probes=true}
  local r,w,d=run(s,c,opts);local a,b,e=old.suggest(s,m,c,opts)
  check(m.snapshot.fingerprint(r)==m.snapshot.fingerprint(a) and w==b and m.snapshot.fingerprint(d)==m.snapshot.fingerprint(e),'non-exhaust result and work unchanged')
 end
end
-- Concealed payloads are never used as a Steel-priority hint. Swap every
-- possible hidden identity with the same public unordered population.
do
 local s=state(1,2,4);s.blind={key='bl_wheel',name='The Wheel',chips=1};s.hand[#s.hand].face_down=true
 s.deck[1]=F.card('hidden-steel450',8,'Spades','m_steel');s.deck[1].seal='Red'
 s.deck[2]=F.card('hidden-debuff450',7,'Spades','m_steel');s.deck[2].debuff=true
 target(s,.2)
 local result,work=m.growth.visible_retained(s,m,12)
 check(result and work<=12,'qualified public visible proof remains available')
 local hidden=#s.hand
 for i=1,#s.deck do
  local x=F.copy(s);x.hand[hidden],x.deck[i]=x.deck[i],x.hand[hidden]
  x.hand[hidden].face_down=true;x.deck[i].face_down=false;F.population(x)
  local r,w=m.growth.visible_retained(x,m,12)
  check(r and w<=12 and m.snapshot.fingerprint(r.action)==m.snapshot.fingerprint(result.action) and r.play.score==result.play.score,'same public pool, hidden assignment-independent action/floor')
 end
end
-- Fresh actual decisions re-evaluate after each physical draw and conserve
-- the same winning anchor and required Steel rather than pretending draws win.
do
 local s=state(1,5,2);for i=7,24 do s.deck[i]=F.card('draw450:'..i,2+i%8,'Spades')end;target(s);local total=0
 for left=3,1,-1 do
  local hash=m.snapshot.fingerprint(s)
  local r=m.decision.run(s,m,nil,{prepared_scoring=false,search={fast_clear=false,samples=24,candidates=5,resource_samples=0}})
  check(r.action.kind=='discard' and #r.action.indices>=2,'fresh Decision uses safe spares')
  check(r.evaluations<=140000 and (r.discard_preference_work or 0)<=12,'ordinary and growth caps')
  check(m.snapshot.fingerprint(s)==hash,'fresh Decision preserves input')
  total=total+#r.action.indices;s=assert(m.scoring.after_discard(s,r.action.indices))
  check(s.discards_left==left-1 and clear(s).score>=s.blind.chips,'actual retained clear before fresh draw')
  while #s.hand<s.hand_size do s.hand[#s.hand+1]=table.remove(s.deck)end
 end
 check(total>=6,'all three discards used despite five required Steel')
end
print('Steel shortlist450: '..n..' manufactured assertions passed')
