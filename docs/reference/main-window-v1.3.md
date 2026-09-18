# Main app window v1 — local v1.3 build

Implemented and installed 18 September 2026. This is a local preview of the approved UI Overhaul v2 designs, with Shop option 1 selected. The [Linear implementation record](https://linear.app/spawn-audio/document/ui-overhaul-v2-implementation-validation-and-change-log-5bdfd7d37c11) owns the dated result; approved mockups remain in their existing scoped design documents.

## Delivered

- Today dashboard with the real current Pokémon hero, growth progress, shortcuts and next/current Focus.
- Main navigation, history, page search, independently collapsible/resizable sidebars and hover-only resize guides. Inset rounded content panels in light/dark appearances.
- Shared Focus timer and existing issue controls, notes and prompts; Issues, Projects List/Grid and Initiatives Expanded/Overview.
- Collection Bag, Storage, Pokédex, Catch log and Shop catalogue 1, using existing item, purchase and training operations.
- Usage Overview/Provider/Limits and searchable, expandable Settings groups.

Implementation owners: `MainWindow*.swift`, `TodayDeskView.swift` and the main-window branches of existing Usage, Settings and Shop components. `today-desk-sidebars.md` describes the updated window contract.

## App and data

Installed `/Applications/PokeTaskBar v1.3.app`, bundle `io.github.spawnaudio.poketaskbar.v1.3`, version `1.3.0`. The app opens its main window on launch and Finder reopen. The older v1.2 bundle remains intact.

Existing v1.2 companion progress, inventory, history, preferences, credentials and caches were copied once to the separate `~/Library/Application Support/PokeTaskBar v1.3` folder. The companion snapshot copy was hash-verified. No active session existed at copy time; live sessions are excluded by the one-time installation helper to avoid resuming a duplicate timer. The new copy starts with its floating overlay off and menu panel attached. Subsequent changes in v1.2 and v1.3 do not synchronize.

Rebuild/install: `bash scripts/rebuild-v1.3.sh`. Set `PTB_SKIP_INSTALL=1` to assemble only under `build/`. This uses the existing build script with an explicit app name, bundle ID, version and main-window launch flag. No public release, tag, push or landing deployment was performed.

## Verified

- Final focused native run: **183 tests, 0 failures, 0 skipped**. Suites: MainWindow, TodayDeskLayout, PopoverNavigation, FocusSession, SpriteAspectRatio, AdaptiveMenuBarSizing, LinearRewards and SwiftUIIsolation.
- Actual native mouse events verified page navigation, toolbar collapse, boundary dragging, persisted width and session continuity through navigation/window close.
- Fifteen native SwiftUI renders reviewed across pages, light/dark, paused Focus and a compact window with both sidebars collapsed. They use isolated sample data and an injected Linear response.
- Release build, plist validation, strict bundle signature verification and installed/built executable SHA-256 match passed. Signing is ad hoc for this local build.
- Installed app process and visible 1280×860 main window verified; the sixteenth screenshot captures the installed app using the copied real state.
- Existing menu-bar/floating timer changes were preserved. Of 172 source/test/script files snapshotted before this task, 158 remained byte-for-byte unchanged; the 14 edited baseline files are recorded in `source-comparison.json`.
- Shell syntax checks and `git diff --check` passed.

Evidence is in `build/main-window-v1.3/`: `tests-final.log`, `release-build.log`, `install-verification.json`, `installed-window.txt`, `source-comparison.json` and `screenshots/`.

## Limits of this build

This is the first implementation, not a claim of pixel-identical reproduction of every mockup. Existing Pokémon detail screens are retained while their replacement design awaits approval. Workspace searches cover already loaded Linear data; existing API limits and project-status filters remain. Initiative links use explicit project IDs, but cards require project details in the loaded dashboard. Right-side extras are contextual on Focus/Settings and currently use shared log/usage panels elsewhere.

Live issue creation, status changes, notes and completion were not submitted during QA. Core flows were tested with isolated data/injected responses. Full keyboard/VoiceOver coverage, all new text translations, exhaustive window sizes, Reduced Motion, notarization and public distribution were not verified. Existing compact controls retain their localized strings; some new main-window copy is English.
