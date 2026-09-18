# PokeTaskBar — Themes: Proposal, Mockups & UI Library

This document consolidates the themes exploration for PokeTaskBar: the feature proposal, eight style directions, eighteen Pokémon-type directions, and the UI component breakdown for every theme.

**Status:** design exploration, prepared 18 September 2026. The mockups are visual references; no final theme selection or implementation approval is implied. The implementation notes capture the code seams identified during the proposal and should be rechecked against the current checkout before development.

## Collection at a glance

| Collection | Themes | Screen concepts | Component sheets | Images |
|---|---:|---:|---:|---:|
| Style themes | 8 | 8 | 8 | 16 |
| Pokémon-type themes | 18 | 18 | 18 | 36 |
| Total | 26 | 26 | 26 | 52 |

Every original image is uploaded to Linear and embedded below at its corresponding theme. Each image also has an original-file link. The galleries preserve both the earlier style exploration and the Pokémon elemental-type interpretation.

The most useful next decision is to choose **one custom preset** to implement alongside Classic, then validate the shared theme system before expanding the library.

## Feature proposal

### Product idea

Let people make PokeTaskBar feel like their own workspace by choosing a coherent visual style across the menu-bar panel, Today window, and floating timer. Picking a theme should be one simple choice, with a preview and an easy return to the current appearance.

Keep three concepts separate:

| Choice | Purpose | Initial scope |
|---|---|---|
| Theme | Colours, surfaces, borders, selection treatments, and a small set of component styles | Current appearance plus one custom preset |
| Appearance | System, Light, or Dark | Independent of theme; System by default |
| Experience preferences | Motion, density, visibility, and interaction behaviour | Existing preferences remain independent; new controls need a separate use case |

Themes retain familiar navigation, task actions, timer behaviour, and keyboard interaction. They do not change XP, rewards, Linear state, or the meaning of warnings. Pokémon sprites retain their original colours.

### Visual directions to explore

These are candidates for a theme library, not a commitment to ship all three.

| Direction | Character | Main tradeoff |
|---|---|---|
| Classic | Existing restrained macOS/Linear-like appearance, neutral surfaces, familiar controls | Safest default and reference for regressions |
| Habitat | Warm cream and sage, soft controls, optional static scenery confined to the companion header | More personality; artwork must not compete with task text |
| Retro | Handheld RPG influence, olive palette, sharper controls, restrained pixel accents | More distinctive; small text and multilingual labels still need native fonts |

Concept images illustrate possible directions; they are not production screenshots or exact layout specifications. Repository screenshots currently depict an older token-focused surface. Current source code and the Today desk reference determine the actual product structure.

Both custom directions need deliberate light and dark palettes before shipping. The initial implementation can deliver their palette and control treatment before adding scenery or special typography.

### Settings experience

Add an **Appearance** section near the top of Settings:

1. **Mode:** System / Light / Dark.
2. **Theme:** compact named previews with a clear selected state. Clicking a preview applies the preset immediately across open surfaces and saves the choice.
3. **Restore appearance defaults:** returns only theme and mode to Classic + System.

Preview content should show a representative task title, timer, primary button, selected row, and text on the theme's surfaces. Use the same resolved styles as the real interface so previews stay accurate. Keep previews compact enough for the attached 400pt panel; avoid a separate theme-management window.

The initial release uses each preset's chosen accent. An accent override can come later if people actually need it. Avoid presenting a long list of colour pickers as the first experience.

### Smallest complete release

- Classic and one selected custom preset, each with light and dark variants.
- Persisted theme and mode, immediate updates, and reset to defaults.
- Consistent coverage of the attached/detached panel, Settings, Today, floating timer and prompts, and pet hover callout.
- All existing tabs consume the shared surfaces and controls where applicable.
- Preserve readable text, selected/focused/disabled states, status meanings, and the user's existing animation settings.

Defer theme import/export, arbitrary user palettes, a theme editor, per-window choices, layout packs, unlockable themes, automatic companion-based colours, and animated backgrounds. Those can build on the same foundation if requested.

### Existing implementation seams

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

### Delivery sequence

1. Select one custom direction and settle the supported style changes.
2. Extract the current appearance into the shared definition while preserving its rendering.
3. Wire persisted mode/theme selection through the existing roots and shared components; add the chosen preset.
4. Add Settings previews/reset and finish native window/callout updates.
5. Validate the complete theme-switching flow across the relevant surfaces before expanding the library.

The working tree already contained changes to focus sessions, panel behaviour, and tests when this proposal was prepared. During the exploration, `MenuBarTheme.swift` and further chrome changes appeared. This proposal does not own those changes. Re-read their final state before implementation and integrate without reverting, overwriting, or duplicating them.

