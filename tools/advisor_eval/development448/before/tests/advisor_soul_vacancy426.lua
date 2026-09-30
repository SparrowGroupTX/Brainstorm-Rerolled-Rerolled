-- Manufactured public metadata only; no captured run or original game execution.
local S=dofile('Brainstorm/Advisor/strategy.lua')
local R=dofile('Brainstorm/Advisor/joker_retirement.lua')
local D=dofile('Brainstorm/Advisor/decision.lua')
local E=dofile('Brainstorm/Advisor/execution.lua')
local J=dofile('Brainstorm/Advisor/player_journal.lua')
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local Copy=F.Snapshot.copy
S.joker_retirement=R
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function card(key,name,set,id)
 return {key=key,name=name,id=id,ability={name=name,set=set,consumeable={}},debuff=false}
end
local function state()
 local s=F.state();s.phase='pack';s.teacher_profile='perkeo_yorick_win_v1'
 s.dollars=31;s.bankrupt_at=0;s.ante=6;s.win_ante=8;s.joker_limit=5;s.rental_rate=3
 s.modifiers={};s.consumable_limit=20;s.pack_choices=1
 s.hand={{id='manufactured:held',rank=13,nominal=10,suit='Clubs',ability={set='Default'}}}
 s.deck={};s.hands={};s.round_resets={hands=4,discards=3};s.hand_size=8;s.hand_limit=5
 s.next_blind={key='bl_big',chips=7000};s.interest_cap=25
 s.jokers={F.joker('j_perkeo','Perkeo','p'),F.joker('j_yorick','Yorick','y'),
  F.joker('j_stencil','Joker Stencil','s'),F.joker('j_raised_fist','Raised Fist','r'),
  F.joker('j_mail','Mail-In Rebate','expired')}
 s.jokers[2].ability.x_mult=5;s.jokers[2].ability.extra={discards=23,xmult=1};s.jokers[2].ability.yorick_discards=9
 s.jokers[3].ability.x_mult=1;s.jokers[3].ability.eternal=true;s.jokers[3].ability.rental=true
 local dead=s.jokers[5];dead.ability.perishable=true;dead.ability.perish_tally=0;dead.debuff=true
 dead.edition={foil=true,type='foil',chips=50};dead.sell_cost=3
 s.pack_cards={card('c_soul','The Soul','Spectral','soul'),card('c_devil','The Devil','Tarot','devil')}
 s.pack_cards[2].ability.consumeable={max_highlighted=1,mod_conv='m_gold'}
 return s
end
local function advise(s)return D.run(s,{strategy=S})end
if SOUL_BASELINE426 then
 local a=advise(state())
 check(a.action.kind=='choose' and a.action.index==2,'Exact425 baseline takes Devil instead of admitting expired-Soul preparation')
 print('soul426 baseline: full-row Soul was not admitted; action='..a.action.kind)
 return
