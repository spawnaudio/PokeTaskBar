---
summary: "Proposed themes feature: scope, visual directions, settings flow, and implementation seams."
read_when:
  - Planning themes or appearance customization
  - Introducing shared theme colours and component styles
---

# Themes feature proposal

Status: discussion draft, 2026-09-18. No theme implementation or visual direction has been approved.

## Product idea

Let people make PokeTaskBar feel like their own workspace by choosing a coherent visual style across the menu-bar panel, Today window, and floating timer. Picking a theme should be one simple choice, with a preview and an easy return to the current appearance.

Keep three concepts separate:

| Choice | Purpose | Initial scope |
|---|---|---|
| Theme | Colours, surfaces, borders, selection treatments, and a small set of component styles | Current appearance plus one custom preset |
| Appearance | System, Light, or Dark | Independent of theme; System by default |
| Experience preferences | Motion, density, visibility, and interaction behaviour | Existing preferences remain independent; new controls need a separate use case |

Themes retain familiar navigation, task actions, timer behaviour, and keyboard interaction. They do not change XP, rewards, Linear state, or the meaning of warnings. Pokémon sprites retain their original colours.

## Visual directions to explore

These are candidates for a theme library, not a commitment to ship all three.

| Direction | Character | Main tradeoff |
|---|---|---|
| Classic | Existing restrained macOS/Linear-like appearance, neutral surfaces, familiar controls | Safest default and reference for regressions |
| Habitat | Warm cream and sage, soft controls, optional static scenery confined to the companion header | More personality; artwork must not compete with task text |
| Retro | Handheld RPG influence, olive palette, sharper controls, restrained pixel accents | More distinctive; small text and multilingual labels still need native fonts |

Concept images illustrate possible directions; they are not production screenshots or exact layout specifications. Repository screenshots currently depict an older token-focused surface. Current source code and the Today desk reference determine the actual product structure.

Both custom directions need deliberate light and dark palettes before shipping. The initial implementation can deliver their palette and control treatment before adding scenery or special typography.

## Settings experience

Add an **Appearance** section near the top of Settings:

1. **Mode:** System / Light / Dark.
2. **Theme:** compact named previews with a clear selected state. Clicking a preview applies the preset immediately across open surfaces and saves the choice.
3. **Restore appearance defaults:** returns only theme and mode to Classic + System.

Preview content should show a representative task title, timer, primary button, selected row, and text on the theme's surfaces. Use the same resolved styles as the real interface so previews stay accurate. Keep previews compact enough for the attached 400pt panel; avoid a separate theme-management window.

The initial release uses each preset's chosen accent. An accent override can come later if people actually need it. Avoid presenting a long list of colour pickers as the first experience.

## Smallest complete release

- Classic and one selected custom preset, each with light and dark variants.
- Persisted theme and mode, immediate updates, and reset to defaults.
- Consistent coverage of the attached/detached panel, Settings, Today, floating timer and prompts, and pet hover callout.
- All existing tabs consume the shared surfaces and controls where applicable.
- Preserve readable text, selected/focused/disabled states, status meanings, and the user's existing animation settings.

Defer theme import/export, arbitrary user palettes, a theme editor, per-window choices, layout packs, unlockable themes, automatic companion-based colours, and animated backgrounds. Those can build on the same foundation if requested.

## Existing implementation seams

| Source | What exists | Proposed use |
|---|---|---|
| `Sources/PokeTaskBar/UI/MenuBarTheme.swift` | New working-tree code defines semantic light/dark colours and menu-bar-specific controls | Build on this emerging definition; extend it for preset selection and broader coverage instead of creating a competing palette |
| `Sources/PokeTaskBar/UI/MenuBarPanel.swift` | Window geometry and host configuration; appearance code is being changed in the working tree | Keep geometry separate from theme values and coordinate native window updates |
| `Sources/PokeTaskBar/UI/PopoverChrome.swift` | Shared card, capsule button, segment, border, material, and floating chrome | Make these components resolve theme values; preserve their call sites where practical |
| `Sources/PokeTaskBar/Core/UsageStore.swift` | Observable preferences backed by injected `UserDefaults` | Reuse this preference mechanism for stable theme and appearance identifiers |
| `Sources/PokeTaskBar/UI/SettingsView.swift` | Grouped settings and in-panel navigation | Add the Appearance section using existing settings patterns |
| `Sources/PokeTaskBar/UI/TodayDeskView.swift` | Separate `NSWindow` and hosting root, shared controls, material background | Apply the same resolved theme and native appearance at this root |
| `Sources/PokeTaskBar/UI/FloatingPetPanel.swift` | Separate overlay roots and an AppKit hover callout with resolved colour snapshots | Update both SwiftUI content and AppKit surfaces when appearance changes |
| `Sources/PokeTaskBar/UI/SessionOverlayView.swift` | Timer, prompts, and controls share floating chrome | Inherit theme without rebuilding or restarting the session |

Build on the emerging menu-bar theme with a small preset identifier and semantic roles: shell, canvas, surface, primary/secondary text, border, accent, selected, and control states. Its current scope is explicitly the menu-bar window; broadening that scope is a feature decision, not an automatic refactor. Add only component parameters used by the selected preset, such as corner style. No theme registry, plugin loader, or external theme format is needed.

Resolve the theme from the saved preset, appearance preference, and effective system appearance. Pass the result through SwiftUI's environment and update the relevant AppKit window/view appearance from the same source. A root tint change alone cannot cover the app's custom fills, native window backgrounds, and AppKit callout.

Account for values currently cached in static properties, including `TahoeHairline`, and colours resolved into `CGColor` snapshots. They must refresh when a user switches themes; a window reopen should not be required.

Keep status, error, warning, rarity, chart-series, and Linear team colours distinct from decorative theme accents. Review hardcoded colours by purpose instead of replacing them globally.

## Delivery sequence

1. Select one custom direction and settle the supported style changes.
2. Extract the current appearance into the shared definition while preserving its rendering.
3. Wire persisted mode/theme selection through the existing roots and shared components; add the chosen preset.
4. Add Settings previews/reset and finish native window/callout updates.
5. Validate the complete theme-switching flow across the relevant surfaces before expanding the library.

The working tree already contained changes to focus sessions, panel behaviour, and tests when this proposal was prepared. During the exploration, `MenuBarTheme.swift` and further chrome changes appeared. This proposal does not own those changes. Re-read their final state before implementation and integrate without reverting, overwriting, or duplicating them.

## Acceptance and validation

- Fresh preferences and unknown saved identifiers resolve to Classic + System safely; valid choices survive a relaunch.
- Switching theme or mode updates already-open windows and the floating timer without resetting a task, losing typed notes, or changing window/sidebar state.
- System mode follows a macOS appearance change; explicit Light/Dark choices remain selected.
- The attached 400pt panel and larger detached/Today windows retain usable controls and readable content in English, Korean, and Japanese.
- Selected, hover, pressed, disabled, keyboard-focus, warning, error, and timer-overtime states remain distinguishable in both palettes.
- Reduced Motion and increased-contrast preferences are respected; theme changes do not add continuous animation or background polling.
- Review before/after captures from the actual app. Check the real SwiftUI and AppKit roots, not just preview thumbnails.
- Add focused tests for preference fallback/persistence and cross-root appearance updates; use the existing layout/rendering tests where relevant. Run the macOS build and repository test/coverage gate for implementation changes.

This proposal was grounded by source and reference-image inspection. No app build, runtime theme validation, or implementation tests were performed for this planning-only change.