### Acceptance and validation

- Fresh preferences and unknown saved identifiers resolve to Classic + System safely; valid choices survive a relaunch.
- Switching theme or mode updates already-open windows and the floating timer without resetting a task, losing typed notes, or changing window/sidebar state.
- System mode follows a macOS appearance change; explicit Light/Dark choices remain selected.
- The attached 400pt panel and larger detached/Today windows retain usable controls and readable content in English, Korean, and Japanese.
- Selected, hover, pressed, disabled, keyboard-focus, warning, error, and timer-overtime states remain distinguishable in both palettes.
- Reduced Motion and increased-contrast preferences are respected; theme changes do not add continuous animation or background polling.
- Review before/after captures from the actual app. Check the real SwiftUI and AppKit roots, not just preview thumbnails.
- Add focused tests for preference fallback/persistence and cross-root appearance updates; use the existing layout/rendering tests where relevant. Run the macOS build and repository test/coverage gate for implementation changes.

This proposal was grounded by source and reference-image inspection. No app build, runtime theme validation, or implementation tests were performed for this planning-only change.

## Shared UI component inventory

Every theme has a component sheet arranged into twelve specimen groups, with foundation swatches and typography in its header.

| Area | Included elements and states |
|---|---|
| Foundations | Canvas, surface, text, accent, border, selected fill; heading, body, and timer numerals |
| 01 Actions | Primary, secondary, plain, destructive, and icon controls; hover, pressed, disabled, and keyboard focus |
| 02 Navigation | Focus / Linear / Collection / Usage; Bag / Storage / Dex / Shop; back and disclosure controls |
| 03 Text inputs | Task title, focused field, masked credential field, multiline session note, and validation error |
| 04 Choice controls | On/off toggles, checked/unchecked boxes, slider, picker, and open selection menu |
| 05 Rows and inspector | Normal/selected task rows, pin indicator, status and priority properties |
| 06 Badges and status | Todo, In progress, Done, High, Rare, and overtime warning |
| 07 Progress and score | XP bar, XP/Coins totals, small usage chart, and loading spinner |
| 08 Companion and items | Companion card, selected Pokédex tile, egg/item tile, and purchase action |
| 09 Focus timer | Running, paused, overtime, and focus-duration selection |
| 10 Floating chrome | Expanded timer island, folded countdown, speech bubble, and tooltip |
| 11 Feedback and confirmation | Reset confirmation, success, error/retry, and warning |
| 12 Empty, loading, and log | No pinned task, loading skeleton, session log, and note row |

The inventory follows the app's shared controls, Settings, Linear task surfaces, collection, and floating timer. A specimen is a styling example, not a request to add a new workflow. Native menus and tooltips should retain native behaviour and the appearance support macOS provides.

## Style-theme gallery

These eight directions explore materials, typography, and visual character. Each has one full screen and one matching component sheet. Classic provides the baseline; the other directions remain candidates.

### Classic

Native restrained macOS utility. Cool gray #F3F4F6 shell, white canvas, crisp charcoal text, blue accent, fine neutral dividers, 12pt continuous corners and subtly rounded controls. System sans and monospaced timer. Flat calm highly usable reference style.

**Screen concept**

![Classic — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/c5b16d6a-d836-4c34-9f8a-1bfa65b05c56/cb545b47-39b4-4d05-a7b1-be7cda1613f6)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/c5b16d6a-d836-4c34-9f8a-1bfa65b05c56/cb545b47-39b4-4d05-a7b1-be7cda1613f6)

**UI component breakdown**

![Classic — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/2bf0984d-e6dd-4a15-b19d-8c547936c3f1/6832f993-534d-4dbc-92aa-8fb4114e70c7)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/2bf0984d-e6dd-4a15-b19d-8c547936c3f1/6832f993-534d-4dbc-92aa-8fb4114e70c7)

### Habitat

Warm cream #F5F4E9, pale sage #E5EBDC, deep forest ink #253C32, botanical green #487454 accents. Soft modest rounded controls, quiet nature-inspired warmth. Tiny pixel shoreline ONLY inside companion tile, never decorating every component. Clear native rounded sans.

**Screen concept**

![Habitat — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/f572f8fa-c63d-4821-aa5b-cbff767a2f05/fb48a400-dc2b-46bf-bfef-b37c1880d535)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/f572f8fa-c63d-4821-aa5b-cbff767a2f05/fb48a400-dc2b-46bf-bfef-b37c1880d535)

**UI component breakdown**

![Habitat — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/7b99ba82-5a46-4ac4-8753-da1745638b2d/0b5087a6-b993-43df-8511-1d841ac81822)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/7b99ba82-5a46-4ac4-8753-da1745638b2d/0b5087a6-b993-43df-8511-1d841ac81822)

