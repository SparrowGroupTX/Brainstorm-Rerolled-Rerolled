# Completionist++ advisor guide

Completionist++ requires a recorded Gold Stake win with each of the 150 vanilla
Jokers. The advisor can track what remains and explain when an action buys or
sells a missing Joker. Holding a Joker is an opportunity to earn its sticker;
only the game records completion after a qualifying win.
Keep each target in your Joker row when that win is recorded; buying it earlier
and selling it before the win does not earn its sticker.

## Start using it

1. After your normal game restart activates the installed update, open the
   **Brainstorm** menu and select **Completionist++**.
2. Click **Enable Completionist++**. This enables normal-deck advice and Gold
   tracking. Your HUD and unrelated settings remain unchanged. Tracking is off
   until you opt in; **Track Gold stickers** can turn it off again.
3. Start a normal **Gold Stake** run without manually entering a seed. Challenge
   runs, manually seeded runs and acquisitions made after that run's first win
   do not provide a new qualifying sticker win.
4. Read the advisor, then click **Execute** yourself when you accept its action.
   After a purchase, sale or other action, wait for fresh advice. A displayed
   multi-action endpoint describes the comparison; Execute takes one step.

The advisor does not start runs, click Execute, load checkpoints or change
collection records. Existing seed searches also begin only through your own
search controls. A found offer is not an acquired Joker or a won run.

## Reading progress

The page shows recorded Gold wins, known missing stickers and unknown records
separately. `*` marks a distinct missing Joker currently held; `?` marks unknown
history. Duplicate copies of one Joker count as one sticker opportunity.
Debuffed or Negative copies remain physical Jokers, but do not add a second
target for that identity.

Tracking reads the active profile's already-loaded history. Missing or malformed
metadata is not treated as zero progress. Unsupported stake catalogs, held
Jokers or run contexts disable collection planning while preserving whatever
progress can be stated. Switching profiles or newly recording a sticker makes
old advice stale before Execute can use it.

## Release scope

- **Installed 293–294:** normal-deck availability, opt-in tracking, remaining
  Joker pages and acquisition/sale disclosures. Tracking alone does not change
  tactical rankings. The running game's loaded version is not confirmed.
- **Installed 295:** a bounded shop comparison immediately
  before **Violet Vessel** or **Verdant Leaf**. It can buy a missing Joker or
  retain one an otherwise equivalent plan would sell. It compares holding the
  row, the current recommendation and every admitted one-buy/one-sale endpoint.
  Other final bosses and unsupported Joker effects retain ordinary advice.
- **Installed 296:** a known missing-Joker selector for the existing user-clicked
  normal opening search. Activation waits for your normal game restart.

The 295 comparison requires four supported paired opening samples, each at
least 25% above the known boss target and no weaker than either reference. It
includes actual purchase/sale cash, inventory and liquidity guards. These are
composition samples, not a win probability or a complete-blind guarantee.

## Find a missing Joker

From **Brainstorm > Completionist++**, click **Find a missing Joker** to open
**Gold search**. Cycle through known missing identities, then click **Prepare
target search** for a supported target. Unknown history receives no target
credit. Preparing filters does not start a search; use the normal search
controls yourself when ready.

The existing normal search assumes all profile unlocks. Gold-win history does
not verify those unlock flags, so a prepared filter is not proof that the
predicted offer will appear on your profile. Preparation does not change your
deck, stake or seeded-run restrictions. Select a normal Gold Stake run yourself;
this feature does not make manually entered seeds eligible for stickers.

Follow the route displayed for the selected target:

- **Early route:** play Small and Big without skips or shop rerolls until the
  target is found. Inspect their shops and Buffoon packs; avoid other Joker
  acquisitions and Joker-generating cards until the searched Joker.
- **Legendary Soul route:** take the opening Charm Tag and use its Soul.
- **Stone Joker:** direct search cannot model its Stone Card prerequisite.
  **Prepare Marble prerequisite only** searches for Marble Joker instead.
  Buy Marble and select a blind to add a Stone Card; find Stone Joker separately
  during play. This neither searches for nor guarantees Stone Joker.

**Restore previous search filters** returns the saved filters. This shares the
existing **Collection** page's backup; repeated preparation does not overwrite
that original backup. Finding an offer still leaves acquisition, survival and
retention through the winning boss to be achieved.

## What remains to improve

The system still needs broader boss and Joker-retention support, stronger
integration of survival with acquisition and later retention, and evaluation of
search cost versus simply starting another run. Four opening samples do not
cover the full draw distribution or prove a good strategy for earlier shops.
The 295 margin is an uncalibrated guard, not a measured confidence interval.

No Completionist++ time reduction, completion rate or superiority to a good
human player has been measured. Meaningful calibration needs separately
registered unseen runs that retain losses, errors and timeouts, and measure
total real time including search, failed attempts, computation and user actions.
Passing fixtures establishes supported behavior; it does not establish wins.
