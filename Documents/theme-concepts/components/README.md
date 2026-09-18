# Theme component mockups

Eight static component sheets expand the themes explored in this task. Each uses the corresponding concept image as its visual reference. Generated with the built-in Image Gen tool on 2026-09-18.

These are design mockups, not implemented components or verified accessibility specifications.

## Sheets

- [Classic](classic-components.png)
- [Habitat](habitat-components.png)
- [Retro](retro-components.png)
- [Pokédex](pokedex-components.png)
- [Midnight Observatory](midnight-observatory-components.png)
- [Paper Journal](paper-journal-components.png)
- [Ocean Glass](ocean-glass-components.png)
- [Neon Arcade](neon-arcade-components.png)

## Element families

| Group | Mockup coverage |
|---|---|
| Foundations | Canvas, surface, text, accent, border, selected fill, headings, body text, timer numerals |
| Actions | Primary, secondary, plain, destructive, and icon controls; hover, pressed, disabled, and keyboard focus |
| Navigation | Root tabs, Collection segments, back navigation, disclosure states |
| Text inputs | Task title, focused field, masked credential field, multiline session note, validation |
| Choice controls | Toggles, checkboxes, slider, picker label, open selection menu |
| Rows and inspector | Task rows, selection, pin indicator, property label/value rows |
| Badges and status | Workflow status, priority, rarity, overtime warning |
| Progress and score | XP bar, XP/Coins totals, miniature usage chart, spinner |
| Companion and items | Companion card, selected Pokédex tile, egg/item tile, purchase control |
| Focus timer | Running, paused, overtime, duration selection |
| Floating chrome | Timer island, folded countdown, speech bubble, tooltip |
| Feedback and confirmation | Reset confirmation, success, error/retry, warning |
| Empty, loading and log | Empty task list, loading placeholder, session log, note row |

The sheets group these into twelve specimen areas, with foundations in the header. Inspect the full-resolution files to compare details. An image may simplify individual sample controls; the inventory above is the intended scope for a future implementation.

## Source grounding

The inventory was drawn from the app's shared chrome, Settings, Linear issue controls/composer, companion and collection views, and floating session overlay. Existing workflows and semantic status colours should guide implementation. Theme styling must not override the meaning of errors, warnings, or completion.

Native menus, tooltips, and other system-owned surfaces are visual references here; actual customisation should preserve native behaviour and available macOS appearance support.

## Refinements before implementation

The visual review confirmed all twelve specimen groups are present on each sheet. Generated details still need normal design refinement: several Start buttons show a pause glyph and should use a play glyph; confirmation copy must match the actual reset behaviour; Ocean Glass needs a clearer enabled-toggle sample. Palette codes, font names, chart labels, and sample values shown inside the images are illustrative, not an approved specification. Keyboard behaviour, contrast, and actual-size readability need validation in the implemented app.

[Generation prompts](prompts.md) retain the shared component specification and each theme direction. [Return to theme concepts](../README.md).