### Retro

Handheld RPG inspired LCD sage #DCE6BF and #BFCB9B with dark olive #253729 ink. Crisp squared 4px corners and selective pixel-step edges. Blocky short section headings and timer, native sans for all other labels. Full colour sprites. No scanlines, no fake device shell, no texture that reduces readability.

**Screen concept**

![Retro — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/4d60fdb6-c6d0-4583-9d35-d97c02fa3f32/465bc014-2987-41cf-882d-71196555dd8e)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/4d60fdb6-c6d0-4583-9d35-d97c02fa3f32/465bc014-2987-41cf-882d-71196555dd8e)

**UI component breakdown**

![Retro — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/996aeafe-63e2-45a4-8dac-f18b40c6c064/9999b7c2-b23d-41ef-a01f-9d92480bbfa2)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/996aeafe-63e2-45a4-8dac-f18b40c6c064/9999b7c2-b23d-41ef-a01f-9d92480bbfa2)

### Pokédex

Warm vermilion #BA343D, soft porcelain #F5F1E8, charcoal ink, cyan sensor accent. Restrained red instrument-panel borders and clipped-corner controls. Cream form fields, red primary buttons. Precise technical section labels, clean native sans body. A tiny sensor motif at the title only, no physical device or bolts.

**Screen concept**

![Pokédex — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/3ccdb5af-c621-4533-a61a-881274ef4a6e/a94c5809-165e-47cc-a950-a8df833925ac)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/3ccdb5af-c621-4533-a61a-881274ef4a6e/a94c5809-165e-47cc-a950-a8df833925ac)

**UI component breakdown**

![Pokédex — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/db1da85e-0179-4905-b9a9-2c6f70fda76c/6e271b7f-5928-4201-bf0c-de19b82114f4)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/db1da85e-0179-4905-b9a9-2c6f70fda76c/6e271b7f-5928-4201-bf0c-de19b82114f4)

### Midnight Observatory

Deep inky indigo #141A2B, slate-blue raised surfaces #202A40, moon-white #F0EBDC text, brass-gold #DDBA78 accent. Soft thin borders, gold primary controls. One tiny constellation detail confined to the companion tile. Elegant low-light native typography, no neon glow.

**Screen concept**

![Midnight Observatory — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/955b5b7b-db14-4bef-8620-bbf63afd815c/166bc159-150c-4e75-9c14-4a2946461631)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/955b5b7b-db14-4bef-8620-bbf63afd815c/166bc159-150c-4e75-9c14-4a2946461631)

**UI component breakdown**

![Midnight Observatory — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/647f1502-f8cd-4b79-a7f6-3d763979ef8a/f9f345ee-d242-420e-9660-af42a36935e6)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/647f1502-f8cd-4b79-a7f6-3d763979ef8a/f9f345ee-d242-420e-9660-af42a36935e6)

### Paper Journal

Warm ivory #F6F0E3, oatmeal #E8DFCF, espresso #332C28, burnt orange #B95032. Serif section headings plus very readable sans controls, minimal ink rules, nearly square flat controls, no shadows or glass. Paper grain barely perceptible and absent behind small control labels. Dark ink primary buttons.

**Screen concept**

![Paper Journal — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/09fabe32-e9d9-45e8-a9a9-decf65429bc5/2d8761ff-7e5e-4599-80ed-24d9c8ec8966)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/09fabe32-e9d9-45e8-a9a9-decf65429bc5/2d8761ff-7e5e-4599-80ed-24d9c8ec8966)

**UI component breakdown**

![Paper Journal — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/14d35145-1ff5-439b-bd2e-2ecaa4991f4f/cced0b35-75c7-4272-be62-3b6df5a01a1c)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/14d35145-1ff5-439b-bd2e-2ecaa4991f4f/cced0b35-75c7-4272-be62-3b6df5a01a1c)

### Ocean Glass

Luminous icy aqua #E6F3F5, sea glass #D3ECEC, navy teal ink #153D48, ocean blue #087AA0. Soft frosted native surfaces, delicate white rim highlights, quiet translucency while retaining opaque legible fields and menus. Rounded native type. Water caustics only in companion tile, no heavy glass blob decoration.

**Screen concept**

![Ocean Glass — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/709a8e2b-b322-451c-b7cb-339626a05cff/1524e5d3-8268-4a37-b5b5-2163ab01889b)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/709a8e2b-b322-451c-b7cb-339626a05cff/1524e5d3-8268-4a37-b5b5-2163ab01889b)

**UI component breakdown**

![Ocean Glass — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/2fdb4516-24b6-41f6-bb73-e6d81fc307ee/d7e4e47c-85c6-4571-b3bb-62231b9ae7f2)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/2fdb4516-24b6-41f6-bb73-e6d81fc307ee/d7e4e47c-85c6-4571-b3bb-62231b9ae7f2)

