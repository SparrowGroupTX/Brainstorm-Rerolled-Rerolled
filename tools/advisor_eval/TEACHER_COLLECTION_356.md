# Real-game teacher collection 356

The production advisor is the initial, fallible teacher for a narrow Red Deck /
Gold Stake / Yorick + Perkeo pilot. Its decisions are not expert labels merely
because they were executed or belonged to a winning run. Human review should
prioritize starter sales, discard growth, copy ordering, Perkeo inventory, shop
cash, boss preparation, and final losses. Retain useful decisions from losses;
do not punish every preceding action for the terminal result.

The new explicit button, **Clear logs + collect 10 win-first runs**, requests a
fresh product session after normal restart. It clears journal-owned observation
files at the start, records up to ten actual run starts, and retains Stop/Resume
counts. It uses the existing bounded native opening search; Burnt is flexible,
Blueprint/Brainstorm interchangeable, alternate Legendary fallback disabled,
and no missing-sticker quota. Search failure can stop before ten starts.

Teacher mode preserves the real sticker ledger as `collection_progress` while
omitting the optional `completionist_goal` policy objective. Generic pace skips
are suppressed; prescribed opening Charm skips and the ordinary exact clearing,
growth, consumable, copy, cash and legality safeguards remain. This is a scoped
objective change, not evidence that the advisor can reliably win or outperform
a human. Normal auto-run remains available with its original collection goal.

Public blind route capture now includes the current ante's Small/Big/Boss
identity, score threshold, status and base restrictions during hands, shops and
packs as well as blind selection. Unsupported scaling remains unknown. It does
not reveal future antes. The learning adapter preserves this and other public
state; the frozen 355 networks still use their old 80/530 inputs and are not
silently changed, promoted or retrained by this release.

Collection journals record changed public observations once and reference them
from advice, requested/executed action, callback, terminal, checkpoint and error
events. Full policy forecasts and hidden-state fingerprints are not training
inputs. The watchdog uses compact public-state keys, with reuse on unchanged
frames. It queues retirement after thirty seconds without new public progress,
or after an explicit unsupported decision/error. Actual replacement waits for a
settled state with no unresolved game action, worker, save, input or modal.
Verified terminal results take priority. Abandoned stalls, unsupported decisions,
errors, wins and losses remain separate. A permanently busy game may therefore
wait rather than being forcibly interrupted.

There were zero live matches/searches/GPU jobs or log purges by development
tools. The batch is prepared, not executed. Current loaded runtime is unknown
after the reported computer crash. Earlier evidence and closed allowances remain
preserved. Exact release/test/install receipts are under `runs/teacher356_*`;
prospective scope and limits are in `development356/AUTHORITY.md` and `BUDGET.json`.

The new UI initially exceeded its synthetic height allowance by 0.09 units;
removing the extra explanatory row restored fit, including the existing 1.08
font-scale test. No live screenshot or game control was used for layout checks.

Released 2.156.0-alpha on2026-09-16 at12:44:02CDT. Candidate and exact-installed
regression both passed226Lua fixtures and391Python tests (including30 new
manufactured learning-data contracts). All89deployment and105frozen runtime/
dependency files match. Policy digest:
`946c0a1920b8c02f352532ce52bc17a057469c2937615564ecc91de06e4900d0`.
Backup: installedmod`deployment-backups/advisor-20260916-124401`.
Current settings and allsevennativeDLLs were preserved. Activation waits for the
user's normal restart. No actual logs were cleared and no batch was started.

Teacher launch allowances are reserved before callbacks. A launch that throws
or fails after changing game identity closes the session with separate uncertain
start evidence and cannot Resume into an extra launch. Confirmed starts remain
distinct from consumed/uncertain starts. A completed nonresumable teacher session
ends recording and restores the ordinary advisor objective; manual Stop retains
the current session for Resume. Archive mode changes rotate segments.
