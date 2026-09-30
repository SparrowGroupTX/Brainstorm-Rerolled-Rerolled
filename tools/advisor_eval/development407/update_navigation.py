"""Prepend current audit facts; preserve every byte of prior navigation history."""
from pathlib import Path
import hashlib,json
R=Path(__file__).resolve().parents[3];P=Path(__file__).resolve().parent
pre=json.loads((P/'prework.json').read_text())
common='''COMPLETED COHORT AUDIT407 — 2026-09-26
The user reported the latest ten-run session complete. Read tools/advisor_eval/
AUDIT_CHECKPOINT_407.md and development407/REPORT.md, RUN_TIMELINES.md,
OPPORTUNITIES.md, SCREEN_ADJUDICATION.md, REPAIR_SPEC.md and FINAL_VERIFICATION.json.
Preserved25 public segments/22,817 events: loaded-label2.195 has4 verified wins,
4 losses and2 nonterminal Acorn retirements across all10 starts. All1,929 policy
actions link;5/5 Blueprint and4/4 Brainstorm offers acquired.26/54 Buffoons opened;
3 Invisible passed;2 Death uses physically confirmed.282 discard flags remain
categorized hypotheses.29 invented diagnostic checks reproduce supported gaps.
New priorities: Yorick sale-plan abandonment, Green/Misprint/Blackboard Acorn
support, free-Planet purchase penalties, and non-Jupiter Fool capability/value
mismatch. The narrow existing hand-phase Fool/Jupiter route remains distinct.
Runtime/install remain exact2.195 checkpoint404; no runtime repair, new freeze,
install or gameplay control. Current audit and its one review/one recheck are
complete. Latest normal exit is not confirmed; collection completion or process
absence does not establish it. No population50% or causal gain claim is made.
Earlier unaudited/unconfirmed-label notes are historical for this now captured
cohort. All full resume preservation, execution, budget and release requirements
below remain mandatory. Stop this audit after delivery; next authorized runtime
repair needs a new exact combined freeze and every required validation gate.

'''
prefixes={n:common for n in ('ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md')}
prefixes['tools/advisor_eval/NEXT_PRIORITIES_404.md']='''Audit407 update (2026-09-26): the user-reported completed cohort has been fully
captured and audited; read AUDIT_CHECKPOINT_407.md and development407/REPAIR_SPEC.md.
Next authorized repair priorities: funded engine-sale continuity; Acorn public
Green growth and Misprint/Blackboard support; correct free-pack upgrade objective;
non-Jupiter Fool capability-aware acquisition/use. Invisible maturation, Joker-pack
utility, unsafe-blind spending and growth-discard completeness remain hypotheses.
All9 visible Blueprint/Brainstorm offers were acquired; this does not close
opportunity/funding quality. Current runtime remains exact installed404.
No repair/release is pending. Preserve budgets, historical work and closed
experiment boundaries. The completed audit is not authority for further gameplay.

'''
prefixes['tools/advisor_eval/ARCHITECTURE_MAP_404.md']='''Audit407 source-map update (2026-09-26; runtime unchanged):
- shop_sequences.lua:85/110/270: ordinary buys bypass shared admission except
  Madness; core sale projects legally; fresh voucher incumbent exits graph scope.
  Internal continuation is not the same as journaled action.followup. Run7 sold
  Yorick14081 then spent proceeds on Telescope14091 instead of the funded plan.
- acorn_belief.lua:77/116/266: Green public growth, Misprint and Blackboard lack
  canonical action continuity. acorn_ordering.lua:51 selects supported floors
  only for Lucky, omitting no-Lucky Misprint. These cause two observed retirements.
- strategy.lua:802/1038/3014 plus shop_scoring.lua:1043: free pack upgrade can
  receive off-plan utility3 plus acquisition hurdle-14; ten Planet skips recorded.
- pack_scoring.lua:156 generic owned-Fool shop admission requires zero Jokers.
  Separate consumables.lua:403/454 hand-phase Fool/Jupiter route exists; do not
  generalize the observed non-Jupiter capability gap to all Fool use.
- flag_suspect_decisions.py remains unchanged406. Its explicit-followup and
  selected-merit comparisons miss unstructured engine-sale plans and defects in
  the merit objective itself. Discard flags are hypotheses, not optimality tests.
Read development407/REPORT.md, REPAIR_SPEC.md and FINAL_VERIFICATION.json.

'''
prefixes['tools/advisor_eval/WIN_RATE_RESEARCH.md']='''## Completed loaded-label2.195 cohort — audit407, 2026-09-26

See development407/REPORT.md, complete opportunity/run/discard tables, and exact
capture/verification.25 segments/22,817 events;10 starts=4 verified wins,4 losses,
2 nonterminal Acorn retirements. All1,929 policy links match recorded current
advice. No captured scoring/replay or game control.29 invented module-diagnostic
checks pass; runtime remains exact installed404. No causal win gain or population
50% rate. The prior2.194 cohort and all earlier hypotheses remain separate.

### WR-054 — supported, unpatched: Acorn floor selection and public continuity

Run2 Green play5736 completes5747, invalidates5751, retires5755 with3 hands/3
discards. Green is scored but lacks qualified public action transition. Run5
canonical Misprint without Lucky rejects after one score11021; existing lower
bound is not selected. Misprint/Blackboard would also invalidate after an action.
Invented controls reproduce both mechanisms. Public popup-before-completion is
essential; do not derive Green identity from stale Mult. Neither retirement is
a verified loss or saved win. See REPORT.md and bounded review.

### WR-055 — confirmed deviation, unpatched: sale-funded shop plan abandoned

Run7 sells Yorick14081 for a Fortune Teller/Ice Cream endpoint, then buys Telescope
14091 and exits14102 without either planned Joker. Internal sequence lacks the
structured followup used by the screen; fresh voucher arbitration exits sequence
scope. Later Ante5 loss15660 cannot by itself prove retaining Yorick wins.
Shared-admission asymmetry is manufactured/source-supported; the404 Perishable
guard does not automatically apply to unstickered Ice Cream. Require complete
funding, horizon and freshly validated physical continuation before core sales.

### WR-056 — confirmed local defect, unpatched: free Planet inherits buy hurdle

Ten all-Planet skips have complete negative-merit receipts. Run7 Uranus14069
improves recorded opening134.25→193.5 yet gets-11. Invented complete-finishing
fixture reproduces a free upgrade76→174 but capped progress1→1, value3 minus
acquisition hurdle14, and skip. Scope costs correctly; preserve actual pack choice,
Fool history and other effects. No full-run rescue established.

### WR-057 — supported mismatch, unpatched: non-Jupiter Fool copied but unused

Run3 buys ordinary Fool6735, has11 by7406 and loses Flint7531 without owned use.
Known last-used Planets include Mercury/Venus/Pluto; generic shop Fool projection
excludes every Joker row despite positive acquisition/copy valuation. The existing
hand-phase Fool/Jupiter route is separate and not refuted. Not every accumulated
copy is proven legally usable; value must match qualified executable transitions.

WR-050 update:5/5 Blueprint,4/4 Brainstorm acquired;26/54 Buffoons opened. Three
Invisible passes include affordability/full-row/maturity tradeoffs, not confirmed
missed safe purchases. Zany/plain Joker ranking7699 is a survival-versus-durable
utility hypothesis; complete rejected worlds are missing.406 screen misses plans
without explicit followup and choices whose own objective is wrong.

WR-051 update:2 confirmed Death uses/6 offers, both revealed packs; Glass8S and
ordinary AS under Ride the Bus are contextually defensible.862 fishing receipts
say no held Death; this cohort cannot establish adequate owned-Death fishing.
WR-001/021/022 update:200 short discards and82 unused-discard clears retained
and categorized; no blanket five-card/exhaust-discard rule follows.172 truncated
shop receipts and93 fallback pack advices remain support/budget concerns.
Further repair requires new exact combined freeze and mandated full gates.

'''
for name,prefix in prefixes.items():
 f=R/name;raw=f.read_bytes();assert hashlib.sha256(raw).hexdigest()==pre['before_files'][name],name
 f.write_bytes(prefix.encode('utf-8')+raw)
print('Prepended407 facts to six navigation/ledger files, preserving complete previous bytes.')
