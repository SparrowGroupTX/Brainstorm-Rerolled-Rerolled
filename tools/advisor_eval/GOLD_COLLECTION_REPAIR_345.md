# Gold collection repair 345

## Outcome being repaired

The passive journal confirms the user's second reported zero-progress win was
running **2.144.0-alpha**. Session `session-20260916T042025Z-1`, seed `YVYN2Z11`,
won Ante 8 Verdant Leaf with **686,952 / 400,000 chips and $98**. The original
`set_joker_win` and `set_deck_win` callbacks verify the win at sequence 2240.
All five final Jokers—Caino, Yorick, Cartomancer, Devious Joker and Brainstorm—
already had Gold stickers. The new-sticker receipt correctly reports zero, and
collection progress remained **59 / 150**. Perkeo had been sold during the final
blind to disable Leaf.

The run used 232 automatic actions over 305.7940514 seconds. It left 22 shops,
12 of which displayed at least one missing Joker, and made no paid rerolls.
Visible offers alone do not prove legal, affordable or safe acquisition.

| Recorded decision | Visible missing offer | Cash | Held consumables | Logged collection rejection |
| --- | --- | ---: | --- | --- |
| Pre-Small action 2070 / exit 2086 | Loyalty Card, $5 | $85 / $81 | 22 cards, 23 slots; 21 Negative | Owned-row supported-identity guard; zero comparisons |
| Pre-Big exit 2149 | None | $76 | 24 cards, 24 slots; 22 Negative | Same owned-row guard; zero comparisons |
| Pre-Leaf exit 2192 | Eternal Crafty Joker, $4 | $89 | 26 cards, 26 slots; 24 Negative | Existing final-shop Perkeo projection required at most eight cards |

All three late shop exits recorded zero score calls. Before Small, the row
contained Negative Perkeo, Yorick, Eternal holographic Cartomancer, Caino,
Eternal Devious Joker and Brainstorm. Installed344's stable-row gate excluded
Cartomancer. Its fixed-hold Tarot certificate also excluded Cartomancer/Caino
from the row roster and every Tarot class actually held here: Temperance, Sun,
Moon, Wheel of Fortune and Hanged Man. These are separate admission gaps.

`development345/log_analysis/summary.json` preserves the compact audit, exact
input byte prefixes, original frame/event anchors, append-active qualification
and frozen344 source references. Its SHA256 is
`8dc3b229797a894021ef48aeeabdfbc652ff569960fb15fe00e68e91ffac3b04`.
The larger preserved audit is `passive_audit.json`, SHA256
`c194bc9f3599674b2d6284df3a92d9b453e796a02519e91a3f9517b63ef786cb`.
There were no decode errors. Other observed losses and the unfinished run at the
captured prefix remain explicit; this session is not a representative cohort.

## Runtime changes and limits

`Advisor/gold_tarot_hold.lua` now accepts raw absent `pinned` as the vanilla
unpinned default, as well as explicit false. True and malformed values still
reject; normalized snapshots still require false. Preserved Card constructor
and copy code establish this source-shape mismatch. The passive snapshots
already normalize the field, so this audit does **not** claim raw nil was
observed as the cause of the reported run's rejection.

The same module broadens the fixed-hold certificate to all **22 canonical
vanilla Tarot identities**. Magician and Hermit keep their exact known configs.
The other twenty identities require consistent visible, plain constructor data,
zero score/hand/discard defaults, the actual registered center and matching
snapshot certificate. Temperance's bounded money display is retained without
crediting its payout. Hidden, malformed, unsupported edition, buffer/capacity,
identity, constructor and metatable cases remain rejected.

This is a dependency proof for **unused ordinary/Negative Tarots held throughout
the first hand**. It preserves every original card. Perkeo's future Negative
copies add a card and a slot without changing first-hand score dependencies;
their exact identities, prices, resale proceeds, later uses and future utility
remain unresolved and uncredited. The extension does not qualify arbitrary
mod callbacks or the use effects of those twenty Tarots. Planets and Observatory
remain outside this Tarot-only certificate, preserving their separate policy.

The fixed-hold copy resolver now checks a canonical **110-identity Joker roster**
instead of a small hand-selected subset. Source keys, names, visible physical
IDs, Boolean copy compatibility, activity metadata and copy-chain guards still
must agree. Cartomancer is present only for the ending-shop dependency proof;
its blind-start effect needs the separate full-inventory gate below.

