---
summary: "Linear project cards and expandable issue status sections, based on the 27 September references."
read_when:
  - Changing project-card layout, project metadata, or expanded issue loading
---

# Linear project cards

`LinearProjectCard` is shared by the main-window Projects list and grid, projects
inside Initiatives, and the compact menu-bar Projects page. It follows the supplied
27 September screenshots: muted project ID; health, status, priority and lead avatar;
colored project icon and title; two-line description; date range and teams; initiative
and additional count; label dots; next/overdue milestone; customers; and issue count.
Missing metadata is omitted. Emoji render directly; Linear's named decorative icons
use SF Symbol equivalents. Customer logos and lead avatars use their supplied URLs.

The title-row **Minimize card** chevron hides the description, metadata, issue count
and expanded issue list while retaining the title and header icons/controls. Restoring
the card retains its own prior expansion state. See [shared minimize behavior](linear-issue-cards.md#minimize-cards).

The entire summary area expands/collapses the card. The project ID opens Linear;
the context menu also opens Linear and retains the main-window Issues navigation.
Expansion respects Reduce Motion. Cards adapt to appearance and increased contrast.
Month, quarter, half-year and year targets retain their date resolution, and date-only
values retain their calendar day across time zones.

Opening a project fetches all non-archived project issues through cursor pagination,
including completed and canceled work. Each populated workflow status gets an icon,
name, count and its existing issue cards. Click the status header to fold or unfold
that section independently; sections start unfolded and respect Reduce Motion.
Distinct custom states remain distinct,
including identically named states from different teams. Categories follow workflow
order, states use configured positions where available, and issues keep priority order.
Issue status, priority and Focus controls retain their existing behavior. Changing
status moves an issue between sections; closing it keeps it in a fully loaded project.

The collapsed count uses Linear's `currentProgress.scopeCount`, not the short issue
preview. If unavailable, a full loaded list supplies the count; otherwise the count
is explicitly marked as a preview. Failed full fetches preserve the preview and expose
Retry. Completed pages are applied together, so a failed later page cannot silently
become the complete list. Closing the card cancels its loading task; credential changes
and newer dashboard snapshots prevent stale results from being applied.

Project relationship metadata is requested separately from nested preview issues,
in batches of up to 50 projects. The combined query exceeded Linear's 10,000-point
limit in live validation. Relationship previews are bounded to 5 teams, 10 initiatives,
20 labels/milestones/customer requests per project; duplicate customers are collapsed.
Failure to enrich metadata preserves the existing project dashboard. A dashboard
refresh replaces previews and reloads currently expanded cards.

## Project controls

The card's **Pin to top** button persists project IDs in local preferences across app
restarts. Pinned cards lead the current filtered list or grid and nested initiative
projects, preserving the selected order within each group. **Unpin from top** removes
the pin. A dashboard refresh clears pins for confirmed completed projects, including
custom status names whose type is `completed`; missing data does not clear pins.
A small divider separates pinned and unpinned matches. In Grid it spans the full
width between the two groups; no divider appears when either group is empty.
Pin validation: 84 focused checks passed, with three optional full-window previews
skipped. Coverage includes preference reloads, manual unpinning, confirmed completion,
failed/missing sync data, stable ordering, native pin-button clicks without expansion
or Focus changes, and narrow/wide card renders in light/dark. This is local fixture
validation; no live Linear status changes or installed-app replacement were performed.

The subsequent pin-feature build-and-replace installed and relaunched
`/Applications/PokeTaskBar v1.4.app` (PID 36350). Signing verification passed, the
103 recorded build inputs stayed unchanged, and macOS confirmed launch completion.
Built and installed executable SHA-256:
`8e4a5a60da016a3fff5a05bf76c3ff1f8ee3809324a592736b951a77f274c71e`.

The **Issue Filter** button opens a popover of native checkboxes, which stays open
while selecting or deselecting multiple statuses. Hidden status choices persist in
`hiddenLinearIssueStatuses` and are shared by Projects, Initiatives and the menu-bar
pages. All statuses start visible; **Show all statuses** resets the filter. Custom states
such as Todo and Planned remain separate. Choices include team workflow states even
when no preview issue currently occupies them. Filtering never changes a project's
total issue count; an empty filtered expansion explains that no selected statuses match.

The current project status is a dropdown using Linear's complete project-status
catalog, including unused custom statuses, plus **All**. The dashboard
paginates all non-archived projects instead of selecting only started projects. If
the status catalog is unavailable, tabs fall back to the statuses present on projects.

The sort menu offers name A–Z, priority, earliest target/start date, recently updated,
and newest created. Missing priorities/dates sort last; ties use name then ID. Search,
status selection and sorting work together in both list and grid. Main-window selections
survive page navigation; the compact Projects page keeps its own session selections.
Issue-card metadata preferences elsewhere remain available.

## Validation

The 28 September merge check built successfully and ran the complete suite: 1,469
tests, 22 optional skips and 60 failed assertions across 11 tests. Every failing
test also fails in the current `Master` CI run; no new failing test names appeared.
All Linear feature suites passed. The repository-wide gate remains red because of
those existing failures; focused native interaction results are recorded below.

The streamlined workspace-controls follow-up passed 90 focused checks, with two
unrelated optional window previews skipped. Native mouse checks cover independent
status folding, multiple checkbox changes without dismissing Issue Filter, and
minimized issue defaults through the actual initiative-to-project view. Preference
reloads, initiative sorting, and pinned divider boundaries are covered separately.
Light/dark Projects list/grid and Initiatives previews are in
`build/workspace-controls/`. This verifies local fixtures; no live Linear mutations
were used, and the full repository gate was not rerun.
The additional native reset check passed: **Show all statuses** clears the selections
without dismissing the popover. The follow-up replaced and relaunched the installed
`/Applications/PokeTaskBar v1.4.app` (PID 55778). Bundle identity, signature, unchanged
build inputs and completed launch were verified. Built/installed executable SHA-256:
`71ab05045b8987cbde1529497caf6ae5ece51d729dd46b8c8a3a867c6e65994b`.

The focused 27 September run passed 82 tests, with no skips: Linear client, project
and issue cards, sorting, rewards, planned work, main-window navigation and rendering,
and SwiftUI isolation. Production project cards were captured at 240, 350 and 620pt
in light/dark, with actual mouse expansion/collapse and an idle-timer assertion.
Fixtures also cover missing metadata, duplicate customers, custom/unknown statuses,
closed issues, pagination errors/repeated cursors, date resolution and optimistic
status moves after a failed refresh.

Read-only live requests verified the production container and metadata queries against
seven active/production projects. The screenshot's routine project returned 32 issues
across Backlog, Planned, Todo, In Progress and Done. No live mutations were performed.
Native interaction checks use fixtures; they do not establish remote avatar loading.
The full repository gate was not rerun for this feature; known baseline failures are
recorded in `linear-issue-cards.md`.

The local v1.4 release bundle built successfully with `PTB_SKIP_INSTALL=1` and passed
`codesign --verify --deep --strict`. This build did not replace the installed app.

On the subsequent build-and-replace request, `/Applications/PokeTaskBar v1.4.app`
was rebuilt, replaced in place and relaunched. Installed signing verification passed,
the installed executable matched the built executable's SHA-256, and the running
process was verified at the installed path.

The project-controls follow-up passed 91 focused tests with no skips or failures,
including the concurrent initiative-card changes. Coverage includes all project and
status-catalog pages, every sort option and missing values, distinct issue statuses,
navigation retention, native expansion/filtering/collapse, and narrow/wide list/grid
renders in light/dark appearance. Read-only live queries returned 36 non-archived
projects and nine project statuses, including unused custom statuses.

The controls build also replaced `/Applications/PokeTaskBar v1.4.app` in place and
relaunched successfully (PID 28910). Installed signing verification passed, source
inputs remained unchanged during the release build, and built/installed executables
both had SHA-256 `689ef7c884d25e9ea31eca461014d836f79fd688c61f8c39b40b0cbd8231decf`.
