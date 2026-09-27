---
summary: "Linear-style issue cards shared by the main window, popover, and project/initiative issue lists."
read_when:
  - Changing issue-card layout, metadata visibility, or card controls
---

# Linear issue cards

The 19 September 2026 screenshot references use a small rounded surface, muted issue
identifier above the title, an assignee avatar at the upper right, a workflow icon beside
the title, and wrapping outlined metadata pills. The shared `LinearIssueEntityRow`
now uses that structure at every issue-list call site.

The sliders menu switches between **Minimal** and **All available**. Its shared
`linearIssueCardAllMetadata` preference defaults to false. Minimal shows priority,
due date and project; both modes retain the ID, title, status and assignee. All available
adds time in progress, cycle, milestone, estimate, team, labels and created/updated dates
when those values exist. Labels retain their Linear colors. Missing values add no
placeholder pills. Date-only deadlines keep their intended calendar day in every time zone.

Clicking the card reveals its metadata, description, recorded completion details and
the existing Focus action. The issue ID opens Linear; the workflow and priority icons
retain their existing update actions. Expansion alone does not create a focus session.
Status changes carry the new workflow color through the optimistic update.

The small target button beside the assignee opens a duration menu: **15 min**, **30 min**,
**45 min**, **1 hour**, and **Custom Time**. Custom Time uses the existing validated
minute picker. Choosing a duration goes through the shared focus session, including
its confirmation before switching away from an active issue. Opening the menu alone
does not start a timer. The expanded Focus action remains available.

Issue tabs are **In progress**, **Todo**, **Planned**, and **Completed** in both the
main window and compact Linear page. Todo matches the named workflow status rather
than all unstarted issues. Completed is a label change and retains the existing
completed-today data window. Each tab remembers its own sort choice while its
navigation/view is alive: priority, earliest due date, recently updated, newest
created, or title A–Z. Missing dates sort last; the default remains priority.
At narrow widths the main-window tab strip scrolls horizontally without breaking labels.

The current data boundary still applies: nested container previews omit labels, and
sub-issue progress and team-specific estimate display names are not fetched. Estimates
use the numeric value already supported by the app. No counts or metadata are invented
to reproduce the reference screenshots.

Expanded project cards now fetch the full non-archived issue list, including labels,
and group it by workflow status. See [Linear project cards](linear-project-cards.md)
for that surface's layout, loading behavior and validation.

## Minimize cards

The title-row chevron minimizes each issue independently, leaving its title, identifier,
status, assignee and Focus control visible. Everything below the title is hidden,
including metadata in both display modes, dates, descriptions and expanded actions.
The chevron or a click on the minimized card restores its previous expansion state.
This is local view state and resets when that card view is recreated.

The same control is available on [project cards](linear-project-cards.md) and
[initiative cards](linear-initiative-cards.md), including nested and menu-bar cards.
It respects Reduce Motion and has localized tooltips and accessibility labels.

## Validation

`LinearCardMinimizeTests` uses native mouse events on Issues, Projects, Initiatives
and Overview summaries at 240/1000pt, in light/dark and both metadata modes. It checks
title-only height, restoring summary/expanded content, and no focus, pin or selection
side effects. Set `PTB_MINIMIZE_PREVIEW_DIR` to save summary/minimized captures.
The minimize follow-up passed 22 focused tests with three optional window previews
skipped; the relevant full-workspace preview then passed separately. Native card
previews and coverage regions were inspected. This is fixture validation, not live
Linear verification or an installed-app replacement.

The subsequent requested build-and-replace installed the minimize feature in
`/Applications/PokeTaskBar v1.4.app` and verified a single launched instance (PID 46052).
All 103 build inputs stayed unchanged; bundle signing passed and the installed
executable matched the built app. SHA-256:
`4235f28ca3a61da46b1a6d1f09884df8ee32d75e8d3768a4c0306b0c1822db47`.

`LinearIssueCardTests` checks metadata parsing, optional values, workflow-color responses
and date-only deadlines in three time zones. Set `PTB_ISSUE_CARD_PREVIEW_DIR` to capture
the production SwiftUI card in light/dark at 240, 340 and 620pt outer widths. This check
also sends native mouse events to expand the card and verifies that the timer stays idle.
`MainWindowTests.testRenderPlannedWorkspaces` covers the containing Issues, Projects,
Initiatives and compact popover surfaces with injected Linear data.

The focused 19 September run executed 79 tests: 76 passed, one unrelated opt-in preview
was skipped, and two existing `TahoeButtonStyleTests` assertions failed. The latter
expect `LinearPropertyRow` in `TodayDeskView.swift` and prohibit existing segmented
pickers; both causes were confirmed in the pre-change HEAD. Card/Linear tests and
native expansion/navigation checks passed. Renders use fixtures; they do not prove a
live account sync or remote avatar download.

The 27 September follow-up passed all 155 targeted Linear, sorting, focus, window,
and SwiftUI-isolation checks, including native light/dark card and workspace previews.
Before/after renders retain the card geometry and metadata layout with the target
button added. Todo tests cover named-status matching, team-state hydration, container
merging, optimistic status/priority edits when refresh fails, and clearing credentials.
Sort tests cover missing dates, stable ties and independent tab selections.

The full gate ran 1,445 tests (15 skipped) and reported 75 failed assertions across
14 tests. Twelve failing tests reproduced in a saved copy of the starting code;
the two floating-panel interaction tests passed in isolated reruns. The missing
`@MainActor` annotation on the existing window border was fixed and its check now
passes. Other pre-existing failures remain in companion growth, save-transfer field
coverage, settings visibility and old UI style assertions, so the full gate is not green.
This validation uses injected Linear data and does not establish live-account sync.
