# Source-shaped Certificate front capture —310

309's public registry guard required `id` and `nominal` on each loaded front.
Original Card:set_base reads the front's suit/value and derives those two fields
on the constructed card. Requiring them on the raw definition could make the
Certificate comparison unavailable despite a complete ordinary front registry.

The capture normalizer now derives rank and nominal from the13 exact source
value spellings. It still requires exactly52 distinct canonical suit/rank pairs,
an ordinary c_base center, no mod markers and no conflicting optional id/nominal
metadata. Unknown values and malformed definitions remain unsupported. It does
not fill in a missing registry, mutate loaded definitions or read saves.

Source evidence is the preserved full card.lua under
runs/planet_pool_source1/source/card.lua, SHA256
5073d834e08119da9516f1795a8c3d93110669aeb409c29ad1b308e0eb0be453.
Its hash matches the original card member recorded by active-cycle M16.
The relevant complete Card:set_base method starts at line97; no new executable
ZIP inspection or source execution was required for this read-only analysis.

Changed runtime: Advisor/certificate.lua. tests/advisor_certificate.lua now
uses raw suit/value-only definitions throughout its complete comparisons, with
318 checks covering all52 derived ranks/nominals and conflict rejection. The
same full five-card comparison remains4,293 calls under50,000. Focused
Certificate/snapshot/runtime fixtures passed. Exact candidate/installed full
reports are bound in the310 final verification record.

309's prior passing fixture evidence is preserved; it used already-normalized
front definitions and did not establish this raw capture path. No captured
source replay or terminal improvement is claimed by310. The pending pack
survival priority remains detached until its complete resource guards pass.

Tooling-only: finalizer accepts a compact architecture navigation note and
links preserved history instead of recursively copying it into each new map.
The start document links the session's full outcomes/authority rather than
duplicating them. Prior documentation/verification records remain intact.