end
do
 local s=state();local before=F.Snapshot.fingerprint(s)
 local plans,proof=R.soul_sales(s,S)
 check(#plans==1 and plans[1].index==5 and proof.complete,'Foil expired Mail frees the unique ordinary slot')
 check(plans[1].after.dollars==34 and #plans[1].after.jokers==4,'Exact proceeds and physical capacity')
 check(plans[1].after.jokers[3].ability.x_mult==1,'No projected temporary Stencil bonus is invented')
 check(proof.evaluations==0,'Structural proof consumes no score calls')
 local a=advise(s);check(a.action.kind=='sell' and a.action.index==5,'Real decision chooses sale for Soul')
 check(not a.action.followup,'Execute only the sale, never a precommitted second action')
 local receipt=a.strategy.pack_diagnostics.comparisons[1]
 check(receipt.kind=='expired_sale_for_soul' and receipt.admitted and receipt.status=='structural','Auditable admission receipt')
 local compact=J.compact_copy_death_review(a)
 check(compact and compact.pack.candidates[1].sold_id=='expired' and compact.final_kind=='sell','Public compact journal preserves reason and final action')
 check(F.Snapshot.fingerprint(s)==before,'Detached proposal leaves source public data unchanged')
 local next_state=plans[1].after
 local next_advice=advise(next_state)
 check(next_advice.action.kind=='choose' and next_advice.action.index==1,'Fresh vacancy chooses actual visible Soul')
 check(S.shop_sequence_api.capacity(s,s.pack_cards[1],true)==false,'Full row reports Soul slot as unavailable')
 check(S.shop_sequence_api.capacity(next_state,next_state.pack_cards[1],true),'Fresh vacancy makes Soul legal')
 check(not R.suggest(s,S),'No broadening of shop rental-retirement scope')
end
do
 local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
 local Score=dofile('Brainstorm/Advisor/scoring.lua')
 local Pack=dofile('Brainstorm/Advisor/pack_scoring.lua')
 S.pack_scoring=Pack
 local modules={strategy=S,shop_scoring=Shop,scoring=Score,pack_scoring=Pack}
 local s=state();local a=D.run(s,modules)
 check(a.action.kind=='sell' and a.action.index==5,'Real shop context retains exact structural vacancy advice')
 check(a.evaluations<=50000,'Original shared computation budget remains bounded')
 check(a.strategy.pack_diagnostics.comparisons[1].status=='structural','Sale has no fabricated score receipt')
 check(a.strategy.pack_diagnostics.complete==false and a.strategy.pack_diagnostics.structural_only and
  a.strategy.pack_diagnostics.soul_vacancy_complete,'Exact vacancy completion is separate from unperformed tactical pack coverage')
 local after=S.shop_sequence_api.after_joker_sale(s,5)
 local fresh=D.run(after,modules)
 check(fresh.action.kind=='choose' and fresh.action.index==1,'Actual incomplete Soul projection uses whole strategic fallback')
 check(fresh.strategy.pack_diagnostics.tactical_fallback,'Unsupported legendary outcome does not receive a scored claim')
 check(fresh.evaluations<=50000,'Fallback preserves accumulated computation accounting')
 S.pack_scoring=nil
end
local function reject(label,edit)
 local s=state();edit(s)
 local plans=R.soul_sales(s,S)
 check(#plans==0,label)
end
for _,case in ipairs({
 {'nonteacher',function(s)s.teacher_profile=nil end},
 {'collection trade protected',function(s)s.completionist_goal={}end},
 {'wrong phase',function(s)s.phase='shop'end},
 {'no choices',function(s)s.pack_choices=0 end},
 {'missing choices',function(s)s.pack_choices=nil end},
 {'already vacant',function(s)s.joker_limit=6 end},
 {'overfull',function(s)s.joker_limit=4 end},
 {'temporary debuff',function(s)s.jokers[5].ability.perish_tally=1 end},
 {'expiry absent',function(s)s.jokers[5].ability.perishable=nil end},
 {'not debuffed',function(s)s.jokers[5].debuff=false end},
 {'eternal',function(s)s.jokers[5].ability.eternal=true end},
 {'pinned',function(s)s.jokers[5].pinned=true end},
 {'ability pinned',function(s)s.jokers[5].ability.pinned=true end},
 {'Negative frees no ordinary slot',function(s)s.jokers[5].edition={negative=true}end},
 {'unknown edition',function(s)s.jokers[5].edition={foil=true,unknown_callback=true}end},
 {'active Mail not covered',function(s)s.jokers[5].debuff=false;s.jokers[5].ability.perishable=false end},
 {'unknown expired callback',function(s)s.jokers[5].key='j_unknown'end},
 {'sale callback Joker',function(s)s.jokers[5].key='j_diet_cola'end},
 {'Baseball body dependence',function(s)s.jokers[4].key='j_baseball'end},
 {'Abstract body dependence',function(s)s.jokers[4].key='j_abstract'end},
 {'Swashbuckler sell value',function(s)s.jokers[4].key='j_swashbuckler'end},
 {'Campfire trigger',function(s)s.jokers[4].key='j_campfire'end},
 {'unknown retained effect',function(s)s.jokers[4].key='j_unknown'end},
 {'hidden retained card',function(s)s.jokers[1].face_down=true end},
 {'ambiguous identities',function(s)s.jokers[5].id='y'end},
 {'unknown copy capability',function(s)s.jokers[1].blueprint_compat=nil end},
 {'unsettled order',function(s)s.ordering_safe=false end},
 {'noncanonical Stencil',function(s)s.jokers[3].ability.x_mult=2 end},
 {'cash lowers hand size',function(s)s.modifiers.minus_hand_size_per_X_dollar=5;s.dollars=34 end},
 {'missing cash',function(s)s.dollars=nil end},
 {'all eternal',function(s)s.modifiers.all_eternal=true end},
 {'upcoming sacrifice boss',function(s)s.next_blind.key='bl_final_leaf'end},
 {'pending shuffle boss',function(s)s.blind_choices={Boss='bl_final_acorn'}end},
 {'random debuff boss',function(s)s.round_resets.blind_choices={Boss='bl_final_heart'}end},
 {'hidden Soul',function(s)s.pack_cards[1].identity_redacted=true end},
 {'hidden competing offer',function(s)s.pack_cards[2].face_down=true end},
 {'stale Soul absent',function(s)table.remove(s.pack_cards,1)end},
 {'duplicate Soul',function(s)s.pack_cards[2]=Copy(s.pack_cards[1])end},
 {'debuffed Soul',function(s)s.pack_cards[1].debuff=true end},
 {'modified Soul effect',function(s)s.pack_cards[1].ability.consumeable.extra=2 end},
 {'modified Soul name',function(s)s.pack_cards[1].ability.name='Unknown'end},
 {'wrong Soul set',function(s)s.pack_cards[1].ability.set='Tarot'end},
 {'unknown Soul identity',function(s)s.pack_cards[1].id=nil end},
 {'Soul edition',function(s)s.pack_cards[1].edition={negative=true}end},
 {'unknown inventory',function(s)s.consumeables[1].key='c_ankh';s.consumeables[1].ability.set='Spectral'end},
 {'Temperance sale-value decline',function(s)s.consumeables={card('c_temperance','Temperance','Tarot','t')};s.consumeables[1].ability.extra=50;s.consumeables[1].ability.consumeable.extra=50 end},
 {'Fool can regenerate Temperance',function(s)s.consumeables={card('c_fool','The Fool','Tarot','f')};s.last_tarot_planet='c_temperance'end},
 {'unknown inventory buffer',function(s)s.consumeable_buffer=nil end},
 {'copy reroute after dead target',function(s)s.jokers[1]=F.joker('j_blueprint','Blueprint','b');s.jokers[2],s.jokers[5]=s.jokers[5],s.jokers[2]end},
})do reject(case[1],case[2])end
do
 local s=state();s.jokers[4]=F.joker('j_blueprint','Blueprint','b')
 -- A dead final target remains absent after removing it: no live effect is lost.
 check(#R.soul_sales(s,S)==1,'Unresolved final copy stays unresolved; no imagined gain')
 s=state();s.jokers[4]=F.joker('j_blueprint','Blueprint','b');s.jokers[4],s.jokers[2]=s.jokers[2],s.jokers[4]
 check(#R.soul_sales(s,S)==1,'Active Blueprint retains same Stencil endpoint')
 s=state();s.jokers[5].key='j_trio';s.jokers[5].ability.name='The Trio'
 check(#R.soul_sales(s,S)==1,'Existing supported expired effects also qualify')
 s=state();s.pack_cards[2]=card('c_black_hole','Black Hole','Spectral','better')
 local a=advise(s)
 check(a.action.kind=='choose' and a.action.index==2,'A stronger free alternative prevents the preparatory sale')
 check(not a.strategy.pack_diagnostics.comparisons[1].admitted,'Preflight rejection remains visible')
end
for _,teacher in ipairs({true,false})do for _,pinned in ipairs({true,false})do
 local s=state();s.challenge='c_omelette_1';s.teacher_profile=teacher and s.teacher_profile or nil
 s.jokers[5]=F.joker('j_egg','Egg','valuable');s.jokers[5].sell_cost=40;s.jokers[5].pinned=pinned
 local a=advise(s)
 check(a.action.kind~='sell','Soul capacity cannot activate the legacy Omelette sale for an active/pinned Egg')
end end
-- Real execution adapter, manufactured callbacks: sale settles before a fresh
-- decision. No real G, game process, source callbacks or generated identity.
do
 local s=state();local a=advise(s)
 local g={STATES={SPECTRAL_PACK=1},STATE=1,GAME={pack_choices=1,STOP_USE=0},FUNCS={},
  hand={cards={},highlighted={},config={highlighted_limit=5}},jokers={cards=Copy(s.jokers)},pack_cards={cards=Copy(s.pack_cards)}}
 function g.hand:unhighlight_all()self.highlighted={}end
 function g.hand:add_to_highlighted(c)self.highlighted[#self.highlighted+1]=c end
 for _,area in ipairs({g.jokers,g.pack_cards})do for _,c in ipairs(area.cards)do c.area=area end end
 local calls={}
 g.FUNCS.can_sell_card=function(e)e.config.button='sell_card'end
 g.FUNCS.sell_card=function(e)
  check(e.config.ref_table.id=='expired','Adapter sells the actual expected expired card')
  calls[#calls+1]='sell';table.remove(g.jokers.cards,5)
 end
 g.FUNCS.can_use_consumeable=function(e)if #g.jokers.cards<5 then e.config.button='use_card'end end
 g.FUNCS.use_card=function(e)check(e.config.ref_table.id=='soul','Adapter selects the actual visible Soul');calls[#calls+1]='choose'end
 local ok,why=E.execute(g,a.action);check(ok,why)
 check(#calls==1 and calls[1]=='sell','Sale invokes only one callback')
 s=S.shop_sequence_api.after_joker_sale(s,5);a=advise(s)
 ok,why=E.execute(g,a.action);check(ok,why)
 check(#calls==2 and calls[2]=='choose','Fresh decision reaches legal Soul use')
 g.GAME.pack_choices=0
 ok=E.execute(g,a.action);check(not ok and #calls==2,'Exhausted pack cannot execute stale choice')
end
print('advisor_soul_vacancy426: '..checks..' checks passed')
