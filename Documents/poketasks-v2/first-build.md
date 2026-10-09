# PokeTasks v2.0 — First native build

Built and installed on 2 October 2026 at `/Applications/PokeTasks v2.0.app` with a Poké Ball icon. This is a separate local experimental app and profile.

## What to try

- Today: unfold the Today, Soon and Later groups in their shared panel. Use the status tabs in the Issues tray below the divider, then drag an issue into a group. The calendar button selects a day without changing the active timer.
- Planning defaults to personal changes for new profiles. Optional linked moves use the issue's own team states; existing saved preferences survive rebuilds.
- Time Blocking: drag an issue into the day panel, move or resize its block, or use its scheduling menu. The day panel folds independently; left navigation folds to icons.
- Issues and Projects: unfold a parent to reveal its sub-issues. Each child keeps the same status, notes, focus and planning actions. Folding a parent does not stop a child's timer.
- Floating timer: title/time at rest; Pause, Notes, Complete and three-dot actions replace the title on hover or keyboard focus. Narrow widths use icons. The existing three-dot menu remains available.
- Insights: review measured task time, sessions, plan coverage and the seven-row heatmap; export session records as CSV.

Existing Linear-style cards are reused. Initiatives are hidden with their code and data retained. Document/note syncing remains in the backlog.

## One-time reset for the first build (02:39 AWST)

Only v2's stats, session history and collection were reset. The prior v2 save is recoverable at:

`~/Library/Application Support/PokeTasks v2.0/backups/pre-reset-20261002-023952`

The Linear connection, saved plan, language and settings were preserved. Fresh-state and initial launch checks found zero earned XP, collection/storage entries and task-session history. New progress can accumulate normally after that reset. The original profile was not edited.

## Validation

Post-install rerun: **112 checks, 109 passed, three optional previews skipped, zero failures**. Native checks exercise timer clicks, parent/project folding, child focus, calendar selection and timeline move/resize/cancel. Data checks exercise personal/linked planning, persistence, failed writes, time accounting, legacy adoption, DST and CSV. Branch-region coverage was inspected.

The historical full-suite comparison predates the latest UI revision and still has baseline failures. Full VoiceOver, live Linear writes, notarization and multi-monitor/travel-time-zone UI checks remain unverified. The build uses a local development signature and does not auto-update through the public release channel.

## Source and evidence

- Worktree: `experiments/PokeTasks-v2`, branch `codex/poketasks-v2`, base `d8ea10167d5472b14a4680b9222082a740a23f08`.
- Rebuild: `scripts/rebuild-v2.sh`.
- `installed-bundle.json` and `build-preview/installed-launch.json`: packaged/installed binary and icon checks, strict signature and initial native main-window launch.
- `reset-verification.json`: reset counts and backup hashes.
- `build-validation.json`, `final-validation.log`, `final-region-coverage.txt`: final validation evidence.
- `revision-build-assets.json`: 14 revised uploaded assets. Previous asset manifests record historical uploads; their mutable preview source files may have been refreshed later.

All scoped Linear documents remain attached to the PokeTasks project. The index links the owning feature documents, generated mockups, all four motion videos, supplied references and native screenshots.

- [PokeTasks v2 - Document Index](https://linear.app/spawn-audio/document/poketasks-v2-document-index-d2ff2b22fc39)
- [Implementation, Validation & Change Log](https://linear.app/spawn-audio/document/ui-overhaul-v2-implementation-validation-and-change-log-5bdfd7d37c11)

## 2 October follow-up — Floating timer hover fix

Rebuilt and replaced PokeTasks v2.0 in place. Leaving the timer keeps its actions
for two seconds, then restores the title with a 200 ms crossfade (an immediate swap
with Reduced Motion). Re-entry cancels the hide. Native tracking works while another
app is active; lingering mouse focus is released, keyboard movement stays available,
and the existing three-dot menu remains usable while the pointer is away.

115 relevant checks: 112 passed, three optional previews skipped, zero failures.
The native regression caught two assertions when the old focus latch was restored;
its tracking-area preservation check also passed in a further targeted run.
Installed/build binary hashes match, the strict local signature verifies and one
installed process was confirmed. Collection, history, planning, connection and
session identity were preserved. No second reset was performed; the existing session
restores paused on restart.

Latest evidence: `hover-installed-bundle.json`, `hover-final-validation.log`,
`hover-injected-failure.log`, `hover-tracking-validation.log` and
`hover-region-coverage.txt`. Earlier installation/reset records remain historical.


## 2 October 2026 — Timeline interaction repair and vertical issue groups installed

Rebuilt and replaced `/Applications/PokeTasks v2.0.app` in place. See [Time Blocking](https://linear.app/spawn-audio/document/poketasks-v2-time-blocking-861f5be0e815) for continuous move/resize/drop previews and restored timeline scrolling, and [Today, Soon & Later](https://linear.app/spawn-audio/document/poketasks-v2-today-soon-and-later-286ed82cf2e7) for the vertical In Progress / Planned / Todo tray and updated native previews. The same coordinate repair covers both main-window sidebar dividers. Existing Linear card styling and sub-issue behavior are retained.

**Proof:** the original multi-update block replay failed two assertions (30 minutes of pointer movement moved the block only 10 minutes); the original sidebar replay also failed its distance assertion. Updated native checks cover direction changes, resize, Escape, Undo, actual issue drops, overlap rejection, independent status disclosures, and wheel scrolling followed by folding/unfolding.

**Validation:** the final broader run executed **140 checks: 135 passed, four optional previews skipped, one timer-composer key-window assertion failed**. That timer check passed when rerun separately. A grouped native-build run initially failed three block-driver assertions; the isolated block replay passed, and the remaining **11 native-build checks passed together**. These reruns do not make the broader run clean. Native region coverage was inspected for the changed paths; reduced-motion and uninvoked menu/accessibility branches remain outside this interaction replay. Existing full-suite/distribution limitations above still apply.

**Installation:** strict signature verification passed; installed and packaged executable SHA-256 match (`6abbf6e115ea…`); the Poké Ball icon is retained; one process was confirmed from the installed bundle. Collection, task history, planning, connection and session identity matched across the restart. **No further stats/collection reset occurred.** There was no active session to resume. No live issue-status or completion mutation was used for QA.

Local evidence: `Documents/poketasks-v2/timeline-installed-bundle.json`, `timeline-final-validation.log`, `timeline-timer-rerun.log`, `timeline-native-drag-validation.log`, `timeline-native-drop-status-validation.log`, `timeline-region-coverage.txt` and `timeline-assets.json`.
