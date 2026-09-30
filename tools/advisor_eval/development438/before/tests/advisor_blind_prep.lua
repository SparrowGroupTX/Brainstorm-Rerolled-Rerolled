local P=dofile('Brainstorm/Advisor/blind_prep.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local n=0
local function ok(v,m) assert(v,m);n=n+1 end
local function j(key,a,sell) return {key=key,ability=a or {},sell_cost=sell or 2} end
local function state(row) return {phase='blind',jokers=row,joker_limit=5,ante=3,win_ante=8,
  consumeables={},modifiers={},hands={},playing_cards={},dollars=10} end
local s=state({j('j_ceremonial',{mult=0}),j('j_blueprint'),j('j_perkeo'),j('j_egg',{},8)})
s.jokers[1].pinned=true
local fp=Snap.fingerprint(s)
local r,diag=P.suggest(s,S)
ok(r and r.action.kind=='reorder_jokers','executable preparation')
ok(r.action.order[1]==1,'pinned Dagger stays pinned')
local projected,effects=P.project(s,r.action.order)
ok(effects.sacrifices[1].victim~=2 and effects.sacrifices[1].victim~=3,'protect copy and Perkeo engines')
ok(diag.orders<=64,'bounded order checks')
ok(Snap.fingerprint(s)==fp,'advice is detached')
local fresh=Snap.copy(s);fresh.jokers={};for i,index in ipairs(r.action.order) do fresh.jokers[i]=s.jokers[index] end
ok(P.suggest(fresh,S)==nil,'refresh does not repeatedly reorder')
local result=D.run(s,{blind_prep=P,strategy=S})
ok(result.action.kind=='reorder_jokers','nonhand decision routes preparation before blind selection')
s.jokers[2].ability.eternal=true
ok(P.suggest(s,S)==nil,'eternal neighbour blocks sacrifice')
s.jokers[2].ability.eternal=nil;s.jokers[1].debuff=true
ok(P.suggest(s,S)==nil,'debuffed Dagger inactive')
s.jokers[1].debuff=nil;s.phase='shop'
ok(P.suggest(s,S)==nil,'only irreversible blind entry preparation')
s.phase='blind';s.jokers[2].face_down=true
ok(P.suggest(s,S)==nil,'hidden row not projected')
local chain=state({j('j_ceremonial',{mult=1}),j('j_ceremonial',{mult=2},7),j('j_egg',{},10)})
local after,e=P.project(chain,{1,2,3})
ok(#after.jokers==2 and #e.sacrifices==1 and after.jokers[1].ability.mult==15,'sliced Dagger never slices next card')
chain.jokers[2].ability.eternal=true
after,e=P.project(chain,{1,2,3})
ok(#after.jokers==2 and e.sacrifices[1].dagger==2 and after.jokers[2].ability.mult==22,'eternal Dagger may still consume right neighbour')
chain.jokers[1].pinned=true
ok(P.project(chain,{2,1,3})==nil,'invalid pinned order rejected')
ok(P.project(chain,{1,1,3})==nil,'duplicate order rejected')
local negative=state({j('j_ceremonial',{mult=0}),j('j_egg',{},6),j('j_stencil'),j('j_swashbuckler')})
negative.jokers[2].edition={negative=true};negative.joker_limit=6
after,e=P.project(negative,{1,2,3,4})
ok(after.joker_limit==5 and after.jokers[2].ability.x_mult==3,'Negative removal updates Stencil slots')
ok(after.jokers[3].ability.mult==4,'Swashbuckler excludes destroyed resale value')
for _,engine in ipairs({
  {key='j_caino',rarity=4,ability={name='Caino',caino_xmult=100,extra=1},sell_cost=10},
  {key='j_triboulet',rarity=4,ability={name='Triboulet',extra=2},sell_cost=10},
  {key='j_yorick',rarity=4,ability={name='Yorick',x_mult=8},sell_cost=10},
  j('j_blueprint',{name='Blueprint'},8),j('j_brainstorm',{name='Brainstorm'},8),
  j('j_green_joker',{name='Green Joker',mult=100},6),j('j_hologram',{name='Hologram',x_mult=10,extra=0.25},8),
  j('j_unknown_engine',{name='Unmodeled Engine',extra={power=1000}},100),
}) do
 local t=state({j('j_ceremonial',{mult=0}),j('j_joker',{name='Joker',mult=4}),engine})
 t.jokers[1].pinned=true
 local proposal=P.suggest(t,S)
 ok(not proposal or proposal.preparation.sacrifices[1].victim~=3,'never introduce sacrifice of '..engine.key)
 t.jokers[2]=engine;t.jokers[3]=j('j_egg',{},1)
 proposal=P.suggest(t,S)
 ok(proposal and proposal.preparation.sacrifices[1].victim==3,'supply Egg to protect '..engine.key)
end
local cheap=state({j('j_ceremonial',{mult=0}),j('j_joker',{name='Joker',mult=4},2),j('j_egg',{},10)})
cheap.jokers[1].pinned=true
r=P.suggest(cheap,S)
ok(r and r.preparation.sacrifices[1].victim==3,'known minor effect may be replaced by stronger resale fodder')
print('advisor_blind_prep: '..n..' checks passed')
