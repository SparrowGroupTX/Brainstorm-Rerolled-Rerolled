# Offline decision evidence and alternatives

Run from the repository root on an explicitly copied BRJ2 journal and its hash
manifest. The output directory must be new:

```powershell
python -B tools/advisor_eval/review_decisions.py --copy-dir tools/advisor_eval/development440/install/captures/001/logs --manifest tools/advisor_eval/development440/install/captures/001/manifest.json --output tools/advisor_eval/my_new_review --max-packets 96 --sample-size 16
```

The tool does not discover live journals, execute policy/scoring, simulate games,
read saves, install code or dispatch alternatives. An exported challenge is a
specification for a later bounded investigation, not experimental authorization.
Existing closed experiment budgets stay closed.

## Read the output

Only trust a directory containing `COMPLETE.json`, whose hashes bind the four
outputs. An integrity failure produces `error.json`, not a trusted review. Inputs
are read twice and hash/causal verified; packets are buffered until both pass.

* `REPORT.md`: the review queue, confidence and next discriminating test.
* `report.json`: exact observation/advice/request/settlement anchors, public state,
  selected action, recorded reasons, confidence, severity, alternative subsets and
  explicit coverage/omission counts.
* `adjudication.json`: editable diagnosis ledger. Record the first demonstrated
  failing stage, competing alternative, falsifier, independent expected behavior,
  negative controls, holdout cases and loaded follow-up before calling a fix done.
* `challenge_queue.json`: bounded previews and investigation requirements. Full
  enumerated selections remain in report.json. Nothing in this file executes.

## Confidence and proof scope

`established_receipt_inconsistency` means linked records contradict each other:
for example, a final-action receipt reports discard but the current advised,
requested and settled action is play. It establishes a recording/pipeline defect,
not that playing was strategically inferior.

`recorded_alternative_signal` means the policy reports qualified five-card
candidates but chose fewer cards or played. Candidate physical identities,
complete worlds and final overrides still need inspection. A count is not a
survival certificate. Other flags remain review hypotheses, including higher
recorded Joker merit. The tool does not rank whole-game strategies from scalar
merit or opening score.

`first_unresolved_stage` is the earliest evidence gap for proving an alternative
better. It is not the first demonstrated bug. An admission exception is evidence
to test; it may be an appropriate survival/resource safeguard.

## Discard alternatives

For hand decisions with positive discards, stable distinct public physical IDs,
an explicit selection limit and known forced-selection metadata, the tool
enumerates every subset satisfying those structural constraints. It includes
every forced card, selects at most five/observed limit, and does not silently
exclude enhanced/sealed/Death-source cards. Those receive resource annotations.

When the original action played cards, it also computes the maximum discard size
that retains all those physical cards. That maximum is exact ONLY within the
specified selection problem. Retaining the cards does not prove retaining their
score: sorting, Bell, held effects, draw effects, destruction, cash costs and
future play can matter. No proposed discard is called safe or game-optimal.

Public unknown cards keep their unknown identity. If redaction removed the forced
selection constraint, the enumeration refuses rather than assuming it is false.
The solver supports at most12 held cards,2048 subsets per packet and32768 subsets
per report. Combination counts are checked before enumeration. A capped case has
no partial optimum; it remains in the report with a specific missing capability.

## Coverage and blind spots

Default:96 packets, including16 deterministic unflagged samples. Hard maxima:
128packets,32samples,256retained legacy flags and32receipt-inconsistency examples.
All legacy rule hits are counted even when ranked out. The second verified pass
selects the lowest SHA256 identities from decisions with NO legacy rule hit, so
capped-away or delayed flags cannot contaminate the unflagged population.

The inherited settlement recognizer covers discards, clearing plays, Joker
acquisitions/sales, voucher purchases and selected shop/pack closures. It does NOT
cover every ordinary non-clearing play, consumable use or pack opening. Denominators,
unsupported classes, stale/missing-link counts, tail actions, omitted packets and
enumeration coverage are reported. The sample is representative of this declared
eligible population under its deterministic selection rule, not of all decisions.

Review one representative per context family, then corroborate recurrence. A
confirmed root cause requires the complete causal chain. Do not infer a losing
purchase from a later missed Blueprint without evaluating the earlier survival
tradeoff using only information available at the purchase.

## Acceptance of a repair

Keep the minimal reproducer, independent expectation, nearby negative cases,
frozen comparison, untouched validation cases and a loaded follow-up measurement
together. Separate mechanics confidence from strategy confidence. A shared bug
in production and simulator is not independent confirmation. Full release gates
remain mandatory for runtime edits; offline-tool tests do not qualify a runtime
release. The former 2.219 timeout was resolved and its exact full gates passed
in INSTALLED_CHECKPOINT_444.md; consult current checkpoints for release status.
