# Content-sized menu bar panel

**Implemented and installed, 18 September 2026:** see [implementation and validation](IMPLEMENTATION.md). The video below remains the original design mockup.

29-second video mockup based on the app's native SwiftUI fixture renders. This is a motion study, not an implemented application change. Source application files and the installed app were not modified.

Open `adaptive-panel-mockup.mp4` or `preview.html`.

## Proposed behavior

- Keep the attached panel's current width. Its default remains 400 pt.
- Keep its top edge anchored below the menu bar icon. Animate only its height and corresponding bottom edge, over about 280 ms.
- Measure the active page's natural content height at the current width, then add the toolbar, padding, and footer.
- Resize on navigation, collection segment changes, expanded sections, and meaningful content changes, including entering or leaving a focus session.
- Cap height at the smaller of the attached-panel limit (currently 660 pt) and the available screen space. Longer content scrolls inside the panel. Retain comfortable padding.
- Use immediate resizing when Reduce Motion is enabled. Do not animate timer ticks or every incremental loading update. Preserve the prior size until a new page has a stable measurement.
- Keep detached windows manually resizable; automatic fitting applies to the attached menu bar panel.

## Why there is empty space now

`MenuBarPanelMetrics` starts at 400 × 640 pt and enforces an attached minimum height of 520 pt. `PopoverView`, `tabContent`, and Collection's segment container expand to fill the window. The root `GeometryReader` also takes its available height. Several pages contain scrolling containers, whose viewport height is not the same as their content's natural height.

## Implementation outline

1. In `PopoverView.swift`, separate intrinsic page content measurement from the expanded shell. Measure the stack **inside** each scroll view, at the actual available width; measuring the root window or scroll viewport would just return its existing height. Avoid hidden duplicate view trees that could run side effects twice.
2. Provide each page's measured content height, including local navigation and fixed chrome, through one preference/callback path. For lazy lists, use a bounded visible-row layout or a capped desired height; do not depend on the height of only the currently realized rows.
3. In `MenuBarPanel.swift`, add one attached-panel fitting method. Relax the global 520 pt floor in both window constraints and the SwiftUI root. Clamp the measured target to the usable screen height and a small chrome-safety minimum.
4. Reuse the existing status-item placement calculation to preserve the anchor. Update the window frame, including its origin, using an approximately 280 ms eased animation. Changing just the height through `setContentSize` can move the top edge because AppKit uses bottom-origin window coordinates.
5. Ignore subpixel measurement changes; cancel/replace superseded transitions and reset measurements when width changes. Preserve input focus and per-page scroll state. Do not persist attached automatic heights as detached window sizes.

Apple references: [window frame animation](https://developer.apple.com/documentation/appkit/nswindow/setframe(_:display:animate:)) and [SwiftUI geometry observation](https://developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)). A preference plus background geometry measurement is also suitable for the app's macOS 14 deployment target.

## Video scenes

| Time | Scene | Illustrative height |
| --- | --- | --- |
| 0–3 s | Current Collection, unused area highlighted | 640 pt |
| 3–6.2 s | Collection fits its single-row fixture | 337 pt |
| 6.2–9.7 s | Running Focus session | 640 pt |
| 9.7–13 s | Linear setup state | 290 pt |
| 13–16.3 s | Usage and Time XP | 446 pt |
| 16.3–19.5 s | Collection | 337 pt |
| 19.5–22.8 s | Settings with a capped viewport | 640 pt |
| 22.8–26 s | Idle Focus | 462 pt |
| 26–29 s | Compact Collection recap | 337 pt |

These values demonstrate the motion. Production heights must be measured from the current content, language, font settings, and width rather than hard-coded per tab. The video uses isolated sample data; it does not show the user's live Linear account. Settings shows the existing first scroll position, not a recorded scroll interaction. Collection's other segments use the same proposed sizing rule but are not individually demonstrated.

## Validation to perform when implementing

Exercise all four root tabs, all Collection segments, Settings, short and long lists, setup/empty/error states, expanded sections, active/paused/idle sessions, long titles, and supported languages. Verify the top edge stays fixed, controls and footer remain reachable, long content scrolls, the window stays within small displays, and detached windows retain user sizing. Check rapid tab switching, Reduce Motion, and no repeated resize loop while the timer ticks.

## Regeneration

`render.swift` composites unchanged native UI content into the animated shell and exports H.264 MP4 using AppKit and FFmpeg. `source-assets` contains the native sample renders used as visual inputs. `stills` contains one frame per scene.

Compile with a compatible macOS SDK, specifying an explicit macOS deployment target, then pass this directory to the executable. Use `--stills-only` to inspect frames before rendering the video.
