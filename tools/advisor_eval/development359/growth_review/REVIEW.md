# Yorick / opening enhancement priority review 359

Read-only source and existing manufactured-test review on 2026-09-16. No captured
policy evaluation, scorer execution, game control, save access, source component,
search, simulation or training was performed. This note is a proposed repair,
not installed behavior or a terminal-outcome claim.

## Concrete integration issue

`Brainstorm/Advisor/decision.lua:278` calls `consumables.develop` before the safe
growth planner on an already-clearing hand. Line 284 calls `growth.suggest` only
when no consumable suggestion exists. Every fresh state repeats this priority.
Thus a sequence of positive Empress upgrades can prevent even considering an
otherwise qualified Yorick or first-discard Burnt investment. This is not a
comparison of the alternatives. The six-score enhancement and twelve-score
growth budgets are already declared beside each other at lines 274-276.

The optional enhancement may also change the later growth admission. In
`growth.lua:218-226`, a multi-card Mult clear requires a narrowly qualified
additive row; Lucky or Glass clears remain excluded because sorting or random
effects can change the proof. Using an enhancement before considering a safe
discard therefore can remove a previously available growth opportunity. This
does not license removing the sorting, uncertainty or held-card safeguards.

Smallest useful integration repair: compare safe growth before optional
known-clear development, or compute both inside the existing shared allowance
and prefer a qualified **discard** growth action to the optional enhancement.
Keep development as the fallback if no safe useful discard exists. Do not give
the unrelated Death cycling **play** unconditional precedence. Refresh after
each actual discard; do not queue a sequence or promise favorable draws.

This is a bounded ordering preference, not a proof that every discard is more
valuable than every enhancement. It should expose the chosen priority in
diagnostics and preserve the ordinary rescue path when no clear is proven.

## Why it may still clear with discards unused

- `growth.lua:472` requires an exact reliable clear at 105% of the remaining
  target, then rescoring retained physical cards after each transition at the
  same floor. This cannot intentionally discard the held winning combination
  and hope to redraw it. An eight-card hand with a five-card reserved Flush can
  offer at most three safe disposable cards, not five.
- Partial Yorick utility at line 567 is
  `80 * count / threshold * increment / current_X * min(1, horizon/6)`.
  The exact growth bonus is `15 * immediate_increments`; cash, interest, Blue /
  Gold resources and a fixed default action cost 4 are subtracted. With five
  ordinary free discards, threshold 23 and horizon 6, partial merit is
  `17.3913 / current_X - 4`: it becomes negative already at X5. This is an
  uncalibrated preference, not a learned estimate of the future win benefit.
- The two-discard threshold extension considers only a threshold crossed by the
  second action. Its strict plain finite-population proof admits normal Small /
  Big blinds, canonical cards, a narrow additive Joker row, sufficient remaining
  draws, all inventory preserved, and inert Burnt only after an agreed first
  discard. It cannot generalize to all rows, bosses, or three-plus-discard
  investment sequences.
- `profile.final` / zero horizon properly stops further investment at the final
  boss. Paid discards, valuable Blue / Gold, insufficient deck, unsupported
  discard effects, hidden identities and replacement hazards are separate
  reasons not to blindly exhaust every discard.
- The planner is only integrated in the known-clear shortcut here. Amber Acorn
  public-order belief still lacks a complete future discard comparison. That
  separate gap is already documented; changing this priority does not repair it.

Do not simply raise utility or force all discards. A later improvement could
compare a complete bounded multi-discard sequence or measure effective copied
Yorick gain, but it needs explicit supported common-world endpoints, full
resource/action costs, and fresh authorized outcome validation. Merely changing
the constant would not resolve the missing planning.

## Manufactured regression cases for the narrow priority repair

1. Production `Decision.run` with an exact 105%+ retained High Card, active
   immature Yorick, at least five plain spare cards and several Empress copies.
   Both individual modules would recommend actions; published action must be a
   five-card discard, retaining the complete inventory and unchanged input.
2. A fresh manufactured observation after a real modeled discard/refill still
   has a safe retained clear and remaining discards: it considers another useful
   discard rather than draining the Empress stock. Only one action is returned.
3. With zero discards or no useful safe growth candidate, supported Empress
   development remains available. With no active Yorick/Burnt, behavior remains
   the normal development route.
4. First-discard Burnt plus Yorick still considers its actual hand category and
   copy setup rather than spending Empress first. Preserve the existing complete
   phase-copy proofs and extra rearrangement-action costs.
5. Final boss, insufficient post-discard floor, paid-discard costs, Blue / Gold
   retention, Purple unsupported generation, forced/concealed draw hazards and
   oversized populations must retain their current rejection behavior.
6. Instrument the real scorer and verify exact reported calls, local 12 and 6
   limits, total fast-clear <=70, lower caller allowance, and no hidden RNG.

Relevant existing coverage: `tests/advisor_growth.lua`,
`tests/advisor_yorick_margin.lua`, `tests/advisor_yorick_pair.lua`,
`tests/advisor_burnt_pair_inert.lua`, `tests/advisor_weighted_growth.lua`,
`tests/advisor_surplus_development358.lua` and phase-copy fixtures. Existing
tests explicitly expect a mature distant Yorick to finish when action cost wins;
changing those expectations is a separate policy change, not this integration
repair.
