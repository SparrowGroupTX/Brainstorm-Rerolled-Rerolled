"""Render preserved descriptive data as review tables, never run the policy."""
from pathlib import Path
from collections import Counter
import json
P=Path(__file__).resolve().parent
load=lambda n:json.loads((P/n).read_text())
def text(v):return str(v).replace('|','/').replace('\n',' ')
def table(headers,rows):return '\n'.join(['| '+' | '.join(headers)+' |','|'+'|'.join('---' for _ in headers)+'|']+['| '+' | '.join(text(v) for v in r)+' |' for r in rows])+'\n'
def write(n,s):(P/n).write_text(s,encoding='utf-8')
runs=load('analysis/runs.json');ds=load('analysis/decisions.json')
notes={
1:'Win. Blueprint232→243; early Banner replaced at595 and Zany at1446. Final Yorick x8; main Perkeo stock Hierophant. Invisible338 was unaffordable at first exposure. Winning result does not validate every short discard or skipped pack.',
2:'Nonterminal Acorn retirement. Blueprint4617→4638. Three free-Planet skips3800/4242/4339 and full-row Rental Invisible pass4826. Glass8 Spades Death5692 confirmed. Acorn first play5736 succeeds physically; public Green continuity invalidates after5747, then retirement5755 with3 hands/3 discards.',
3:'Flint loss. Brainstorm6006→6017; four later affordable Buffoons passed. Perkeo had no source until ordinary Fool6735; eleven Fools accumulated by7406 with no owned use. Last shop$21, complete bounded policies predict shortfall. Final expired Greedy and low Planet levels; loss21,110 chips short. No proved winning counterfactual.',
4:'Head loss at Ante1. Buffoon7699 chooses durable Zany over Perishable plain Joker despite lower opening mean; utility favors permanence/trips. Exit7711$5 and empty Perkeo pool. Final478/600 after all hands/discards. Competing complete world results missing, so ranking error remains a hypothesis.',
5:'Nonterminal Acorn retirement before first boss play. Brainstorm8103→8115; Misprint acquired during run;21? no invented exact use count here. Perkeo World uses recorded in inventory actions below. Blackboard chosen10813. Misprint uncertainty stops Acorn11021 after one score; Misprint and Blackboard also lack post-action admission.',
6:'Win with Brainstorm11835→11856. Seven of seven Buffoons opened. Half Joker11739 has missing/incomplete pack comparison; later Bootstraps11884 and Throwback12671 selected. Invisible12413 passed with full row; delayed duplication absent from complete valuation. Pluto copying plus Observatory supports huge final score; outcome does not prove Invisible pass optimal.',
7:'Big Blind loss at Ante5. Buffoon→Ride the Bus14047, paid Celestial→skip14069, Yorick sold14081 for Fortune Teller/Ice Cream plan, proceeds spent on Telescope14091. Blueprint14623→14634 acquired later. Death14946 copies Ace Spades over Queen Diamonds under Ride the Bus. Final row lacks Yorick; loss2,639 short, not proof a different early plan wins.',
8:'Win. Four all-Planet skips16000/16256/16598/16621. Blueprint17028→17046 replaces Zany coherently; Brainstorm18384→18405 also acquired. Cash engine and final six-slot row survive Crimson Heart. Zany16112 outranks Mad despite lower opening mean; merits and eligibility are recorded, optimality is unresolved.',
9:'Plant loss at Ante4 with$61. No Blueprint/Brainstorm offered. Perkeo Chariot used11 times; the four targets after Plant became public were nonfaces. Triboulet remains face-dependent. Two all-Planet skips19279/20058. Last shop20069 admits uncertainty but safe-baseline/catalog-mass reroll guards decline more search. First Plant play20161 realizes9,380 against displayed14,420 with disclosed randomness; final15,792/18,000.',
10:'Win despite final cash-7. Blueprint20919→20951 acquired after a funded sale. Six Buffoons offered, none opened; only the first passed while Blueprint absent and directly affordable. Perkeo Venus used31 times and five Venus copies sold. This coherent scaling success is a useful counterexample to treating every low-cash or unused-discard state as an error.'}
notes[5]=notes[5].replace('Misprint acquired during run;21? no invented exact use count here. ','Misprint acquired during run. ')
rows=[]
for r in runs:
 s=r['last_observation'];h=r['last_hand'];b=h.get('blind')or{}
 rows.append([r['run'],r['end']['details']['outcome'],b.get('name'),s.get('chips'),b.get('chips'),s.get('dollars'),s.get('hands_left'),s.get('discards_left'),r['end']['sequence']])
