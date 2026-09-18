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

The titled, resizable window has a transparent title bar and hidden title. The toolbar leaves space for native traffic lights. An inset rounded content canvas sits inside a light/dark shell with visible outer gutters and bottom corners. There are no permanent sidebar separator lines or resting resize grips. White/dark rounded panels organize content without edge-to-edge rules.

## Navigation and pages

`MainWindowNavigation` retains back/forward history, Collection selection, workspace searches and project filtering across page changes. `PopoverNavigation` is bridged for reused controls; the main window never creates another focus session.

- Today is the dashboard: actual current Pokémon hero, growth progress, shortcuts and next/current Focus.
- Focus shows the shared timer, issue controls, local Pomodoro setup, notes and existing confirmation/check-in flows.
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

## Validation

`MainWindowTests` covers retained navigation state, project routing, timer continuity, egg purchase semantics and actual native navigation/collapse/drag events. Its opt-in screenshot check renders the implemented views with isolated state and an injected Linear response. `TodayDeskLayoutTests` covers width/collapse persistence and minimum-size math. Native event checks need display-server access; offscreen renders alone do not prove clicks work.

See `main-window-v1.3.md` for this build's results and remaining validation limits.