`Advisor/gold_goal.lua` and `Advisor/shop_scoring.lua` admit Cartomancer only
when the settled consumable inventory is **exactly full**, its buffer is zero
and public identity/activity requirements are satisfied. Under this family's
hold policy, Negative Perkeo copying preserves the same lack of free capacity,
so Cartomancer cannot generate a card at blind selection. The exception is
restricted to fixed-current-row comparisons. Free-slot Cartomancer, other
generators and unresolved startup effects remain unsupported. In particular,
the actual pre-Small input above has one free slot and remains outside this
proof; this repair does not claim to solve that decision.

`Advisor/gold_acquisition.lua` extends its existing winning-Ante pre-Small/Big
comparison to **Violet Vessel and Verdant Leaf**. It still completes the declared
family of hold, each admitted visible missing-Joker buy, and each legal sale of
one completed original Joker followed by that buy. At most three offers, six
owned Jokers and twenty-two endpoints are admitted. Cash, borrowing, Eternal,
Negative capacity, original inventory, physical population and complete metadata
guards remain in force. Four identical public-composition worlds compare fixed
physical Joker rows with warning-free supported random score floors. Every
selected endpoint must retain at least **125% of the next target** and the
required cash reserves. Excess score can be traded for a distinct missing key;
no sampled margin is called a win probability or guaranteed clear.

New `Advisor/gold_retention.lua` prevents an ordinary complete sale-and-buy plan
from undoing collection progress solely to recover excess score. It compares
the complete paid incumbent against holding the actual current row, with all
consumables retained. The incumbent must declare one sale followed by one or
two visible Joker buys; only a strict loss of distinct missing keys is eligible
for an override. Both endpoints must qualify, and holding must preserve the
same four-world margin and cash guards. Bare sales, undeclared continuations,
Tarot uses, unsupported bosses and incomplete comparisons receive no override.

`Advisor/decision.lua` reserves up to **8,000 evaluations within the existing
50,000 shop limit** for this review when eligible missing cargo is aboard. Actual
work is shared across acquisition, ordinary shop planning and retention;
unsuccessful work remains charged. A complete retention result exits with the
**exact fixed row that was compared**. Later `phase_copy` postprocessing is
suppressed only for that certified exit, preventing it from silently changing
the copying/order policy or exposing the target to immediate resale on a fresh
decision. Ordinary and unsupported paths retain their previous postprocessing.
`Advisor/runtime.lua` wires the helper; `Advisor/player_journal.lua` records
bounded current-only retention diagnostics alongside acquisition/final reasons.

No score cap increased: ordinary **140,000**, shop **50,000**, consumable
**25,000**, fast clear **70**, and the separate Acorn ordering limit are unchanged.
No native DLL changed. General collection rerolls, free-slot generators, broader
earlier-Ante collection planning, and final-shop Heart/Acorn acquisition remain
outside this slice. Bell keeps its existing separate supported comparison.

## Component validation

Root's merged relevant regression passed **11 / 11 Lua fixtures** in
`development345/root_component/validation_final.json`; the log SHA256 is
`88fd4f255c68f4738c411afa8160a2a59dde1198cca1da9e764336e448d13812`.
These are manufactured local tests, not continuations of recorded gameplay.

The source/test/evidence map is:

- Raw constructor defaults: `pin_component/component_report.json`;
  `tests/advisor_gold_tarot_hold_pin.lua` and the production dependency fixture
  `tests/advisor_gold_acquisition_runtime.lua`.
- Unused Tarot scope: `tarot_scope_component/component_report.json`;
  `tests/advisor_gold_tarot_hold_scope.lua` (508 checks across the twenty added
  identities and guards).
- Canonical row identities: `row_component/component_report.json`;
  `tests/advisor_gold_tarot_rows.lua` (812 source-identity and mixed-offer checks).
- Cartomancer/final-shop boundary:
  `cartomancer_component/validation3.json` and
  `tests/advisor_gold_cartomancer.lua` (5,846 checks, including complete floor
  accounting and cooperative yielding).
- Retention: `retention_component/component_report.json`,
  `retention_component/budget_integration_report.json`, and
  `retention_runtime_component/validation1.json`;
  `tests/advisor_gold_retention.lua`, `advisor_gold_retention_budget.lua`, and
  `advisor_gold_retention_runtime.lua` verify paid continuations, remaining-budget
  accounting and actual production postprocessing.
