# One-use original-source probe 454

The user said “Go for it!” after the proposed next step and its source-execution
boundary was explained. This registration fixes the exact job before execution;
the older experiment leases remain closed. The job is a single isolated Lua
source probe, not a game launch, episode, seed search, policy run or training.

## Hypothesis and falsifier

For the seven manufactured ordinary-edition Golden/Joker fixtures in
`fixtures.json`, the actual original `Card` methods, source end-round row loop,
original queued `ease_dollars`, and original `evaluate_round` should produce
the source-derived settled rental cash, Perishable/debuff state, Joker bonus and
interest shown by the repaired candidate. Any differing field, missing case,
unexpected callback, queue count, timeout or source error falsifies this
bounded claim. It does not establish full frame timing, payout action, blind
refresh, shop, RNG or uninterrupted sequence parity.

## Inputs and provenance

- Cases: exactly seven IDs in `fixtures.json`; no random seeds, hidden deck
  order, player profile or save input. Synthetic ordinary Jokers only, with
  zero blind reward and zero unused-hand income.
- Source: `Balatro.exe` read as ZIP, SHA-256
  `0d75fe164accf3312734d4b37ac98788dd15f0b8e4f9bb8b7f90c4e59de93f47`.
  Member hashes: `card.lua`
  `5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453`,
  `functions/common_events.lua`
  `522ea0810101de1004685e13e7ed05a750b4e115e5231dca2cbc97aeb8c3e5fc`,
  `functions/state_events.lua`
  `6c86aefb42d0323d737f87aaa84f53e42b755e72cd0bfd163b7d9cca5c0a99a9`.
- Runtime: `lua51.dll` SHA-256
  `d0039528d0c48acf9e4b93e39f929ecd8def2b08c429971b809d8751aae49fb2`.
  No game process or real profile is used. Installed advisor451/2.226 remains
  unchanged; the Python candidate is the development454 overlay.
- The exact fixture, candidate, reference, test, probe, runner and prepared
  Lua hashes are in `SOURCE_PROBE_PREPARED.json`. Dependency drift stops before
  the worker. `--check-only` verified the prepared bytes without invoking Lua.

## Caps and accounting

- One worker, one Lua state, seven deterministic cases. At most seven
  round-end loops, seven cash-out evaluations and eleven Joker callbacks.
- Worker wall time 20 seconds; coordinator target 30 seconds. One
  single-threaded Lua worker, Python thread environments set to one; no GPU.
  There is no hard OS CPU-affinity quota.
- Attempt artifacts capped at 1,048,576 bytes. The prepared 117,701-byte Lua
  source is frozen outside the attempt directory. Output exceeding the cap is
  explicitly classified and truncated at the recorded boundary.
- Only `source_attempt_001` may run. The runner creates that directory with
  `exist_ok=False` and writes a consumed lease before starting the worker.
  No automatic retry, renamed-directory renewal, fallback episode or extra
  worker. It preserves stdout/stderr, all case comparisons and failure status.
- Stop on mismatch, missing case, timeout, source error or artifact cap. An
  unsupported or incomplete result is not a win/loss or parity pass.

The probe executes the original row loop and source methods, but sets the blind
to `nil` during expiry to exclude queued blind refresh, then uses an inert
blind for `evaluate_round`. It flushes original queued rental events before
evaluation. It reads the original evaluation rows; it does not press or
execute the cash-out payment action. Those exclusions remain visible even on
a passing result.
