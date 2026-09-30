-- Independent manufactured states; never copied from a public journal.
local F=dofile('tests/fixtures/retained418.lua');local m=F.modules()
local S=dofile(STRATEGY420_PATH or 'Brainstorm/Advisor/strategy.lua');m.strategy=S
S.consumables=m.consumables
local checks=0;local function check(v,msg)checks=checks+1;assert(v,msg)end
local function tarot(key,id,negative)
 local names={c_death='Death',c_empress='The Empress'}
 return {key=key,id=id or key,cost=3,sell_cost=1,edition=negative and {negative=true} or nil,
  ability={set='Tarot',name=names[key],consumeable=key=='c_death' and {mod_conv='card',mod_num=2,min_highlighted=2,max_highlighted=2} or {mod_conv='m_mult',mod_num=2,max_highlighted=2}}}
end
local function shop()
 local s=F.state();s.phase='shop';s.ante=3;s.dollars=20;s.jokers={F.j('j_perkeo'),F.j('j_yorick')}
 s.shop_jokers={tarot('c_death','offer')};s.shop_booster={};s.shop_vouchers={};s.hand={};s.deck={};s.playing_cards={}
 s.consumeables={tarot('c_empress','held',true)};s.consumable_limit=3;s.consumeable_buffer=0;s.reroll_cost=5
 s.next_blind={key='bl_big',label='Big',ante=3,chips=2000};s.blind={key='bl_small',chips=1000}
 s.hands={Pair={played=8,level=1,chips=10,mult=2}}
 for i=1,39 do s.playing_cards[i]=F.card('public:'..i,2+(i%13),'Spades')end
 s.playing_cards[1]=F.card('owned_source',13,'Clubs','m_mult')
 return s
end
local function utility(s,key)local _,i=S.inventory_value(s,{tarot(key)});return i.direct end
do
 local s=shop();local fp=m.snapshot.fingerprint(s);local a=S.advise(s)
 check(a.action.kind=='buy' and a.action.index==1,'visible Death is acquired beside Empress once useful upgraded stock exists')
 check(m.snapshot.fingerprint(s)==fp,'source valuation does not mutate public inventory')
 local mult=utility(s,'c_death');s.playing_cards[1]=F.card('owned_source',13,'Clubs','m_glass')
 local glass=utility(s,'c_death');check(glass>mult,'Glass source raises Death value over Mult source')
 s.playing_cards[1].edition={polychrome=true};s.playing_cards[1].seal='Red'
 check(utility(s,'c_death')>=glass,'stacked source does not reduce copying utility')
 local hidden=F.copy(s);hidden.playing_cards[1].identity_redacted=true
 check(utility(hidden,'c_death')<glass,'redacted public identity cannot receive source-quality credit')
 local plain=F.copy(s);plain.teacher_profile=nil
 local ordinary=utility(plain,'c_death');plain.playing_cards[1]=F.card('owned_source',13,'Clubs')
 check(utility(plain,'c_death')==ordinary,'nonteacher stock contract unchanged')
 s=shop();s.playing_cards={F.card('a',13,'Clubs','m_glass'),F.card('b',13,'Clubs','m_glass')}
 check(utility(s,'c_death')==0,'identical upgraded deck has no useful copying recipient')
 -- Room remains after a Negative sale only if it already existed; never
 -- manufacture an ordinary slot by removing a Negative source.
 s=shop();s.consumeables={tarot('c_empress','sole')};s.consumable_limit=1
 local sale=S.advise(s)
 check(sale.action.kind=='sell' and sale.action.area=='consumeables','full ordinary slot can compare complete Empress-to-Death endpoint')
 local fresh=F.copy(s);fresh.dollars=fresh.dollars+fresh.consumeables[1].sell_cost;fresh.consumeables={}
 check(S.advise(fresh).action.kind=='buy','fresh empty-slot advice acquires the intended Death')
 fresh.shop_jokers={};check(S.advise(fresh).action.kind~='buy','vanished offer is not followed by a stale purchase')
 s=shop();s.consumeables={tarot('c_empress','sole',true)};s.consumable_limit=1
 check(S.advise(s).action.kind~='sell','Negative sale cannot invent replacement space')
 s=shop();s.consumeables={tarot('c_empress','sole')};s.consumable_limit=1;s.dollars=0;s.jokers[1].ability.rental=true
 check(S.advise(s).action.kind~='sell','unfunded replacement preserves its existing source')
 s=shop();s.consumeables={tarot('c_empress','sole')};s.consumable_limit=1;s.shop_jokers[1].unknown=true
 check(S.advise(s).action.kind~='sell','unknown offer cannot authorize a source sale')
 s=shop();s.consumeables={tarot('c_empress','sole')};s.consumable_limit=1;s.dollars=40
 local copy=F.j('j_blueprint');copy.id='visible_copy';copy.cost=3;s.shop_jokers[2]=copy
 local ctx={evaluations=0,truncated=false}
 function ctx:compare(before,after)
  self.evaluations=self.evaluations+4
  local worlds={};for i=1,4 do worlds[i]={clear=true,progress=1}end
  local finish={complete=true,supported=true,known_mechanics=true,samples=4,selected={clearing_samples=4,worlds=worlds}}
  return {samples=4,ratio=2,adjustment=15,before_target=1000,after_target=1000,before_mean=2000,after_mean=4000,
   before_finishing=finish,after_finishing=finish,complete_finishing=true,
   common_worlds={kind='shop_four_common_worlds_v1',samples=4,world_ids={1,2,3,4},family_key='invented420'},reason='Manufactured paired support.'}
 end
 check(S.advise(s,{shop_scoring=ctx}).action.area~='consumeables','a stronger supported fresh Blueprint purchase prevents a consumable sale plan')