out='# All ten run timelines407\n\nPublic loaded label2.195, one completed collection. Starts/outcomes are explicit; unsupported rows remain nonterminal. Event numbers refer to the hashed capture/index. Final winning observations may already advance Ante to9.\n\n'+table(['Run','Outcome','Last blind','Final chips','Target','$','Hands','Discards','Ending event'],rows)
for r in runs:
 out+=f"\n## Run{r['run']} — {r['end']['details']['outcome']}\n\nStart{r['start']['sequence']}; ending{r['end']['sequence']}; final public observation{r['last_observation']['sequence']}.\n\n{notes[r['run']]}\n\n"
 out+='Recorded action counts: '+', '.join(f'{k}={v}' for k,v in sorted(r['action_counts'].items()))+'.\n\n'
 out+='Inventory actions (counts, not inferred outcomes): '+', '.join(f'{k}={v}' for k,v in sorted(r['inventory_actions'].items()))+'.\n'
 out+='\nSee `analysis/decisions.json` for the complete ordered decision chain; `deep2/shop_exits.json` retains every exit, `late/loss_blind_entries.json` every loss-run entry, and `catalog/inventory_maxima.json` all observed consumable maxima.\n'
write('RUN_TIMELINES.md',out)

watch=load('analysis/copy_opportunities.json')
rows=[]
for o in watch:
 rows.append([o['run'],o['card']['key'],o['card'].get('id'),o.get('first_sequence'),o.get('first_owned_sequence'),o.get('bought_actions',o.get('acquisition_actions','See JSON'))])
out='# Full watched opportunities407\n\nFive Blueprint and four Brainstorm offers acquired; three Invisible offers passed. These are physical visible-offer counts, not unseen-pack probabilities. The twelve watched rows include Invisible; they must not be called twelve copy acquisitions.\n\n'
# Historical helper uses first_seen rather than first_sequence in some versions.
for row,o in zip(rows,watch):
 row[3]=o.get('first_seen',o.get('first_sequence',o.get('first_observation_sequence')))