### Neon Arcade

Near-black aubergine #18121F, deep plum #261B31, soft lavender-white #F3EEF7 text, orchid-pink #ED71CE primary accent, cyan #64E2ED secondary accent. Crisp modest cut-corner controls, limited bright borders, restrained accent glow only. Sharp readable system sans and monospaced timer, not gimmick fonts. No scanlines, visual noise, or busy grid behind controls.

**Screen concept**

![Neon Arcade — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/8c368708-3500-4c77-beca-ed229f5197df/2ba1f930-7a19-43e6-9412-f179c9c63a4e)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/8c368708-3500-4c77-beca-ed229f5197df/2ba1f930-7a19-43e6-9412-f179c9c63a4e)

**UI component breakdown**

![Neon Arcade — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/adf5a2f1-5fde-45e8-af63-e14558a99d78/0d77c516-244a-4834-a0b0-8e568dc9f63d)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/adf5a2f1-5fde-45e8-af63-e14558a99d78/0d77c516-244a-4834-a0b0-8e568dc9f63d)

## Pokémon-type theme gallery

The following eighteen directions use the [standard Pokémon type inventory](https://sg.portal-pokemon.com/game/type-chart/). Each explores the same task/focus workflow with a type-specific palette, surface treatment, control shape, and restrained motif.

Companion selection remains independent of the interface theme. Electric and Grass retain Lapras as their example companion after the character-specific generation attempts failed; their interface styling still follows the named type. Electric's final direction uses graphite and electrical yellow.

### Normal

**Example companion:** Eevee.

Soft linen studio: warm ivory #F4F0E7 canvas, oatmeal #DDD5C5 shell, cocoa #39342F ink, warm taupe #8D7968 accent. Matte paper-soft surfaces, 10px quietly rounded controls, elegant unembellished system sans, fine warm rules. Tiny woven-fabric motif confined to companion strip. Comfortable neutral everyday style; distinctly tactile, not plain default gray.

**Screen concept**

![Normal — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/9682d052-f207-47d7-b975-55d3f87dc667/b1da88f0-ec38-4568-8808-38d72c8fa117)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/9682d052-f207-47d7-b975-55d3f87dc667/b1da88f0-ec38-4568-8808-38d72c8fa117)

**UI component breakdown**

![Normal — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/5b1fd504-cc0f-4ecc-b262-d0a401a19c7f/fd91411d-87ab-43be-9893-9be774d04d97)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/5b1fd504-cc0f-4ecc-b262-d0a401a19c7f/fd91411d-87ab-43be-9893-9be774d04d97)

### Fire

**Example companion:** Charmander.

Ember forge: dark warm basalt #241A19 canvas, lifted charcoal #352724 surfaces, ivory #FFF0DD ink, vivid ember #F57B3A primary accent and muted red-orange edges. Crisp chamfered 7px controls, thin ember keylines, monospaced clock. Subtle warm ember/firelight in companion strip only. Restrained premium warmth, no flame behind task text or dramatic full-screen fire.

**Screen concept**

![Fire — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/bd6ae46c-5851-41e8-be37-255b8751e510/816bf333-9a10-4d78-8f0d-fabe5ec6b975)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/bd6ae46c-5851-41e8-be37-255b8751e510/816bf333-9a10-4d78-8f0d-fabe5ec6b975)

**UI component breakdown**

![Fire — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/b85a5967-6191-4b8c-8b4e-849f35e7f322/9721d81e-50e3-4991-99dd-fdcfa4da55fd)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/b85a5967-6191-4b8c-8b4e-849f35e7f322/9721d81e-50e3-4991-99dd-fdcfa4da55fd)

### Water

**Example companion:** Squirtle.

Deep tidal blue: rich deep-ocean #102F46 canvas, blue #19465D raised surfaces, seafoam-white #E4F7F5 ink, bright turquoise #55D4D1 accent. Smooth rounded controls with quiet ripple contours, soft blue dividers, cool crisp system sans. Small pixel tidal pool or concentric ripple in companion strip only. Dark aquatic style, distinctly deeper than Ocean Glass.

**Screen concept**

![Water — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/df2ca577-d4e9-411a-ab49-2fed7e3e0a24/e7fe3601-1cd4-4642-8923-66d12b3a3a16)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/df2ca577-d4e9-411a-ab49-2fed7e3e0a24/e7fe3601-1cd4-4642-8923-66d12b3a3a16)

**UI component breakdown**

