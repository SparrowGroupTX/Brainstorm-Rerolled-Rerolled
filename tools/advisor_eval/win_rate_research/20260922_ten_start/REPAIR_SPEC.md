# Proposed repair: complete affordable replacement comparison

Status: proposed, not implemented or released. WR-005, 2026-09-22.
Evidence priority: public affordable copy offers passed in two losing runs; source
confirms a generic-winner gate ahead of full replacement merit. A broader sequence
planner already exists but excludes inventories above4: run4 had7 at6505. Voucher
incumbents are also excluded. Exact historical endpoint rejections are absent.
Success cannot be claimed from this cohort.

## Acceptance behavior

For each visible, affordable, supported Joker offer and each eligible one-Joker
sale, compare the complete original row against the funded final row, retaining
inventory, Negative capacity, cash/interest/rental effects, legal ordering and
expiration. A generic voucher/pack winner must not hide a different replacement
endpoint. Choose among hold, ordinary purchase and complete replacement merits in
one arbitration. Unsupported or incomplete families remain explicitly labeled;
they cannot acquire invented score evidence or discard protected mechanics.

This does not guarantee buying a Blueprint: unaffordable, harmful, redundant,
unsupported or insufficiently supported replacements may still be rejected. It
does not force a copy when safe survival or other resources are more valuable.

## Concrete implementation scope

1. `shop_sequences.lua:suggest` already enumerates a broader graph. Preserve it.
   Add/reuse a narrowly bounded hold-inventory/one-sale/one-buy comparison where
   that broader graph is not admitted; do not raise its four-consumable bound or
   enumerate Tarot-use permutations. The complete inventory must still be valued
   and supported at both endpoints. No automatic expansion to unknown effects.
   `strategy.lua:best_shop_purchase`/`replacement_sale_plan`: separate candidate
   enumeration from generic best selection. Pass all eligible visible Joker
   endpoints into the existing final-merit calculation, not just one winner per sale.
   Avoid applying purchase cost or score adjustment twice. Do not reconstruct a
   vacant-slot scoring baseline; reuse original-row endpoint evidence.
2. `shop_scoring.lua:context:compare` and existing copy-order preparation: reuse
   complete common-world families and exact cached unchanged endpoints. Reserve a
   bounded replacement family within the existing50,000 shop cap, deterministically
   admitting only families that can finish. Preserve140,000/25,000/70/12 other caps.
   Do not claim all legal endpoints were compared when a bounded family was omitted.
3. Journal a bounded public receipt per visible offer/sale: candidate key/index,
   affordability/capacity/known-effect/admission reason; whether compared; family
   identifier, completion, evaluations and budget omission; final utility, cost,
   score evidence kind and arbitration reason. Include selected action and its
   advice/observation IDs. No hidden data, RNG or candidate world identities.
4. Keep one-action execution: sell only after an admitted final endpoint, wait for
   settlement, then refresh before buying. Preserve357 asynchronous shop protections.
   A receipt is not an authorization to enqueue stale follow-up actions.

## Cheapest falsifying checks before policy edits

Read-only source confirms the gate, but not its realized influence. Build a genuinely
manufactured small fixture, not a renamed captured row: give generic candidate A a
higher purchase rating than candidate B while B's supported full replacement endpoint
has higher final merit. Cover A as a voucher and as a different Joker. Observe whether
production arbitration ever evaluates B. If it already compares B elsewhere and
selects it correctly, refute this mechanism and stop that patch; inspect the recorded
candidate diagnostics next. No captured-state replay is authorized.

If manufacturing valid production comparisons cannot reproduce the omission, do not
substitute arbitrary mocked scores as evidence of a real policy improvement. Record
the distinction between an algorithmic counterexample and a gameplay fixture.

## Required manufactured acceptance fixtures

* More than four held consumables do not by themselves prevent the narrow
  replacement family; unsupported inventory effects still prevent certification.
  Confirm the broad graph retains its limits and completed existing comparisons
  are reused rather than duplicated.
* Competing voucher cannot suppress a supported beneficial copy replacement.
* Competing Joker with higher purchase rating but worse final row cannot hide the
  better endpoint; reversing shop order leaves the comparison/result deterministic.
* Additive-Mult positions and Blueprint/Brainstorm copy chains use actual legal
  layouts; permanent counters stay physical. Hold beats redundant overkill when
  costs outweigh benefit. Perishable candidate exclusion is retained.
* Eternal victims rejected; Negative sale does not falsely free an ordinary slot;
  Credit Card removal recomputes borrowing; rental liability and imminent expiration
  remain represented. No unsupported sale-trigger row is waved through.
* Whole Perkeo/Negative/Observatory inventory valued at both endpoints; selling a
  copy source cannot leave its old future utility behind. No generic pool-sale
  feature is added to this slice.
* Partial/uncertain worlds cannot become a supported floor. Low remaining budgets
  produce a receipt with explicit incomplete scope and never overspend or compare
  unequal families. No changes to unknown-mechanics safeguards.
* Sale settlement, refreshed purchase indices, missing/changed offers and occupied
  slots cannot cause duplicate buys or stale execution. Teacher objective propagation
  stays intact; normal collection admission continues to apply in its own profile.
* Recorder receipt round-trips under the journal/converter schema; capped summaries
  do not leak concealed data or obscure unsupported/error classifications.

## Dependencies, risks and later validation

Dependencies: current364 runtime, shop scoring/copy ordering, liquidity/resource
transitions, gold admission, player journal. Main risks are budget starvation,
double-counted utility, rental/interest underpricing and stale asynchronous execution.
Candidate telemetry is part of validating this comparison, not a separate broad
observability rewrite. A preserving teacher-start UI is a separate prerequisite for
any future no-purge study; it must not silently enter this policy slice.

After an explicitly authorized implementation: focused manufactured regression,
required independent review if release rules require it, then all current candidate
and exact-installed release gates with frozen provenance. Installation only through
`install_slice.py` with explicit files/backups/hash checks, preserving settings and
all seven DLLs. None of this is authorized to run during the present diagnosis audit.

Expected local effect: admitted complete replacement endpoints are no longer lost
behind generic purchase winners, and every visible rejected opportunity has an
auditable reason. Full-run benefit remains unvalidated until a separately authorized,
user-started frozen post-repair cohort. Do not automatically replay these ten seeds,
restart ten runs, or interpret passing fixtures as a win-rate improvement.
