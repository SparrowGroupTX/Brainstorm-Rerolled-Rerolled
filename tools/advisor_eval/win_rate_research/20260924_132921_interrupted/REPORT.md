# Interrupted 2026-09-24 teacher marathon: Amber Acorn and retirement

This is a frozen, passive public-log audit of one user-started Red Deck / Gold
Stake searched Yorick + Perkeo, `perkeo_yorick_win_v1` session. The journal
label is **loaded 2.175.0-alpha**; installed 2.177 and the then-uninstalled
2.178 repository candidate are separate states. A public version string does
not attest loaded bytes. The Acorn/controller source hashes in release 376
(2.175) and release 378 (2.177) match.

`capture/manifest.json` binds 15 unchanged BRJ2 segments (32,141,558 bytes),
13,931 contiguous records, no decoding gaps/errors, and the cutoff
2026-09-24T14:07:45Z / sequence 13,931. `capture/frozen/` preserves original
bytes; `capture/events.jsonl` and `capture/summary.json` are detached public
extracts. No save/profile data, hidden Joker identity, future draw, captured
policy/scorer evaluation, original-source execution or tool-controlled game
action was used. Balatro was no longer running when the source files were
frozen; the user said they would exit after seeing the stall.

Six of the requested ten **starts** occurred, all on distinct searched seeds:

| Start | Seed | Observed status |
| --- | --- | --- |
| 1 | 86DQSAXV | Verified win, sequence 2,296 |
| 2 | FQ7ZJDXV | Verified loss, sequence 3,585 |
| 3 | OK5W2MXV | Unsupported Amber Acorn retirement, sequence 6,153 |
| 4 | 4I8LRMXV | Verified win, sequence 8,838 |
| 5 | RLZ6C2YV | Unsupported Amber Acorn retirement, sequence 11,480 |
| 6 | FQKJL4YV | Nonterminal controller-error stop, sequences 13,930–13,931 |

Operational yield was two wins / six starts, with one loss, two unsupported
retirements and one incomplete error stop. There are no observed seventh
through tenth starts or terminal outcomes for runs 3, 5 or 6. Neither this
selected prefix nor older batches calibrate the policy's win rate.

All three Acorn entries had a complete initial public order belief and an
accepted conservative play. The next public ability transition failed with
`Current public inventory abilities are not qualified`, leaving advice
unavailable. Public pre-hide rows and first invalidation are anchored at:

| Run | Public pre-hide row | First unavailable advice | Complete worlds |
| --- | --- | --- | --- |
| 3 | 6,121: Perkeo, Yorick, Brainstorm, Raised Fist, Devious Joker | 6,150 | 120 |
| 5 | 11,442: Blueprint, Perkeo, Yorick, Greedy Joker, Card Sharp | 11,477 | 120 |
| 6 | 13,890: Banner, Odd Todd, Blueprint, Perkeo, Yorick, Joker | 13,928 | 720 |

Run 6's first Acorn observation was 13,900; advice 13,904 recommended a
visible two-card play with a 3,864 minimum across all 720 worlds. The play
settled at 13,924, and observation 13,925 still redacted all six Joker
identities. This is a post-action ability-qualification gap, **not** the older
seven-Joker/5,040-world cap. `acorn_belief.lua:advance_public` required
`own_signatures` for every remembered card; those four public base Jokers had
no qualified popup signature. Their effects read current hand, discards or
hand-play history without changing their own ability on ordinary play/discard.
Static installed-game source anchors: `game.lua` lines 390, 397, 409, 433
(SHA256 `bbc67bd3fbadd1ea3f3f0aba07ef8596118d89ff1e9758718f9e17c07a96e912`);
`card.lua` lines 3206–3215, 3320–3339, 3707–3711, 4040–4044
(SHA256 `5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`).
Their actual public captured ability shapes are in the linked observation
rows. This source analysis supports ability stability, not any claim that
those first plays would eventually win.

At 13,929 the controller successfully logged an unsupported-retirement
request. Its pending action fingerprint had a projected byte length of
**264,638**, above the controller's 262,144-byte generic clone bound. The
next `auto_run.lua:maybe_abandon` expression copied the raw full context
*before* entering `pcall(cb.abandon_run,...)`, triggering `Controller data
must be plain finite values.` The session stopped at 13,930 and the recorder
ended at 13,931. Runs 3 and 5 had 202,727- and 170,066-byte pending keys and
retired normally. The product retirement callback only uses run identity,
run number, outcome, elapsed seconds and action count; the full projected
request is already journaled. This is a separate copy-bound hole from the
release 348 pre-projection log repair.

The repository repair admits only source-verified static ability shapes for
Raised Fist, Banner, Odd Todd and Card Sharp across observed play/discard.
Their hidden-slot popup effects remain wildcards; unknown ability fields,
other Jokers and unsupported actions still invalidate. The second repair
sends a fresh scalar-only callback context after the full projected log.
Manufactured fixtures check five/six Joker complete worlds, bounded 720-world
post-play advice, one physical Yorick transition, unknown-shape refusal,
one verified retirement with a >262,144-byte exact key, and no duplicate
execution. This is a defect-class correction; real-game continuation and
full-run yield remain unvalidated until a later user-started run.
