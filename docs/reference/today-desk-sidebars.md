---
summary: "Main app window v1: Today dashboard, shared navigation and borderless dual sidebars."
read_when:
  - Changing the main window layout, chrome, or pin/openDesk behavior
  - Changing main-window navigation or shared Focus behavior
  - Changing sidebar resize, collapse, or persisted width keys
---

# Main app window v1

Implemented for the local PokeTaskBar v1.3 build on 18 September 2026. This supersedes the older Focus-centered Today desk. Approved design decisions live in the scoped [UI Overhaul v2 documents](https://linear.app/spawn-audio/document/ui-overhaul-v2-34ba3019297c); follow `linear-documentation.md` before adding new information.

## Window and surfaces

`TodayDeskController` owns the main `NSWindow`, navigation and hosting lifecycle. Identifier `PokeTaskBar.TodayDesk` and frame autosave `PokeTaskBarTodayDesk` remain stable. Default content size is 1280×860; minimum size comes from `TodayDeskMetrics`. Closing the window releases its view tree and keeps navigation and the shared focus session alive.

The titled, resizable window has a transparent title bar and hidden title. The toolbar leaves space for native traffic lights. Its page tab shares the content canvas's leading edge while the navigation sidebar is expanded, following its resolved width during resize. Collapsing navigation retains room for the window controls. An inset rounded content canvas sits inside a light/dark shell with visible outer gutters and bottom corners. There are no permanent sidebar separator lines or resting resize grips. The canvas, rounded panels, custom tabs and search boxes have subtle 1pt borders; custom borders adapt to light/dark and increased contrast without intercepting clicks.

## Navigation and pages

`MainWindowNavigation` retains back/forward history, Collection selection, workspace searches and project filtering across page changes. `PopoverNavigation` is bridged for reused controls; the main window never creates another focus session.

- Today is the dashboard: actual current Pokémon hero, growth progress, shortcuts and next/current Focus.
- Focus shows the shared timer, issue controls, local task timer setup, notes and existing confirmation/check-in flows. Task timers accept an optional title and description, persist locally, and never create or update Linear issues. The floating setup keeps its quick Pomodoro Start and adds task setup alongside it.
- Issues, Projects and Initiatives use existing Linear data/actions. Projects has List and Grid; Initiatives has Expanded and Overview. Initiative membership comes from actual project IDs, including projects without open issues.
- Collection provides Bag, Pokémon Storage, Pokédex/Catch log and approved Shop catalogue 1. Buying, training and item use reuse the existing store operations and inline confirmations.
- Usage has Overview, Provider and Limits. Settings uses expandable groups and search over existing controls.
- The right extras column contains the current issue inspector on Focus, session log, usage summary and contextual Settings help. Primary actions stay inside the central content when extras are hidden.

## Resize and collapse

The two toolbar buttons collapse/expand their respective sidebars independently. Invisible boundary hit regions show a faint vertical guide on hover/drag and a horizontal-resize pointer. Dragging updates preferred widths; VoiceOver adjustable actions change widths in 16pt steps. Collapsed boundaries are not exposed as adjustable controls.

Widths clamp to 160–320pt and at most 40% of the container, while reserving at least 360pt for the center where possible. Window resizing only changes resolved on-screen widths; it does not rewrite preferred widths. No sidebar state is stored in the window frame autosave value.

| UserDefaults key | Default | Meaning |
| --- | --- | --- |
| `todayDeskLeftWidth` | 212 | Preferred navigation width |
| `todayDeskRightWidth` | 232 | Preferred extras width |
| `todayDeskLeftCollapsed` | false | Hide navigation |
| `todayDeskRightCollapsed` | false | Hide extras |

## Shared behavior

Pin requests with `openDesk: true` open the main window on Focus. Popover issue pins keep their existing Focus routing without opening the main window. Main-window issue controls route to its Focus page. Navigation, sidebar collapse/resize and window close must never restart, stop or duplicate a session. Existing menu-bar and floating timer work remains shared with this build.

`PTBOpenMainWindowOnLaunch=1` in a bundle opens the main window on launch and Finder reopen. The v1.3 build sets this flag. Other named bundles retain their existing launch behavior.

All timers wait at zero until Continue, Finish, Mark done (Linear only), or an explicit time change. Expiry presents an independent floating alarm window plus a macOS notification when authorized. The native Glass sound repeats while waiting; Settings → Notifications can disable it. Silence or closing the alarm stops sound while retaining the zero-time choice. Sleep holds silence playback; waking resumes it unless silenced. Extending or resetting rearms the next expiry. Relaunch restores running timers paused and presents any already-finished timer again.

Settings → Desktop adds an optional focused title in the menu bar, a detached floating timer, and a pin lock for its independent saved screen position. The detached timer keeps running and hosts notes/check-ins with the pet hidden; attaching it again preserves the pet's position. Timer size scales the whole attached, collapsed or detached timer from 50–200%, independently of its width. The floating egg renders at half the Pokémon size and follows the same Pokémon size setting. Existing edge tuck, hover reveal and quick Pomodoro Start remain available.

## Validation

`MainWindowTests` covers retained navigation state, project routing, timer continuity, egg purchase semantics and actual native navigation/collapse/drag events. Its opt-in screenshot check renders the implemented views with isolated state and an injected Linear response. `TodayDeskLayoutTests` covers width/collapse persistence and minimum-size math. Native event checks need display-server access; offscreen renders alone do not prove clicks work.

Local task timers and completion alarms were checked on 1 October 2026: 150 focused tests passed, with three unrelated optional screenshot tests skipped. This includes 90 Focus tests, native task-title/duration input, alarm window and sound playback, existing floating timer interactions, and ten light/dark previews under `build/local-task-timer-preview`. Reintroducing the old 30-second automatic continuation caused the new unattended-expiry regression test to fail; the final source was restored and all 90 Focus tests passed again. Validation used a temporary source copy because other chats were editing the checkout during compilation; timer feature sources matched the tested copy.

The combined timer/display/sizing build was checked on 1 October 2026: 144 focused tests passed with no skips, followed by two passing native main-window checks. This covers title/description persistence, local-task Linear boundaries, completion alarms, detached movement/pinning, notes/check-ins, 50/100/200% scaling in both appearances, egg sizing, edge tuck and non-token XP hatching. The full suite ran 1,489 tests (22 skipped), failing 15 test cases; unchanged Master ran 1,470 (21 skipped), sharing 11 of those failures. The four additional native window checks passed in the focused runs. The full test/coverage gate remains failing; this build does not claim a green full suite.

The subsequent native test cleanup passed six checks covering scaling, detached input, edge tuck and the two main-window interactions in one process. A queued-release assertion first failed twice with the old detached-input helper, then passed after both typing helpers consumed their mouse-up events. The edge-close check now waits for its actual bounded result. These corrections affect tests only; the installed app source remains identical. The initial full-run logic-core coverage was 93.12%, above the 75% floor.

See `main-window-v1.3.md` for this build's results and remaining validation limits.