end
do
 local s=shop();s.dollars=48;s.ante=6;s.shop_jokers={};s.consumeables={tarot('c_death')}
 s.playing_cards[1]=F.card('modest',2,'Hearts');s.playing_cards[1].edition={foil=true}
 local pack={id='standard',key='p_standard_normal_1',cost=4,ability={set='Booster',name='Standard Pack'}}
 s.shop_booster={pack};local score=S.shop_sequence_api.card_value(s,pack)
 check(score>50 and S.advise(s).action.kind=='open','funded Death source exploration continues after a modest Foil source')
 s.ante=7;check(S.shop_sequence_api.card_value(s,pack)>50,'Ante7 does not impose a binary source-search cutoff')
 s.dollars=40;s.jokers[1].ability.rental=true;s.modifiers.discard_cost=3;s.round_resets={discards=4}
 check(S.shop_sequence_api.card_value(s,pack)<50,'paid discards and rentals remain reserved')
 s=shop();s.dollars=48;s.shop_jokers={};s.consumeables={tarot('c_death')};s.shop_booster={pack}
 s.playing_cards[1]=F.card('stacked',13,'Clubs','m_glass');s.playing_cards[1].edition={polychrome=true};s.playing_cards[1].seal='Red'
 check(S.shop_sequence_api.card_value(s,pack)<50,'fully stacked preferred source ends the extra hunt premium')
 s=shop();s.dollars=48;s.consumeables={tarot('c_death')};s.next_blind={label='Boss',ante=8};s.ante=8
 check(S.shop_sequence_api.card_value(s,pack)<50,'no future-horizon stock premium before the final boss')
end
-- Actual fresh target selection switches physical sources and uses a real reorder.
do
 local s=F.state();s.jokers={F.j('j_yorick')};s.consumeables={tarot('c_death','one'),tarot('c_death','two')}
 s.hand={F.card('weak',2,'Hearts'),F.card('old',12,'Spades','m_mult'),F.card('new',13,'Clubs','m_steel')}
 F.population(s)
 local targets=S.development_targets(s,s.consumeables[1])
 check(targets and s.hand[targets[2]].id=='new','current stronger source supersedes the former source')
 s.hand={s.hand[3],s.hand[1],s.hand[2]};F.population(s)
 local _,_,order=S.development_targets(s,s.consumeables[1]);check(order and s.hand[order[#order]].id=='new','source on the left requires physical rearrangement')
 local fresh=F.copy(s);fresh.hand={};for i,k in ipairs(order)do fresh.hand[i]=s.hand[k]end
 targets=S.development_targets(fresh,fresh.consumeables[1]);local after=assert(m.consumables.apply(fresh,1,targets))
 check(fresh.hand[targets[2]].id=='new' and after.hand[targets[1]].enhancement=='m_steel','fresh legal Death copies the new source')
 local hidden=F.copy(s);hidden.hand[1].face_down=true
 local _,_,bad=S.development_targets(hidden,hidden.consumeables[1])
 check(not bad or hidden.hand[bad[#bad]].id~='new','concealed source is never targeted from its hidden identity')
 local absent=F.copy(s);table.remove(absent.hand,1)
 targets=S.development_targets(absent,absent.consumeables[1]);check(not targets or not absent.hand[targets[2]] or absent.hand[targets[2]].id~='new','not-yet-drawn source is not a current legal target')
end
do
 local s=shop();s.phase='pack';s.pack_type='STANDARD_PACK';s.pack_choices=1;s.shop_jokers={};s.consumeables={tarot('c_death')}
 s.pack_cards={F.card('plain_offer',2,'Hearts'),F.card('better_offer',13,'Clubs','m_glass')}
 s.pack_cards[2].edition={polychrome=true};s.pack_cards[2].seal='Red'
 local a=S.advise(s);check(a.action.kind=='choose' and a.action.index==2,'revealed stacked source wins over weak Standard dilution')
 s.pack_cards={s.pack_cards[1]};a=S.advise(s)
 check(a.action.kind=='skip_pack','Death ownership does not justify adding a weak revealed card')
end
do
 local s=shop();s.jokers[2].ability.x_mult=10;s.next_blind.chips=500;s.shop_booster={}
 local modules={strategy=S,scoring=m.scoring,shop_scoring=dofile('Brainstorm/Advisor/shop_scoring.lua'),
  shop_sequences=dofile('Brainstorm/Advisor/shop_sequences.lua'),consumables=m.consumables}
 local r=m.decision.run(s,modules,nil,{prepared_scoring=false})
 check(r.action.kind=='buy' and r.action.index==1,'real complete shop path buys useful Death beside retained Empress')
 check(r.evaluations<=50000,'source acquisition stays within the shared shop allowance')
 check(r.strategy.perkeo_stock_review and r.strategy.perkeo_stock_review.source_id=='owned_source',
  'public source-acquisition receipt names the actual known physical source')
end
print('Death progression420: '..checks..' checks passed')
