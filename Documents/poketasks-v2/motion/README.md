# PokeTasks v2 — animation mockup videos

Planning studies, 1 October 2026. These are rendered concepts; the app's code,
preferences, session state, and Linear issue statuses are unchanged.

| Video | Length | Demonstrates |
| -- | -- | -- |
| [Workspace motion](workspace-motion.mp4) | 22 s | Nearby-hover utility reveal, right-click Fold all, coordinated disclosure folding, icon-only navigation, width restoration, rounded scroll clipping. |
| [Today and timeline](today-timeline-motion.mp4) | 26 s | Independent timeline folding, section disclosures, Fold all, direct block movement/resizing, immediate duration feedback. |
| [Floating timer](floating-timer-motion.mp4) | 18 s | Actions over the title, fixed bounds/clock anchor, title restoration, keyboard focus reveal. |
| [Combined preview](poketasks-v2-motion-preview.mp4) | 66 s | All three films in the order above, with chapter markers. |

All clips are silent H.264 MP4, 1440 × 1000, 60 fps, with normal-speed scenes,
explicitly marked quarter-speed replay, and Reduced Motion examples.

## Visual constraints

- Workspace cards use pixels from the supplied current Projects screenshot.
  Disclosure clips hide/reveal those cards; they are not new card designs.
- Today uses the supplied planning mockup as a layout study. Counts, task
  identities, and status badges are illustrative. The native issue component
  remains the implementation baseline. The Soon sample has a separate fictional
  identity; folding changes presentation only.
- Timer states use the revised rest/hover study; only the title/action slot
  changes. Its clock is intentionally frozen at 24:18 to inspect the anchor.
  The native More button replaces the baked still-image pointer in the film.
- Card text keeps a fixed reading width in these videos. They demonstrate panel
  movement and clipping, not final text reflow at every window size.
- Source pictures are kept intact. The standalone renderer reuses the existing
  AppKit/CoreGraphics → MP4 approach in the repository's motion previews.

## Scene times

Workspace: normal-speed scenes 0–14 s; quarter-speed sidebar replay 14–18 s;
Reduced Motion 18–22 s. Disclosure 160 ms; navigation 220 ms; nearby-hover reveal
90 ms. Scroll movement 12–14 s demonstrates the rounded viewport boundary.

Today: normal-speed scenes 0–18 s; quarter-speed timeline replay 18–22 s;
Reduced Motion 22–26 s. Timeline 200 ms; sections 160 ms. Drag/resize 13–16 s
uses the same pointer displacement as the block geometry; durations snap to
five-minute increments.

Timer: normal-speed scenes 0–9 s; quarter-speed reveal replay 9–13 s; Reduced
Motion 13–18 s. Title/actions crossfade within one fixed slot over 120 ms.

## Reproduce

Run from the worktree:

```sh
xcrun swiftc Documents/poketasks-v2/motion/render.swift \
  -module-cache-path /private/tmp/poketasks-v2-motion-module-cache \
  -o Documents/poketasks-v2/motion/render
Documents/poketasks-v2/motion/render Documents/poketasks-v2 --check
Documents/poketasks-v2/motion/render Documents/poketasks-v2
```

The renderer's self-check validates easing endpoints and Reduced Motion swaps,
then writes preview frames for review. Movie metadata, complete decoding, and
selected transitions are checked separately before publication. These checks
do not prove native runtime smoothness, pointer capture, accessibility, live
sync, or installed-app behavior.

The canonical motion owner is [UI Motion & Animation Outline](https://linear.app/spawn-audio/document/ui-motion-and-animation-outline-c51cbefca508).
