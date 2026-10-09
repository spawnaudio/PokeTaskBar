# PokeTasks v2 - Backlog & Open Decisions

Source: [PokeTasks v2 - Backlog & Open Decisions](https://linear.app/spawn-audio/document/poketasks-v2-backlog-and-open-decisions-7d11e3b3d15f)

**Status: planning · 1 October 2026.** These items are outside the first proposed build slice.

## Low-priority document and note syncing

Explore project documents and task-linked notes after planning and time tracking work well.

* First candidate: open/link existing Linear documents in context, then explore cached read-only documents.
* Editable sync needs explicit ownership, conflict behavior, offline handling, attachment support, and reliable error recovery before it becomes a commitment.
* Preserve existing focus notes/check-ins. New document sync must not hold up the timer or silently overwrite a remote edit.
* Reuse the user's existing Linear Notes direction when assessing integration; do not build a second general notes app without deciding why it is needed.

## Initiatives — proposed v2 deferral

Temporarily remove the Initiatives destination from the visible app for v2. Keep its views, models, Linear integration, stored preferences/pins, and existing card appearance intact for reintroduction. This is a scope proposal, not a deletion or migration.

Hide entry points consistently in navigation/search/menus; stale navigation history should fall back to Projects. Keep useful initiative references already present inside project metadata unless the user chooses to hide them. No live initiatives or projects are deleted. Do not add a general feature-flag framework for this one deferred surface.

## Later candidates

| Candidate | Add when |
| -- | -- |
| Week planning and recurring blocks | The day timeline is useful and repeat planning becomes a clear friction. |
| Calendar overlays/write-back | Local blocking works and the user confirms which calendar and sync direction. |
| Local task inbox | Linear tasks and standalone sessions leave a demonstrated capture gap. |
| Richer reports / PDF export | Session history and CSV are trustworthy and need a shareable report. |
| Cross-device planning sync | Local planning proves valuable and the source-of-truth/conflict rules are agreed. |

## Decisions before feature implementation

1. Team-specific status mappings and reverse-sync behavior for the user-selected optional linked mode. Personal planning remains the default; see the priorities brief.
2. Whether to defer the visible Initiatives surface for v2 while retaining all code and data.
3. What “scores” should mean beyond tracked minutes and existing XP.
4. Whether the independently foldable day timeline opens by default.
5. Select the first behavior refinement; current Issues/Projects/Initiatives card visuals remain unchanged.

## Suggested delivery order

1. Fix rounded scrolling edges, retain icon navigation when folded, add scoped context-menu controls, and make timer hover actions overlay its title. Keep current cards unchanged; decide the Initiatives deferral.
2. Add independently foldable planning groups with persistence and keyboard moves. Personal planning is default; add the selected optional linked mode only after team mappings and error/Undo behavior are resolved.
3. Add the day timeline and block editing linked to the existing session flow.
4. Establish complete session retention, then ship task/project reports, scores, and the heatmap.
5. Revisit note/document syncing when the core workflow is settled.

Session retention must land before any claim of complete historical tracking. This order is a proposal, not an approved roadmap or release date.
