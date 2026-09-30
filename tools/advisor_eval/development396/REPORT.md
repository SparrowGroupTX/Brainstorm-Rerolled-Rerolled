# Loaded-label 2.191 ten-start diagnosis and 2.192 repair — 2026-09-26

`capture/manifest.json` and `capture/verification.json` bind all 27 copied
BRJ2 segments of `session-20260926T035918Z-1`: 56,712,597 bytes and
24,635 consecutive events. There are exactly ten starts and ten endings:
**four verified wins, five verified losses, one nonterminal unsupported
retirement**, no error or timeout. The operational yield is 4/10 starts;
the nine terminal games contain four wins and five losses. All ten owned
searches found the requested conditional opening on ten distinct recorded
seeds. Public observations report `Brainstorm v2.191.0-alpha` 21,766 times
and win-first `perkeo_yorick_win_v1` 3,643 times. Those labels do not attest
exact loaded bytes or establish a population win rate. The earlier separate
loaded-label-2.191 cohort in `../development395/` had 3 wins/7 losses; the
two small selected cohorts cannot identify an improvement trend.

| Start | Result | Furthest ante | Last material observation |
| --- | --- | ---: | --- |
| 1 | Loss | 8 | Amber Acorn, 102,610/400,000, three discards left. |
| 2 | Win | 9 | Verdant Leaf cleared at 533,000/400,000. |
| 3 | Win | 9 | Verdant Leaf cleared at 498,560/400,000. |
| 4 | Loss | 6 | The Needle, 46,176/60,000, no discards left. |
| 5 | Unsupported | 8 | Amber Acorn, 112,651/400,000, four hands and four discards left. |
| 6 | Win | 9 | Cerulean Bell cleared at 404,860/400,000. |
| 7 | Loss | 7 | Big Blind, 52,470/165,000, no discards left. |
| 8 | Loss | 4 | The Wheel, 9,924/18,000, three discards left. |
| 9 | Loss | 5 | The Wheel, 27,414/50,000, three discards left. |
| 10 | Win | 9 | Cerulean Bell cleared at 409,590/400,000. |

The strongest reproduced defect is start 5's **Acorn hard stop**. Public
pre-shuffle observation 13553 shows Yorick, Perkeo, Bull, Brainstorm and
Scholar. Advice/action 13567/13570 made a supported fixed play; visible Joker
events 13575–13581 confirmed completion. Advice 13585 then had zero score
evaluations and said `Current public inventory abilities are not qualified`;
13586–13588 retired the run as unsupported without a terminal game result.
`acorn_belief.lua:advance_public` invalidated the entire known inventory
because Bull and Scholar had no qualified fixed-ability transition. It did
not need to read a concealed Joker identity. Candidate 2.192 admits only
their exact base-game ability shapes after observed play/discard, still
retaining every possible public order and declining modified shapes. The
manufactured five-Joker fixture confirms complete 120-world advice after
play and discard, fresh-cash Bull and fresh-Ace Scholar scoring, and fail-
closed mutations. This is a local source repair; start 5 was not replayed or
rescued.

Two Wheel losses expose other concealed-action gaps. Start 8's actions
20295, 20307, 20318 and 20329 repeatedly fell back to immediate plays;
advice explicitly named `Hidden discarded identities have unmodeled
observation history from Faceless Joker`. Its three remaining discards are
not proof that a particular discard would have cleared. Reassigning those
hidden discarded identities would condition on information the player did
not observe, so the guard remains. Start 9's first fully visible hand used
ordinary search; after a Lucky-involved play, actions 21903 and 21914
reported `A future play transition is unsupported: uncertain score or
growth`, then lost with three discards. This is consistent with the source's
owned-Joker Lucky transition exclusion, though the public record does not
identify the exact failing sampled effect. Candidate 2.192 supplies an
opt-in, no-trigger Lucky floor for the concealed continuation only. It
rejects mandatory triggers, Tax hand-size interaction and nonmonotone cash/
Lucky-Cat growth. The independent fixture finds a discard over a play in a
complete four-world comparison; it does not assert that start 9 would have
discarded or won.

The earlier loaded-2.184 Wheel start 10 in `../development394/` also showed
four hidden hand slots and a possible Purple Seal blocking every first-
discard continuation. Candidate 2.192 compares a fixed visible non-Purple
first-discard family across complete common worlds when a generated Purple
Tarot would lack a supported identity. Full consumable inventory and no-
Purple controls keep the ordinary family. It does not silently assign a
Tarot or invent hidden draws.

Start 1's Acorn loss is a separate immediate-only planning limitation:
action 3371 still chose a fixed play with three discards left because public
Joker-order advice does not plan future discards. Starts 4 and 7 instead
exhausted discards by their terminal hands. Large cash/stock remains worth
qualification: start 3 won while holding $336; start 5 had $82 and sixteen
Fools when it stopped; start 7 lost with eight Fools. Those counts do not
prove a profitable available purchase, use, sale or a rescued outcome.
`analysis/{cohort,lifecycle,searches,actions,loss_decisions}.json` preserves
compact passive extracts with sequence/hash anchors; original evidence is
unchanged in `logs1/` and `capture/`.

Release 2.192 changes exactly six runtime paths listed in
`runs/concealed396_candidate/freeze.json`. Candidate and exact-installed
gates passed 262 Lua fixtures and 392 Python tests with unchanged frozen
policy/test hashes. Exact installation and backup are recorded in
`runs/concealed396_installed/record.json` and
`runs/concealed396_final/final_verification.json`. The user's current
configuration and all seven native DLLs were preserved. Installation does
not prove activation or improved full-run yield; a normal user restart and
later passive public observations are needed. No captured-state policy/
scorer replay, game-process control, save/profile access, native search or
training was performed by tools during this work.
