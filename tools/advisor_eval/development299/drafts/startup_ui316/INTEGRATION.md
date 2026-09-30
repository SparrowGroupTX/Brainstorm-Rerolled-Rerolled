# Startup diagnostics316 UI

Detached only. Root owns staging, version, release and installed verification. The two UI files were copied from the exact bases in `base_hashes.json`. `integration.patch` includes their changes and three production-only fixture files; no root runtime/test files were edited here.

Load the corresponding pure status getters from `development300/start_status316` in the same coherent release:

- `Brainstorm.CollectionSearchProduct.status_report()` uses dot syntax.
- `Brainstorm.AutoRun:status_report()` uses colon syntax.
- Both return only requested/busy/text/phase/owner. The manual successful launch is phase `started`, requested true, busy false. No UI code calls the stateful legacy auto `status()`.

The UI reads the loaded `Brainstorm.VERSION` global. It appears in the existing HUD header, the existing advisor/details/settings header, and the existing collection-run title; no disk version/config/profile/log file is read. The search page abbreviates only the leading `Brainstorm ` brand to keep its title compact.

An explicitly requested busy manual or automatic operation shows a110scaled-pixel diagnostic HUD even on the main menu or when the ordinary advisor or its HUD are disabled. Overlays, pause and screen transitions retain existing hiding behavior and clear hitboxes. Ordinary idle advisor geometry remains82scaled pixels. The waiting text uses font metrics, at most four lines, with visible ellipsis on overflow. `Full status` is beside the existing page Stop button, on the same row; it opens existing advisor details with the complete bounded reason. The page has three compact live status rows, replacing two rows and the redundant final explanatory row. It does not grow with text.

Read-only report changes retain a stopped/rejected notice for15seconds using the UI clock. An unchanged stopped report does not renew the timer. A manual `started` phase clears its previous notice immediately. Explicit request failures with requested=false are latched by the existing Start callback through `A.note_search_notice`. Messages are bounded to512bytes and controls are normalized to spaces. The full bounded message remains available in explicit details after HUD expiry.

Normal `A.open()` and Ctrl+H use only active/nonexpired notices, so a stopped notice cannot indefinitely replace ordinary advice or suppress refresh. The dedicated `brainstorm_search_status_open` callback calls `A.open_search_status()` for persistent diagnostics; the Full status page button and a drawn HUD status card use this explicit view. Closing it clears the view flag. A subsequent normal open always returns to ordinary advice after expiry.

The new manual Stop latch is `A.hud_search_stop`. It invokes only `CollectionSearchProduct.stop('HUD Search Stop clicked.')` on an explicit left click. Existing automatic Stop invokes AutoRun.manual. Both stale drawn Stop states return before any Execute, including when the ordinary advisor is inactive. A stopped notice uses a status/details button with no Execute token. Draw, status polling and mouse movement do not start, stop, cancel, execute, save or write settings.

Production fixture mapping:

- `production_tests/advisor_startup_ui.lua` -> new `tests/advisor_startup_ui.lua`:33 manufactured UI checks.
- `production_tests/advisor_collection_status.lua` -> existing test; updates the old140character/two-row assertion to the new bounded three-row/details behavior;22 checks.
- `production_tests/advisor_runtime.lua` -> existing test; changes its inert auto stub to the pure status_report contract;470 checks. No policy change is introduced by that fixture edit.

The detached `test_layout.lua` exercises the existing381check geometry suite against the new UI. It need not replace the production layout fixture. All4focused fixtures passed,906checks total. The measured compact page stayed within the existing8x5.7 envelope at normal and8%larger fonts; quick run max7.7132x4.7780 and automatic long-status max7.3676x5.2380. These are synthetic layout envelopes, not live screenshots or proof of activation.

Limits: this makes the actual loaded build and controller waiting reason observable. It does not itself repair startup/input routing or demonstrate successful live search. Parent owns those integration fixes. M22 remains prepared and unregistered on hold.
