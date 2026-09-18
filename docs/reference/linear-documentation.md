---
summary: Active PokeTasks Linear project, document ownership and rules for adding only new information.
read_when:
  - Before creating or updating Linear issues, project information or documents for this repository.
  - When deciding where to record design decisions, approved mockups, implementation results or validation.
---

# Linear documentation routing

Confirmed by the user on 18 September 2026. This file routes work; live Linear documents remain the source of truth for their contents.

## Active project

- Project: [PokeTasks](https://linear.app/spawn-audio/project/poketasks-cedf1ccdaeb7/overview)
- Project ID: `191c2b8c-3de2-459b-b99c-403f5db3245b`
- Decision index: [UI Overhaul v2](https://linear.app/spawn-audio/document/ui-overhaul-v2-34ba3019297c), ID `325bd321-5807-49c3-91c1-d45c0f370423`.
- Existing local UI document map: `Documents/ui-overhaul-v2/linear-document-map.json`.

Do not use the former PokeTokenBar - Adjustments project (`332b8967-458a-476c-bfbb-4684fd0ce0ee`) or former monolithic UI Overhaul v2 document (`36914001-ea7f-458f-81ad-c3fbe7290147`) as a default write destination. Old publication manifests describe historical uploads; they do not override this routing.

## Choose the owning document before writing

Refresh the project's resource/document list first: the user may reorganise it again. Read the candidate document in full; list/search previews may be truncated. The following verified map is a starting point, not permission to skip the live check.

| Information | Existing destination |
| --- | --- |
| Decision status and links to detailed design documents | [UI Overhaul v2](https://linear.app/spawn-audio/document/ui-overhaul-v2-34ba3019297c) |
| Shared palette, typography, spacing, surfaces, sidebar and interaction rules | [Foundations & Shared Interaction Language](https://linear.app/spawn-audio/document/ui-overhaul-v2-foundations-and-shared-interaction-language-e25429d73e2c) |
| Today dashboard, main navigation and menu-bar layouts | [Today, Navigation & Menu Bar](https://linear.app/spawn-audio/document/ui-overhaul-v2-today-navigation-and-menu-bar-3090ca806631) |
| Focus page, floating timer/pet and their behaviour | [Focus & Floating Timer](https://linear.app/spawn-audio/document/ui-overhaul-v2-focus-and-floating-timer-fcd3495bbc65) |
| Issues, Projects and Initiatives layouts and navigation | [Workspaces: Issues, Projects & Initiatives](https://linear.app/spawn-audio/document/ui-overhaul-v2-workspaces-issues-projects-and-initiatives-f0f3fb690b50) |
| Pokédex, Bag, Storage, Catch log, Shop and Pokémon details | [Collection: Pokédex & Bag](https://linear.app/spawn-audio/document/ui-overhaul-v2-collection-pokedex-and-bag-20fb94c02bdb) |
| Usage views and Settings | [Usage & Settings](https://linear.app/spawn-audio/document/ui-overhaul-v2-usage-and-settings-f51879d32e66) |
| Dated implementation changes, actual test results, installation verification and limitations | [Implementation, Validation & Change Log](https://linear.app/spawn-audio/document/ui-overhaul-v2-implementation-validation-and-change-log-5bdfd7d37c11) |
| Detailed motion timing, choreography and motion-specific validation | [UI Motion & Animation Outline](https://linear.app/spawn-audio/document/ui-motion-and-animation-outline-c51cbefca508) |
| Theme proposal, scope and delivery decisions | [Themes - Proposal](https://linear.app/spawn-audio/document/themes-proposal-c961fe0edace) |
| Theme images, visual comparisons and reusable theme UI references | [Themes - Mockups & UI Library](https://linear.app/spawn-audio/document/themes-mockups-and-ui-library-ac697c706b9d) |
| App update procedures | [Updating the App](https://linear.app/spawn-audio/document/updating-the-app-0b098e76ee15) |
| Historical upstream project material | [PokeTokenBar Project Docs](https://linear.app/spawn-audio/document/poketokenbar-project-docs-bef0f5335df5) |

For topics outside this map, inspect all current project documents for an appropriate owner. Do not file unrelated material in a convenient UI document or create a duplicate document. Resolve an unclear destination with the user after checking available context.

## Add only new information

1. Compare the proposed addition against the owning document and any related project documents by meaning, not just exact wording. Already documented facts, decisions, images and test runs need no second copy.
2. Write the new or changed material once, in the owning document. Use a short link from another document when needed. Keep the decision index to links and concise changed status.
3. Distinguish proposals, user-approved designs, implemented behaviour and verified results. Attach the exact selected mockup to its owning design document; reuse an existing uploaded image when available. Do not treat an unselected proposal as approved.
4. Separate durable design requirements from dated implementation/validation evidence. Report only checks actually run and retain their limitations.
5. Re-read the destination immediately before saving. Prefer narrowly anchored patches, preserve concurrent edits and existing images, and never replace a whole document from a stale local snapshot.
6. Re-read after saving to verify the destination project/document, the intended addition, preserved content and image references. If the addition is already present, stop without another write.

This context update does not resume completed tasks, authorise new implementation, broadcast messages to external people, or require a documentation entry when nothing changed.
