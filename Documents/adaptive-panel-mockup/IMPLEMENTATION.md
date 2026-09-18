# Adaptive panel — implementation and local installation

Implemented and installed on 18 September 2026 in `/Applications/PokeTaskBar v1.2.app`.

## Behavior

The attached panel retains its width and top anchor while its bottom edge resizes to the current content over 280 ms. Short pages shrink below the old 520 pt floor. Long pages scroll at the 660 pt limit, further limited by the available screen. Session changes, Collection segments, expanded content, language changes, and width changes all feed the same measurement path. Identical/capped measurements do not reschedule resizing. Reduce Motion uses immediate resizing. Detached windows retain manual sizing.

`MenuBarContentSizing.swift` measures the actual mounted content and scroll viewports. It does not create hidden duplicate pages or fetch data to measure layout. `MenuBarPanelController` coalesces changed measurements and preserves the menu-bar anchor. Existing visual styling, navigation, integrations, and focus-session behavior are retained.

## Preservation

- Saved the starting source/tests/documentation and a hash manifest in `/private/tmp/ptb-adaptive-baseline-20260918` before editing.
- Used incremental edits on top of existing uncommitted work. Did not reset, stash, switch branches, commit, or replace source files with an earlier checkout.
- Checked other active project tasks. The UI implementation task had finished before installation; independently updated design/resource documents were retained.
- Checked the build-source hash manifest immediately before installation and again after launch.
- Preserved the installed app's identifier (`io.github.spawnaudio.poketaskbar.v1.2`), executable name, Info.plist, icon, and launch-agent metadata. Replaced its executable and refreshed its existing ad-hoc signature.
- Kept the previous bundle at `/private/tmp/ptb-adaptive-backup/PokeTaskBar v1.2.app`. No extra app copy was added to the visible Applications folder. No app save files were directly edited.

## Validation

- Final focused run: **37 tests passed, zero failures and zero skips**. Includes native content fitting, the real window controller, all root tabs, all Collection segments, small and large lists, active/paused/idle sessions, seven languages, two widths, light/dark render checks, and explicit SwiftUI actor isolation.
- Native renders showed compact Linear setup (289 pt), Usage (445 pt), small Collection, and capped Settings/Shop pages. Heights are measured, not hard-coded per tab.
- Mutation proof: disabling content-minus-viewport adjustment in an isolated copy made the native Focus regression test fail, reproducing a window stuck at 640 pt. The shared workspace was not mutated for this check.
- Full suite: **1,310 tests executed, 12 skipped**. Nine failing cases (58 assertions) reproduce in the untouched snapshot. A new explicit-actor annotation omission was found in that run, fixed, and verified in the final focused run. The complete suite was not repeated after that annotation-only correction.
- Existing failing cases: branching/repeat growth, difficulty/repeat growth, delayed Ditto reveal, graduation levels, candy stage limits, save-transfer field classification, session-key Settings scroll visibility, and repeated graduation. These unrelated areas were left intact. The whole-suite gate is therefore not green.
- Inspected coverage regions for the measurement and controller paths. Native controller testing required display-server access; the restricted sandbox reports no screen, so that test explicitly skips there. The final focused run ran with display access and passed it.
- Release build passed using the Xcode beta toolchain and isolated build/cache paths.
- Staged and installed bundles passed `codesign --verify --deep --strict`; Info.plist passed validation.
- Installed executable matched the staged executable. Relaunch produced one running process (PID 54729), confirmed again after installation.

The original MP4 remains a design preview. This installation was validated through native tests and launch/signature checks; live Linear writes and every external integration were not exercised.

Detailed logs and snapshots are under `/private/tmp/ptb-adaptive-*` and may be removed by macOS temporary-file cleanup.