out+=table(['Run','Offer','Physical ID','First exposure','First owned','Action evidence'],rows)
out+='\nThe source watch ledger is `analysis/copy_opportunities.json`; canonical first/last exposures and selected physical cards are also in `catalog/all_offers.json`. All acquired IDs appear in the later owned row. Invisible passes are discussed in REPORT.md; full rejected replacement receipts are in `followup/critical_decisions.json`.\n'
# Render canonical exposure times to avoid helper field naming ambiguity.
canonical=[o for o in load('catalog/all_offers.json') if o['card']['key'] in ('j_blueprint','j_brainstorm','j_invisible')]
out+='\n'+table(['Run','Key','First','Last','Cash first','Price','Owned','Selected action events'],[[o['run'],o['card']['key'],o['first'],o['last'],o['first_cash'],o['card'].get('cost'),o['first_owned'],','.join(str(a['sequence']) for a in o['actions'])or'none'] for o in canonical])
out+='\n## All54 Buffoon offers\n\nTwenty-six openings all have confirmed later reveals. Twenty-eight were unopened;20 directly affordable at the last exposure, ten of those without owned Blueprint. Affordability below is immediate cash only, not funding/reserve adequacy. First exposure Ante and cash/row at last exposure can differ after intervening purchases.\n\n'
out+=table(['Run','First','Ante','Price','Last cash','Blueprint then','Open events','Disposition'],[[b['offer']['run'],b['offer']['first'],b['offer']['ante'],b['offer']['card'].get('cost'),b['last_cash'],b['last_owned_blueprint'],','.join(str(a['sequence']) for a in b['offer']['actions'])or'none','opened' if b['offer']['actions'] else 'unopened/affordable' if b['directly_affordable_at_last_observation'] else 'unopened/cash short'] for b in load('followup/buffoon.json')])
out+='\n## All six Death offers\n\nTwo actual choices; two passes belonged to the searched Soul opening; the other two selected cash-generating Tarot cards. No unseen outcome or better future draw is inferred. Full public offered hands and receipts remain in the underlying index/JSON.\n\n'
out+=table(['Run','Exposure','Ante','Outcome action events'],[[x['offer']['run'],x['offer']['first'],x['offer']['ante'],'; '.join(str(c['request'])+': '+str(c['chosen']) for c in x['choices'])] for x in load('followup/death.json')])
out+='\nBoth selected Death transformations match the owned population after pack closure; see `deep2/death.json`.5692 copies Glass8 Spades;14946 copies ordinary Ace Spades in a Ride the Bus row. No hand-phase held Death exists in the linked advice states.\n'
out+='\n## Every Joker-pack choice, skip and enabling sale\n\nThirty decisions:18 direct choices plus skips/enabling sales. Seventeen of18 choices have complete comparable receipts; one(11739) does not. Different opening means do not by themselves establish dominance across growth, durability, draw selection and whole-blind resources.\n\n'
rows=[]
for x in load('followup/joker_pack_choices.json'):
 cs=x['receipt'].get('candidates',[])
 rows.append([x['run'],x['request'],x['action']['kind'],x['chosen'],','.join(c['key'] for c in x['offers']),x['receipt'].get('complete'),'; '.join(f"{c.get('key',c.get('index'))}:{round(c['score'],2) if isinstance(c.get('score'),(int,float)) else '?'}:{c.get('reason','')}:sale{c.get('sold_index','-')}" for c in cs)])
out+=table(['Run','Event','Action','Selected physical card','Offers','Complete','Recorded merit/reason/sale'],rows)
out+='\n## All-Planet skips\n\nAll ten have complete candidate receipts; this replicated negative-utility pattern is stronger evidence than labeling every skipped pack a mistake. The generic cost mechanism is reproduced independently, with no claim each instance would change a terminal outcome.\n\n'
out+=table(['Run','Event','Offered keys','Recorded scores'],[[x['run'],x['request'],','.join(c['key'] for c in x['offers']),','.join(str(round(c.get('score',0),3)) for c in x['receipt'].get('candidates',[]))] for x in load('deep2/pack_choices.json') if x['action'].get('kind')=='skip_pack' and any(c.get('ability',{}).get('set')=='Planet' for c in x['offers'])])
write('OPPORTUNITIES.md',out)

flags=load('deep2/flag_adjudication.json');counter=Counter((f['rule'],f['evidence_category']) for f in flags)
out='# Discard flag adjudication407\n\nThe unchanged406 tool yielded282 hypotheses:200 short discards and82 unused-discard clears. There are348 recorded discard actions and174 confirmed round clears. No automatic instruction to discard five or exhaust all discards follows.\n\n'+table(['Rule','Evidence category','Count'],[[*k,n]for k,n in sorted(counter.items())])
out+='\nAll flags have been assigned the evidence category below. These are review dispositions, not282 complete counterfactual evaluations. `insufficient_evidence` means the retained public receipts cannot establish whether a different legal action improves win probability. Source-conservative guards are candidates for bounded extension, not justification to remove safeguards. Twelve short discards and eight unused clears have no watched growth Joker; four final-boss clears lack later normal-run growth, although independent reward considerations can still exist.\n\n'
out+=table(['Run','Request','Rule','Evidence category','Disposition'],[[f['run'],f['request'],f['rule'],f['evidence_category'],f['status']]for f in flags])
out+='\nOriginal flag IDs, recorded cards, resources, anchors and advice are in `screen/report.json`; full growth/risk receipts and IDs are in `deep2/flag_adjudication.json`. For each next repair, require a common retained-clear and draw-risk comparison with growth thresholds, Green loss, held effects and rewards. Do not treat absent diagnostics as absent candidates or a five-card optimum.\n'
write('SCREEN_ADJUDICATION.md',out)
print('Wrote three review tables with all ten runs, watched offers and282 flag dispositions.')