- Existing acquisition and compact journal regressions remain in the merged
  eleven-fixture receipt. Earlier failed harness evidence is preserved separately.

Preserved mechanic references are the already-extracted
`runs/chicot_order_source1/source/card.lua` and
`source/functions/common_events.lua`, plus the preserved source key/name catalog.
No executable archive or live save/profile was read for these components.

## Exact freeze, authorized comparisons and release status

Frozen candidate: `runs/gold345_candidate/record.json`, policy digest
`57fb0ac87d621fc21ae1c3c3923f854bee5b64228c378249cbf2718e6c8d2bcb`,
**102 frozen product/dependency files**. Root must bind the final verification
record and installation to these exact bytes after all required checks.

Full candidate and exact-installed regressions both passed
**207 Lua fixtures / 361 Python tests**, with unchanged frozen policy and tests.
**2.145.0-alpha** was installed at
`2026-09-15T23:54:46.6483274-05:00`, with backup
`advisor-20260915-235445`. All **86 deployment files and 102 frozen policy files**
matched. Current settings and native DLLs were preserved.

The exact-installed report is `runs/gold345_installed_validation/report.json`,
SHA256 `bcecb5d0f684ec4096d312b1bf3cbda1bbb9910b95d173866fe68d66afa6a994`.
The final deployment-verification destination is
`runs/gold345_final/final_verification.json`; its exact hash is bound by the
checkpoint records when finalization writes it.
Activation of 2.145 has not been observed; the running game remains undisturbed
and normal user restart activates it.

The user separately authorized two recorded public shop comparisons, four
single-policy evaluations of at most thirty seconds each, **120 seconds total**.
Exact approval question and reply are preserved in
`development345/captured_validation/prepare_registration.py`.
Jobs are baseline/candidate for action2070 and exit2192. They use exact original
public JSON field bytes and actual passive player context, with no source game,
search, new run, save/profile read, action dispatch or live control.

The old snapshots explicitly contain unsupported source certificates for the
newly admitted Tarot classes. Those fields stay **unchanged**. A comparison can
therefore remain unsupported even though a newly captured manufactured raw card
passes the new constructor checks. Raw registry identity/parameters and positive
certificates must not be reconstructed or imputed. These are dependent
development inputs and partial admission-gate comparisons, not unseen holdouts.

All **four one-use jobs were consumed** after prospective registration. Each
completed its detached policy call with unchanged input and preserved full
results. Total reserved time was **120 seconds**; exact recorded actual time was
**2.3846720000728965 seconds**. There were no worker errors, timeouts,
interruptions or replacements. These completed executions still returned
unsupported collection comparisons; completion does not mean acquisition
succeeded.

| Public state | Baseline344 action | Candidate345 action | Actual score calls | Result |
| --- | --- | --- | ---: | --- |
| 2070, pre-Small | Open Celestial Pack, shop booster 2 | Same | 0 for each | Cartomancer has a free slot; both reject the owned-row comparison |
| 2192, pre-Leaf | Leave shop | Same | 0 for each | Candidate passes the full-inventory Cartomancer/row gate, then rejects the unchanged old unsupported Tarot certificates |

For 2192, baseline acquisition rejected its Small/Big-only scope; its separate
final-shop path rejected the eight-card Perkeo limit. Candidate's acquisition
path reaches the whole-inventory certificate guard instead. No positive
certificate was invented and no action improvement was demonstrated. The
pre-Small free-slot limitation remains an implementation gap independently of
the old certificate data.

The authoritative closure is `runs/gold345_captured_validation/CLOSED.json`,
SHA256 `247ee955cd462ac5e6ee3ed237b9a58bef8a007b2ff1841222e8557369cd00b2`.
Its four job directories preserve registrations, spent receipts, full results,
compact diagnostics, raw stdout/stderr and outer timing. This fresh allowance is
now **CLOSED**, with no unused capacity and no additional jobs authorized.
Historical allowances remain closed separately.

No complete attempt has demonstrated a new sticker, rescued run, higher win
rate or achievement completion from 345. Fixture counts, passing regressions,
admission changes and a selected purchase are not terminal outcome evidence.
