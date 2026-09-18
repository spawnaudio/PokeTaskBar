# UI Overhaul v2

**Status:** Approved visual direction for Today, Focus, Issues, Projects, Initiatives, Collection, Usage, Settings, the menu-bar window and the floating pet/timer overlay. Issues uses option 2; Projects defaults to option 1 with option 3 as Grid; Initiatives defaults to option 2 with option 3 as Overview; Collection uses option 3; Usage defaults to option 1 with Provider and Limits as alternate views; Settings uses option 3; Collection Bag uses option 3 with the current Pokémon as its hero; Storage uses the last displayed Pokémon Preview Workspace; Catch log uses option 3, Individual History Workspace. Updated 18 September 2026.

PokeTaskBar is being redesigned around Linear's desktop application language: calm neutral surfaces, precise typography, inset content panels, clear navigation, and restrained interaction feedback. Today is the dashboard, with the Pokémon as its main hero and clear routes into the rest of the app.

This document records the decisions approved in the [Design Mockups task](codex://threads/01a0b269-3b7a-71a0-ae64-ec0f4fc45e10). It is the PokeTaskBar-specific interpretation of [Linear App Design Breakdown](https://linear.app/spawn-audio/document/linear-app-design-breakdown-a616cfb54f0a), supported by [Linear Styles](https://linear.app/spawn-audio/document/linear-styles-ec0c89494ba4) and the supplied light-mode Linear screenshots.

## Approved mockups

### Today dashboard — selected combination

The user selected the second light Today concept's centred Pokémon hero, then combined it with the first concept's expanded left navigation. The following combined mockup is the selected reference.

![Approved Today dashboard with centred Pokémon hero, expanded navigation and optional right-side extras](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/77e4f922-06a4-4800-a983-3dbc842d3ab6/0581f385-fb2e-4b44-8338-6b52fbe6284c)

**Later approved correction:** remove permanent sidebar separators, full-height section rules and visible resize grip dots. Keep the inset rounded panels and surrounding gutters. A temporary low-opacity resize guide may appear on pointer approach or during resizing. This correction takes precedence over any lines or grips visible in the mockup.

### Menu-bar window — approved visual direction

The user approved the compact dark menu-bar concept, including the navigation tabs, companion strip, active issue and focus timer.

![Approved compact menu-bar window with Linear styling, Pokémon companion and focus controls](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/d203a296-0184-48a7-a266-dbeff0e8513d/750b1635-c8a7-49de-8f85-efcb9834d9c0)

### Focus page — selected option 1

The user selected the first displayed Focus mockup, **Focus Session**, on 18 September 2026. This is the approved Focus page reference.

![Approved Focus page — option 1, with centred task and timer, expanded navigation, companion and session details on the right](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/822a64a7-65e2-446b-93d8-20908ae3072d/3b679c06-7355-4601-a889-1b5c25f0da5f)

The large central timer and task context lead this page. The companion and session details remain in the optional right sidebar. The shared no-permanent-sidebar-separators rule applies.

### Issues page — selected option 2

The user changed the Issues selection to the second displayed mockup, **Inline Issue Workspace**, on 18 September 2026. This replaces the previously selected option 3.

![Approved Issues page — option 2, with inline task expansion and the optional right sidebar collapsed](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/1ecbf957-8bbe-498d-bb68-e7aa7ad154bb/7ea768a7-dd92-425c-9f26-1677688cb896)

Task details, properties and Start focus live inside the expanded issue row. Other issues remain compact beneath it. The earlier project-grouped Issues option 3 is superseded.

### Projects page — default list and optional grid

The user approved **option 1, Expandable Projects**, as the default List view, with **option 3, Project Gallery**, available as an alternate Grid view. Both references describe the same Projects destination.

![Approved Projects default List view — option 1, with expandable projects and nested issues](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/4b6d5a4e-b9cd-493e-9a17-e926e8f9b6b3/18660ec9-76af-48fa-9df4-ae20a2d10928)

![Approved Projects alternate Grid view — option 3, with project cards and supporting project details](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/b792248a-123a-48a2-9da1-feccd0299e77/6707df8d-ca8d-4fa8-a165-70a53435de54)

**Requested interaction addition:** place a compact labelled **List / Grid** view switch beside the project search controls. The original mockups above predate this control; their layouts are approved. Start in List view, then remember the user's view preference. This is a view choice within Projects, not a separate navigation destination.

### Initiatives page — default Expanded and optional Overview

The user approved **option 2, Purpose-led Workspace**, as the main Initiatives view, with **option 3, Initiative Overview**, available as an alternate.

![Approved Initiatives default Expanded view — option 2, with the selected initiative and its projects expanded inline](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/6f8e5e26-b05f-44cf-889d-a9c5adb04e26/c9017b1a-4f67-4bb0-ab69-1130f4551cff)

![Approved Initiatives alternate Overview view — option 3, with a compact initiative list and selected initiative project cards](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/0d519304-1a80-4107-89ac-8a18a62aea38/83f70fae-60f6-42a1-a260-dd0839e7023f)

**Requested interaction addition:** provide a compact labelled **Expanded / Overview** switch near the search controls. These original mockups predate the switch; their layouts are approved. Start in Expanded view and remember the user's chosen view.

### Collection page — selected option 3

The user selected **option 3, Pokémon Detail Workspace**, as the Collection Pokédex layout.

![Approved Collection Pokédex — option 3, with a compact species list beside the selected Pokémon detail workspace](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/c5db46ea-5fad-4ca4-be15-79cf8068cc5c/c5608963-6a58-420a-a133-1dcedd31df0c)

The selected species stays visible in a compact list while its artwork, identity, representative action and profile occupy the main detail area. The optional right extras sidebar is collapsed in this reference.

### Usage page — default Overview with Provider and Limits alternatives

The user approved **Usage Overview** as the main Usage view, with **Provider Workspace** and **Limits First** available as alternatives.

![Approved Usage default — option 1, Usage Overview with daily consumption chart and optional limits and Time XP extras](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/bb581324-a702-4dd9-a998-e02f4250174f/fdaa987c-d37e-448c-b40b-1c80a03ca6ed)

![Approved Usage alternate — option 2, Provider Workspace with provider breakdown and official limits in the main canvas](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/97ae9ec6-bd9e-45e4-82f7-70c0e284cc90/394fc4dd-dc78-49ed-bb7e-c413998c3d01)

**Requested interaction addition:** provide a compact labelled **Overview / Provider / Limits** view switch near the Usage heading. Overview is the initial default. The original screenshots predate this switch. Remember the chosen view and preserve the selected provider and sidebar preferences.

![Approved Usage alternate — Limits First, with remaining capacity in the main canvas and provider and Time XP extras](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/826edfc9-ecf2-4e72-9c7a-0140a77eecb0/b2a41a5c-2b41-44c2-a463-fde44d55ee33)

The user confirmed that their reference to “4” means the last displayed image, **Limits First**. This is the saved third Usage concept; the additional displayed image was the refinement of Provider Workspace.

### Settings page — selected option 3

The user selected **option 3, Inline Settings**. General preferences expand in place, with the other settings categories available as compact disclosure rows below.

![Approved Settings page — option 3, Inline Settings with an expanded General group and optional contextual help](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/fb0453b1-5800-4741-9db5-81a08c3a2c7b/9cd326bd-877f-4451-8764-d86c3b3ac581)

The main canvas contains the search and all setting controls. The optional right panel explains the current section and provides a supplementary Collection link. The shared no-permanent-sidebar-separators rule applies.

### Collection Bag — option 3 with the requested Pokémon hero

The user selected **option 3, Item Detail Workspace**, with the explicit correction that **the Pokémon must be the main hero instead of the candy**. This revised reference implements that direction.

![Selected Bag option 3 revised with Lapras as the main hero and compact selected-item details beneath](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/1e1cf253-5823-4aed-a5af-b995ec945777/35cd195f-8990-4079-be56-892b0a68e124)

The current Pokémon's name and large crisp sprite lead the workspace. The selected item's small icon, available quantity, effect and Use item action sit below. The original large-candy composition is superseded.

### Collection Storage — selected Pokémon Preview Workspace

The user selected the **last displayed image, Pokémon Preview Workspace**, by referring to image 4 in the previous response, which began with the revised Bag image. It is saved as **Storage option 3**.

![Approved Collection Storage — Pokémon Preview Workspace with a compact stored list, large selected Pokémon and separate current-trainee context](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/134712ba-7a8d-4169-8080-1106fb8fd8a9/3953063f-a789-4532-ba2e-e891c21c55fe)

Keep the full stored list visible beside the selected Pokémon's large preview. The compact current-trainee strip above distinguishes who is training now from who is selected to train next.

### Collection Catch log — selected option 3

The user selected **option 3, Individual History Workspace**. Keep the dated individual-record browser beside a large preview of the selected Pokémon.

![Approved Catch log option 3 — Individual History Workspace](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/482e2242-59e3-40bf-8dc9-32839e0a98d7/4c3cccbd-0aec-4d3e-9be8-1afad79449e9)

The selected Pokémon is the hero of this history workspace. Its recorded nature, catch date, rarity, state and evolution history remain in the main canvas, with optional extras collapsed.

The images establish visual composition and hierarchy. Example task IDs, dates, numbers, Pokémon levels, progress values, text and incidental icons are illustrative; they are not new requirements for the data model or reward system. Production copy should stay calm and neutral. In particular, the generated “work is piling up” wording and a positive treatment of increased token usage should not be treated as approved product messaging.

## Shared visual language

### Window, panels and separation

- Use a continuous neutral window shell surrounding a lighter inset main content surface.
- The main panel has rounded corners and visible gutters on all four sides. Its lower corners remain visible above the window's bottom edge.
- Left navigation belongs to the surrounding shell. Optional right-side extras sit in discrete content panels with space between them.
- Do not divide the window with permanent vertical separator strokes or edge-to-edge horizontal rules. Use spacing, alignment and differences in surface tone to explain the layout.
- Quiet outlines around individual cards, inputs and buttons may remain. Short internal separators are acceptable when they help read a list; they must not become window-wide section rules.
- Use cards where content forms a useful group, such as a next-focus action, a log or a usage summary. Avoid boxing every label and row.
- Keep the native window controls and compact page/tab context. Preserve normal Mac window movement and resizing.

### Colour and appearance

The approved Today reference is light and the approved menu-bar reference is dark. These are two appearances of the same design language, rather than a requirement to permanently tie each surface to a different theme.

The following values are starting points derived from the design references, not exported Linear tokens or measured final implementation values.

| Role | Light appearance | Dark appearance |
| --- | --- | --- |
| Window shell / navigation | `#EFF0F2` | `#17181B` |
| Main content canvas | `#F8F8FA` | `#1F2023` |
| Grouped content surface | `#FFFFFF` | `#292A2E` |
| Selected neutral surface | `#E0E1E4` | `#303138` |
| Primary text | `#242528` | `#F1F1F3` |
| Secondary / metadata text | `#73757B` | `#92949B` |
| Subtle component outline | `#E7E8EB` | `#2B2C31` |

Colour is concentrated in the Pokémon sprite, a narrow progress bar, small status icons and meaningful labels. Use blue/cyan for companion progress, yellow for in-progress status, and appropriate small semantic colours for other states. Selected navigation and primary controls use restrained neutral fills. Avoid decorative gradients, glow, heavy glass effects, or large saturated panels.

### Typography, spacing and shape

- Use a neutral SF Pro / Inter-like interface character. Prefer the native system font when implementing the Mac app; font selection is not a requirement to bundle a new typeface.
- Start with 14–15 pt body/interface text, 12–13 pt compact controls and metadata, and 28–32 pt main headings. Use size, weight and position to establish hierarchy.
- Issue identifiers and timestamps are smaller and quieter than task titles. Property labels are muted; values are clearer and aligned.
- Timers use stable monospaced digits. Avoid letting changing numbers move adjacent controls.
- Work from a 4 pt rhythm with 8, 12, 16, 24 and 32 pt spacing. Use roughly 10–12 pt shell gutters and comfortable content padding.
- Start around 12–14 pt for main panel corners, 10–12 pt for grouped content, and 6–8 pt for compact controls and selections. Reserve pills for short statuses or tags.
- Use a consistent small outline icon family. Labels remain visible in expanded navigation. Check icon meaning and optical alignment during implementation.
- Keep Pokémon sprites crisp and proportional, with their original pixel character. Do not stretch them as panels resize.

## Today is the dashboard

### Centre content

The centre contains the essential experience, independent of either sidebar:

1. **Page context:** Today, the current date, and a brief personal greeting.
2. **Pokémon hero:** a large centred companion, its name, small rarity label and compact progress information. The creature is the strongest visual element on this page.
3. **Quick page shortcuts:** clear Issues, Projects and Collection buttons with useful labels, icons and directional affordances.
4. **Next focus:** one compact task summary with its identifier, title, duration and an obvious Start focus action.

The hero is centred within the available dashboard canvas, not the full window. The canvas naturally gains space when a sidebar is collapsed. Preserve readable type, sprite proportions and useful button sizes during this reflow.

Today should make it easy to arrive, see the companion, and choose a next action. Detailed issue work, the full timer experience, collection management and usage analysis belong on their respective pages. Avoid expanding Today into an inventory of every feature.

### Left navigation

The approved expanded sidebar contains the PokeTaskBar identity, account/workspace context, search, and labelled destinations:

- Today
- Focus
- Issues
- Projects
- Initiatives
- Collection
- Usage

Settings is anchored near the bottom. Selection uses a quiet neutral row fill. A collapse/reopen control remains discoverable in the window chrome. The compact icon rail from the original second concept is a reference for a possible collapsed state; exact collapsed-state behaviour should be tuned with the motion work.

### Right-side extras

Right-side panels contain optional supporting information, initially a short Today log and a compact usage glance with a route to the Usage page. They remain visually quieter than the Pokémon hero and primary next action.

No essential action should exist only in this rail. Hiding it must leave the central dashboard useful and complete. Its content changes with the active destination. Focus uses a companion panel and Session details panel, as specified below.

## Sidebars and interaction boundaries

Both sidebars are independently collapsible and resizable. Preserve each preferred width when it closes, and restore that width within the available window space when reopened. Let the centre take the released space. Avoid compressing labels, squashing sprites or allowing the primary action to become inaccessible at narrower sizes.

**Approved resting state:** no permanent sidebar separator, full-height section rule or resize grip dots. The shell gutter stays visually clean.

**Approved hover/resize behaviour:** a subtle, partly transparent guide appears when the pointer approaches the boundary, stays visible during the drag, and disappears afterwards. The resize cursor communicates the action. The visible guide and the usable pointer target can have different widths.

The [Animations task](codex://threads/01a0b28b-64c4-7fb3-812b-77222ebdcb1d) owns this refinement. Its [PTB - UI Motion & Animation Outline](https://linear.app/spawn-audio/document/ptb-ui-motion-and-animation-outline-6da069c18ba5) contains the detailed proposed timings, proximity handling, direct drag tracking, keyboard operation and Reduced Motion behaviour. Those timings are tuning proposals rather than measured Linear values.

## Menu-bar window

Adapt the shared design to a compact attached window, around the existing 400 × 640 pt starting size, with a rounded shell and clear hierarchy.

- A small PokeTaskBar header and utility controls sit above Focus, Linear, Usage and Collection tabs.
- A compact companion strip provides the Pokémon, name, rarity and progress.
- The active Focus view gives the selected issue title and state clear context, followed by a prominent timer and stable controls.
- Pause and Mark done are the primary controls; time adjustment and reset remain secondary.
- Pomodoro is a compact supporting entry, and Open Today is the clear route to the full dashboard.
- Keep status and sync feedback quiet. Actions that open the full app or a Linear issue should be distinguishable from timer controls.
- Use the approved dark graphite surfaces, subtle control outlines and small colour accents. Apply the same no-permanent-major-separators principle when refining the shared window structure; fine local grouping within the compact panel may remain.

The menu-bar mockup establishes appearance and information hierarchy. It does not change session lifecycle, completion rules, integration behaviour or the app's reward calculations.

## Floating pet and timer — approved horizontal overlay

Approved on 18 September 2026. Implement the thin Locu-inspired timer strip and the reviewed button interactions in both light and dark appearance.

![Approved floating timer button states in dark and light: rest, hover, pressed and after click](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/67c2e648-15e4-4c32-b29c-a7ea7641b440/f9eb1191-9574-4392-8716-ea3f4b44f995)

### Composition and resizing

* The expanded timer is a single 42 pt high horizontal strip, initially about 384 pt wide. Widening reveals more task context without increasing its height.
* Keep the unboxed Pokémon beside the timer, crisp and proportional. The timer and pet move together.
* Use the existing Linear-inspired menubar palette, a quiet 1 pt outline, roughly 9 pt corners, stable monospaced timer digits and a narrow cyan progress indicator.
* The right grip moves the entire overlay. The left edge resizes the strip horizontally with an appropriate cursor, keeping the right edge and pet anchored. Retain the user's width and position, with bounds that keep the overlay reachable.
* Apply the same styling to all three modes: expanded, compact/folded and pet-only. Compact uses a 153 × 34 pt outlined surface with monospaced countdown, Pause/Resume, Expand and New Linear Issue. Pet-only keeps the unboxed Pokémon and a 32 pt rounded-square timer toggle. Preserve the existing timer behavior and pet anchoring. The earlier tall expanded-card concept is superseded by this strip.

### Hover, press and completed actions

| Control | Rest | Hover | Pressed | After clicking |
| -- | -- | -- | -- | -- |
| Pause / resume | Quiet outline glyph | Subtle neutral fill | Slight inset/compression and stronger neutral fill | Switch to Play while paused; use a restrained cyan selected treatment |
| Add five minutes | Compact +5 label | Subtle neutral fill | Same pressed feedback | Add five minutes through the existing session logic; briefly highlight the control |
| Complete | Quiet checkmark | Subtle neutral fill | Same pressed feedback | Use the existing completion flow; preserve failures, confirmation rules and session accounting |

Controls reveal on hover without changing the outer strip width or moving the clock. Keyboard focus must also reveal them; accessible labels remain available. Use short transitions and respect Reduce Motion and increased contrast.

### Existing behavior and implementation boundaries

* Reuse the current FocusSessionStore clock, pause/resume, additional-time and completion paths. Do not introduce a second timer or change rewards, persistence, Linear state transitions, or duration limits.
* Preserve zero-time and check-in prompts, note posting, reset/forfeit confirmations, issue status controls, new-issue access, Pomodoro setup, fold controls and pet interactions. Secondary actions can move into the strip's overflow menu; prompt/composer surfaces can expand separately above it.
* Preserve all newer working-tree changes, including the adaptive menu-bar sizing and focus improvements. Implement against the current checkout, then validate and replace the identified installed app in place.

### Approved reference files

The interactive horizontal mockup and the light/dark rest → hover → pressed → after-click comparison are preserved under `Documents/ui-overhaul-v2/mockups/` as `floating-timer-horizontal.html`, `floating-timer-button-states.html` and `floating-timer-button-states.png`.

### Implementation and validation — 18 September 2026

Implemented in the native macOS overlay and installed by replacing `/Applications/PokeTaskBar v1.2.app` in place. The bundle identifier remains `io.github.spawnaudio.poketaskbar.v1.2`, retaining the existing settings and data directory.

* The expanded strip is 42 pt high with a persisted 288–720 pt width, hover/keyboard controls, explicit press feedback, a left resize rail and a right movement grip.
* Secondary actions remain in the overflow popover. Existing prompts, folding, notes, Pomodoro setup and session accounting are preserved. Adding time keeps the pre-existing behavior of resuming the countdown.
* Native checks cover both appearances, all seven languages, minimum/default/maximum widths, persisted resizing, pet anchoring through fold/unfold, keyboard movement and accessibility resizing.
* Focused validation: 112 tests passed; one optional menu-bar screenshot test skipped. The five new overlay tests also passed on the final run. Native light/dark overlay images were rendered and inspected separately.
* Release build succeeded; installed signature verification passed; the installed executable matched the built bundle and the replacement app relaunched.
* Preservation verification: all 218 pre-existing files outside the seven directly edited files remained byte-for-byte unchanged. Existing adaptive menu sizing and focus tests passed.
* Live Linear issue completion was not exercised against a real issue; the UI reuses the existing completion path. No changes were made to reward calculations or session timing logic.

### Compact and pet-only completion — 18 September 2026

The earlier implementation covered the expanded strip but left the compact clock and pet-only toggle on their previous styling. Both now use the shared Linear palette in light and dark, quiet 1 pt outlines and 7 pt corners.

* Compact groups the clock, Pause/Resume, Expand and New Linear Issue in one 153 × 34 pt surface. Pause/Resume calls the existing session action and stays folded; clicking the clock edits its remaining time; the chevron expands the timer. Paused state shows a cyan Play control. Overtime remains visible.
* Pet-only uses the timer glyph inside a 32 pt rounded-square control. It opens the existing Pomodoro setup; setup uses Cancel, and the expanded strip retains its collapse control. The pet remains unboxed and movable.
* Native hover and press feedback matches the expanded controls. Keyboard labels, increased contrast and Reduce Motion are retained.
* New native validation covers the actual compact and idle branches of FloatingPetView, using mouse events to verify Pause, Resume, Expand and timer setup in both appearances and all seven languages. Geometry checks preserve the compact footprint and pet anchoring.

* Final validation: all 119 focused tests passed. The release build and installed signature check succeeded; the installed binary matched the built bundle. The existing v1.2 app was replaced in place. All 328 other pre-existing files stayed unchanged, including the Poké Ball and Linear done-today count implementation.

### Expanded timer entry — 18 September 2026

Opening the timer from the pet must reveal the same horizontal design before a session starts. The initial implementation left this route on the old translucent setup card, even though the running strip was present.

* Pre-start setup uses the shared opaque 42 pt strip, saved width, monospaced planned time, duration menu, Start button and native move/resize handles. The adjacent close button returns to pet-only mode.
* Starting a timer keeps the strip width and pet anchor. Running mode retains hover controls, Pause/Resume, +5, Complete and the overflow menu. Compact and pet-only designs remain intact.
* Validate the complete native open → resize → start → pause → fold → expand flow in light and dark. Checks must confirm the surface is drawn and both drag handles exist; a reserved panel frame or an isolated strip preview is insufficient.
* Keep the red-and-white Poké Ball and Linear done-today count in the menu bar.

* Repair validation: all 120 focused checks passed. The new full-window regression failed on the old entry panel and passed after the fix. Coverage confirmed the setup-only resize path executed. The corrected release was built and replaced in place; the installed signature and binary were verified. All 327 other existing files, including the running strip, compact design and coloured menu icon, remained unchanged.

### Editable floating time — 18 September 2026

* Clicking the clock in setup, expanded or compact mode opens the same time picker, with 25/50/90-minute presets and a custom whole-minutes field. The compact chevron continues to expand the strip.
* Before starting, edits set the planned duration (5–180 minutes). During a session, edits set the time remaining. The picker shows the available range within the existing 180-minute total planned-time cap.
* Enter or Save applies the value; Escape or Cancel discards the draft. Invalid values leave the clock unchanged. Paused sessions stay paused; elapsed work, rewards and sleep state are preserved.
* Light/dark native checks exercise clock clicks, text entry, apply, cancellation and persistence without changing the smaller strip or its left resize/right move handles.

### New issue button on the floating timer — 18 September 2026

* A persistent plus button opens the shared New Linear Issue composer from setup, expanded and compact timer modes. It uses the existing Linear connection check, tooltip and accessible label.
* Opening or closing the composer leaves the current session and pet position unchanged. The compact surface is 153 × 34 pt to accommodate the extra action; the expanded strip retains its current size, editable clock and left resize/right move handles.
* Native checks click the button in all three modes in light and dark, verify the actual composer window, and confirm that disconnected Linear disables the action. No live issues are created by these checks.

### Choose focus duration before starting — 18 September 2026

* Selecting Focus on an issue opens a small anchored duration popover in the issue list and Today. Create & Focus opens the same picker before creating the issue.
* Show the task title, 25/50/90-minute presets and a custom whole-minutes field within the existing 5–180-minute range. Seed the field with the last planned duration; presets change only the draft.
* Start focus (or Enter with a valid value) commits the duration and starts the issue session. Cancel, Escape or dismissing the picker leaves the current session and saved duration unchanged.
* When switching from an active session, show the existing forfeit confirmation after choosing a duration. Carry that exact choice through confirmation; cancelling the switch preserves the original session.
* Use the shared Linear-inspired palette in light and dark. Keep keyboard entry available immediately and retain the existing floating timer layout and controls.

### Focus pop-outs — 18 September 2026

* Timed check-ins, time-up choices, reset and forfeit confirmations, and the floating note composer share the approved opaque graphite/white canvas, subtle 1 pt border, 8 pt corners and compact typography.
* Scope the existing Linear-style rectangular primary, secondary and quiet buttons to these panels. Preserve their actions, note entry, check-in schedule, confirmation rules and timer accounting.
* Keep the current expanded, compact and pet-only floating timer designs exactly as approved. Their sizes, colours, hover controls, clock editing, new-issue button, resize/move handles and positioning are outside this styling change.
* Native light/dark previews and the existing focus/overlay regression suite validate the change. The floating timer, pet, clock-editor and palette source files remain byte-for-byte unchanged.

## App flow and motion

Today is the home base. Its shortcuts and matching left-navigation entries lead to the same destinations. Start focus leads into the Focus experience for the selected task. The sidebar selection and page context update together, with an easy route back to Today.

Keep navigation fast and preserve useful context on return. Opening or closing a sidebar should not reset the current task, session or page. The Pokémon supplies personality while the surrounding controls remain restrained.

Motion should be smooth, short and interruptible. Keep the outer shell stable during page changes; coordinate panel movement with the central canvas. Pointer resizing tracks directly. Keyboard focus must remain usable, and Reduced Motion receives an appropriate alternative. Follow the dedicated motion outline for details rather than creating a competing set of animation rules here.

## Focus — approved layout

The approved first Focus option continues the Today window shell and expanded labelled navigation, with Focus selected. Today's Start focus action opens this page for the chosen task.

### Main content

- Keep the Focus heading and date near the top of the inset main canvas.
- Centre the active issue identifier, task title, status and project context above the timer.
- Make the remaining time the dominant element, using large stable monospaced digits. Place the planned-duration caption and slim progress track immediately below it.
- Keep Pause/Resume and Mark done directly below the timer. Mark done has the prominent dark fill; Pause/Resume is quieter. Time adjustment and Reset are tertiary controls.
- Place a compact session-note composer near the bottom of the main canvas. Its explicit Post note to Linear label communicates where the note goes.
- Preserve generous whitespace and stable control placement as the timer updates.

### Optional right-side extras

Use two separate rounded panels with a shell gutter between them: the Pokémon companion above, and Session details below. The details show the current status, planned duration and next check-in. The Pokémon is supporting context here; Today retains its dedicated large hero.

The main task, timer, controls and note composer remain available when the right sidebar is collapsed. Both sidebars retain the approved collapse/resize behaviour and clean boundaries at rest. These panels must not introduce permanent sidebar separators or visible resize grips.

This selection approves the visual arrangement. Existing timer lifecycle, pause, completion eligibility, reset confirmation, check-in and note-posting behaviour continue to apply. Example issue IDs, durations and timestamps remain illustrative.

Focus options 2 and 3 remain unselected exploration history. The approved Focus reference is option 1; see Approved mockups above for the other selected pages.

## Issues — approved layout

The selected second Issues option uses the shared inset canvas and expanded navigation, with Issues selected. The optional right sidebar is collapsed in the reference, leaving a wide main canvas.

- Keep the Issues heading, date, New issue action, In progress / Completed today tabs, local search and quiet sync feedback.
- Present a flat issue list with disclosure controls and compact rows. An expanded issue shows its identifier, readable title, status, project, team, priority, labels and description in place.
- Use a subtle rounded neutral surface for the expanded region. Keep the remaining rows unboxed, with spacing rather than separator rules.
- Put the planned duration and prominent Start focus action inside the expanded issue, with Open in Linear as a secondary route. Starting focus opens the approved Focus page for that task.
- Keep other issues visible below the expanded region, with status, identifier, title and project context.
- All essential reading and actions remain in the main canvas. Optional right extras may be restored, but are not needed for the approved inline workflow.
- Apply the shared sidebar collapse/resize behaviour, inset corners and clean boundaries at rest.

This replaces Issues option 3's project-grouped list and bottom Selected issue panel. Those are no longer the Issues implementation target. Option 1 remains unselected. Example data and incidental generated glyphs remain illustrative.

## Projects — approved List and Grid views

Projects uses option 1 as its default List layout and option 3 as an optional Grid layout. Option 2 remains unselected. Both modes use the same project data and the same shared navigation, inset canvas and optional right-side extras.

### Shared controls and view switching

- Keep Projects, In progress / Production tabs, Find a project and quiet refresh/sync feedback.
- Add a compact List / Grid switch beside the search field, with a clear selected state and accessible labels. The switch changes only presentation.
- Use List on first visit, then restore the user's chosen view. Preserve the selected project, search query, active status tab and useful navigation context when switching.
- Keep primary navigation and issue access in the main canvas so hiding the optional right sidebar leaves both modes usable.
- Project actions lead to that project's issues. Start focus applies only to an individual issue, never to an entire project.

### Default List — option 1

Use expandable project rows with a project icon, title, issue count, brief description, lead and target date. Expanded projects reveal compact indented issue rows. The selected issue may show its planned duration and Start focus control directly in the row. Keep labels and priority information aligned without boxing each issue.

The optional right rail shows Project details and About this project in separate rounded panels, including status, lead, target date, description and an Open in Linear link.

### Alternate Grid — option 3

Show projects as meaningful standalone cards in a responsive grid. Each card includes the project identity, brief purpose, status, issue count, target date and a route into the project. Selected cards use a quiet neutral tint.

The selected card's View issues action opens the approved Issues view scoped to that project. Open project actions expose the project's detail and issues. The optional right rail shows Project details and a compact Issues in this project preview; it does not hold the only route into those issues.

### Visual continuity

Keep both modes calm and consistent: neutral surfaces, readable typography, modest icons, open gutters and no permanent major section/sidebar separator strokes. Preserve card and sprite proportions during resizing. Use actual project information in implementation; mock names, counts and dates are illustrative.

## Initiatives — approved Expanded and Overview views

Use option 2 as the default main view and option 3 as an alternate overview of the same initiatives. Option 1 remains unselected.

### Shared navigation and view switching

- Keep Initiatives selected in the shared sidebar, with Active / Planned tabs, Find an initiative and quiet sync feedback.
- Add an Expanded / Overview switch beside the search controls, using a clear selected state and accessible labels.
- Start with Expanded on first visit; remember the user's preference. Preserve the selected initiative, search query and active status tab when switching.
- Both modes lead from an initiative to a project, then to an issue and Focus. Never start a focus session for an entire initiative.
- Keep essential project navigation in the main canvas and maintain the shared collapsible/resizable sidebars. The references illustrate different sidebar visibility states; users retain independent control of the extras sidebar.
- Project counts and project relationships must reflect actual linked data. Names, counts, purposes and dates in these mockups are illustrative.

### Default Expanded — option 2

Present one initiative expanded in place on a gently tinted rounded region, with a clear title, purpose sentence, status, owner, target date and secondary Open in Linear route. The reference shows the optional right sidebar collapsed.

List the initiative's projects as spacious rows within the expanded region. Each has an identity, brief purpose, issue count and Open project action. Other initiatives remain compact collapsed rows below, retaining their purpose, project count and target. Use whitespace and alignment rather than separator strokes or nested cards for every row.

### Alternate Overview — option 3

Show a compact initiative list with purpose, project count and target date. A quiet selection fill identifies the current initiative. Display that initiative's project cards below the list, with purpose, issue count, target date and Open project actions.

The optional right rail holds Initiative details and Purpose in separate rounded panels. Selecting another initiative updates its project area and supporting details together. These panels remain supplemental.

Both modes follow the same neutral palette, readable type, restrained icons and inset corners. Major section/sidebar boundaries stay clean at rest; resize guides appear only during pointer approach or resizing.

## Collection — approved Pokédex layout

Use option 3 as the Collection Pokédex browsing layout. Options 1 and 2 remain unselected. This approves the Pokédex screen and Collection navigation, not a new reward system or changes to training and storage rules.

### Navigation and browsing

- Keep Collection selected in the shared sidebar and preserve the local Bag, Storage, Pokédex and Shop destinations. Pokédex is the default.
- Retain the Pokédex / Catch log choice within the Pokédex area.
- Place Find a Pokémon, rarity and shiny controls above the browser, with a quiet species count.
- Show a compact scrollable species list with small pixel sprites, species numbers and readable names. A subtle neutral-blue fill identifies the selection.
- Keep the list and selected-species workspace together inside the main inset canvas. Use whitespace and surface tones rather than a permanent vertical dividing stroke.
- The optional right extras sidebar is collapsed in the reference. Browsing and selected-Pokémon actions remain usable when it is hidden.

### Selected Pokémon workspace

Show the name, species number, rarity and raising state clearly above a crisp proportional sprite. Place Set representative below the artwork, followed by a compact profile summary and a View details route into the existing complete species and individual details.

Set representative changes the representative display; it does not start training, swap a stored partner or begin focus. Use an appropriate representative/star icon rather than the generated play glyph in the mockup. Preserve individual selection where a species has multiple collected entries.

Keep the profile data factual and specific to the selected entry. Level 32, the twelve displayed species and other sample details are illustrative. Keep sprites crisp at resized widths and make the browser scroll rather than shrink labels.

### Collection subviews

Bag follows the separately selected Pokémon-hero layout below. Storage follows the separately selected Pokémon preview workspace. Catch log follows option 3, Individual History Workspace. Shop and full species/individual detail remain existing routes whose content-level redesigns are still to be reviewed. Preserve their existing actions and data while applying the shared window styling where appropriate.

## Collection Bag — Pokémon hero and item browser

Use the selected option 3 structure with the user's requested Pokémon-first hierarchy. Keep Bag inside Collection's Bag / Storage / Pokédex / Shop navigation. The optional right extras sidebar is collapsed in this reference.

### Item browser and main hero

* Keep a compact item browser inside the main canvas. Show the item's small sprite, name and quantity for consumables, with a quiet selection fill.
* Separate stored eggs through a small label and whitespace. Keep each egg's Train action and a Manage in Storage route available.
* In the adjacent main workspace, lead with the **actual current training Pokémon**: its name, modest current/level context and a large crisp proportional sprite. This is the main hero of Bag.
* Place the selected item's small icon, name, available quantity and clear effect below the Pokémon. Keep them secondary to the hero and avoid heavy nested cards.
* Keep Use item below the item summary, with a text-only label rather than a Play glyph.
* Both the browser and all essential actions stay inside the inset main canvas. Preserve the shared rounded surfaces, open gutters and no-permanent-major-separators rule.

### Existing item and training behaviour

Rare Candy and Mint act on the current training Pokémon, not a chosen representative or an arbitrary stored entry. Selecting an item updates the details without consuming it. Use item opens the existing inline confirmation naming the current Pokémon, followed by Use and Cancel.

Preserve existing eligibility, unavailable reasons, inventory accounting and the post-use Focus route for XP/evolution feedback. Use actual model constants for effects; the reference shows Rare Candy +1.5M XP and illustrative quantities.

Shiny Charm remains passive: show its owned/active effect without a quantity, Use, Equip or consumption action. Its details can replace the consumable summary beneath the hero without implying a targeted application.

Fresh Egg remains a stored egg. Train uses the existing inline swap confirmation; do not add immediate hatching, timers or invented progress. Preserve the current partner through the existing storage flow.

Keep the existing quiet empty-Bag state. Do not add item prices, balances, battle stats, equipment slots, bulk use, sale or trade controls to this layout.

This requested Pokémon hero correction supersedes the original third concept's large candy and the earlier exploration instruction to keep Pokémon small on Bag. Lapras, level 32, five candies, two mints and one stored egg are illustrative; render the real current Pokémon and inventory.


## Collection Storage — approved Pokémon preview workspace

Use the last displayed Pokémon Preview Workspace, saved as Storage option 3. Options 1 and 2 remain unselected.

### Browsing and visual hierarchy

* Keep Storage inside Collection's Bag / Storage / Pokédex / Shop navigation.
* Show a compact current-trainee strip above the browser, with a small sprite, name and modest level context. The active trainee is separate from the stored-entry list.
* Keep a compact stored list on the left inside the main canvas, with each entry's sprite, name and existing evolution-stage or stored-egg metadata.
* Selection updates the adjacent preview without swapping the trainee. Identify the selection with a quiet neutral-blue fill.
* Make the selected stored Pokémon's crisp proportional sprite the main artwork in the preview. Keep its name and stage/state clear.
* Put the training action and explanation below the preview. The reference shows the right extras sidebar collapsed; all essential browsing, identities and actions remain in the main canvas.
* Preserve the approved inset rounded panels, open gutters and clean sidebar/major section boundaries at rest.

### Train and preserve progress

Train first opens the existing inline confirmation, naming the current trainee and making clear that it moves to Storage with its progress kept. Explicit Train commits the existing swap; Cancel leaves the active trainee unchanged. Selecting a row alone never swaps or starts a focus timer.

Use the same confirmation for a stored egg. Preserve its existing tier information and state; do not invent immediate hatching, countdowns or hatch progress.

Keep the single training slot, stable individual IDs, stored progress, loading/unknown-name handling and the existing empty-storage state. This layout introduces no release, deletion, trade, bulk action, storage capacity limit or new reward rule.

The reference's Lapras level 32, three starter Pokémon, evolution-stage labels and one Fresh Egg are illustrative. Render actual saved entries and current-trainee data.

## Collection Catch log — approved Individual History Workspace

**Selected layout: option 3.** Catch log remains within Collection → Pokédex → Catch log. Keep the approved expanded left navigation, floating inset main canvas, open gutters and visible rounded bottom corners. Both sidebars remain independently collapsible and resizable; no permanent sidebar or major-section separator strokes, edge-to-edge rules or resting resize grips. Only the previously assigned motion task may add the subtle proximity/drag guide.

### Individual browser and Pokémon hero

- A compact browser on the left of the main canvas shows the individual records, their small sprites, dates and Raising / Trophy / Released state. Selecting a row updates the adjacent preview with a quiet neutral row fill.
- Pin the current raising record first, followed by historical records newest first. Preserve distinct individuals of the same species: the two illustrative Lapras rows have different catch dates and states. Use stable individual IDs, not species IDs, for selection.
- Make the selected individual the large Pokémon hero. In the approved image this is Gengar; it is a historical Trophy, while Lapras remains the current trainee. Keep artwork crisp and proportional.
- Show the selected record's rarity and state beside its name, recorded nature and catch timestamp below, and the evolution chain with small sprites and names. View details opens the existing detail route for this exact individual.
- Keep all essential record metadata, filters and actions in the main canvas so optional right-side extras can stay collapsed. Separate the browser and preview with open space rather than a vertical line.

### Filters, chronology and existing behaviour

- Use one compact rarity/shiny filter interface with counts. Counts refer to individuals; Shiny overlaps rarity totals. Preserve Uncommon and Legendary choices even when the example has zero of each.
- The six illustrative records and dates in the reference are mock data. Read rarity, nature, timestamps, evolution order and state from actual records. Preserve unknown legacy metadata as unknown, with undated history after dated records.
- Released is a historical state, not a new action. Selecting a record only changes browsing. This page adds no Train, Use item, Release, trade, delete, export or manual logging controls.
- Use the real shiny sprite and an accessible Shiny label when the record is shiny; approximate generated sprite colours are not authoritative.
- Preserve empty collection, zero-result, loading and unknown-data states. Retain scroll position when opening and returning from details.

## Usage — approved Overview, Provider and Limits views

Usage opens in Usage Overview, with Provider Workspace and Limits First available through a local view switch. These are presentations of the same Usage destination.

### Shared controls and data

* Place an Overview / Provider / Limits view switch near the page heading. Start in Overview, then remember the user's chosen view.
* Preserve the selected provider, refresh state, useful page context and independently controlled sidebar widths and visibility when switching.
* Keep token consumption, official provider limits and Time XP clearly distinct. Show actual values in implementation; the mockups use illustrative totals and reset times.
* Today, week and month totals describe locally counted tokens. Provider totals and input/output/cache breakdowns use the same period and should reconcile with those totals.
* Official remaining percentages come from the selected provider's quota source, not the local token count. Label bars as remaining and fill them accordingly; show each window's reset time.
* Preserve loading, unavailable, stale, expired-auth and error states. Missing readings are not zero consumption or zero remaining capacity. Keep refresh available.
* Time XP retains the existing enable toggle, today's awarded XP, daily cap, reward interval and next-award information. It is not a token provider and does not increase token usage.
* Increased consumption is neutral. Do not add celebratory arrows, token goals, invented budgets or billing estimates.
* Apply the shared inset panels, calm typography and no-permanent-sidebar-separators rule. Any incidental strokes in generated references do not override that rule.

### Default Overview — option 1

Lead with today's token total and quieter week/month totals. Give the daily consumption chart the main supporting surface, with modest bars, readable units and sparse dates. Keep the provider list and selected-provider breakdown below it.

Use the optional right extras for the selected provider's official limits and a separate Time XP panel. Keep a View limits route beside the selected provider in the main canvas; Time XP remains reachable when extras are hidden. Charts must represent real observations and not invent future days.

### Alternate Provider — option 2

Use the wide main canvas for a provider selector, selected-provider token total and aligned input/output/cache breakdown. Keep the all-provider summary compact and clearly labelled.

Show the selected provider's official quota windows and reset times directly in the main canvas. A compact daily-usage disclosure leads to the shared chart; a horizontal Time XP group remains available below. The reference shows right extras collapsed, but switching views must respect the user's independently chosen sidebar state.

The refined second image is the approved Provider reference. Its earlier rendering with additional divider strokes is superseded. These selections approve composition and view switching, not new tracking, account access or reward calculations.


### Alternate Limits — last displayed Usage image

Give the selected provider's official remaining capacity the strongest emphasis: separate 5-hour and weekly windows with clearly labelled remaining percentages, proportional capacity bars and reset times. Keep the provider picker in the main canvas.

Keep Today, week and month token totals quiet at the top. Place the all-provider daily usage chart below the capacity section, with explicit token units and period.

The optional right extras hold provider totals and token breakdowns, followed by Time XP. Provider selection remains in the main canvas; the Provider view also exposes breakdowns when the extras are hidden. Time XP remains accessible through the shared Usage settings. Preserve independent sidebar visibility and widths across all three views.

All three views use the same underlying readings, refresh state and provider selection. The layout switch changes emphasis without changing quota calculations, token accounting or reward behaviour.

## Settings — approved inline layout

Use option 3, Inline Settings. Keep the expanded main app navigation with Settings selected near the bottom. The main pale rounded canvas holds the settings browser; optional contextual help occupies a separate right-side panel.

### Finding and adjusting preferences

* Put Settings, a short quiet introduction and Find a setting at the top of the main canvas.
* Use an accordion: General starts expanded in one meaningful white grouped surface. Other categories remain compact, unboxed disclosure rows. Reveal the chosen section in place, one at a time, and keep the expanded controls in view.
* Preserve the six General controls: language, representative Pokémon, refresh interval, animation quality, limit display and launch at login. Align labels and controls; use spacing rather than row or section rules.
* Keep the concise battery explanation beside animation quality. Show Used / Remaining as a labelled segmented choice; its actual value follows the saved preference.
* Language, toggle and dropdown changes keep their existing immediate-apply behaviour. Do not introduce a global Save/Cancel footer. Credential fields retain their existing explicit Save actions within their own section.
* Search should reveal and focus the relevant section/control. Reconcile keyboard shortcuts with app-wide search; do not duplicate an incidental generated shortcut.
* Preserve focused-control accessibility, keyboard disclosure operation and readable control sizes when the window narrows.

### Category organisation

General is followed by Desktop, Notifications, Connections, Difficulty, Updates, Data & backup, Advanced and About & support.

Desktop groups the existing Menu bar and Floating pet controls. Connections contains the existing Linear settings. The remaining groups retain their current functions, including notification thresholds, Time XP, update checks, save export/import, session-key and scan-path settings, logs and support. The approved screenshot shows category organisation and General; it is not approval to remove any controls from unopened groups.

Keep advanced inputs behind their disclosure during ordinary browsing. The existing expired-session-key route must still open Advanced and focus the relevant field directly. Preserve import confirmations, errors, disabled states and the existing credential handling.

### Optional contextual help

Show one modest panel explaining the expanded section. In General, explain following the current companion versus choosing a representative from Collection, with a quiet Open Collection link.

This help is supplemental: the representative control and its Collection route remain in the main canvas when extras are hidden. Both sidebars remain independently collapsible/resizable, with open gutters and no permanent separator strokes or resting grips.

The mockup's English, Follow current, 2 min, Balanced, Remaining and launch-at-login values are illustrative. Use actual saved preferences. Options 1 and 2 remain unselected. The selection approves visual organisation, not new account, theme, cloud, tracking or reward features.


## Page-by-page approval workflow

Continue the design exploration one page at a time. When the user selects a page design, add that exact mockup and its styling/layout decisions to this document, verify the image, and immediately begin mockups for the next page without a separate continuation prompt.

Today, Focus, Issues, Projects, Initiatives, Collection, Usage, Settings and the menu-bar window are approved. Issues uses option 2; Projects defaults to option 1 with option 3 as an alternate; Initiatives defaults to option 2 with option 3 as an alternate; Collection uses option 3 for Pokédex browsing. Usage defaults to Overview, with Provider and Limits as alternate views. Settings uses option 3. Main navigation layouts are now selected. Collection Bag uses option 3 with the user's requested Pokémon hero correction. Collection Storage uses the last displayed Pokémon Preview Workspace, saved as option 3. Collection Catch log uses option 3, Individual History Workspace. Continue with the remaining Collection subviews in order: Shop, then full Pokémon details. Page layouts remain proposals until selected. This workflow covers design mockups; production implementation is a separate step.

## Visual review checklist

- Today retains a large centred Pokémon hero and useful quick navigation.
- Expanded navigation matches the selected combined mockup.
- Panels retain rounded corners and open surrounding gutters.
- Major sidebar/section boundaries are clean at rest; temporary guides appear only for interaction.
- Essential content works with either or both sidebars hidden.
- Text remains readable and sprites retain their aspect ratio during resizing.
- Hover, selection, press and keyboard focus are distinguishable in both appearances.
- Timer and session controls keep stable placement and use existing behaviour.
- Mock data, incidental glyphs and generated copy are checked before becoming product requirements.
- New page concepts remain proposals until selected.

## References

- [Linear App Design Breakdown](https://linear.app/spawn-audio/document/linear-app-design-breakdown-a616cfb54f0a) — main external styling reference.
- [Linear Styles](https://linear.app/spawn-audio/document/linear-styles-ec0c89494ba4) — supporting themes and colour resources.
- [PTB - UI Motion & Animation Outline](https://linear.app/spawn-audio/document/ptb-ui-motion-and-animation-outline-6da069c18ba5) — motion and sidebar interaction detail.
- [Design Mockups task](codex://threads/01a0b269-3b7a-71a0-ae64-ec0f4fc45e10) — selection history and new page exploration.
- [Animations task](codex://threads/01a0b28b-64c4-7fb3-812b-77222ebdcb1d) — motion study and assigned refinements.

Local source copies are preserved in the repository under `Documents/ui-overhaul-v2/mockups/`.
