# Floating battle prototype — design QA

final result: passed

Scope: browser prototype preparation, not native application integration. No actionable P0/P1/P2 findings remain in the demonstrated flow. Minor visual differences are listed below; this is not a pixel-identical reproduction of the generated artwork.

## Current rollback and animation proof — October 2

The user rejected the Emerald UI restyle and requested the earlier appearance with animations retained. Restored the v1 teal ridge frame, Pixelify Sans, generated arena/trainer, plain HP/XP bars, original item icons and blue command selection. Removed the replacement UI font, cursor, health card, tile graphics and their preparation tool. Earlier restyle captures are historical, unselected evidence in `evidence/emerald-v2/`.

Current evidence is `evidence/animations-v1/`. Reviewed `rollback-comparison.png` beside the previous v1 idle capture, and `restored-states.png` covering idle, running, muted pause, zero HP, potion bag and Full Restore. Layout, assets, colours and copy retain the previous appearance. Current default browser viewport was 1280 × 720, with full-page crops based on measured rectangles and zero scroll offset.

- Kept stepped Lapras movement, original two-frame opponents, button hover/press feedback and the brief potion-use flash. The final mockup is `mockups/battle-animated.gif`, recorded from 20 live browser screenshots. `motion-samples.json` confirms both movement offsets and both opponent frames.
- Verified all three sprite surfaces report paused animation state during pause and at zero HP. The paused numeric clock stayed unchanged. Zero HP has a truly empty fill; HP/XP widths update immediately so pause and expiry never leave a bar animating between values. Reduced-motion guards remain in the stylesheet; no system preference emulation was performed.
- Verified sprite images load, potion use resumes from zero, the potion flash is attached, and button transforms have the stepped transition. The 360 × 180 actual-size expiry frame contains all four actions. Current browser warning/error log was empty after refresh.
- Reran the existing session flow check successfully and rebuilt the final source successfully. These remain browser checks; native integration is still pending.

final result: passed

## Original v1 comparison evidence

The selected visual truth is `references/`. Final browser screenshots are `evidence/*-final-page.png`; corresponding `*-rect.json` files record the measured game rectangle in document coordinates. The verified game crops and comparison boards are in the same folder.

| State | Selected reference | Combined source/implementation comparison |
|---|---|---|
| Trainer idle | `references/idle.png` | `evidence/comparison-idle.png` |
| Muted pause | `references/paused.png` | `evidence/comparison-paused.png` |
| Zero HP | `references/zero-hp.png` | `evidence/comparison-zero-hp.png` |
| Hyper Potion selected | `references/potion-bag.png` | `evidence/comparison-potion-bag.png` |
| Full Restore, 20 extra minutes | `references/full-restore.png` | `evidence/comparison-full-restore.png` |
| Restored after Hyper Potion | `references/restored.png` | `evidence/comparison-restored.png` |

All six combined boards were opened and visually reviewed after capture. Focused comparisons were also reviewed: `evidence/comparison-copy-and-controls.png` for the two-line expiry dialogue and four actions, and `evidence/comparison-hp-and-xp.png` for empty HP and unchanged XP.

Browser viewport: 1000 × 800 CSS pixels, device scale factor 1. Normal logical game size: 360 × 180; bag: 360 × 260; Full Restore: 360 × 200. Detail mode scales these frames to 720 × 360, 720 × 520 and 720 × 400 raster pixels. Full-page captures are 1000 pixels wide; page heights vary with expanded content. Crops include document scroll offsets, so controls are not cut off by a viewport-relative crop.

Source images: idle/paused/zero/restored 1774 × 887, bag 1476 × 1065, Full Restore 1681 × 936. References were normalized to the same game-frame dimensions for comparison, removing only their arbitrary generation density. The bag and Full Restore aspect ratios closely match their logical targets. Actual-size proof is `evidence/idle-actual-page.png`, with a measured 360 × 180 frame. Long-title evidence is `evidence/actual-size-long-title-page.png`.

## Findings and comparison history