![Water — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/448aa758-a06f-428d-bd7c-671c99cb6a4b/4d6f8bae-2f7c-4ced-a9ea-6ad0ff2a12ac)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/448aa758-a06f-428d-bd7c-671c99cb6a4b/4d6f8bae-2f7c-4ced-a9ea-6ad0ff2a12ac)

### Electric

**Example companion:** Lapras.

Volt at night: graphite #212126 canvas, deep charcoal #303036 surfaces, warm ivory #FFF7DB ink, saturated electrical yellow #F1D54E accents. Crisp cut corners, exact thin yellow keylines, segmented XP, subtle tiny circuit traces only beside companion. Dark primary buttons in yellow fill with black labels. Energetic but legible, no bright pink.

**Screen concept**

![Electric — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/cd38637c-b9e1-4905-b343-fbdaabe162e0/ec253bb2-56c0-4901-8608-0e9a89bc1cdb)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/cd38637c-b9e1-4905-b343-fbdaabe162e0/ec253bb2-56c0-4901-8608-0e9a89bc1cdb)

**UI component breakdown**

![Electric — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/3c748241-f55c-4ae7-ab38-30a20219f0d7/d8832571-ad6a-43b0-a155-cadb39d2521a)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/3c748241-f55c-4ae7-ab38-30a20219f0d7/d8832571-ad6a-43b0-a155-cadb39d2521a)

### Grass

**Example companion:** Lapras.

Fresh greenhouse: pale leaf #F0F5E7 canvas, sage #DCE8CD shell, forest #234D35 ink, leaf-green #588E45 accent. Gently leaf-rounded asymmetric detail on companion card only; simple soft rectangle controls and botanical fine dividers. Bright clean native sans, small leaf-vein detail in companion strip. Quiet morning garden, no image under body text.

**Screen concept**

![Grass — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/56c2d784-cbcc-41ce-b185-f9e52505e8f4/27e194c9-2dcf-4fee-a33f-2bfe830066d5)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/56c2d784-cbcc-41ce-b185-f9e52505e8f4/27e194c9-2dcf-4fee-a33f-2bfe830066d5)

**UI component breakdown**

![Grass — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/8d223231-6cea-4206-88b5-2b7c12bcfceb/0354067f-c376-4c9e-b79b-10bd435451c6)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/8d223231-6cea-4206-88b5-2b7c12bcfceb/0354067f-c376-4c9e-b79b-10bd435451c6)

### Ice

**Example companion:** Alolan Vulpix.

Polar crystal: snow-white #F4FBFE canvas, frost-blue #D7EAF2 shell, arctic navy #25465D ink, icy blue #68ACD0 accent and pale lavender secondary note. Fine faceted 6px corners and frost-white hairline edges, restrained translucency with solid legible fields. Small crystal/snowflake motif in companion strip. Crisp airy high-contrast winter daylight.

**Screen concept**

![Ice — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/d2561fbf-08ca-4c0d-ac3e-8098f690fb72/4d605d4b-0392-4d15-a088-89cf08574f9e)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/d2561fbf-08ca-4c0d-ac3e-8098f690fb72/4d605d4b-0392-4d15-a088-89cf08574f9e)

**UI component breakdown**

![Ice — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/c40a481f-8195-4187-88e2-22edf0c0d617/1e2adabd-a4ef-4bd6-9bb3-7941fd087cd8)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/c40a481f-8195-4187-88e2-22edf0c0d617/1e2adabd-a4ef-4bd6-9bb3-7941fd087cd8)

### Fighting

**Example companion:** Machop.

Dojo discipline: warm unbleached #F3E7D5 canvas, muted clay #E0C4A7 shell, deep oxblood #592F2F ink, vermilion #BA5342 accent. Strong flat squared 4px controls, bold sturdy sans headings, disciplined rules and a narrow wrapping-band motif in companion strip. Athletic precision, calm capable work tool, no arena, violence or distressed grunge.

**Screen concept**

![Fighting — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/d019d51b-5c7d-43af-aad4-2e22a2e427aa/ef8a2d2d-c2fb-4304-97ff-f18afd660867)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/d019d51b-5c7d-43af-aad4-2e22a2e427aa/ef8a2d2d-c2fb-4304-97ff-f18afd660867)

**UI component breakdown**

![Fighting — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/e51ddab5-25c8-4e7d-863b-ba2ce566126b/4159d3eb-5392-44fb-9927-f79f82492855)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/e51ddab5-25c8-4e7d-863b-ba2ce566126b/4159d3eb-5392-44fb-9927-f79f82492855)

### Poison

**Example companion:** Ekans.

Amethyst laboratory: dark aubergine #24192F canvas, plum #382342 raised surfaces, pale lilac #F1DEF7 text, orchid #BF78D6 accent plus a tiny acid-lime #CEE17A secondary detail. Clean elongated capsules, thin violet borders and delicate specimen markings. Small abstract liquid-drop motif in companion strip. Elegant curious chemistry mood, no skulls, hazardous gore, or overpowering slime.

