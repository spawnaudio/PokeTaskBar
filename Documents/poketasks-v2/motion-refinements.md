# PokeTasks v2 — motion refinements

Source: [UI Motion & Animation Outline](https://linear.app/spawn-audio/document/ui-motion-and-animation-outline-c51cbefca508)

## PokeTasks v2 — reveal and folding refinements, 1 October 2026

**Planning additions; no native motion changes are claimed.** Reuse the timings and interruptible transitions above.

* Left navigation folds to a stable icon rail while the canvas expands; the independently folded timeline restores its preferred width. Clip labels during transition rather than compressing them.
* Fold all / Unfold all updates one scoped presentation state and animates together. No cascading per-card stagger. Maintain rounded viewport corners throughout the transition.
* Reveal secondary controls on approach to their fixed hit region or keyboard focus. Reuse the existing intent/exit grace so pointer crossings do not flicker; keep them visible during menus and dragging.
* Floating timer actions crossfade over the title within the same bounds. Keep the clock anchor fixed and exclude per-second clock ticks from the transition. Reduced Motion can swap title/actions immediately.
* Verify quick reversals, keyboard focus recovery, minimum sizes, and Reduced Motion in the native implementation. A still mockup cannot prove runtime smoothness.

The [Foundations document](<https://linear.app/spawn-audio/document/ui-overhaul-v2-foundations-and-shared-interaction-language-e25429d73e2c>) owns the shared menu and hover rules; [Focus & Floating Timer](<https://linear.app/spawn-audio/document/ui-overhaul-v2-focus-and-floating-timer-fcd3495bbc65>) owns the exact overlay behavior.

## Animation previews

Three feature clips and a 66-second chaptered preview are in [the motion folder](motion/README.md). Each includes normal-speed scenes, marked quarter-speed replay, and Reduced Motion examples. All four exports passed complete decoding and metadata checks. The timer clock pixels match at rest and hover.

The combined preview and workspace film are embedded in the canonical Motion outline. The Today/timeline and timer films are embedded in their feature owners. All four are indexed in Linear; publication checks are in `motion-publication-verification.json`. These are rendered concepts, with no native runtime or installed-app validation.
