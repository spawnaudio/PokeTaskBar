---
summary: "Linear initiative cards based on the 27 September 2026 reference screenshots."
read_when:
  - Changing initiative summaries, relationship metadata, or project health rollups
---

# Linear initiative cards

**Pin to top** persists initiative IDs in local preferences across app restarts and
puts pinned cards first in main-window and menu-bar lists, within the current
tab and search. **Unpin from top** removes the pin. Refresh checks saved initiative
IDs in batches of 50 because completed initiatives leave the active/planned feed;
confirmed completion clears the saved pin. Missing data and failed requests retain it.
Pin validation and its local-only scope are recorded under
[Project controls](linear-project-cards.md#project-controls); initiative checks also
cover completion outside the active/planned feed and requests spanning multiple batches.

`LinearInitiativeCard` shares one expandable summary across the main window
and the compact menu-bar Initiatives page. It uses a colored initiative icon,
title and description, priority, owner avatar, lead team, target, completed/total
projects, initiative health and project-health dots. Wide cards keep properties beside
the title; compact cards wrap them below. The existing issue-card metadata preference
also controls initiative label pills and status. Label-group names such as Area and
Outcome are retained in tooltips and accessibility labels. Quarter and half-year
targets reuse the project card's date formatter.

**Minimize card** leaves the title, initiative icon, pin and Linear link visible;
description, properties, labels and nested projects are hidden.
See [shared minimize behavior](linear-issue-cards.md#minimize-cards).

Clicking a summary expands its existing project cards. The separate link and context menu open Linear. Native
buttons preserve keyboard access, expansion respects Reduce Motion, and surfaces use
appearance and increased-contrast settings. Nested projects retain their own issue
loading and controls. Their issue cards start **Minimized**, and each issue-status
header folds or unfolds its own section. Issues represented by a project are not
duplicated below it.

The toolbar has an Active / Planned status dropdown, the shared persistent
**Issue Filter** checkbox popover, and sorting by name, priority or target date
(the initiative fields currently loaded). Missing values sort last, and ties use
name then ID. Pinned initiatives remain first with a small divider before unpinned
matches. The Expanded / Overview switch and Overview mode have been removed.
See [Project controls](linear-project-cards.md#project-controls) for shared filter
and divider behavior.

Metadata loads separately from issue previews in batches of ten initiatives. Project
relationships paginate in pages of 100 before counts are exposed; failed enrichment
keeps the prior summary and issues. Duplicate project IDs count once. Missing totals
are omitted. Label previews are capped at 30 per initiative. The existing dashboard
limit of 50 active/planned initiatives is unchanged.

The supplied screenshot's Active Projects column counts reported health across project
statuses, including completed work. Started projects without an update use gray;
unstarted projects without an update have no health indicator. This reproduces the
reference totals (for example, seven green projects for Fun Side Projects). Initiative
health is separate from this rollup. See [Linear's initiative documentation](https://linear.app/docs/initiatives).

## Validation — 27 September 2026, Australia/Perth

Native previews cover 240, 360 and 1000pt, light/dark, and both metadata modes. Mouse
events expand/collapse the production view and reveal project cards without starting a
focus timer. The wide-layout height check prevents long descriptions from forcing the
compact layout at desktop widths. Fixtures exercise complete/missing metadata,
relationship pagination, repeated/failed pages, preserved issue previews, duplicate
IDs and health reported on non-started projects.

The final focused run passed 93 checks with one unrelated project-toolbar preview
skipped. It includes Linear client/rewards, issue/project/initiative cards, project
controls, planned work, main-window navigation/rendering, lazy-list checks and SwiftUI
isolation. A broader name-matched run also reached the existing companion-growth and
old Today Desk style failures; the full repository gate was not rerun or declared green.

Read-only live requests accepted the exact production metadata query for all eight
active/planned initiatives and confirmed the reference labels, date resolutions and
health totals. No Linear writes were made. Remote avatar downloads were not verified.
Preview images are generated in `build/initiative-cards/`; before/after containing
workspace captures were also inspected. This work does not replace the installed app.