**Screen concept**

![Poison — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/23aac00a-4edc-4ee0-860f-c47f75503052/1a4d309f-ee41-4764-80bf-d9382a129f4c)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/23aac00a-4edc-4ee0-860f-c47f75503052/1a4d309f-ee41-4764-80bf-d9382a129f4c)

**UI component breakdown**

![Poison — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/ed0e4cb9-f8e2-43db-8861-cc13b935711d/fcc8b997-78e6-4cca-b52a-c155c44896ea)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/ed0e4cb9-f8e2-43db-8861-cc13b935711d/fcc8b997-78e6-4cca-b52a-c155c44896ea)

### Ground

**Example companion:** Sandshrew.

Desert strata: warm sand #F0DFBF canvas, ochre #DAC099 shell, dark earth #513B2A ink, sun-baked terracotta #AD6A40 accent. Matte layered surfaces, sturdy 6px rounded rectangles, fine horizontal stratum lines, legible grounded humanist sans. Tiny dune contour in companion strip only. Sunlit earthy and quiet, no gritty noisy texture.

**Screen concept**

![Ground — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/1b928b71-b1c6-4ec2-a5aa-d4d01ef100a2/267ff32b-63ef-4330-adb0-d5c43ccaf766)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/1b928b71-b1c6-4ec2-a5aa-d4d01ef100a2/267ff32b-63ef-4330-adb0-d5c43ccaf766)

**UI component breakdown**

![Ground — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/4bb4c2fe-cb01-4ead-9a28-bba4346601c2/af0c0086-7d8d-4398-be03-80fc9d2caaef)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/4bb4c2fe-cb01-4ead-9a28-bba4346601c2/af0c0086-7d8d-4398-be03-80fc9d2caaef)

### Flying

**Example companion:** Pidgey.

Open sky: cloud-white #F5F9FC canvas, powder-blue #DFEBF8 shell, deep slate-blue #314E73 ink, cornflower #759FDB accent. Long airy capsule controls, subtle sky gradients only in empty header space, extra breathing room, light thin rules. Small feather/windline motif beside companion. Effortless native legibility, no clouds behind text.

**Screen concept**

![Flying — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/70e668e3-2084-4b27-8ae1-398cef155e23/4e33c74a-4aa2-46ed-a2f4-c850478780dd)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/70e668e3-2084-4b27-8ae1-398cef155e23/4e33c74a-4aa2-46ed-a2f4-c850478780dd)

**UI component breakdown**

![Flying — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/a415a2dc-b46a-4260-b360-0e4534d79094/f9f93458-a7c6-49f5-afbd-fa94df284a4c)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/a415a2dc-b46a-4260-b360-0e4534d79094/f9f93458-a7c6-49f5-afbd-fa94df284a4c)

### Psychic

**Example companion:** Abra.

Astral mind: rich indigo-plum #241B38 canvas, violet #382849 surfaces, very pale pink #F9E8F3 ink, saturated rose #E985B7 accent with lilac #AD9FEB secondary. Smooth concentric orbital outlines and pill controls; clean geometric sans and calm aligned timer. Tiny orbital rings confined to companion header. Thoughtful cosmic energy, distinct from gold Midnight Observatory and cyan Neon Arcade.

**Screen concept**

![Psychic — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/83adda90-c468-401c-97a6-1f43ee74d391/129d218c-e61b-46ee-b762-08ba5e933b83)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/83adda90-c468-401c-97a6-1f43ee74d391/129d218c-e61b-46ee-b762-08ba5e933b83)

**UI component breakdown**

![Psychic — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/f3533c85-e6a8-4a20-8e90-14401462c0a4/43be8ffb-043d-439a-997e-0737780ac067)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/f3533c85-e6a8-4a20-8e90-14401462c0a4/43be8ffb-043d-439a-997e-0737780ac067)

### Bug

**Example companion:** Caterpie.

Field study: creamy chartreuse-white #F2F3DB canvas, light olive #DEE3B6 shell, dark moss #38451F ink, lively chartreuse #8EAA39 accent. Neatly segmented progress indicators, compact softly angular 6px controls, micro leaf-vein geometry in companion strip. Precise friendly naturalist notebook, sharper lime/olive rather than Grass's leafy green.

**Screen concept**

![Bug — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/6d221014-cf58-41e5-ac0c-3805879314b4/0a0f2ac8-9f5a-43e1-a973-819fc86eecdc)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/6d221014-cf58-41e5-ac0c-3805879314b4/0a0f2ac8-9f5a-43e1-a973-819fc86eecdc)