1. **[P2, fixed] Bag and custom-form hierarchy.** The first combined comparison showed undersized headings and too much space assigned to bag rows. Evidence: `evidence/before-refinement-potion-bag.png` and `evidence/before-refinement-full-restore.png`. Increased these headings from 14 to 18 points, gave the header 36 points, and reduced bag rows from 30 to 26 points. Rebalanced the Full Restore form within its 200-point height. Revised evidence: the final bag and Full Restore comparison boards above.
2. **[P2, fixed] Dialogue/action proportions.** The first combined comparison showed an oversized one-line dialogue strip and shorter action buttons. Evidence: `evidence/before-refinement-zero-hp.png`. The normal strip is now 22 points with 32-point commands. A subsequent capture exposed clipping of the second expiry line; zero HP now retains a 28-point strip with 26-point commands. Revised evidence: `evidence/comparison-zero-hp.png` and the focused copy/control comparison. Both expiry lines and all four actions are visible.
3. **Browser/flow fixes before the comparison gate.** Added stable command keys to remove the React warning, moved keyboard focus when opening a form/menu, separated the duration draft so Cancel discards edits, and refreshed the preview after its source cache became stale. These were functional fixes, not counted as visual QA iterations.

## Required fidelity surfaces

- **Typography:** bundled Pixelify Sans provides readable pixel-style text with a monospace fallback. Header, species, timer, bars, dialogue and controls keep the source hierarchy. Titles remain single-line with truncation and a full-title tooltip. Larger bag/custom headings now match their role in the references. Letter shapes and the clock weight are slightly rounder/heavier than the generated font; classify this as P3 polish rather than claiming an exact font match.
- **Spacing/layout:** compact frame sizes remain fixed; the trainer/player, central stats and opponent keep their source placement. Bag rows, expanded headings and two-line expiry copy fit. Every normal command lies inside the measured frame. Full Restore uses a native numeric stepper in place of separate drawn plus/minus buttons, an intentional prototype control choice.
- **Colors/tokens:** teal frame/separators (`#09607b`), cream panels (`#f2f0d5`), mint arena/bag and blue selections preserve the reference palette. Pause applies 50% grayscale plus muted saturation to the entire game. HP uses green/yellow/red thresholds and an empty red outline at zero; XP stays blue and unchanged during potion use.
- **Images:** generated trainer and arena assets are present, with trainer transparency and undistorted arena cover cropping. Pokémon and items use supplied game sprites with pixel sampling; opponent animation uses original two-frame sheets. The rear-facing Lapras and actual item sprites intentionally replace Image Gen's illustrative species/items; sources and sizes are documented in `asset-sources.md`. No illustrated asset is replaced by CSS or SVG art.
- **Copy/content:** the exact idle challenge, muted pause message, two-line expiry dialogue, Rest/Use a Potion/Forfeit semantics, item counts/effects and restoration acknowledgement are represented. Older mock labels “Finish” and “Add time” use the later agreed Rest/potion terminology. A Shop shortcut is included for the requested empty-bag flow.

## Interaction and build proof

- Runnable flow check passed: `node tests/session.test.mjs`. It covers expiry, all five potions, paused use, custom validation, whole-effect time-cap rejection, buying, Rest and Forfeit.
- Browser checks passed: start/pause/resume; Hyper Potion from zero; Full Restore while paused; invalid custom input and Escape without consumption; empty bag → Shop → buy → use; disabled use at the time cap; completion failure/retry; Forfeit confirmation/cancel; Rest settlement; duration Cancel; long-title visibility and keyboard focus. A 400 × 650 viewport was also exercised during the flow pass; the final long-title capture uses the normal 1000 × 800 viewport.
- Final source was explicitly refreshed. Browser warning/error logs were checked after that refresh: none. Earlier React key warnings remain historical browser log entries and were fixed.
- Final static build passed: `npm run build`. No native Swift tests, app installation, live Linear requests, durable inventory transactions or real shop purchases were performed.

## Follow-up polish

- **[P3]** Confirm Pixelify Sans optical size, sprite scale and image sampling on both Retina and 1× native displays.

## Implementation checklist

- [x] Compare source and rendered screens at normalized density, including focused copy/bar regions.
- [x] Resolve all observed P0/P1/P2 visual findings and capture the result again.
- [x] Verify core interactions, real-size controls, browser logs and static build.
- [ ] Follow `implementation-plan.md` for native integration and its distinct verification requirements.
