-- Manufactured counterfactuals; no captured-state replay or game execution.
local P='Brainstorm/Advisor/';local F=dofile('tests/fixtures/retained418.lua')
local S=dofile(P..'strategy.lua');local J=dofile(P..'joker_plan.lua');S.joker_plan=J
S.conditional_value=dofile(P..'conditional_value.lua');S.synergies=dofile(P..'synergies.lua')
local catalog={};for _,c in ipairs(dofile('tests/fixtures/joker_centers421.lua'))do catalog[c.key]=c end
local function card(k)local c=F.copy(assert(catalog[k],k));c.id=k;c.ability.mult=c.ability.mult or 0;c.ability.t_chips=c.ability.t_chips or 0;c.sell_cost=2;return c end
local n=0;local function check(x,t)n=n+1;assert(x,t)end
local function state(h)
 local s=F.state();s.phase='pack';s.hand={};s.deck={};s.hands={[h or 'Pair']={played=12,level=4}}
 s.round_resets={hands=4,discards=3};s.next_blind={key='bl_big',ante=3};s.jokers={F.j('j_yorick'),F.j('j_perkeo')}
 return s
end
local function value(s,k)return S.owned_joker_value(s,card(k))end
local s=state();local fingerprint=dofile(P..'snapshot.lua').fingerprint
local before=fingerprint(s)
local count=0;for k in pairs(catalog)do local v,reason,known=value(s,k);check(known and v==v and math.abs(v)<math.huge and type(reason)=='string','explicit finite vanilla value: '..k);count=count+1 end
check(count==150,'all150 vanilla identities audited');check(before==fingerprint(s),'valuation leaves public data unchanged')
local full=state('Full House');local pair=state('Pair');local high=state('High Card');local flush=state('Flush');local straight=state('Straight')
check(J.match(J.profile(full),'Pair')==1 and J.match(J.profile(full),'Three of a Kind')==1 and J.match(J.profile(full),'Two Pair')==1,'Full House activates contained pair/trips/two-pair')
local five=state('Flush Five');check(J.match(J.profile(five),'Pair')==1 and J.match(J.profile(five),'Four of a Kind')==1 and J.match(J.profile(five),'Flush')==1 and J.match(J.profile(five),'Two Pair')==0,'Flush Five containment does not invent two distinct pairs')
check(value(full,'j_jolly')>value(straight,'j_jolly'),'Pair joker follows contained ranks')
check(value(full,'j_jolly')==value(pair,'j_jolly'),'contained Pair receives the same unconditional type-Mult benefit')
check(value(pair,'j_duo')>value(straight,'j_duo'),'Duo shares rank-repeat activation')
check(value(straight,'j_order')>value(pair,'j_order'),'Order keeps real Straight value')
check(value(high,'j_half')>value(flush,'j_half'),'Half supports one-card scoring plans')
local psychic=F.copy(pair);psychic.next_blind.key='bl_psychic'
check(value(psychic,'j_half')<value(pair,'j_half'),'Psychic forces5 played despite2 scoring cards')
local steel=F.copy(psychic);steel.hand_size=8;steel.playing_cards={};for i=1,8 do steel.playing_cards[i]=F.card('steel:'..i,13,'Clubs',i<=6 and 'm_steel' or 'c_base')end
check(J.profile(steel).scoring_cards==2 and J.profile(steel).held==3,'Psychic preserves scoring count but constrains physical held capacity')
check(value(steel,'j_mime')==54,'Mime cannot retain six Steel effects after playing five of eight cards')
steel.jokers[#steel.jokers+1]=card('j_chicot');check(value(steel,'j_mime')>54,'Chicot restores held capacity')
check(value(high,'j_flower_pot')<value(full,'j_flower_pot'),'four scoring suits unsupported by singleton plan')
check(value(high,'j_seeing_double')<value(pair,'j_seeing_double'),'Seeing Double needs separate scoring suits')
check(value(straight,'j_shortcut')>value(pair,'j_shortcut') and value(flush,'j_smeared')>value(straight,'j_smeared'),'enablers distinguish Straight from Flush')
local needle=F.copy(pair);needle.next_blind.key='bl_needle'
check(value(needle,'j_card_sharp')<value(pair,'j_card_sharp'),'one hand cannot activate repeated-play Card Sharp')
check(value(needle,'j_dusk')>value(pair,'j_dusk') and value(needle,'j_acrobat')>value(pair,'j_acrobat'),'last-hand effects match Needle opportunity')
needle.jokers[#needle.jokers+1]=card('j_burglar');check(value(needle,'j_card_sharp')>0,'Burglar adds hands after Needle restriction')
needle.jokers[#needle.jokers]=nil;needle.round_bonus={next_hands=1};check(value(needle,'j_card_sharp')>0,'actual extra next hand survives Needle reset subtraction')
local clean=F.copy(pair);clean.playing_cards={};for i=1,24 do clean.playing_cards[i]=F.card('rank:'..i,13,'Clubs')end
check(value(clean,'j_triboulet')>value(pair,'j_triboulet'),'repeated kings increase Triboulet opportunity')
check(value(clean,'j_sock_and_buskin')>value(pair,'j_sock_and_buskin'),'face retrigger follows repeated rank concentration')
check(value(clean,'j_hack')==0 and value(clean,'j_scholar')==0,'wrong-rank engines earn no nonexistent triggers')
check(value(clean,'j_flower_pot')==0 and value(clean,'j_seeing_double')==0,'all ordinary Clubs cannot fill other required scoring suits')
local suits=F.copy(clean);suits.hands={['Five of a Kind']={level=4,played=12}}
check(value(suits,'j_flower_pot')==0,'five scoring cards alone do not establish four suits')
for i,c in ipairs(suits.playing_cards)do c.suit=({'Clubs','Hearts','Diamonds','Spades'})[i%4+1]end
check(value(suits,'j_flower_pot')>0,'four-suit population remains a real opportunity')
local wild=F.copy(clean);wild.playing_cards[1]=F.card('wild',13,'Clubs','m_wild')
check(value(wild,'j_flower_pot')==0 and value(wild,'j_seeing_double')>0,'one Wild can fill only one missing suit')
wild.playing_cards[2]=F.card('wild2',13,'Clubs','m_wild');wild.playing_cards[3]=F.card('wild3',13,'Clubs','m_wild');check(value(wild,'j_flower_pot')>0,'three Wilds can fill three missing suits')
local smear=F.copy(clean);smear.jokers[#smear.jokers+1]=card('j_smeared');smear.hands={['High Card']={played=12,level=4}}
check(value(smear,'j_seeing_double')>0 and value(smear,'j_flower_pot')==0,'Smeared one black card can satisfy Double but not four distinct Pot cards')
local redacted=F.copy(clean);redacted.playing_cards[1]={id='opaque',unknown=true,identity_redacted=true}
local opaque={};for _,k in ipairs({'j_hanging_chad','j_glass','j_hit_the_road','j_sixth_sense','j_oops','j_scholar'})do opaque[k]=value(redacted,k)end
redacted.playing_cards[1].rank=14;redacted.playing_cards[1].enhancement='m_glass';redacted.playing_cards[1].edition={polychrome=true}
for k,v in pairs(opaque)do check(value(redacted,k)==v,'redacted stale payload cannot change utility: '..k)end
check(value(redacted,'j_flower_pot')>0,'incomplete composition is not proof of impossible suit coverage')
check(value(clean,'j_mime')==0,'Mime has no vanilla held effect to repeat')
clean.jokers[#clean.jokers+1]=card('j_baron');check(value(clean,'j_mime')>50,'held Kings plus Baron create real Mime value')
for _,c in ipairs(clean.playing_cards)do c.rank=10;c.base.id=10 end
check(value(clean,'j_photograph')==0 and value(clean,'j_triboulet')==0,'no face/KQ population earns no face XMult')
local red=card('j_red_card');local unscaled=S.owned_joker_value(pair,red);red.ability.mult=60
check(S.owned_joker_value(pair,red)>unscaled+25,'existing Red Card Mult is retained while unearned skips lose value')
for _,k in ipairs({'j_castle','j_runner','j_square','j_wee'})do local c=card(k);local old=S.owned_joker_value(pair,c);c.ability.extra.chips=160;c.ability.t_chips=0
 check(S.owned_joker_value(pair,c)>old+15,'extra.chips not shadowed by initialized zero: '..k)
end
local ca=card('j_caino');local old=S.owned_joker_value(pair,ca);ca.ability.caino_xmult=8;check(S.owned_joker_value(pair,ca)>old+50,'Caino uses real counter')
local gl=card('j_glass');old=S.owned_joker_value(pair,gl);gl.ability.x_mult=6;check(S.owned_joker_value(pair,gl)>old+40,'Glass Joker retains growth after glass population disappears')
local road=card('j_hit_the_road');old=S.owned_joker_value(pair,road);road.ability.x_mult=10;check(S.owned_joker_value(pair,road)==old,'resetting Hit the Road cannot carry last-round multiplier')
check(value(pair,'j_green_joker')<value(pair,'j_mystic_summit'),'full-discard strategy favors exhausted-discard Mult over unscaled Green')
check(value(pair,'j_drunkard')>value(pair,'j_banner') and value(pair,'j_merry_andy')>value(pair,'j_delayed_grat'),'discard enablers beat discard-hoarding triggers')
local empty=F.copy(pair);empty.consumeables={card('j_joker'),card('j_joker')};check(value(empty,'j_cartomancer')<value(pair,'j_cartomancer'),'full consumable slots constrain generator')
check(value(pair,'j_vagabond')==0,'cash-rich plan cannot trigger Vagabond')
check(value(pair,'j_baseball')==0,'legendary row is not uncommon Baseball support')
local uncommon=F.copy(pair);uncommon.jokers[#uncommon.jokers+1]=card('j_mime');check(value(uncommon,'j_baseball')>0,'Baseball recognizes actual Uncommon partner')
local stencil=card('j_stencil');stencil.edition={negative=true};local incoming=S.owned_joker_value(pair,stencil)
local retained=F.copy(pair);retained.joker_limit=retained.joker_limit+1;retained.jokers[#retained.jokers+1]=stencil
check(S.owned_joker_value(retained,stencil)==incoming,'owned Negative Stencil capacity is counted once')
local generic=F.copy(pair);generic.teacher_profile=nil;local _,_,known=S.owned_joker_value(generic,card('j_hanging_chad'));check(not known,'generic objective retains prior strategy contract')
local unknown=card('j_hanging_chad');unknown.key='mod_unknown';local _,_,k=S.owned_joker_value(pair,unknown);check(not k,'unknown mod Joker never becomes known by generic ability fields')
-- A self-owned hand affinity must not manufacture evidence for the new policy.
local without=J.profile(pair);local with=F.copy(pair);with.jokers[#with.jokers+1]=card('j_order');check(fingerprint(J.profile(with))==fingerprint(without),'Joker cannot justify its own hand plan')
local levels=F.copy(pair);levels.hands['Four of a Kind']={played=1,level=20};check(J.match(J.profile(levels),'Four of a Kind')>0.8,'newly developed hand levels can outweigh old history')
print('Joker plan421: '..n..' checks passed')