**UI component breakdown**

![Bug — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/c8554836-c849-4680-8c84-4d654b754c74/03f4572a-7ed2-4482-baf6-41a2b8af7bfd)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/c8554836-c849-4680-8c84-4d654b754c74/03f4572a-7ed2-4482-baf6-41a2b8af7bfd)

### Rock

**Example companion:** Geodude.

Granite workshop: pale limestone #EAE6DE canvas, stone #D4CBBB shell, charcoal-umber #413E36 ink, ochre-bronze #A38A4C accent. Flat quarry-block geometry, bevel-free squared controls with 3px corners, substantial but restrained dividing rules. Very subtle mineral fleck only in companion strip, all reading surfaces smooth. Architectural calm, no fake 3D boulders surrounding controls.

**Screen concept**

![Rock — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/bd963576-f1eb-4904-aeb3-2d38121d1162/1a19a588-862e-4006-aadc-6cb5ba1942d6)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/bd963576-f1eb-4904-aeb3-2d38121d1162/1a19a588-862e-4006-aadc-6cb5ba1942d6)

**UI component breakdown**

![Rock — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/b2fa9f07-f954-49b1-bdba-ee0e1f58042e/d1df7c17-df92-405c-9a68-3d111b26476a)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/b2fa9f07-f954-49b1-bdba-ee0e1f58042e/d1df7c17-df92-405c-9a68-3d111b26476a)

### Ghost

**Example companion:** Gastly.

Lavender dusk: smoky violet #211D32 canvas, raised dusk #342C49 surfaces, soft lilac-white #ECE5FC ink, spectral lavender #AD93DE accent with tiny seafoam #95CBBE details. Soft quiet rounded controls, faint hazy halo confined to companion strip, subtle dashed or fading separators sparingly. Friendly mysterious twilight; legible still surfaces, no horror, no wisps behind task text.

**Screen concept**

![Ghost — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/dc3cb9cd-f35f-4dea-a695-f3ea99397b32/0820be61-0246-4778-97cd-dbbbcc36349f)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/dc3cb9cd-f35f-4dea-a695-f3ea99397b32/0820be61-0246-4778-97cd-dbbbcc36349f)

**UI component breakdown**

![Ghost — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/063b3442-1c7e-4e0a-88d5-ba3fb49f5748/3867aab9-dae3-4a9d-8f5e-68d938fa01d0)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/063b3442-1c7e-4e0a-88d5-ba3fb49f5748/3867aab9-dae3-4a9d-8f5e-68d938fa01d0)

### Dragon

**Example companion:** Dratini.

Royal scale: regal navy #171F39 canvas, sapphire #273252 surfaces, warm pearl #F3ECD9 text, antique gold #D5B673 accent with royal violet #8E78CD secondary. Elegant modest angular corners, slender double-rule accents on companion header, orderly subtle scale geometry there only. Majestic precise UI, solid typography, no weapons, castle scenes, heavy fantasy scrollwork or tiny serif text.

**Screen concept**

![Dragon — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/483ac078-b8df-4977-aaf9-91412da087a5/5e066817-d083-4976-b23c-d29b72471a59)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/483ac078-b8df-4977-aaf9-91412da087a5/5e066817-d083-4976-b23c-d29b72471a59)

**UI component breakdown**

![Dragon — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/fa89512a-0b00-4734-97c2-58b13d40da84/ddcfb34d-6fe5-4578-84b0-1766619f7a0d)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/fa89512a-0b00-4734-97c2-58b13d40da84/ddcfb34d-6fe5-4578-84b0-1766619f7a0d)

### Dark

**Example companion:** Umbreon.

Nocturne: nearly black charcoal #171719 canvas, graphite #272629 surfaces, warm pearl #EEE9DF text, muted moon-gold #B7A575 accent. Restrained matte controls, barely rounded 8px corners, quiet high-contrast selection and thin warm neutral rules. One small crescent/ring detail beside companion. Understated monochrome and gold; distinguish from Dragon by removing heraldic geometry and blue-violet colour.

**Screen concept**

![Dark — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/f6cd5f6f-b9d0-4946-aa16-7a9c493b53c1/8d14e275-005d-4245-800e-c74243655757)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/f6cd5f6f-b9d0-4946-aa16-7a9c493b53c1/8d14e275-005d-4245-800e-c74243655757)

**UI component breakdown**

![Dark — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/1f2a0653-01ab-4a07-acc1-26420d290186/7b996aa9-6ca4-4db4-81ea-919fa053e740)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/1f2a0653-01ab-4a07-acc1-26420d290186/7b996aa9-6ca4-4db4-81ea-919fa053e740)

### Steel

**Example companion:** Magnemite.

