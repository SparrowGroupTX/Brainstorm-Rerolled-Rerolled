# External research and mechanics ledger — accessed2026-09-22

Questions came from the observed copy-acquisition failures, unused consumables,
and discarded-versus-retained resources. Eight targeted search queries were used;
no more searches authorized in this pass. Six distinct source URLs were attempted.
Read accounting conservatively charges10/12 slots, including indexed excerpts,
unsuccessful opens and full-page revisits. Research is closed; unused allowance
is not a new study or experiment authorization. Only two full external sources
were accessible and substantively read. No video was watched or represented as read.

Queries: Reddit early Perkeo/Observatory Gold; balatro.wiki Perkeo/Yorick/Observatory;
Balatro University Gold Ante8; Reddit DrSpectred Gold discards; Balatro wiki
Perkeo/Yorick; Perkeo wiki random Negative; Balatro University strategy economy
guide; Fandom Observatory1.5. Unrelated search results were not substituted for
inaccessible sources. No tools were downloaded and no external instructions run.

## S1 — early Perkeo survival and economy

URL: https://www.reddit.com/r/balatro/comments/1ix0iuu/how_do_i_convert_an_early_perkeo_to_a_guaranteed/

Title: “How do I convert an early perkeo to a guaranteed win?” OP Undying_Shadow057,
2025-02-24; relevant replies by LordMarcel, PreviousAmphibian407 and Lyrics2Songs.
Game patch unspecified. Full discussion read. This is anecdote/reasoned strategy,
not measured Gold-Stake win-rate evidence or mechanics authority.

Useful claim: before Ante8, stabilize current scoring; copy useful planets/deck
fixing or Hermit/Temperance for economic flexibility rather than rely on finding
Observatory. Conditions: currently useful target, a funded survival plan, enough
remaining shops. Prediction for WR-002/005: affordable high-impact offers should
not be passed solely to accumulate unusable copies/cash. Counterexample in our
cohort: strong inventory waste exists in winners, and a rental purchase can worsen
cash risk. Do not conclude that every copy should be sold or every planet retained.

## S2 — Perkeo community wiki mechanics

URL: https://balatrogame.fandom.com/wiki/Perkeo

Title: Perkeo, Balatro Wiki; community authors, undated/version unspecified.
Direct page failed with402; only indexed excerpt was accessible. It describes
one random held consumable copied Negative on leaving shop. This is a rules claim,
verified independently against local source below. It predicts held low-value and
Negative cards both affect copying probability (WR-002). No full-page strategy
claim is attributed to an unread page.

## S3 — original written Gold-Stake strategy

URL: https://mancunion.com/2025/09/01/a-guide-to-gold-stake-balatro/

Title: “A guide to Gold Stake Balatro”; Adam Whiteley,2025-09-01; full article read,
especially Red Deck and comparative hand consistency/economy sections. Patch
unspecified. Author's own reported experience, not a controlled benchmark.

Useful claim: Red Deck's extra discard can improve hand quality, and deck fixing
should support the chosen hand. Prediction: early discards should yield playable
hands or useful growth, not merely raise counters; hand-level investment without
draw support can fail (WR-001/002). Counterexample to the author's strong Yorick
optimism: six cohort losses despite Yorick, including x10. We do not adopt a forced
five-card-hand strategy or treat the author's confidence as win-rate evidence.

## Inaccessible sources / no substituted claims

* https://balatrogame.fandom.com/wiki/Observatory — full page inaccessible;
  mechanics verified locally, not attributed to a read wiki article.
* https://balatro.wiki/Perkeo — inaccessible; no substantive claim used.
* https://steamcommunity.com/sharedfiles/filedetails/?id=3197193231&l=english —
  inaccessible original guide; no claim of reviewing it.

Balatro University searches did not produce an accessible reviewed explanation
within this pass. No video title was treated as evidence. S3 supplies an actual
original written strategy explanation; its limitations are explicit.

## Installed/preserved mechanics verification

`mechanics_reference.json`: read-only ZIP inspection of installed Balatro.exe,
never executed. `globals.lua` reports1.0.1o-FULL. Installed `card.lua` SHA256
`5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`
matches previously preserved `runs/diagnostic287_20260913_222344/b_preparation2/source/card.lua`.

* `Card:calculate_joker`, card.lua2412–2424: at shop end Perkeo chooses from
  `G.consumeables.cards`, copies the chosen card and sets Negative. No exclusion
  of existing Negative copies. The queued next copy can see the enlarged pool;
  the advisor's bounded inventory model already accounts for this. There is no
  user-selected source to assume. Rule verified; usefulness of selling is inference.
* card.lua2293–2301: an active matching Planet under Observatory contributes its
  configured Xmult. game.lua614 configures extra1.5. This supports the user's
  mechanics statement, not an unconditional always-hold policy.
* card.lua2788–2802: Yorick increments on physical discarded cards, with copying
  excluded from the physical counter update. Copying his score multiplier and
  copying physical discard growth are different. Current snapshot counters use
 23-card thresholds. More copied physical growth must not be invented.

These are installed base-game mechanics plus inspected frozen advisor logic.
Public logs do not cryptographically attest every loaded third-party modification.
No save/profile file or hidden RNG/identity was read, and no source was executed.
