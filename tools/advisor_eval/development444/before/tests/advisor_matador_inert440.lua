-- Constructed canonical Matador rows, no captured states or source execution.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules();local n=0
local function check(x,msg)n=n+1;assert(x,msg)end
local names={bl_small='Small Blind',bl_big='Big Blind',bl_needle='The Needle',bl_final_leaf='Verdant Leaf'}
local function state(key)
 local s=F.state(false);s.blind={key=key,name=names[key],debuff={},chips=10};s.hand={};s.deck={};s.consumeables={}
 for i=1,6 do s.hand[i]=F.card('mat440:'..i,13,'Clubs')end
 s.jokers={F.joker('j_matador','Matador',{extra=8}),F.j('j_yorick')};F.population(s);return s
end
for key in pairs(names)do for _,copied in ipairs({false,true})do for _,edition in ipairs({'none','holo','foil','polychrome'})do
 local s=state(key)
 if copied then s.jokers={F.j('j_blueprint'),s.jokers[1],s.jokers[2]}end
 local j=s.jokers[copied and 2 or 1]
 if edition~='none'then j.edition=edition=='holo'and{holo=true,mult=10}or edition=='foil'and{foil=true,chips=50}or{polychrome=true,x_mult=1.5}end
 local before=m.snapshot.fingerprint(s);local after,e,p=m.scoring.after_play(s,{1,2})
 check(after and p.legal and not p.uncertain,'complete canonical inert transition '..key)
 check(after.dollars==s.dollars and p.expected_dollars==0,'Matador gives no invented earnings')
 check(after.hands_left==s.hands_left-1 and after.hands_played==s.hands_played+1,'real play resources settle')
 check(#after.jokers==#s.jokers and #after.playing_cards==#s.playing_cards,'Joker/population preserved')
 check(m.snapshot.fingerprint(s)==before,'input unchanged')
end end end
for _,change in ipairs({
 function(s)s.blind={key='bl_flint',name='The Flint',debuff={},chips=10}end,
 function(s)s.blind.disabled=true end,
 function(s)s.blind.debuff={h_size_ge=5}end,
 function(s)s.blind.name='Unknown' end,
 function(s)s.blind.debuff=nil end,
 function(s)s.jokers[1].ability.extra=9 end,
 function(s)s.jokers[1].ability.h_dollars=2 end,
 function(s)s.jokers[1].ability.callback440=true end,
 function(s)s.jokers[1].key='custom_matador' end,
 function(s)s.jokers[1].identity_redacted=true end})do
 local s=state('bl_small');change(s);local a,why=m.scoring.after_play(s,{1,2})
 check(not a and type(why)=='string','unknown trigger/resources remain unsupported')
end
print('Matador inert440: '..n..' checks passed')