Precision alloy: light cool-silver #EDF0F2 canvas, brushed-gray #D9DFE3 shell, gunmetal #2C3841 text, desaturated steel-blue #5C8493 accent. Clean 6px machined corners, exact 1px borders, flat panels with restrained metallic gradient only in shell, technical mono labels and readable native sans body. Tiny rivet-free concentric instrument marking by companion. Refined precision, no industrial clutter.

**Screen concept**

![Steel — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/f05e80a5-7004-4110-b489-573a06611b6a/6418499a-e5aa-4b1d-8d02-eb59293c96e7)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/f05e80a5-7004-4110-b489-573a06611b6a/6418499a-e5aa-4b1d-8d02-eb59293c96e7)

**UI component breakdown**

![Steel — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/d630a770-7a7b-4d6c-966c-80b5d0e7ffa4/4077e78b-b924-4008-b5f6-b6d86847cb43)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/d630a770-7a7b-4d6c-966c-80b5d0e7ffa4/4077e78b-b924-4008-b5f6-b6d86847cb43)

### Fairy

**Example companion:** Clefairy.

Rose quartz: blush-white #FFF4F5 canvas, petal-pink #F0DDE8 shell, dark mulberry #633D5C ink, raspberry-rose #BC709F accent, whisper of lilac. Soft 14px rounded controls, delicate fine borders, one tiny star-petal sparkle detail in companion strip, polished rounded sans. Gentle magical warmth, grown-up and readable, no glitter shower, heart overload, pastel low contrast, or cartoon toy controls.

**Screen concept**

![Fairy — screen concept](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/e7ead920-4ccd-4719-a61f-5bceebf17e19/9ed652ed-dcc4-4aaf-9110-5056572f7b5c)

[Open original screen image](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/e7ead920-4ccd-4719-a61f-5bceebf17e19/9ed652ed-dcc4-4aaf-9110-5056572f7b5c)

**UI component breakdown**

![Fairy — UI component breakdown](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/85087fad-bc9f-47a7-ad14-59f6ae8aaa8d/21790925-0bbf-4fb4-bbd9-a4cc3a4b7dfc)

[Open original component sheet](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/85087fad-bc9f-47a7-ad14-59f6ae8aaa8d/21790925-0bbf-4fb4-bbd9-a4cc3a4b7dfc)

## Review notes before implementation

- These are static, AI-generated design mockups. They do not establish final component measurements, colour tokens, typography, or production behaviour.
- The earlier style sheets contain some Start controls with pause glyphs; use a play triangle for Start/Resume and two bars for Pause. The Pokémon-type sheets were prompted with this correction.
- Ocean Glass needs a clearer enabled-toggle example. Confirmation copy must match the actual reset behaviour.
- Some sample values and colour codes differ between screen and component images. Use the written art directions to guide refinement, then define one verified token set per chosen preset.
- Red error, green success, and amber warning meanings must remain recognisable, with labels or icons as well as colour. Decorative accents must not erase workflow, priority, rarity, or chart-series distinctions.
- Full-colour Pokémon sprites should retain their identity. Keep scenery and elemental decoration near the companion, with quiet surfaces behind task text and controls.
- The gallery is not a complete light/dark pair for each preset. The selected shipping presets need deliberate palettes for both appearances, plus actual-size, keyboard, contrast, and reduced-motion validation.
- No app build or runtime validation was performed for this design work. The proposal's acceptance checklist is the implementation validation target.

## Source materials and related project documents

[Download the source proposal, prompts, art directions, and manifests (.zip)](https://uploads.linear.app/a141582e-95cc-44d1-be9a-788a5efdeb3c/0ca826e2-0880-4f1b-8f85-de087a1bf211/41ea1a16-9bdd-462e-9411-ed82115f7b91)

The source archive contains the original feature proposal; gallery indexes; screen and component generation prompts; all eighteen written type art directions; and the Pokémon-type image manifest. The original images are embedded individually in this document and attached to the existing [Create New Design Changes Document issue](https://linear.app/spawn-audio/issue/PER-193/create-new-design-changes-document).

Related project context:

- [UI Overhaul v2](https://linear.app/spawn-audio/document/ui-overhaul-v2-46c9d567cbb8)
- [PTB - UI & Feature Changes](https://linear.app/spawn-audio/document/ptb-ui-and-feature-changes-126970aa7332)
- [PTB - UI Motion & Animation Outline](https://linear.app/spawn-audio/document/ptb-ui-motion-and-animation-outline-6da069c18ba5)
- [Session Timer + Today desk](https://linear.app/spawn-audio/document/session-timer-today-desk-18c1e55bd90a)

Local source folder: `Documents/theme-concepts/`. Original proposal: `docs/reference/themes-feature-proposal.md`.
