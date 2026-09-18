---
summary: "Locked popover IA: Focus · Linear · Usage · Collection, nested Linear filters, Dex default, pin-to-Focus."
read_when:
  - Changing popover tabs, shell toolbar, Focus/Usage/Collection layout
  - Changing Linear pin, nested Linear filters, or Collection segments
  - Restyling popover chrome (Linear chips, cards, menu-bar panel attach/detach)
  - Changing the Today window (dual sidebars — see today-desk-sidebars.md)
---

# Popover Focus / Usage / Collection

Navigation locked 2026-09-12; menu-bar styling updated 2026-09-18 from the approved Linear-inspired mockup. Keep the four root tabs and nested Linear navigation.

This file lives under `docs/reference/` because the repo publishes only that docs tree (`docs/*` is gitignored).

## Root chrome

**NSWindow** (not a transient `NSPopover`). Click-outside and focus loss do **not** close it. Status-item click toggles visibility via `orderOut` (the attached window is not `.closable`, so `performClose` is a no-op). The close button and pet/open paths bring it forward if already shown. Hosting is still torn down on close (energy).

**Attached (default).** Borderless, not movable, always placed under the status item. Dragging does **not** undock it. Non-opaque window (`NSColor.clear`) with 12pt continuous rounding on the hosting view so the attached panel is not square. Linear light shell `#F3F4F6` / canvas white (`MenuBarPanelMetrics.shellFill` / `canvasFill`); dark keeps a matching split. 8pt gap around a 12pt-rounded inset canvas plus a hairline. Content-sized: default width **400**, resizable width **400–500**, height fits the active page with a **180 pt** chrome floor and **660 pt** maximum (also capped to the available screen). The top edge stays anchored; the bottom edge animates over **280 ms**, or immediately with Reduce Motion. The initial hosting size remains **400×640** until measured. Stock borderless `NSWindow` cannot become key — the panel uses `MenuBarPanelWindow` so Settings `SecureField`s accept typing.

**Detached.** Only the toolbar detach button undocks. Then it is a movable, resizable window with `fullSizeContentView`, a hidden transparent titlebar, and traffic lights on the same darker shell as the tabs (leading inset **76pt**). Frame autosave `PokeTaskBarMenuBarPanel`. No 500pt cap — normal window min/max (min height **400**, max **2400**). The same button snaps it back under the status item and locks it again.

Default size **400×640**. `MenuBarTheme` supplies appearance-specific shell, canvas, surface, text, border, and teal accent colors through the scoped `menuBarChrome` environment. Light uses `#F3F4F6` / white; dark uses `#17181B` / `#1F2023`. Shared cards and chips use 7–8pt corners inside this window. The status-item pill and Today window retain their own styling. Lists remain unboxed. SF Pro, compact labels, and a large monospaced countdown establish hierarchy. The small progress indicators use `MenuBarProgressStyle` because the AppKit-backed indicator can ignore tint on macOS.

Compact layout tests still use `PopoverMetrics.width` (360). Live width is `\.popoverContentWidth`.

Do not restyle Collection / Dex / Shop **content** as Linear except the shared segment pills. Keep light/dark via the scoped `MenuBarTheme` and existing `MenuBarPanelMetrics` dynamic colors — do not fall back to `controlBackgroundColor` / `underPageBackgroundColor` (washed Linear-light greys) or lock a Nordic Gray / Inter dark-only theme.

## Shell toolbar

The first row contains the app title, detach/attach, and Settings. Detached traffic lights reserve space in this row only. The second row contains **Focus · Linear · Usage · Collection**, with a neutral selected fill. `ViewThatFits` falls back from icons plus labels to labels only, then accessible icons for longer translations. A back chevron appears away from Focus or in Settings. Settings uses the shell heading rather than a duplicate inner header. Quit remains in Settings.

A fixed footer opens **Today**. It shows Linear loading, failure, or the actual last-sync time when available; it never invents a successful sync.

Reopening from hidden always lands on **Focus** (`PopoverNavigation.reset()`). Clicking outside does not hide the panel, so the current tab stays. Settings remains an in-window swap, not a sheet.

