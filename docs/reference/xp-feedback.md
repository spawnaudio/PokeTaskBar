# XP feedback

Real XP awards show a brief `+amount XP` receipt in the menu bar and over the
floating pet, with a soft colour pulse at the edge of the pet's screen (or the
menu bar's screen when the pet is hidden).

- Teal: token, time-open, and focus-session XP.
- Green with a checkmark: issue and project completions.
- Purple: Rare Candy growth XP.
- Receipts last three seconds. Background awards within 30 seconds are totalled
  into one later receipt; completion and candy receipts take priority in the queue.
- Amounts come from the actual award after daily caps and Mint bonuses. Candy
  remains growth-only and is not multiplied. Menu bar hover shows the exact amount.
- Seed polls, repeated completions, and zero awards produce no receipt.
- Pet receipts follow dragging, stay on screen, and never take focus or clicks.
  Existing completion and evolution speech bubbles remain available.
- Reduce Motion and Low Power Mode use static text and omit the edge pulse.
  Sleep clears pending feedback; waking does not replay it.

`CompanionStore.onXPEarned` emits transient receipts. `XPFeedbackController`
serializes them for both surfaces; it has no idle timer and does not persist
notifications or change the reward economy. The presentation windows are released
when each receipt ends.

Validation lives in `XPFeedbackTests`: actual award paths, Mint and caps,
completion deduplication, batching, queue timing, sleep cleanup, pet placement,
click-through behavior, and edge-only drawing. Set `PTB_XP_PREVIEW_DIR` when
running that suite to render native light/dark samples.

## Validation on 2026-09-19

- App compiled; all 11 feedback checks passed, including the opt-in native previews.
- Final focused reward/session run: 158 passed, one optional preview skipped.
- Full suite: 1,344 tests, 15 skipped; 13 test cases failed (76 assertions).
  Eleven failures reproduced using the original `CompanionStore` reward logic in
  a temporary copy: repeat-hatch/growth fixtures, save-transfer field inventory,
  settings rendering, and existing UI style expectations. Two floating-timer
  focus tests passed when rerun separately with both versions. The full suite
  therefore remains a failing gate; these failures were not changed here.
- Logic-core line coverage: 89.55% (75% floor); `XPFeedback.swift`: 100%.
  Award and queue branches were also inspected using region coverage.
- Installed app bundles were not replaced. Native component previews do not
  constitute a live end-to-end check of a Linear completion on multiple displays.
