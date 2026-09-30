# Journal work reuse architecture — 335

Finalized session, component and exact-installed receipts own release status.
This navigation grants no experiment authority.

| Layer | Source and boundary |
| --- | --- |
| Callback request details | `player_journal.lua`: collect selected indices and input fields only when recording is enabled, unsuppressed and not already failed. Invocation/return/error handling remains identical. |
| Public advice status | `player_journal.lua`: a missing key or different game proves advice is not current; otherwise retain a full fresh fingerprint. Every complete observation still captures and detaches its snapshot. |
| Hook lifetime | `callback_hooks.lua` and `acorn_public_hooks.lua` retain333 cooperative ancestry, replacement and nested-callback behavior. |
| Runtime/autoplay safety | `runtime.lua` and `Core/auto_run_product.lua` keep all existing fresh capture, publication and dispatch gates. No cross-frame cache is introduced. |
| Archive and timing | Event structure, clock rules, append verification, archive storage and timing collectors remain unchanged; metrics count the work actually executed. |
| Manufactured differential test | `tests/advisor_journal_reuse.lua`:236 checks, exact event-byte equivalence and work counts across recorder/advice states and callback lifecycle changes. |
| Frozen test dependency | `tests/fixtures/journal_reuse335/player_journal334.lua` and `hashes.lua`, included in full test/dependency hashes without joining the runnable fixture glob. |
| Component evidence | `development335/runtime_component/validation.json`:five fixtures,443 checks; nine detail collections and sixteen fingerprints avoided in manufactured cases. |

Component: `JOURNAL_UNUSED_WORK_335.md`. Full release evidence uses the
`runs/journal335_*` prefix. No new runtime module, source adapter or native build
is introduced; the deployment/product inventory remains83/99 files.

Separate scoring, inventory and economy audits are not part of this release.
Earlier candidate grouping and observation architecture remain in
`ARCHITECTURE_MAP_334.md` and `ARCHITECTURE_MAP_333.md`; read relevant sections
only. Their receipts remain preserved and grant no renewed experiment quota.