## Focus

Pinned: a compact companion strip (76pt sprite, name, rarity, growth progress), Score/Coins row, and one unboxed current-focus section. Companion details, evolution, and Store in Storage remain accessible from the companion ellipsis. The task section shows ID, title, status/project when available, countdown, progress, Pause/Resume, and Mark done. Add time and Reset remain inline; Unfocus is in the timer ellipsis. Existing confirmation and check-in paths are preserved.

A separate **Pomo Timer** row opens duration setup when there is no active session. It is disabled during an active timer. **Time XP** is expandable. The content scrolls at smaller heights and with long titles or prompts; the shell and Today footer stay fixed.

Idle: the companion strip remains, with an Open Linear action and the Pomo Timer row. A running Pomodoro uses the same countdown and pause controls, with **Finish** replacing Mark done and no Linear-specific metadata.

**Pomodoro.** Overlay chevron and Focus/Today idle open duration options (25 / 50 / 90) on the floating island (`FocusSessionStore.openPomodoroSetup`). **Start** begins a timer with no Linear issue (`FocusPinnedIssue.pomodoroID`). Same clock / XP / pause path; hide Linear ID, status, notes, Mark done. Pinning a Linear issue while a pomodoro is running uses the forfeit path.

## Linear

Keep nested tabs — do not flatten:

- Sub: Issues · Projects · Initiatives
- Issues: In progress · Completed today
- Projects: In progress · Production
- Initiatives: Active · Planned

Header: **New issue + refresh** in their own hairline card. **2pt** below that, a second card holds Chrome-style **Issues · Projects · Initiatives** (selected tab joins the page; idle tabs sit on the darker strip). Nested filters stay inside that card; the issue/project/initiative list is a **nested** hairline panel with unboxed rows. Unboxed issue rows: the **whole highlighted row** toggles fold (title, chips, padding, whitespace) except dedicated controls (ID, priority, status, pin) and markdown text selection. Folded layout is title + ID on line 1; **team** (+ **due**) on the first metadata line with trailing priority / status / pin; **project** on the next line; **labels** on the line below that — not one shared chip strip. Team chip uses workspace tints: SPA/SPAWN red, PER/SQUEAKY aqua blue, HOU/HOUSE orange, STU/STUDY aqua green. Unfolded shows every inspector field plus a **rendered** Linear markdown preview (`LinearMarkdownText`: headings, lists, checklists, emphasis, code, quotes — not flattened caption text). Trailing priority chip (Priority grey / Low blue / Medium yellow / High orange / Urgent red) + status chip tinted to the workflow type + pin. Hide empty fields. Completion XP when present. Projects/initiatives use the same unboxed row language; Initiatives use a grey outline `flag`.

**Pin** starts the session and **switches to the Focus tab**. Do **not** auto-open Today from this pin. Today opens from the fixed menu-bar footer and the pet menu. Pinning from the Today desk is unchanged (`openDesk` as today).

## Today window

Not a popover tab. Dual sidebars (~920×680): left pin list, Focus-like hero, right inspector + log. See `docs/reference/today-desk-sidebars.md`.

## Usage

Today totals, provider split, official limits (stale / auth-expired / tap-to-load), Time XP toggle + cap. Refresh. No companion sprite.

## Collection

Inner **Bag | Dex | Shop**. **Default Dex**. Dex and catch-log headers filter by rarity **and shiny**; when the chip row would wrap, unselected chips show the colour mark + first letter and the selected chip keeps its full label. Settings representative pick still deep-links to Dex. Bag candy still jumps to Focus after use. Shop wallet stays here.

## Overlay timer

The floating pet always shows a 32pt circular chevron button (not a tiny glyph). With a session it folds/expands the island. With no session it opens the Pomo Timer setup island (duration then Start). Clicks left of the sprite go to SwiftUI so the button is hittable.

## Localization

Route copy through `L` (`t(...)` for all seven languages). No Hangul in Swift UI sources. No `== "claude_code"` (or sibling literals) on generic Focus/Usage glance paths.
