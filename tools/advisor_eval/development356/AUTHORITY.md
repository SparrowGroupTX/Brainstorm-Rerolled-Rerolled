# Teacher collection 356 — prospective product scope

User request: prepare real-game demonstrations using the advisor, with public
future-blind information, then auto-run ten matches. Clear previous observation
logs, log state changes and bounded inactivity warnings, and replace stalled or
unsupported runs after thirty seconds when safe. The user subsequently reported
a computer crash; saved work was checked and interrupted reviews resumed.

This release prepares an explicit product control, **Clear logs + collect 10
win-first runs**. No live game is launched, restarted, foregrounded, controlled
or played by development tools. Activation uses the user's normal game restart.
The click clears only the journal's own observation files, closes its writer,
resets accounting, and starts one bounded in-memory session. Repository evidence,
saves, profiles, checkpoints, retry journals and unrelated files are excluded.

Each session permits at most ten actual run starts, including abandoned runs;
each has at most 500 actions and 1,800 seconds, with a 21,600-second session cap.
Each owned opening search has a 30-second outer limit; the existing native search
uses at most 27 seconds within it. Thus ten successful launches can reserve at
most 300 search seconds and 18,000 play seconds. A failed search stops the session;
it is not silently renewed. Stop/Resume retains counts and time allowances.
Search uses Red Deck / Gold Stake, Yorick + Perkeo opening, interchangeable copy
Joker by Ante 5, optional Burnt fallback, no missing-Joker quota, no substitution
of a different Legendary. Offers do not guarantee acquisition or survival.

The teacher objective is Ante-8 victory. Public sticker history remains in the
records, but optional missing-sticker trades and generic pace skips are disabled
for this pilot. The opening's prescribed Charm skip remains. Existing survival,
whole-inventory, growth and scoring safeguards remain. No superiority, calibrated
win probability, successful demonstration or measured gain is assumed.

No new detached/source/captured-state/complete simulated attempts, GPU training,
hidden native searches or package installations are requested by this release.
All historical allowances, including 355, remain closed. Routine manufactured
fixtures, full regressions and read-only source analysis are used for development.

At preparation: zero product searches, zero real matches and zero log deletions
were executed by tools. This is a prospective user-started pilot, not a completed
evaluation or an unseen holdout cohort. Subsequent actual records, failures,
abandonments, manual intervention and checkpoint provenance must remain separate.
