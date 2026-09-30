local A=dofile('tests/fixtures/modules436.lua');local F=dofile('tests/fixtures/repair416.lua')
local centers={};for _,j in ipairs(dofile('tests/fixtures/joker_centers421.lua'))do centers[j.key]=j end
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local s={phase='shop',teacher_profile='perkeo_yorick_win_v1',ante=5,win_ante=8,dollars=10,bankrupt_at=0,
 joker_limit=5,consumable_limit=2,consumeables={},hands={},modifiers={},probabilities={normal=1},
 hand_size=2,hand_limit=1,round_resets={hands=3,discards=1},current_round={},playing_cards={},jokers={},
 next_blind={key='bl_big',chips=100000},next_blind_chips=100000,shop_jokers={},shop_booster={},shop_vouchers={},reroll_cost=5}
for i,key in ipairs({'j_fortune_teller','j_blue_joker','j_supernova','j_yorick','j_perkeo'})do
 s.jokers[i]=F.copy(centers[key]);s.jokers[i].id=key
end
s.jokers[4].ability.x_mult=4;s.jokers[4].ability.yorick_discards=15;s.consumeable_usage_total={tarot=3}
for i=1,12 do
 local c=F.card('deck'..i,13);c.key='m_lucky';c.enhancement='m_lucky';c.ability.name='Lucky Card'
 c.ability.effect='Lucky Card';c.ability.mult=20;c.ability.p_dollars=20;s.playing_cards[i]=c
end
local original=A.snapshot.fingerprint(s);local calls=0
local scoring=setmetatable({score=function(...)calls=calls+1;return A.scoring.score(...)end,
 after_play=function(...)calls=calls+1;return A.scoring.after_play(...)end},{__index=A.scoring})
local ctx=A.shop_scoring.new(s,scoring,nil,{max_evaluations=50000});local r=ctx:readiness(s)
check(r.supported and r.finishing.complete,'Real shop opening and full owned-Lucky finishing family completes')
check(calls==ctx.evaluations and calls<50000,'Actual scores/transitions charged to unchanged shared shop budget')
local lucky=0
for _,p in ipairs(r.finishing.policies)do
 check(#p.worlds==4,'Complete common-world family')
 for _,w in ipairs(p.worlds)do
  for _,a in ipairs(w.actions)do if a.kind=='play'then
   check(a.sampled_lucky and a.score_guaranteed==false,'No sampled transition becomes a guarantee');lucky=lucky+1
  end end
 end
end
check(lucky>0,'Owned Lucky actually exercised')
local old=ctx.evaluations;local comparison=ctx:compare(s,s)
check(comparison and comparison.complete_finishing and comparison.adjustment==0,'Identical endpoint complete comparison remains neutral')
check(ctx.evaluations==old,'Identical endpoints reuse exact cache without scoring renewal')
check(A.snapshot.fingerprint(s)==original,'Readiness leaves original source state unchanged')
local limited=A.shop_scoring.new(s,A.scoring,nil,{max_evaluations=5})
check(not limited:compare(s,s)and limited.truncated and limited.evaluations<=5,'Incomplete owned family fails closed at existing cap')
print('Owned finishing436: '..checks..' checks passed')
