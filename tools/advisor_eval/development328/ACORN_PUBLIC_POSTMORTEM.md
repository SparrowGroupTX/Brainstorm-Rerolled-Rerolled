# Selected public run 5 postmortem

Scope: read-only analysis of `public_trace/run5.json` and its redacted public snapshots. No captured-state policy evaluation, original-source worker, seed search, save access or live game control. Raw internal fingerprint strings and concealed Joker ID joins were not used. This is selected dependent development evidence, not a representative cohort or a counterfactual terminal result.

## Observed chain

- Sequence 3559: bought a rental Sly Joker for $1 with $3 available after opening an Arcana pack. Its $3 end-of-round charge remained through the early economy. A cheap purchase is not a cheap retained Joker.
- Sequence 3629: left an offered $8 Burnt Joker with $9 available and an open slot. Advice reported that random scoring could not establish next-blind readiness. This documents a missed visible scaling opportunity; it does not establish that buying it would have survived.
- Sequence 3829: with $3 and a full row, sold Perkeo for $10 to fund the visible $10 Blueprint. Perkeo still had ordinary and Negative Mercury available to copy. The recorded comparison quoted paired opening means 2,342 to 7,027 against a 13,500 next-blind target, and explicitly lacked random-score readiness. This trade sacrificed continuing Planet generation; no unseen purchase or future win is inferred.
- Sequence 3956 onward: the system did sometimes rearrange copies and use all three full five-card discards. Growth was not wholly absent. Later immediate clears often left discards unused; whether particular alternatives retained a safe finish remains untested.
- Sequence 4333: cleared Ante 8 Big with an advised Pair of about 309,960, with Yorick at X6 by the next shop. Sequence 4349 selected Amber Acorn with Fortune Teller, rental Swashbuckler, Blueprint, Yorick and eternal Scary Face. Pair was level 7; no consumables were held.
- Sequence 4355 onward: every Joker is redacted and face down in all seven final-blind action records. The selected data contains no public Joker reveal. Advice nevertheless gives position-sensitive exact-looking scores. The final 98,808/400,000 threshold, zero remaining hands, GAME_OVER and explicit loss receipt agree on loss despite `won_field=true`.

## Concrete integration defects found in source

`strategy.lua` replacement row valuation includes Joker ratings, current scaling, and synergies, but omits the existing whole-inventory Perkeo/Observatory value. Thus a proposed sale can lose a real held copying source without that resource loss entering its full-row utility comparison. The existing inventory valuation is bounded and heuristic; integrating it would not establish a rescued run or win probability.

`concealed_belief.has_hidden` tests playing cards but not concealed Jokers. A visible hand during Acorn can therefore enter ordinary `Scoring.score`, whose copy resolver uses the raw internal Joker row. `ordering.lua` correctly refuses concealed/Acorn reorder advice, so ordinary play scoring and order recommendations currently use inconsistent information scopes. Hidden slot IDs must not be joined to pre-blind identities to bypass the concealment.

## Required bounds on a future Acorn planner

The pre-blind public inventory can support a set of possible orders, not the actual hidden assignment. Complete comparisons must choose one fixed action across those possible orders, with every world within the existing ordinary score cap. Publicly observed exact scoring could narrow that set only if all relevant transitions and random outcomes are modeled; no candidate may be discarded merely because its hidden identity is inconvenient. A robust reorder must work over all remaining assignments. An immediate permutation comparison alone neither recovers the true order nor proves the remaining blind can be cleared.

No source experiment or captured-state policy comparison was run for this note. No counterfactual score or win is claimed.
