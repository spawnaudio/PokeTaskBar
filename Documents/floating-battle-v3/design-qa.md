# Floating battle — mockup fidelity QA

final result: passed

Source: the user's three selected mockup crops in `references/chrome-{window,controls,bars}.png`. Scope: buttons, HP/XP bars and window framing in the browser prototype, with existing artwork, font and animations retained.

## Visual comparison

| Surface | Result |
|---|---|
| Typography | Original Pixelify Sans retained. All four commands fit at actual size, including Use a Potion. |
| Layout | Battle stays 360 × 180; bag/shop 360 × 260; Full Restore 360 × 200. Both zero-HP dialogue lines and all actions fit. A 400 × 650 viewport has no horizontal overflow. |
| Colors and framing | Source-derived layered blue frame, cream inset panels, blue selected controls, dark HP/XP outlines and shaded fills match the supplied crops closely. Pause keeps muted colors. |
| Imagery | Transparent nine-slice assets reuse mockup border pixels and selection cursor; all text, values and interaction remain live. Existing trainer, arena, item icons and Pokémon are retained. |
| Copy and behavior | Existing task, potion and completion wording retained. Potion amounts, owned quantities and restored HP remain live. |

The first comparison found two P2 issues: the HP/XP slices lost their dark outlines, and cream pixels narrowed the blue window edge. Both were corrected and checked in the final source/render comparisons. Fresh captures after reloading resolved stale compositor images around filtered state changes; the final zero-HP capture shows the complete window.

Remaining P3 visual differences are deliberate: the original font and real item/species sprites differ from the illustrative mockup artwork. The bag keeps its existing Shop shortcut alongside Use item and Back.

## Evidence and checks

- Before/after and source/render comparisons: `evidence/mockup-fidelity/{before-refinement-comparison,comparison}-{bag,controls,bars}.png`.
- Final idle, running, paused, zero HP, bag and Full Restore captures: `evidence/mockup-fidelity/states.png`; compact proof: `compact-zero-hp.png` in the same folder.
- Twenty browser motion samples show stepped player movement and opponent frame changes. Paused animation states were paused and the countdown stayed fixed. Existing pause/zero and reduced-motion CSS guards are retained.
- `node tests/session.test.mjs` passed expiry, all five potions, paused use, custom validation, full-effect cap, purchase, Rest and Forfeit.
- `npm run build` passed after the final frame/bar refinements.
- Current rendered mockup exports: `mockups/mockup-matched.png` and `mockups/mockup-matched.gif`.

This proof covers the local browser prototype. Native application integration remains in the implementation plan.

Latest bar adjustment: removed the visible XP percentage. Browser measurements confirm both tracks are 127 × 10 pixels with the same left edge; XP retains its accessible value. No browser warnings/errors were captured, and the build passed. Proof: `evidence/equal-bars.json`, `evidence/equal-bars-page.jpg` and `mockups/equal-bars.png`.
